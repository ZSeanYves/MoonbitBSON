///|
fn required_type_error(document : Document) -> BsonErrorInfo? {
  try document.require_string("value") catch {
    Failure(info) => Some(info)
  } noraise {
    _ => None
  }
}

///|
fn invalid_object_id_hex(value : String) -> Bool {
  try ObjectId::from_hex(value) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "Document collection and typed access APIs" {
  let child = Document::new().set("x", Int32(1))
  let document = Document::new()
    .set("string", String("value"))
    .set("document", Document(child))
    .set("array", Array([Int32(1)]))
    .set("i32", Int32(1))
    .set("i64", Int64(2L))
    .set("double", Double(3.0))
    .set("bool", Boolean(true))
  assert_true(document.contains("string"))
  assert_eq(document.length(), 7)
  assert_eq(document.entries().length(), 7)
  assert_eq(document.require("string"), String("value"))
  assert_eq(document.require_string("string"), "value")
  assert_eq(document.require_document("document"), child)
  assert_eq(document.require_array("array"), [Int32(1)])
  assert_eq(document.require_int32("i32"), 1)
  assert_eq(document.require_int64("i64"), 2L)
  assert_eq(document.require_double("double"), 3.0)
  assert_eq(document.require_bool("bool"), true)
  document.remove("string")
  assert_false(document.contains("string"))
  assert_false(document.is_empty())
}

///|
test "typed access errors retain path and message" {
  let error = required_type_error(Document::new().set("value", Int32(1))).unwrap()
  assert_eq(error.kind(), TypeMismatch)
  assert_eq(error.path(), "$.value")
  assert_true(error.message().contains("string"))
}

///|
test "Bson accessors and names" {
  assert_eq(Bson::String("x").as_string(), Some("x"))
  assert_eq(
    Bson::Document(Document::new()).as_document(),
    Some(Document::new()),
  )
  assert_eq(Bson::Array([Null]).as_array(), Some([Null]))
  assert_eq(Bson::Int32(1).as_int32(), Some(1))
  assert_eq(Bson::Int64(2L).as_int64(), Some(2L))
  assert_eq(Bson::Double(3.0).as_double(), Some(3.0))
  assert_eq(Bson::Boolean(true).as_bool(), Some(true))
  assert_eq(Bson::Null.as_string(), None)
  assert_eq(
    Bson::Decimal128(Decimal128::from_bytes(Bytes::make(16, 0))).type_name(),
    "decimal128",
  )
}

///|
test "binary subtype byte mappings" {
  let expected : Array[(Byte, BinarySubtype)] = [
    (0x00, Generic),
    (0x01, Function),
    (0x02, BinaryOld),
    (0x03, UuidOld),
    (0x04, Uuid),
    (0x05, Md5),
    (0x06, Encrypted),
    (0x07, Column),
    (0x08, Sensitive),
    (0x09, Vector),
    (0x20, Reserved(0x20)),
    (0x80, UserDefined(0x80)),
  ]
  for entry in expected {
    let (byte, subtype) = entry
    assert_eq(BinarySubtype::from_byte(byte), subtype)
    assert_eq(subtype.to_byte(), byte)
  }
}

///|
test "ObjectId rejects malformed hexadecimal text" {
  assert_true(invalid_object_id_hex("short"))
  assert_true(invalid_object_id_hex("zz112233445566778899aabb"))
}

///|
test "options expose configured limits" {
  let encode_options = EncodeOptions::new(max_depth=4, max_size=1024)
  assert_eq(encode_options.max_depth(), 4)
  assert_eq(encode_options.max_size(), 1024)
  let decode_options = DecodeOptions::new(
    max_depth=5,
    max_size=2048,
    require_canonical_array_keys=true,
  )
  assert_eq(decode_options.max_depth(), 5)
  assert_eq(decode_options.max_size(), 2048)
  assert_true(decode_options.require_canonical_array_keys())
}

///|
test "typed DateTime ObjectId and UUID APIs" {
  let epoch = DateTime::from_millis(0L)
  assert_eq(epoch.to_millis(), 0L)
  assert_eq(epoch.to_rfc3339(), "1970-01-01T00:00:00Z")
  assert_eq(DateTime::from_rfc3339("1969-12-31T23:59:59.999Z").to_millis(), -1L)
  let object_id = ObjectId::from_parts(0x5F1D7F00U, b"abcde", 0x010203U)
  assert_eq(object_id.to_hex(), "5f1d7f006162636465010203")
  assert_eq(object_id.timestamp(), DateTime::from_millis(1595768576000L))
  let uuid = Uuid::from_string("00112233-4455-6677-8899-aabbccddeeff")
  assert_eq(uuid.to_string(), "00112233-4455-6677-8899-aabbccddeeff")
  assert_eq(Uuid::from_binary(uuid.to_binary()), uuid)
  assert_eq(Binary::new(Uuid, uuid.bytes()).as_uuid(), Some(uuid))
}

///|
test "ObjectId new uses secure entropy or reports unsupported host" {
  try ObjectId::new() catch {
    Failure(info) => assert_eq(info.kind(), UnsupportedEntropy)
  } noraise {
    value => assert_eq(value.bytes().length(), 12)
  }
}

///|
test "secure entropy provider validates and returns host bytes" {
  clear_secure_entropy_provider()
  install_secure_entropy_provider(fn(count : Int) -> Bytes? {
    Some(Bytes::make(count, 0xA5))
  })
  let entropy = secure_entropy_from_provider(8).unwrap()
  assert_eq(entropy.length(), 8)
  assert_eq(entropy[0], 0xA5)
  clear_secure_entropy_provider()
}

///|
test "generic BSON serialization traits" {
  let document = Document::new()
    .set("name", String("Ada"))
    .set("age", Int32(37))
  let encoded = serialize_to_bytes(document)
  let decoded : Document = deserialize_from_bytes(encoded)
  assert_eq(decoded, document)
  assert_eq(to_bson([1, 2, 3]), Array([Int32(1), Int32(2), Int32(3)]))
  let i64 : Int64 = from_bson(Int32(42))
  assert_eq(i64, 42L)
  let optional : Int? = None
  assert_eq(to_bson(optional), Null)
  let decoded_optional : Int? = from_bson(Null)
  assert_eq(decoded_optional, None)
}

///|
test "RawDocument prefix preserves only the first frame" {
  let first = encode(Document::new().set("x", Int32(1)))
  let framed = first + b"next frame"
  let (raw, consumed) = RawDocument::from_prefix(framed[:])
  assert_eq(consumed, first.length())
  assert_eq(raw.bytes(), first)
  assert_eq(raw.view().to_owned(), first)
}

///|
test "RawDocument exposes lazy element ranges" {
  let document = Document::new()
    .set("name", String("Ada"))
    .set("age", Int32(37))
    .set("nested", Document(Document::new().set("ok", Boolean(true))))
  let raw = RawDocument::from_bytes(document.to_bytes())
  let elements = raw.elements()
  assert_eq(elements.length(), 3)
  assert_eq(elements[0].key(), "name")
  assert_eq(elements[0].type_code(), 0x02)
  assert_eq(elements[0].to_bson(), String("Ada"))
  assert_eq(raw.get_element("age").unwrap().to_bson(), Int32(37))
  assert_eq(raw.get_element("missing"), None)
}

///|
test "prefix size limit applies to document, not following frames" {
  let first = encode(Document::new())
  let framed = first + Bytes::make(128, 0)
  let (document, consumed) = decode_prefix_with_options(
    framed[:],
    DecodeOptions::new(max_size=8),
  )
  assert_true(document.is_empty())
  assert_eq(consumed, first.length())
}
