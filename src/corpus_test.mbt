// Selected canonical and error vectors from the MongoDB BSON Corpus.
// Source: https://github.com/mongodb/specifications/tree/master/source/bson-corpus/tests

///|
test "corpus boolean canonical vectors" {
  let true_bytes = b"\x09\x00\x00\x00\x08b\x00\x01\x00"
  let false_bytes = b"\x09\x00\x00\x00\x08b\x00\x00\x00"
  assert_eq(decode(true_bytes), Document::new().set("b", Boolean(true)))
  assert_eq(decode(false_bytes), Document::new().set("b", Boolean(false)))
  assert_eq(encode(decode(true_bytes)), true_bytes)
  assert_eq(encode(decode(false_bytes)), false_bytes)
}

///|
test "corpus boolean error vectors" {
  let invalid_two = b"\x09\x00\x00\x00\x08b\x00\x02\x00"
  let invalid_ff = b"\x09\x00\x00\x00\x08b\x00\xff\x00"
  assert_eq(decoding_error(invalid_two).unwrap().kind(), InvalidBoolean)
  assert_eq(decoding_error(invalid_ff).unwrap().kind(), InvalidBoolean)
}

///|
test "corpus signed integer boundaries" {
  let int32_min = b"\x0c\x00\x00\x00\x10x\x00\x00\x00\x00\x80\x00"
  let int32_max = b"\x0c\x00\x00\x00\x10x\x00\xff\xff\xff\x7f\x00"
  let int64_min = b"\x10\x00\x00\x00\x12x\x00\x00\x00\x00\x00\x00\x00\x00\x80\x00"
  let int64_max = b"\x10\x00\x00\x00\x12x\x00\xff\xff\xff\xff\xff\xff\xff\x7f\x00"
  assert_eq(decode(int32_min).get_int32("x"), Some(-2147483648))
  assert_eq(decode(int32_max).get_int32("x"), Some(2147483647))
  assert_eq(decode(int64_min).get_int64("x"), Some(-9223372036854775807L - 1L))
  assert_eq(decode(int64_max).get_int64("x"), Some(9223372036854775807L))
  assert_eq(encode(decode(int32_min)), int32_min)
  assert_eq(encode(decode(int32_max)), int32_max)
  assert_eq(encode(decode(int64_min)), int64_min)
  assert_eq(encode(decode(int64_max)), int64_max)
}

///|
test "corpus top-level keys may contain dollar and dot" {
  let document = Document::new()
    .set("$numberInt", String("not extended JSON in BSON"))
    .set("a.b", Int32(1))
  assert_eq(decode(encode(document)), document)
}

///|
test "corpus strings allow embedded NUL" {
  let document = Document::new().set("s", String("a\u0000b"))
  assert_eq(decode(encode(document)), document)
}

///|
test "corpus truncated payloads fail without aborting" {
  let valid = encode(
    Document::new()
    .set("string", String("hello"))
    .set("int64", Int64(9223372036854775807L))
    .set("array", Array([Int32(1), Int32(2)])),
  )
  for length in 0..<valid.length() {
    let truncated = valid[0:length].to_owned()
    assert_true(decoding_error(truncated) is Some(_))
  }
}

///|
test "generated mixed documents roundtrip" {
  for value in -128..<128 {
    let document = Document::new()
      .set("i32", Int32(value))
      .set("i64", Int64(value.to_int64() * 0x100000001L))
      .set("double", Double(value.to_double() / 3.0))
      .set("string", String("value-" + value.to_string()))
      .set("array", Array([Int32(value), Boolean(value % 2 == 0), Null]))
      .set("nested", Document(Document::new().set("value", Int32(value))))
    assert_eq(decode(encode(document)), document)
  }
}

///|
test "document size limits reject input and output" {
  let document = Document::new().set("value", String("x".repeat(64)))
  assert_true(limited_encoding_fails(document, EncodeOptions::new(max_size=32)))
  let bytes = encode(document)
  assert_true(limited_decoding_fails(bytes, DecodeOptions::new(max_size=32)))
}
