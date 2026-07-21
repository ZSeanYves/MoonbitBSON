///|
priv enum ExtendedJsonMode {
  Canonical
  Relaxed
}

///|
/// Convert a document to Canonical Extended JSON.
pub fn Document::to_extended_json(self : Document) -> Json raise BsonError {
  document_to_extended_json(self, "$", Canonical)
}

///|
pub fn Document::to_extended_json_string(
  self : Document,
  indent? : Int,
) -> String raise BsonError {
  self.to_extended_json().stringify(indent?)
}

///|
/// Convert a document to Relaxed Extended JSON.
pub fn Document::to_relaxed_extended_json(
  self : Document,
) -> Json raise BsonError {
  document_to_extended_json(self, "$", Relaxed)
}

///|
pub fn Document::to_relaxed_extended_json_string(
  self : Document,
  indent? : Int,
) -> String raise BsonError {
  self.to_relaxed_extended_json().stringify(indent?)
}

///|
pub fn Document::from_extended_json(value : Json) -> Document raise BsonError {
  match bson_from_extended_json(value, "$") {
    Document(document) => document
    _ =>
      raise bson_error(
        TypeMismatch,
        -1,
        "$",
        "top-level Extended JSON must be a document",
      )
  }
}

///|
pub fn Document::from_extended_json_string(
  value : String,
) -> Document raise BsonError {
  let json = @json.parse(value) catch {
    _ => raise bson_error(InvalidExtendedJson, -1, "$", "invalid JSON text")
  }
  Document::from_extended_json(restore_json_number_reprs(json, value))
}

///|
pub fn Bson::to_extended_json(self : Bson) -> Json raise BsonError {
  bson_to_extended_json(self, "$", Canonical)
}

///|
/// Convert a BSON value to Relaxed Extended JSON.
pub fn Bson::to_relaxed_extended_json(self : Bson) -> Json raise BsonError {
  bson_to_extended_json(self, "$", Relaxed)
}

///|
pub fn Bson::from_extended_json(value : Json) -> Bson raise BsonError {
  bson_from_extended_json(value, "$")
}

///|
fn document_to_extended_json(
  document : Document,
  path : String,
  mode : ExtendedJsonMode,
) -> Json raise BsonError {
  let values : Array[(String, Json)] = []
  for entry in document.to_array() {
    let (key, value) = entry
    values.push(
      (key, bson_to_extended_json(value, field_path(path, key), mode)),
    )
  }
  Json::object(Map(values))
}

///|
fn bson_to_extended_json(
  value : Bson,
  path : String,
  mode : ExtendedJsonMode,
) -> Json raise BsonError {
  match value {
    Double(value) => double_to_extended_json(value, mode)
    String(value) => Json::string(value)
    Document(value) => document_to_extended_json(value, path, mode)
    Array(values) => {
      let result : Array[Json] = []
      for index, value in values {
        result.push(bson_to_extended_json(value, index_path(path, index), mode))
      }
      Json::array(result)
    }
    Binary(value) => {
      let inner : Array[(String, Json)] = [
        ("base64", Json::string(@base64.encode(value.bytes()[:], padding=true))),
        ("subType", Json::string(value.subtype().to_byte().to_hex())),
      ]
      tagged("$binary", Json::object(Map(inner)))
    }
    Undefined => tagged("$undefined", Json::boolean(true))
    ObjectId(value) => tagged_string("$oid", value.to_hex())
    Boolean(value) => Json::boolean(value)
    DateTime(value) => datetime_to_extended_json(value, mode)
    Null => Json::null()
    Regex(value) =>
      tagged(
        "$regularExpression",
        Json::object(
          Map([
            ("pattern", Json::string(value.pattern())),
            ("options", Json::string(value.options())),
          ]),
        ),
      )
    DbPointer(value) =>
      tagged(
        "$dbPointer",
        Json::object(
          Map([
            ("$ref", Json::string(value.collection())),
            ("$id", tagged_string("$oid", value.id().to_hex())),
          ]),
        ),
      )
    JavaScript(value) => tagged_string("$code", value)
    Symbol(value) => tagged_string("$symbol", value)
    JavaScriptWithScope(value) =>
      Json::object(
        Map([
          ("$code", Json::string(value.code())),
          ("$scope", document_to_extended_json(value.scope(), path, mode)),
        ]),
      )
    Int32(value) =>
      match mode {
        Canonical => tagged_string("$numberInt", value.to_string())
        Relaxed => Json::number(value.to_double(), repr=value.to_string())
      }
    Timestamp(value) =>
      tagged(
        "$timestamp",
        Json::object(
          Map([
            (
              "t",
              Json::number(
                value.time().to_double(),
                repr=value.time().to_string(),
              ),
            ),
            (
              "i",
              Json::number(
                value.increment().to_double(),
                repr=value.increment().to_string(),
              ),
            ),
          ]),
        ),
      )
    Int64(value) =>
      match mode {
        Canonical => tagged_string("$numberLong", value.to_string())
        Relaxed => Json::number(value.to_double(), repr=value.to_string())
      }
    Decimal128(value) => tagged_string("$numberDecimal", value.to_string())
    MinKey => tagged("$minKey", Json::number(1.0, repr="1"))
    MaxKey => tagged("$maxKey", Json::number(1.0, repr="1"))
  }
}

