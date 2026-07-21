///|
priv struct Decoder {
  data : BytesView
  mut position : Int
  options : DecodeOptions
}

///|
fn Decoder::new(data : BytesView, options : DecodeOptions) -> Decoder {
  { data, position: 0, options }
}

///|
/// Decode exactly one BSON document and reject trailing bytes.
pub fn decode(data : Bytes) -> Document raise BsonError {
  decode_with_options(data, DecodeOptions::new())
}

///|
pub fn decode_with_options(
  data : Bytes,
  options : DecodeOptions,
) -> Document raise BsonError {
  if data.length() > options.max_size {
    raise bson_error(SizeLimit, 0, "$", "BSON input exceeds max_size")
  }
  let decoder = Decoder::new(data[:], options)
  let document = decoder.read_document(data.length(), 0, "$")
  if decoder.position != data.length() {
    raise bson_error(
      TrailingData,
      decoder.position,
      "$",
      "trailing bytes after BSON document",
    )
  }
  document
}

///|
/// Decode the first document in a byte view and return the consumed byte count.
pub fn decode_prefix(data : BytesView) -> (Document, Int) raise BsonError {
  decode_prefix_with_options(data, DecodeOptions::new())
}

///|
pub fn decode_prefix_with_options(
  data : BytesView,
  options : DecodeOptions,
) -> (Document, Int) raise BsonError {
  let decoder = Decoder::new(data, options)
  let document = decoder.read_document(data.length(), 0, "$")
  (document, decoder.position)
}

///|
pub fn Document::from_bytes(data : Bytes) -> Document raise BsonError {
  decode(data)
}

///|
pub fn RawDocument::from_bytes(data : Bytes) -> RawDocument raise BsonError {
  let _ = decode(data)
  RawDocument::from_valid_bytes(data)
}

///|
pub fn RawDocument::to_document(self : RawDocument) -> Document raise BsonError {
  decode(self.bytes())
}

///|
pub fn RawDocument::from_prefix(
  data : BytesView,
) -> (RawDocument, Int) raise BsonError {
  let (_, consumed) = decode_prefix(data)
  let bytes = data[0:consumed].to_owned()
  (RawDocument::from_valid_bytes(bytes), consumed)
}

///|
fn Decoder::read_document(
  self : Decoder,
  outer_limit : Int,
  depth : Int,
  path : String,
) -> Document raise BsonError {
  if depth > self.options.max_depth {
    raise bson_error(
      DepthLimit,
      self.position,
      path,
      "maximum BSON nesting depth exceeded",
    )
  }
  let start = self.position
  let total_length = self.read_i32(outer_limit, path)
  let end = self.checked_container_end(start, total_length, outer_limit, path)
  let document = Document::new()
  while self.position < end - 1 {
    let type_offset = self.position
    let type_code = self.read_byte(end - 1, path)
    if type_code == 0x00 {
      raise bson_error(
        InvalidLength,
        type_offset,
        path,
        "document terminator appears before declared end",
      )
    }
    let key = self.read_cstring(end - 1, path)
    let value_path = field_path(path, key)
    document.set(key, self.read_element(type_code, end - 1, depth, value_path))
    |> ignore
  }
  self.read_terminator(end, path)
  document
}

///|
fn Decoder::read_array(
  self : Decoder,
  outer_limit : Int,
  depth : Int,
  path : String,
) -> Array[Bson] raise BsonError {
  if depth > self.options.max_depth {
    raise bson_error(
      DepthLimit,
      self.position,
      path,
      "maximum BSON nesting depth exceeded",
    )
  }
  let start = self.position
  let total_length = self.read_i32(outer_limit, path)
  let end = self.checked_container_end(start, total_length, outer_limit, path)
  let values : Array[Bson] = []
  while self.position < end - 1 {
    let type_offset = self.position
    let type_code = self.read_byte(end - 1, path)
    if type_code == 0x00 {
      raise bson_error(
        InvalidLength,
        type_offset,
        path,
        "array terminator appears before declared end",
      )
    }
    let key_offset = self.position
    let key = self.read_cstring(end - 1, path)
    let expected = values.length().to_string()
    if self.options.require_canonical_array_keys && key != expected {
      raise bson_error(
        InvalidArrayIndex,
        key_offset,
        path,
        "expected array key " + expected + ", found " + key,
      )
    }
    let value_path = index_path(path, values.length())
    values.push(self.read_element(type_code, end - 1, depth, value_path))
  }
  self.read_terminator(end, path)
  values
}

