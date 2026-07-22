///|
/// A chunked BSON frame decoder for transports that split documents arbitrarily.
pub struct BsonStreamDecoder {
  mut pending : Bytes
} derive(Debug)

///|
pub fn BsonStreamDecoder::new() -> BsonStreamDecoder {
  { pending: b"" }
}

///|
/// Feed a chunk and return every complete document now available.
pub fn BsonStreamDecoder::push(
  self : BsonStreamDecoder,
  chunk : BytesView,
) -> Array[Document] raise BsonError {
  self.pending = self.pending + chunk.to_owned()
  let documents : Array[Document] = []
  while self.pending.length() > 0 {
    let result : (Document, Int)? = try {
      let (document, consumed) = decode_prefix(self.pending[:])
      Some((document, consumed))
    } catch {
      Failure(info) if info.kind() == UnexpectedEnd => None
      error => raise error
    }
    match result {
      None => break
      Some((document, consumed)) => {
        documents.push(document)
        self.pending = self.pending[consumed:].to_owned()
      }
    }
  }
  documents
}

///|
/// Finish the stream, rejecting an incomplete trailing frame.
pub fn BsonStreamDecoder::finish(
  self : BsonStreamDecoder,
) -> Unit raise BsonError {
  if !self.pending.is_empty() {
    raise bson_error(
      UnexpectedEnd,
      self.pending.length(),
      "$",
      "BSON stream ended with an incomplete document",
    )
  }
}

///|
/// Append-only frame encoder for transports that batch complete BSON frames.
pub struct BsonStreamEncoder {
  buffer : @buffer.Buffer
}

///|
pub fn BsonStreamEncoder::new(size_hint? : Int = 256) -> BsonStreamEncoder {
  { buffer: Buffer(size_hint~) }
}

///|
/// Encode one complete document and append it as one frame.
pub fn BsonStreamEncoder::push(
  self : BsonStreamEncoder,
  document : Document,
) -> Unit raise BsonError {
  self.buffer.write_bytes(encode(document))
}

///|
pub fn BsonStreamEncoder::bytes(self : BsonStreamEncoder) -> Bytes {
  self.buffer.to_bytes()
}