///|
fn bson_from_extended_json(value : Json, path : String) -> Bson raise BsonError {
  match value {
    String(value) => String(value)
    Number(value, repr~) => number_from_extended_json(value, repr, path)
    True => Boolean(true)
    False => Boolean(false)
    Null => Null
    Array(values) => {
      let result : Array[Bson] = []
      for index, value in values {
        result.push(bson_from_extended_json(value, index_path(path, index)))
      }
      Array(result)
    }
    Object(values) => object_from_extended_json(values, path)
  }
}

///|
fn object_from_extended_json(
  values : Map[String, Json],
  path : String,
) -> Bson raise BsonError {
  if values.length() == 1 {
    match values.to_array() {
      [("$numberInt", String(value))] => Int32(parse_int(value, path))
      [("$numberLong", String(value))] => Int64(parse_int64(value, path))
      [("$numberDouble", String(value))] => Double(parse_double(value, path))
      [("$numberDecimal", String(value))] =>
        Decimal128(
          Decimal128::from_string(value) catch {
            _ => invalid_extended(path, "invalid $numberDecimal")
          },
        )
      [("$oid", String(value))] => ObjectId(ObjectId::from_hex(value))
      [("$binary", Object(value))] => Binary(binary_from_json(value, path))
      [("$uuid", String(value))] => Binary(uuid_binary_from_json(value, path))
      [("$date", Object(value))] =>
        DateTime(DateTime::from_millis(date_from_json(value, path)))
      [("$date", String(value))] =>
        DateTime(DateTime::from_millis(parse_rfc3339_millis(value, path)))
      [("$regularExpression", Object(value))] =>
        Regex(regex_from_json(value, path))
      [("$timestamp", Object(value))] =>
        Timestamp(timestamp_from_json(value, path))
      [("$minKey", Number(value, ..))] if value == 1.0 => MinKey
      [("$maxKey", Number(value, ..))] if value == 1.0 => MaxKey
      [("$undefined", True)] => Undefined
      [("$symbol", String(value))] => Symbol(value)
      [("$code", String(value))] => JavaScript(value)
      [("$dbPointer", Object(value))] =>
        DbPointer(db_pointer_from_json(value, path))
      [(key, _)] if is_extended_json_wrapper_key(key) =>
        invalid_extended(path, "invalid Extended JSON wrapper " + key)
      _ => plain_document_from_json(values, path)
    }
  } else if values.length() == 2 {
    match (values.get("$code"), values.get("$scope")) {
      (Some(String(code)), Some(Object(scope))) =>
        JavaScriptWithScope(
          JavaScriptWithScope::new(
            code,
            plain_document_from_json_value(scope, field_path(path, "$scope")),
          ),
        )
      _ =>
        if contains_extended_json_wrapper_key(values) {
          invalid_extended(
            path, "Extended JSON wrapper contains invalid fields",
          )
        } else {
          plain_document_from_json(values, path)
        }
    }
  } else if contains_extended_json_wrapper_key(values) {
    invalid_extended(path, "Extended JSON wrapper contains invalid fields")
  } else {
    plain_document_from_json(values, path)
  }
}

///|
fn plain_document_from_json(
  values : Map[String, Json],
  path : String,
) -> Bson raise BsonError {
  Document(plain_document_from_json_value(values, path))
}

