# MoonbitBSON

`MoonbitBSON` implements strict BSON 1.1 binary encoding and decoding with an
owned, insertion-ordered `Document` model.

```mbt check
///|
test "build and roundtrip a document" {
  let user = Document::new()
    .set("name", String("Ada"))
    .set("age", Int32(37))
    .set("active", Boolean(true))
    .set("scores", Array([Double(9.5), Double(10.0)]))
  let encoded = user.to_bytes()
  let decoded = Document::from_bytes(encoded)
  assert_eq(decoded.require_string("name"), "Ada")
  assert_eq(decoded.require_int32("age"), 37)
}
```

`decode` consumes exactly one document. Use `decode_prefix` for framed streams.

```mbt check
///|
test "decode a framed document" {
  let encoded = Document::new().set("x", Int64(42L)).to_bytes()
  let framed = encoded + b"remaining"
  let (document, consumed) = decode_prefix(framed[:])
  assert_eq(document.require_int64("x"), 42L)
  assert_eq(consumed, encoded.length())
}
```

Canonical and Relaxed Extended JSON are available for every BSON value.
Decimal128 uses an exact IEEE 754-2008 text codec, and Relaxed DateTime values
use RFC 3339 strings when they are between the Unix epoch and year 9999.

```mbt check
///|
test "canonical Extended JSON" {
  let document = Document::new()
    .set("count", Int64(9007199254740993L))
    .set("decimal", Decimal128(Decimal128::from_string("1.2500")))
  let text = document.to_extended_json_string()
  let decoded = Document::from_extended_json_string(text)
  assert_eq(decoded, document)
}
```

Typed DateTime, UUID, ObjectId, and generic serialization APIs keep BSON-only
invariants out of application code. Raw elements can be inspected before their
values are decoded.

```mbt check
///|
test "typed and raw APIs" {
  let uuid = Uuid::from_string("00112233-4455-6677-8899-aabbccddeeff")
  let document = Document::new()
    .set("created", DateTime(DateTime::from_millis(0L)))
    .set("request_id", Binary(uuid.to_binary()))
  let raw = RawDocument::from_bytes(serialize_to_bytes(document))
  assert_eq(raw.get_element("created").unwrap().type_code(), 0x09)
  let decoded : Document = deserialize_from_bytes(raw.bytes())
  assert_eq(decoded.require_datetime("created").to_millis(), 0L)
  assert_eq(decoded.require_uuid("request_id"), uuid)
}
```

For a single borrowed frame, keep its input allocation alive and use the raw
view. For high-throughput framing, use one of the stream decoders:

```mbt check
///|
test "borrowed view and split stream" {
  let bytes = Document::new().set("ok", Boolean(true)).to_bytes()
  let view = RawDocumentView::from_bytes(bytes[:])
  assert_eq(view.iter().next().unwrap().key(), "ok")
  let stream = BsonStreamDecoder::new()
  assert_eq(stream.push(bytes[:2]).length(), 0)
  assert_eq(stream.push(bytes[2:])[0].require_bool("ok"), true)
  stream.finish()
}
```

`RawBsonRef` extends the borrowed API to nested documents, arrays, UTF-8 string
payloads, and binary payloads. Values remain borrowed until the caller chooses
`to_bson`, `to_document`, or `to_array`.

`BsonStreamRawDecoder` is the borrowed counterpart to `BsonStreamDecoder`:

```mbt check
///|
test "raw stream view" {
  let first = Document::new().set("ok", Boolean(true)).to_bytes()
  let second = Document::new().set("count", Int32(2)).to_bytes()
  let stream = BsonStreamRawDecoder::new()
  let views = stream.push(first + second)
  assert_eq(views.length(), 2)
  assert_eq(views[0].get("ok").unwrap().to_bson(), Boolean(true))
  assert_eq(views[1].get("count").unwrap().to_bson(), Int32(2))
  stream.finish()
}
```

Complete frames are sliced from an immutable pending `Bytes` buffer. A frame
split across chunks is assembled in that buffer; returned views retain their
backing bytes and remain valid after later `push` calls. This avoids per-frame
`Document` materialization, but cannot be end-to-end zero-copy when the input
frame arrives in separate allocations. `BsonStreamRawDecoder::new` defaults to
a 16 MiB per-frame limit and rejects oversized declared lengths before buffering.

MoonBit cannot derive user-defined traits with the compiler's built-in derive
system. The current compiler reports `E4077` for `derive(ToBson)`, while
`#custom.*` attributes are intentionally ignored by the compiler and can only
be consumed by external tools. Use `tools/bson-derive.mjs` for checked-in
serde-like implementations; the `/// @bson.derive` and
`/// @bson.rename("...")` annotations are source-level metadata consumed by
that generator.
