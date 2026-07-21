///|
fn extended_json_parsing_fails(value : Json) -> Bool {
  try Bson::from_extended_json(value) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "ObjectId hexadecimal conversion" {
  let text = "00112233445566778899aabb"
  let object_id = ObjectId::from_hex(text)
  assert_eq(object_id.to_hex(), text)
  assert_eq(
    object_id.bytes(),
    b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb",
  )
}

///|
test "canonical Extended JSON numeric wrappers" {
  let document = Document::new()
    .set("i32", Int32(-1))
    .set("i64", Int64(9223372036854775807L))
    .set("double", Double(1.0))
  let json = document.to_extended_json()
  let expected = Json::object(
    Map([
      ("i32", Json::object(Map([("$numberInt", Json::string("-1"))]))),
      (
        "i64",
        Json::object(
          Map([("$numberLong", Json::string("9223372036854775807"))]),
        ),
      ),
      ("double", Json::object(Map([("$numberDouble", Json::string("1.0"))]))),
    ]),
  )
  assert_eq(json, expected)
  assert_eq(Document::from_extended_json(json), document)
}

///|
test "canonical Extended JSON special doubles" {
  assert_eq(
    Bson::Double(@double.not_a_number).to_extended_json(),
    Json::object(Map([("$numberDouble", Json::string("NaN"))])),
  )
  assert_eq(
    Bson::Double(@double.infinity).to_extended_json(),
    Json::object(Map([("$numberDouble", Json::string("Infinity"))])),
  )
  assert_eq(
    Bson::Double(-0.0).to_extended_json(),
    Json::object(Map([("$numberDouble", Json::string("-0.0"))])),
  )
}

///|
test "canonical Extended JSON complex values roundtrip" {
  let id = ObjectId::from_hex("00112233445566778899aabb")
  let scope = Document::new().set("x", Int32(1))
  let document = Document::new()
    .set("binary", Binary(Binary::new(Uuid, b"0123456789abcdef")))
    .set("oid", ObjectId(id))
    .set("date", DateTime(DateTime::from_millis(-1L)))
    .set("regex", Regex(Regex::new("a.*", "im")))
    .set("timestamp", Timestamp(Timestamp::new(0xFFFFFFFFU, 7U)))
    .set(
      "code",
      JavaScriptWithScope(JavaScriptWithScope::new("return x", scope)),
    )
    .set("db", DbPointer(DbPointer::new("db.collection", id)))
    .set("undefined", Undefined)
    .set("symbol", Symbol("legacy"))
    .set("min", MinKey)
    .set("max", MaxKey)
  let json = document.to_extended_json()
  assert_eq(Document::from_extended_json(json), document)
}

///|
test "Extended JSON string entry points" {
  let source = "{\"i\":{\"$numberInt\":\"42\"},\"a\":[true,null,\"x\"]}"
  let document = Document::from_extended_json_string(source)
  assert_eq(document.get_int32("i"), Some(42))
  assert_eq(document.get_array("a"), Some([Boolean(true), Null, String("x")]))
  assert_eq(
    Document::from_extended_json_string(document.to_extended_json_string()),
    document,
  )
}

///|
test "invalid Extended JSON is rejected" {
  let invalid_binary = Json::object(
    Map([
      (
        "$binary",
        Json::object(
          Map([("base64", Json::string("%%%")), ("subType", Json::string("00"))]),
        ),
      ),
    ]),
  )
  assert_true(extended_json_parsing_fails(invalid_binary))
  let invalid_timestamp = Json::object(
    Map([
      (
        "$timestamp",
        Json::object(
          Map([
            ("t", Json::number(-1.0, repr="-1")),
            ("i", Json::number(0.0, repr="0")),
          ]),
        ),
      ),
    ]),
  )
  assert_true(extended_json_parsing_fails(invalid_timestamp))
}

///|
test "Decimal128 Extended JSON uses canonical text" {
  let decimal = Decimal128::from_string("1.2500")
  let bson = Bson::Decimal128(decimal)
  let json = Json::object(Map([("$numberDecimal", Json::string("1.2500"))]))
  assert_eq(bson.to_extended_json(), json)
  assert_eq(bson.to_relaxed_extended_json(), json)
  assert_eq(Bson::from_extended_json(json), bson)
  assert_true(
    extended_json_parsing_fails(
      Json::object(Map([("$numberDecimal", Json::string("1.2.3"))])),
    ),
  )
}

///|
test "relaxed Extended JSON uses native finite numbers" {
  let document = Document::new()
    .set("i32", Int32(-1))
    .set("i64", Int64(9223372036854775807L))
    .set("double", Double(1.0))
    .set("nan", Double(@double.not_a_number))
  let expected = Json::object(
    Map([
      ("i32", Json::number(-1.0, repr="-1")),
      (
        "i64",
        Json::number(
          9223372036854775807L.to_double(),
          repr="9223372036854775807",
        ),
      ),
      ("double", Json::number(1.0, repr="1.0")),
      ("nan", Json::object(Map([("$numberDouble", Json::string("NaN"))]))),
    ]),
  )
  assert_eq(document.to_relaxed_extended_json(), expected)
}

///|
test "relaxed Extended JSON integers use the smallest exact BSON type" {
  let document = Document::from_extended_json_string(
    "{\"small\":1,\"i32max\":2147483647,\"i64\":2147483648,\"i64max\":9223372036854775807,\"fraction\":1.0}",
  )
  assert_eq(document.get("small"), Some(Int32(1)))
  assert_eq(document.get("i32max"), Some(Int32(2147483647)))
  assert_eq(document.get("i64"), Some(Int64(2147483648L)))
  assert_eq(document.get("i64max"), Some(Int64(9223372036854775807L)))
  assert_eq(document.get("fraction"), Some(Double(1.0)))
}

///|
test "known Extended JSON wrappers reject invalid value shapes" {
  for
    json in [
      Json::object(Map([("$numberLong", Json::number(5.0, repr="5"))])),
      Json::object(Map([("$oid", Json::number(1.0, repr="1"))])),
      Json::object(Map([("$date", Json::boolean(true))])),
      Json::object(
        Map([
          ("$code", Json::string("return x")),
          ("$scope", Json::string("not a document")),
        ]),
      ),
    ] {
    assert_true(extended_json_parsing_fails(json))
  }
  let unknown = Json::object(Map([("$unknown", Json::number(1.0, repr="1"))]))
  assert_eq(
    Bson::from_extended_json(unknown),
    Document(Document::new().set("$unknown", Int32(1))),
  )
}

///|
test "Extended JSON accepts one-digit binary subtype" {
  let json = Json::object(
    Map([
      (
        "$binary",
        Json::object(
          Map([("base64", Json::string("AQI=")), ("subType", Json::string("4"))]),
        ),
      ),
    ]),
  )
  assert_eq(
    Bson::from_extended_json(json),
    Binary(Binary::new(Uuid, b"\x01\x02")),
  )
}

///|
test "Extended JSON $uuid accepts canonical compact and URN forms" {
  let bytes = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  for
    text in [
      "00112233-4455-6677-8899-aabbccddeeff", "00112233445566778899aabbccddeeff",
      "urn:uuid:00112233-4455-6677-8899-aabbccddeeff",
    ] {
    assert_eq(
      Bson::from_extended_json(
        Json::object(Map([("$uuid", Json::string(text))])),
      ),
      Binary(Binary::new(Uuid, bytes)),
    )
  }
}

///|
test "relaxed Extended JSON DateTime follows BSON corpus" {
  let cases : Array[(Int64, Json)] = [
    (0L, Json::string("1970-01-01T00:00:00Z")),
    (1356351330501L, Json::string("2012-12-24T12:15:30.501Z")),
    (1356351330001L, Json::string("2012-12-24T12:15:30.001Z")),
    (
      -284643869501L,
      Json::object(Map([("$numberLong", Json::string("-284643869501"))])),
    ),
    (
      253402300800000L,
      Json::object(Map([("$numberLong", Json::string("253402300800000"))])),
    ),
  ]
  for case in cases {
    let (milliseconds, expected_date) = case
    let expected = Json::object(Map([("$date", expected_date)]))
    assert_eq(
      Bson::DateTime(DateTime::from_millis(milliseconds)).to_relaxed_extended_json(),
      expected,
    )
  }
}

///|
test "relaxed Extended JSON parses RFC 3339 DateTime" {
  let cases : Array[(String, Int64)] = [
    ("1970-01-01T00:00:00Z", 0L),
    ("1970-01-01T01:00:00+01:00", 0L),
    ("1969-12-31T23:00:00-01:00", 0L),
    ("1970-01-01T00:00:00.123456789Z", 123L),
    ("2000-02-29T00:00:00Z", 951782400000L),
  ]
  for case in cases {
    let (text, expected) = case
    let json = Json::object(Map([("$date", Json::string(text))]))
    assert_eq(
      Bson::from_extended_json(json),
      DateTime(DateTime::from_millis(expected)),
    )
  }
}

///|
test "relaxed Extended JSON rejects invalid RFC 3339 DateTime" {
  for
    text in [
      "2023-02-29T00:00:00Z", "2024-13-01T00:00:00Z", "2024-01-01T24:00:00Z", "2024-01-01T00:00:00",
      "2024-01-01T00:00:00.1234567890Z",
    ] {
    assert_true(
      extended_json_parsing_fails(
        Json::object(Map([("$date", Json::string(text))])),
      ),
    )
  }
}

///|
test "Document writes to official Buffer" {
  let document = Document::new().set("x", Int32(1))
  let buffer = @buffer.Buffer()
  buffer.write_bytes(b"prefix")
  document.write_to(buffer)
  assert_true(buffer.to_bytes().has_prefix(b"prefix"[:]))
  let payload = buffer.to_bytes()[6:].to_owned()
  assert_eq(decode(payload), document)
}
