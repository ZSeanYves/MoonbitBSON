///|
fn benchmark_document() -> Document {
  let document = Document::new()
  for index in 0..<128 {
    document.set(
      "field_" + index.to_string(),
      String("value-" + index.to_string()),
    )
    |> ignore
  }
  document
  .set("nested", Document(Document::new().set("enabled", Boolean(true))))
  .set("payload", Binary(Binary::new(Generic, Bytes::make(512, 0x41))))
}

///|
fn benchmark_encode(document : Document) -> Bytes {
  try encode(document) catch {
    _ => abort("benchmark fixture failed to encode")
  } noraise {
    bytes => bytes
  }
}

///|
fn benchmark_decode(bytes : Bytes) -> Document {
  try decode(bytes) catch {
    _ => abort("benchmark fixture failed to decode")
  } noraise {
    document => document
  }
}

///|
fn benchmark_raw_lookup(raw : RawDocument) -> Bson {
  try raw.get_element("field_96").unwrap().to_bson() catch {
    _ => abort("benchmark fixture failed during raw lookup")
  } noraise {
    value => value
  }
}

///|
test "bench BSON encode 128-field document" (it : @bench.T) {
  let document = benchmark_document()
  it.bench(fn() { it.keep(benchmark_encode(document)) })
}

///|
test "bench BSON decode 128-field document" (it : @bench.T) {
  let bytes = benchmark_encode(benchmark_document())
  it.bench(fn() { it.keep(benchmark_decode(bytes)) })
}

///|
test "bench RawDocument lazy element lookup" (it : @bench.T) {
  let raw = RawDocument::from_bytes(benchmark_encode(benchmark_document()))
  it.bench(fn() { it.keep(benchmark_raw_lookup(raw)) })
}

///|
fn benchmark_raw_view_lookup(view : RawDocumentView) -> BytesView {
  try {
    let iterator = view.iter()
    while iterator.next() is Some(element) {
      if element.key() == "field_96" {
        return element.raw_bytes()
      }
    }
    abort("benchmark field missing")
  } catch {
    _ => abort("benchmark raw view lookup failed")
  } noraise {
    value => value
  }
}

///|
test "bench borrowed RawDocumentView lookup" (it : @bench.T) {
  let view = RawDocumentView::from_bytes(
    benchmark_encode(benchmark_document())[:],
  )
  it.bench(fn() { it.keep(benchmark_raw_view_lookup(view)) })
}