///|
fn Decoder::read_element(
  self : Decoder,
  type_code : Byte,
  limit : Int,
  depth : Int,
  path : String,
) -> Bson raise BsonError {
  match type_code {
    0x01 => Double(self.read_i64(limit, path).reinterpret_as_double())
    0x02 => String(self.read_string(limit, path))
    0x03 => Document(self.read_document(limit, depth + 1, path))
    0x04 => Array(self.read_array(limit, depth + 1, path))
    0x05 => Binary(self.read_binary(limit, path))
    0x06 => Undefined
    0x07 =>
      ObjectId(
        ObjectId::from_valid_bytes(self.read_bytes(12, limit, path).to_owned()),
      )
    0x08 => {
      let offset = self.position
      match self.read_byte(limit, path) {
        0 => Boolean(false)
        1 => Boolean(true)
        _ =>
          raise bson_error(
            InvalidBoolean,
            offset,
            path,
            "BSON boolean byte must be 0 or 1",
          )
      }
    }
    0x09 => DateTime(DateTime::from_millis(self.read_i64(limit, path)))
    0x0A => Null
    0x0B => {
      let pattern = self.read_cstring(limit, path)
      let options = self.read_cstring(limit, path)
      match normalize_regex_options(options) {
        Some(normalized) => Regex(Regex::new(pattern, normalized))
        None =>
          raise bson_error(
            InvalidRegex,
            self.position,
            path,
            "invalid BSON regex options",
          )
      }
    }
    0x0C =>
      DbPointer(
        DbPointer::new(
          self.read_string(limit, path),
          ObjectId::from_valid_bytes(
            self.read_bytes(12, limit, path).to_owned(),
          ),
        ),
      )
    0x0D => JavaScript(self.read_string(limit, path))
    0x0E => Symbol(self.read_string(limit, path))
    0x0F =>
      JavaScriptWithScope(
        self.read_javascript_with_scope(limit, depth + 1, path),
      )
    0x10 => Int32(self.read_i32(limit, path))
    0x11 => {
      let increment = self.read_u32(limit, path)
      let time = self.read_u32(limit, path)
      Timestamp(Timestamp::new(time, increment))
    }
    0x12 => Int64(self.read_i64(limit, path))
    0x13 =>
      Decimal128(
        Decimal128::from_valid_bytes(
          self.read_bytes(16, limit, path).to_owned(),
        ),
      )
    0x7F => MaxKey
    0xFF => MinKey
    _ =>
      raise bson_error(
        UnsupportedType,
        self.position - 1,
        path,
        "unsupported BSON type 0x" + type_code.to_hex(),
      )
  }
}

///|
fn Decoder::read_binary(
  self : Decoder,
  limit : Int,
  path : String,
) -> Binary raise BsonError {
  let length_offset = self.position
  let length = self.read_i32(limit, path)
  if length < 0 {
    raise bson_error(
      InvalidBinary,
      length_offset,
      path,
      "negative binary length",
    )
  }
  let subtype = BinarySubtype::from_byte(self.read_byte(limit, path))
  if subtype == BinaryOld {
    if length < 4 {
      raise bson_error(
        InvalidBinary,
        length_offset,
        path,
        "old binary subtype is shorter than its nested length",
      )
    }
    let nested_length = self.read_i32(limit, path)
    if nested_length != length - 4 {
      raise bson_error(
        InvalidBinary,
        length_offset,
        path,
        "old binary subtype lengths do not agree",
      )
    }
    Binary::new(subtype, self.read_bytes(nested_length, limit, path).to_owned())
  } else {
    Binary::new(subtype, self.read_bytes(length, limit, path).to_owned())
  }
}

///|
fn Decoder::read_javascript_with_scope(
  self : Decoder,
  outer_limit : Int,
  depth : Int,
  path : String,
) -> JavaScriptWithScope raise BsonError {
  let start = self.position
  let total_length = self.read_i32(outer_limit, path)
  if total_length < 14 || total_length > outer_limit - start {
    raise bson_error(
      InvalidLength,
      start,
      path,
      "invalid JavaScript-with-scope length",
    )
  }
  let end = start + total_length
  let code = self.read_string(end, path)
  let scope = self.read_document(end, depth, field_path(path, "$scope"))
  if self.position != end {
    raise bson_error(
      InvalidLength,
      self.position,
      path,
      "JavaScript-with-scope did not consume its declared length",
    )
  }
  JavaScriptWithScope::new(code, scope)
}

