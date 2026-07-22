///|
test "RawDocumentView keeps borrowed element bytes" {
  let bytes = Document::new()
    .set("name", String("Ada"))
    .set("count", Int32(3))
    .to_bytes()
  let view = RawDocumentView::from_bytes(bytes[:])
  assert_eq(view.bytes(), bytes[:])
  let iterator = view.iter()
  let first = iterator.next().unwrap()
  assert_eq(first.key(), "name")
  assert_true(first.key_bytes().equal_to_bytes(b"name"))
  assert_true(first.raw_bytes().length() > 0)
  assert_true(first.as_string_bytes().unwrap().equal_to_bytes(b"Ada"))
  assert_eq(first.to_bson(), String("Ada"))
  let second = iterator.next().unwrap()
  assert_eq(second.key(), "count")
  assert_eq(second.as_int32(), Some(3))
  assert_eq(second.to_bson(), Int32(3))
  assert_eq(iterator.next(), None)
}

///|
test "RawBsonRef borrows nested values and materializes explicitly" {
  let source = Document::new()
    .set("text", String("borrowed"))
    .set("bytes", Binary(Binary::new(Generic, b"abc")))
    .set("nested", Document(Document::new().set("answer", Int32(42))))
    .set("items", Array([Boolean(true), Int64(7L)]))
  let view = RawDocumentView::from_bytes(source.to_bytes()[:])
  match view.get("text").unwrap() {
    String(value) => assert_eq(value.to_string(), "borrowed")
    _ => fail("text was not a borrowed string")
  }
  match view.get("bytes").unwrap() {
    Binary(value) => {
      assert_eq(value.subtype(), Generic)
      assert_true(value.bytes().equal_to_bytes(b"abc"))
    }
    _ => fail("bytes was not a borrowed binary")
  }
  match view.get("nested").unwrap() {
    Document(value) =>
      assert_eq(value.get("answer").unwrap().to_bson(), Int32(42))
    _ => fail("nested value was not a borrowed document")
  }
  match view.get("items").unwrap() {
    Array(value) => {
      assert_eq(value.get(0).unwrap().to_bson(), Boolean(true))
      assert_eq(value.get(1).unwrap().to_bson(), Int64(7L))
    }
    _ => fail("array value was not a borrowed array")
  }
}

///|
test "BsonStreamDecoder handles split and coalesced frames" {
  let first = Document::new().set("first", Boolean(true)).to_bytes()
  let second = Document::new().set("second", Int64(2L)).to_bytes()
  let framed = first + second
  let stream = BsonStreamDecoder::new()
  assert_eq(stream.push(framed[:3]).length(), 0)
  let documents = stream.push(framed[3:])
  assert_eq(documents.length(), 2)
  assert_eq(documents[0].require_bool("first"), true)
  assert_eq(documents[1].require_int64("second"), 2L)
  stream.finish()
}

///|
test "BsonStreamEncoder appends complete frames" {
  let encoder = BsonStreamEncoder::new()
  encoder.push(Document::new().set("one", Int32(1)))
  encoder.push(Document::new().set("two", Int32(2)))
  let decoder = BsonStreamDecoder::new()
  let documents = decoder.push(encoder.bytes()[:])
  assert_eq(documents.length(), 2)
  assert_eq(documents[0].require_int32("one"), 1)
  assert_eq(documents[1].require_int32("two"), 2)
  decoder.finish()
}