///|
fn plain_document_from_json_value(
  values : Map[String, Json],
  path : String,
) -> Document raise BsonError {
  let document = Document::new()
  for entry in values.to_array() {
    let (key, value) = entry
    if key.contains("\u0000") {
      return invalid_extended(path, "Extended JSON document key contains NUL")
    }
    document.set(key, bson_from_extended_json(value, field_path(path, key)))
    |> ignore
  }
  document
}

///|
fn binary_from_json(
  values : Map[String, Json],
  path : String,
) -> Binary raise BsonError {
  if values.length() != 2 {
    return invalid_extended(path, "$binary contains unexpected fields")
  }
  match (values.get("base64"), values.get("subType")) {
    (Some(String(encoded)), Some(String(subtype))) => {
      let bytes = @base64.decode(encoded) catch {
        _ =>
          raise bson_error(
            InvalidExtendedJson,
            -1,
            path,
            "invalid Extended JSON base64",
          )
      }
      Binary::new(
        BinarySubtype::from_byte(parse_hex_byte(subtype, path)),
        bytes,
      )
    }
    _ => invalid_extended(path, "$binary requires base64 and subType strings")
  }
}

///|
fn uuid_binary_from_json(
  value : String,
  path : String,
) -> Binary raise BsonError {
  Uuid::from_string(value).to_binary() catch {
    _ => invalid_extended(path, "invalid $uuid")
  }
}

///|
fn date_from_json(
  values : Map[String, Json],
  path : String,
) -> Int64 raise BsonError {
  match values.to_array() {
    [("$numberLong", String(value))] => parse_int64(value, path)
    _ => invalid_extended(path, "canonical $date requires $numberLong")
  }
}

///|
fn regex_from_json(
  values : Map[String, Json],
  path : String,
) -> Regex raise BsonError {
  if values.length() != 2 {
    return invalid_extended(
      path, "$regularExpression contains unexpected fields",
    )
  }
  match (values.get("pattern"), values.get("options")) {
    (Some(String(pattern)), Some(String(options))) => {
      if pattern.contains("\u0000") {
        raise bson_error(InvalidRegex, -1, path, "invalid Extended JSON regex")
      }
      match normalize_regex_options(options) {
        Some(normalized) => Regex::new(pattern, normalized)
        None =>
          raise bson_error(
            InvalidRegex,
            -1,
            path,
            "invalid Extended JSON regex",
          )
      }
    }
    _ =>
      invalid_extended(path, "$regularExpression requires pattern and options")
  }
}

///|
fn timestamp_from_json(
  values : Map[String, Json],
  path : String,
) -> Timestamp raise BsonError {
  match (values.get("t"), values.get("i")) {
    (Some(Number(time, ..)), Some(Number(increment, ..))) if values.length() ==
      2 =>
      Timestamp::new(
        timestamp_component(time, path),
        timestamp_component(increment, path),
      )
    _ => invalid_extended(path, "$timestamp requires numeric t and i")
  }
}

///|
fn db_pointer_from_json(
  values : Map[String, Json],
  path : String,
) -> DbPointer raise BsonError {
  if values.length() != 2 {
    return invalid_extended(path, "$dbPointer contains unexpected fields")
  }
  match (values.get("$ref"), values.get("$id")) {
    (Some(String(collection)), Some(Object(id))) =>
      match id.to_array() {
        [("$oid", String(hex))] =>
          DbPointer::new(collection, ObjectId::from_hex(hex))
        _ => invalid_extended(path, "$dbPointer.$id requires $oid")
      }
    _ => invalid_extended(path, "$dbPointer requires $ref and $id")
  }
}

///|
fn tagged(key : String, value : Json) -> Json {
  Json::object(Map([(key, value)]))
}

///|
fn tagged_string(key : String, value : String) -> Json {
  tagged(key, Json::string(value))
}

///|
fn double_to_extended_json(value : Double, mode : ExtendedJsonMode) -> Json {
  let text = canonical_double(value)
  match mode {
    Relaxed if !value.is_nan() && !value.is_inf() =>
      Json::number(value, repr=text)
    _ => tagged_string("$numberDouble", text)
  }
}

///|
fn datetime_to_extended_json(value : DateTime, mode : ExtendedJsonMode) -> Json {
  let milliseconds = value.to_millis()
  match mode {
    Relaxed =>
      match relaxed_datetime_string(milliseconds) {
        Some(text) => tagged_string("$date", text)
        None =>
          tagged(
            "$date",
            tagged_string("$numberLong", milliseconds.to_string()),
          )
      }
    Canonical =>
      tagged("$date", tagged_string("$numberLong", milliseconds.to_string()))
  }
}