///|
fn Decoder::read_string(
  self : Decoder,
  limit : Int,
  path : String,
) -> String raise BsonError {
  let length_offset = self.position
  let length = self.read_i32(limit, path)
  if length <= 0 {
    raise bson_error(
      InvalidLength,
      length_offset,
      path,
      "invalid BSON string length",
    )
  }
  let bytes = self.read_bytes(length, limit, path)
  if bytes[length - 1] != 0x00 {
    raise bson_error(
      InvalidCString,
      self.position - 1,
      path,
      "BSON string is missing its NUL terminator",
    )
  }
  decode_utf8(bytes[0:length - 1], path)
}

///|
fn Decoder::read_cstring(
  self : Decoder,
  limit : Int,
  path : String,
) -> String raise BsonError {
  let start = self.position
  while self.position < limit {
    if self.data[self.position] == 0x00 {
      let bytes = self.data[start:self.position]
      self.position += 1
      return decode_utf8(bytes, path)
    }
    self.position += 1
  }
  raise bson_error(
    InvalidCString,
    start,
    path,
    "CString is missing its NUL terminator",
  )
}

///|
fn decode_utf8(bytes : BytesView, path : String) -> String raise BsonError {
  @utf8.decode(bytes) catch {
    _ =>
      raise bson_error(
        InvalidUtf8,
        bytes.start_offset(),
        path,
        "invalid UTF-8 byte sequence",
      )
  }
}

///|
fn Decoder::checked_container_end(
  self : Decoder,
  start : Int,
  total_length : Int,
  outer_limit : Int,
  path : String,
) -> Int raise BsonError {
  if total_length < 5 {
    raise bson_error(
      InvalidLength,
      start,
      path,
      "BSON container is shorter than 5 bytes",
    )
  }
  if total_length > self.options.max_size {
    raise bson_error(SizeLimit, start, path, "BSON container exceeds max_size")
  }
  if total_length > outer_limit - start {
    raise bson_error(
      InvalidLength,
      start,
      path,
      "BSON container exceeds its parent boundary",
    )
  }
  start + total_length
}

///|
fn Decoder::read_terminator(
  self : Decoder,
  end : Int,
  path : String,
) -> Unit raise BsonError {
  if self.position != end - 1 || self.read_byte(end, path) != 0x00 {
    raise bson_error(
      InvalidLength,
      self.position,
      path,
      "BSON container does not end at its declared boundary",
    )
  }
}

///|
fn Decoder::read_byte(
  self : Decoder,
  limit : Int,
  path : String,
) -> Byte raise BsonError {
  if self.position >= limit || self.position >= self.data.length() {
    raise bson_error(
      UnexpectedEnd,
      self.position,
      path,
      "unexpected end of BSON input",
    )
  }
  let value = self.data[self.position]
  self.position += 1
  value
}

///|
fn Decoder::read_bytes(
  self : Decoder,
  count : Int,
  limit : Int,
  path : String,
) -> BytesView raise BsonError {
  if count < 0 ||
    count > limit - self.position ||
    count > self.data.length() - self.position {
    raise bson_error(
      UnexpectedEnd,
      self.position,
      path,
      "unexpected end of BSON input",
    )
  }
  let start = self.position
  self.position += count
  self.data[start:self.position]
}

///|
fn Decoder::read_i32(
  self : Decoder,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let bytes = self.read_bytes(4, limit, path)
  bytes[0].to_int() |
  (bytes[1].to_int() << 8) |
  (bytes[2].to_int() << 16) |
  (bytes[3].to_int() << 24)
}

///|
fn Decoder::read_u32(
  self : Decoder,
  limit : Int,
  path : String,
) -> UInt raise BsonError {
  self.read_i32(limit, path).reinterpret_as_uint()
}

///|
fn Decoder::read_i64(
  self : Decoder,
  limit : Int,
  path : String,
) -> Int64 raise BsonError {
  let bytes = self.read_bytes(8, limit, path)
  let mut value : Int64 = 0L
  for index in 0..<8 {
    value = value | (bytes[index].to_int64() << (index * 8))
  }
  value
}
