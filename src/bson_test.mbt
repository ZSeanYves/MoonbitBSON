///|
fn decoding_error(data : Bytes) -> BsonErrorInfo? {
  try decode(data) catch {
    Failure(info) => Some(info)
  } noraise {
    _ => None
  }
}

///|
fn encoding_error(document : Document) -> BsonErrorInfo? {
  try encode(document) catch {
    Failure(info) => Some(info)
  } noraise {
    _ => None
  }
}

///|
fn limited_encoding_fails(document : Document, options : EncodeOptions) -> Bool {
  try encode_with_options(document, options) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
fn limited_decoding_fails(data : Bytes, options : DecodeOptions) -> Bool {
  try decode_with_options(data, options) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
fn invalid_object_id_fails() -> Bool {
  try ObjectId::from_bytes(b"short") catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
fn invalid_decimal_fails() -> Bool {
  try Decimal128::from_bytes(b"short") catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "known BSON string fixture" {
  let expected = b"\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00"
  let document = Document::new().set("hello", String("world"))
  assert_eq(encode(document), expected)
  assert_eq(decode(expected), document)
}

///|
test "known BSON double fixture" {
  let expected = b"\x10\x00\x00\x00\x01x\x00\x00\x00\x00\x00\x00\x00\xf8\x3f\x00"
  let document = Document::new().set("x", Double(1.5))
  assert_eq(encode(document), expected)
  assert_eq(decode(expected), document)
}

///|
test "complete value model roundtrip" {
  let object_id = ObjectId::from_bytes(
    b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b",
  )
  let decimal = Decimal128::from_bytes(
    b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
  )
  let scope = Document::new().set("answer", Int32(42))
  let values : Array[(String, Bson)] = [
    ("double", Double(1.25)),
    ("string", String("MoonBit 月兔")),
    ("document", Document(Document::new().set("x", Int32(1)))),
    ("array", Array([String("a"), Int64(9223372036854775807L)])),
    ("binary", Binary(Binary::new(Generic, b"abc"))),
    ("binary-old", Binary(Binary::new(BinaryOld, b"old"))),
    ("undefined", Undefined),
    ("object-id", ObjectId(object_id)),
    ("false", Boolean(false)),
    ("true", Boolean(true)),
    ("datetime", DateTime(DateTime::from_millis(-123456789L))),
    ("null", Null),
    ("regex", Regex(Regex::new("a.*b", "im"))),
    ("db-pointer", DbPointer(DbPointer::new("db.collection", object_id))),
    ("javascript", JavaScript("return 1")),
    ("symbol", Symbol("legacy")),
    (
      "javascript-scope",
      JavaScriptWithScope(JavaScriptWithScope::new("return answer", scope)),
    ),
    ("int32", Int32(-2147483648)),
    ("timestamp", Timestamp(Timestamp::new(0xFFFFFFFFU, 0x80000000U))),
    ("int64", Int64(-9223372036854775807L - 1L)),
    ("decimal128", Decimal128(decimal)),
    ("min-key", MinKey),
    ("max-key", MaxKey),
  ]
  let document = Document::from_array(values)
  assert_eq(decode(encode(document)), document)
}

///|
test "decode_prefix reports consumed bytes" {
  let encoded = encode(Document::new().set("x", Int32(1)))
  let combined = encoded + b"tail"
  let (document, consumed) = decode_prefix(combined[:])
  assert_eq(consumed, encoded.length())
  assert_eq(document.get_int32("x"), Some(1))
}

///|
test "exact decode rejects trailing bytes" {
  let encoded = encode(Document::new()) + b"tail"
  let error = decoding_error(encoded).unwrap()
  assert_eq(error.kind(), TrailingData)
  assert_eq(error.offset(), 5)
}

///|
test "declared length is a hard boundary" {
  let error = decoding_error(b"\x06\x00\x00\x00\x00").unwrap()
  assert_eq(error.kind(), InvalidLength)
}

///|
test "early terminator is rejected" {
  let error = decoding_error(b"\x06\x00\x00\x00\x00\x00").unwrap()
  assert_eq(error.kind(), InvalidLength)
}

///|
test "boolean byte must be zero or one" {
  let data = b"\x09\x00\x00\x00\x08x\x00\x02\x00"
  let error = decoding_error(data).unwrap()
  assert_eq(error.kind(), InvalidBoolean)
  assert_eq(error.path(), "$.x")
}

///|
test "degenerate array keys normalize by default" {
  let data = b"\x14\x00\x00\x00\x04a\x00\x0c\x00\x00\x00\x10x\x00\x01\x00\x00\x00\x00\x00"
  let document = decode(data)
  assert_eq(document.get_array("a"), Some([Int32(1)]))
  let canonical = b"\x14\x00\x00\x00\x04a\x00\x0c\x00\x00\x00\x10\x30\x00\x01\x00\x00\x00\x00\x00"
  assert_eq(encode(document), canonical)
}

///|
test "strict array mode rejects noncanonical keys" {
  let data = b"\x14\x00\x00\x00\x04a\x00\x0c\x00\x00\x00\x10x\x00\x01\x00\x00\x00\x00\x00"
  let result = try
    decode_with_options(
      data,
      DecodeOptions::new(require_canonical_array_keys=true),
    )
  catch {
    Failure(info) => Some(info)
  } noraise {
    _ => None
  }
  let error = result.unwrap()
  assert_eq(error.kind(), InvalidArrayIndex)
  assert_eq(error.path(), "$.a")
}

///|
test "invalid UTF-8 is rejected" {
  let data = b"\x0e\x00\x00\x00\x02x\x00\x02\x00\x00\x00\xff\x00\x00"
  assert_eq(decoding_error(data).unwrap().kind(), InvalidUtf8)
}

///|
test "field names containing NUL are rejected" {
  let document = Document::new().set("bad\u0000key", Int32(1))
  assert_eq(encoding_error(document).unwrap().kind(), InvalidCString)
}

///|
test "regex options must be canonical" {
  let document = Document::new().set("r", Regex(Regex::new("x", "mi")))
  assert_eq(encoding_error(document).unwrap().kind(), InvalidRegex)
}

///|
test "depth limits apply to encoding and decoding" {
  let nested = Document::new().set(
    "outer",
    Document(Document::new().set("inner", Document(Document::new()))),
  )
  assert_true(limited_encoding_fails(nested, EncodeOptions::new(max_depth=1)))
  let bytes = encode(nested)
  assert_true(limited_decoding_fails(bytes, DecodeOptions::new(max_depth=1)))
}

///|
test "RawDocument validates and preserves bytes" {
  let bytes = encode(Document::new().set("x", Int64(2147483648L)))
  let raw = RawDocument::from_bytes(bytes)
  assert_eq(raw.bytes(), bytes)
  assert_eq(raw.to_document().get_int64("x"), Some(2147483648L))
}

///|
test "constructor lengths are validated" {
  assert_true(invalid_object_id_fails())
  assert_true(invalid_decimal_fails())
}
