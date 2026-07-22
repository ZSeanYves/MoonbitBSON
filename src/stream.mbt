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
  let buffer = self.pending + chunk.to_owned()
  let documents : Array[Document] = []
  let options = DecodeOptions::new()
  let mut position = 0
  while position < buffer.length() {
    match bson_stream_frame_length(buffer[:], position, options.max_size()) {
      None => break
      Some(length) => {
        let (document, consumed) = decode_prefix_with_options(
          buffer[position:position + length],
          options,
        )
        documents.push(document)
        position += consumed
      }
    }
  }
  self.pending = bson_stream_pending(buffer, position)
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
/// A chunked BSON frame decoder that returns borrowed raw document views.
///
/// Complete frames are sliced from the decoder's immutable pending buffer; no
/// `Document` or per-frame byte copy is created. A frame split across chunks is
/// assembled in that buffer, and returned views remain valid after later
/// `push` calls.
pub struct BsonStreamRawDecoder {
  mut pending : Bytes
  max_size : Int
} derive(Debug)

///|
/// Create a raw decoder with a per-frame size limit (16 MiB by default).
pub fn BsonStreamRawDecoder::new(
  max_size? : Int = 16 * 1024 * 1024,
) -> BsonStreamRawDecoder {
  { pending: b"", max_size }
}

///|
/// Feed a chunk and return every complete raw view now available.
pub fn BsonStreamRawDecoder::push(
  self : BsonStreamRawDecoder,
  chunk : BytesView,
) -> Array[RawDocumentView] raise BsonError {
  let buffer = self.pending + chunk.to_owned()
  let views : Array[RawDocumentView] = []
  let mut position = 0
  while position < buffer.length() {
    match bson_stream_frame_length(buffer[:], position, self.max_size) {
      None => break
      Some(length) => {
        views.push(
          RawDocumentView::from_bytes(buffer[position:position + length]),
        )
        position += length
      }
    }
  }
  self.pending = bson_stream_pending(buffer, position)
  views
}

///|
/// Finish the stream, rejecting an incomplete trailing raw frame.
pub fn BsonStreamRawDecoder::finish(
  self : BsonStreamRawDecoder,
) -> Unit raise BsonError {
  if !self.pending.is_empty() {
    raise bson_error(
      UnexpectedEnd,
      self.pending.length(),
      "$",
      "BSON raw stream ended with an incomplete document",
    )
  }
}

///|
fn bson_stream_frame_length(
  buffer : BytesView,
  position : Int,
  max_size : Int,
) -> Int? raise BsonError {
  let remaining = buffer.length() - position
  if remaining < 4 {
    return None
  }
  let length = raw_view_i32(buffer, position, "$")
  if length < 5 {
    raise bson_error(
      InvalidLength,
      position,
      "$.length",
      "BSON stream frame length must be at least 5",
    )
  }
  if length > max_size {
    raise bson_error(
      SizeLimit,
      position,
      "$.length",
      "BSON stream frame exceeds max_size",
    )
  }
  if length > remaining {
    None
  } else {
    Some(length)
  }
}

///|
fn bson_stream_pending(buffer : Bytes, position : Int) -> Bytes {
  if position == 0 {
    buffer
  } else {
    // Returned views retain `buffer`; only the incomplete suffix needs a new
    // owner before the decoder accepts another chunk.
    buffer[position:].to_owned()
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
