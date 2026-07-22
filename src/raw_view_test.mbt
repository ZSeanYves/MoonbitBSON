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
  assert_eq(stream.push(framed[:first.length() - 1]).length(), 0)
  let documents = stream.push(framed[first.length() - 1:])
  assert_eq(documents.length(), 2)
  assert_eq(documents[0].require_bool("first"), true)
  assert_eq(documents[1].require_int64("second"), 2L)
  stream.finish()
}

///|
test "BsonStreamRawDecoder returns borrowed views across frame boundaries" {
  let first = Document::new().set("first", Boolean(true)).to_bytes()
  let second = Document::new().set("second", Int64(2L)).to_bytes()
  let third = Document::new().set("third", Null).to_bytes()
  let framed = first + second + third
  let stream = BsonStreamRawDecoder::new()
  let first_views = stream.push(framed[:first.length() + 2])
  assert_eq(first_views.length(), 1)
  assert_eq(first_views[0].get("first").unwrap().to_bson(), Boolean(true))
  let second_views = stream.push(framed[first.length() + 2:])
  assert_eq(second_views.length(), 2)
  assert_eq(second_views[0].get("second").unwrap().to_bson(), Int64(2L))
  assert_eq(second_views[1].get("third").unwrap().to_bson(), Null)
  // A view returned by an earlier push retains its immutable frame bytes.
  assert_eq(first_views[0].get("first").unwrap().to_bson(), Boolean(true))
  stream.finish()
}

///|
test "BsonStreamRawDecoder waits for a complete header and rejects incomplete EOF" {
  let bytes = Document::new().set("ok", Int32(1)).to_bytes()
  let stream = BsonStreamRawDecoder::new()
  assert_eq(stream.push(bytes[:2]).length(), 0)
  assert_eq(stream.push(bytes[2:bytes.length() - 1]).length(), 0)
  try stream.finish() catch {
    Failure(info) => assert_eq(info.kind(), UnexpectedEnd)
  } noraise {
    _ => fail("incomplete raw stream unexpectedly finished")
  }
}

///|
test "BsonStreamRawDecoder rejects invalid frame lengths" {
  let stream = BsonStreamRawDecoder::new()
  try stream.push(b"\x04\x00\x00\x00") catch {
    Failure(info) => assert_eq(info.kind(), InvalidLength)
  } noraise {
    _ => fail("invalid raw frame length was accepted")
  }
}

///|
test "BsonStreamRawDecoder enforces max_size before buffering a frame" {
  let stream = BsonStreamRawDecoder::new(max_size=32)
  try stream.push(b"\x00\x04\x00\x00") catch {
    Failure(info) => assert_eq(info.kind(), SizeLimit)
  } noraise {
    _ => fail("oversized raw stream frame was accepted")
  }
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