///|
fn canonical_double(value : Double) -> String {
  if value.is_nan() {
    "NaN"
  } else if value.is_pos_inf() {
    "Infinity"
  } else if value.is_neg_inf() {
    "-Infinity"
  } else if value.reinterpret_as_int64() == -9223372036854775807L - 1L {
    "-0.0"
  } else {
    let text = value.to_string()
    if text.contains(".") || text.contains("e") || text.contains("E") {
      text
    } else {
      text + ".0"
    }
  }
}

///|
fn number_from_extended_json(
  value : Double,
  repr : String?,
  path : String,
) -> Bson raise BsonError {
  match repr {
    Some(text) if !text.contains(".") &&
      !text.contains("e") &&
      !text.contains("E") =>
      match parse_relaxed_integer(text) {
        Some(integer) if integer >= -2147483648L && integer <= 2147483647L =>
          Int32(integer.to_int())
        Some(integer) => Int64(integer)
        None => Double(value)
      }
    None if !value.is_nan() &&
      !value.is_inf() &&
      value.floor() == value &&
      value >= -9007199254740991.0 &&
      value <= 9007199254740991.0 => {
      let integer = value.to_int64()
      if integer >= -2147483648L && integer <= 2147483647L {
        Int32(integer.to_int())
      } else {
        Int64(integer)
      }
    }
    _ =>
      if value.is_nan() || value.is_inf() {
        invalid_extended(path, "JSON number is outside the finite Double range")
      } else {
        Double(value)
      }
  }
}

///|
fn parse_relaxed_integer(value : String) -> Int64? {
  try @strconv.from_str(value) catch {
    _ => None
  } noraise {
    integer => Some(integer)
  }
}

///|
fn is_extended_json_wrapper_key(key : String) -> Bool {
  match key {
    "$numberInt"
    | "$numberLong"
    | "$numberDouble"
    | "$numberDecimal"
    | "$oid"
    | "$binary"
    | "$uuid"
    | "$date"
    | "$regularExpression"
    | "$timestamp"
    | "$minKey"
    | "$maxKey"
    | "$undefined"
    | "$symbol"
    | "$code"
    | "$dbPointer" => true
    _ => false
  }
}

///|
fn contains_extended_json_wrapper_key(values : Map[String, Json]) -> Bool {
  for key in values.keys() {
    if is_extended_json_wrapper_key(key) {
      return true
    }
  }
  false
}

///|
fn parse_int(value : String, path : String) -> Int raise BsonError {
  @strconv.from_str(value) catch {
    _ => invalid_extended(path, "invalid $numberInt")
  }
}

///|
fn parse_int64(value : String, path : String) -> Int64 raise BsonError {
  @strconv.from_str(value) catch {
    _ => invalid_extended(path, "invalid $numberLong")
  }
}

///|
fn parse_double(value : String, path : String) -> Double raise BsonError {
  match value {
    "NaN" => @double.not_a_number
    "Infinity" => @double.infinity
    "-Infinity" => @double.neg_infinity
    _ =>
      @strconv.from_str(value) catch {
        _ => invalid_extended(path, "invalid $numberDouble")
      }
  }
}

///|
fn parse_hex_byte(value : String, path : String) -> Byte raise BsonError {
  match value.length() {
    1 =>
      match hex_nibble(value[0]) {
        Some(low) => low.to_byte()
        None => invalid_extended(path, "binary subType contains non-hex digits")
      }
    2 =>
      match (hex_nibble(value[0]), hex_nibble(value[1])) {
        (Some(high), Some(low)) => (high * 16 + low).to_byte()
        _ => invalid_extended(path, "binary subType contains non-hex digits")
      }
    _ =>
      invalid_extended(
        path, "binary subType must contain one or two hex digits",
      )
  }
}

///|
fn timestamp_component(value : Double, path : String) -> UInt raise BsonError {
  if value.is_nan() ||
    value.is_inf() ||
    value < 0.0 ||
    value > 4294967295.0 ||
    value.floor() != value {
    return invalid_extended(
      path, "$timestamp components must be unsigned 32-bit integers",
    )
  }
  UInt::trunc_double(value)
}

///|
fn[T] invalid_extended(path : String, message : String) -> T raise BsonError {
  raise bson_error(InvalidExtendedJson, -1, path, message)
}
