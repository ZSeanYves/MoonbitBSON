///|
/// A borrowed BSON document view backed by an existing `Bytes` allocation.
///
/// Construction and element iteration keep the original bytes as `BytesView`;
/// no document-wide copy or value allocation is performed until a value is
/// decoded explicitly.
pub struct RawDocumentView {
  bytes : BytesView
} derive(Eq, Debug)

///|
pub fn RawDocumentView::from_bytes(
  bytes : BytesView,
) -> RawDocumentView raise BsonError {
  let end = raw_view_document_end(bytes, 0, "$")
  if end != bytes.length() {
    raise bson_error(
      TrailingData,
      end,
      "$",
      "trailing bytes after raw BSON document",
    )
  }
  { bytes, }
}

///|
/// Create a borrowed view over the first BSON frame in `bytes`.
pub fn RawDocumentView::from_prefix(
  bytes : BytesView,
) -> (RawDocumentView, Int) raise BsonError {
  let end = raw_view_document_end(bytes, 0, "$")
  ({ bytes: bytes[0:end] }, end)
}

///|
pub fn RawDocumentView::bytes(self : RawDocumentView) -> BytesView {
  self.bytes
}

///|
pub fn RawDocumentView::length(self : RawDocumentView) -> Int {
  self.bytes.length()
}

///|
/// Return an iterator that keeps element keys and values as byte views.
pub fn RawDocumentView::iter(self : RawDocumentView) -> RawElementViewIter {
  { document: self, position: 4, end: self.bytes.length() - 1 }
}

///|
/// A single borrowed BSON element. `key()` allocates a String; `key_bytes()` does not.
pub struct RawElementView {
  document : RawDocumentView
  key_start : Int
  key_end : Int
  type_code : Byte
  value_start : Int
  value_end : Int
} derive(Eq, Debug)

///|
pub fn RawElementView::key_bytes(self : RawElementView) -> BytesView {
  self.document.bytes[self.key_start:self.key_end]
}

///|
pub fn RawElementView::key(self : RawElementView) -> String raise BsonError {
  @utf8.decode(self.key_bytes()) catch {
    _ =>
      raise bson_error(
        InvalidUtf8,
        self.key_start,
        "$.\u{24}key",
        "raw element key is not valid UTF-8",
      )
  }
}

///|
pub fn RawElementView::type_code(self : RawElementView) -> Byte {
  self.type_code
}

///|
pub fn RawElementView::raw_bytes(self : RawElementView) -> BytesView {
  self.document.bytes[self.value_start:self.value_end]
}

///|
/// Borrow a BSON string payload without decoding UTF-8 or allocating a String.
pub fn RawElementView::as_string_bytes(
  self : RawElementView,
) -> BytesView? raise BsonError {
  if self.type_code != 0x02 {
    return None
  }
  let length = raw_view_i32(self.document.bytes, self.value_start, "$.string")
  if length < 1 || self.value_start + 4 + length > self.value_end {
    raise bson_error(
      InvalidLength,
      self.value_start,
      "$.string",
      "invalid raw string length",
    )
  }
  let end = self.value_start + 4 + length
  if self.document.bytes[end - 1] != 0 {
    raise bson_error(
      InvalidCString,
      end - 1,
      "$.string",
      "raw string is not terminated",
    )
  }
  Some(self.document.bytes[self.value_start + 4:end - 1])
}

///|
/// Borrow binary payload bytes and retain the wire subtype.
pub fn RawElementView::as_binary_bytes(
  self : RawElementView,
) -> (BinarySubtype, BytesView)? raise BsonError {
  if self.type_code != 0x05 {
    return None
  }
  let length = raw_view_i32(self.document.bytes, self.value_start, "$.binary")
  if length < 0 || self.value_start + 5 + length > self.value_end {
    raise bson_error(
      InvalidBinary,
      self.value_start,
      "$.binary",
      "invalid raw binary length",
    )
  }
  let subtype = BinarySubtype::from_byte(
    self.document.bytes[self.value_start + 4],
  )
  let payload = self.value_start + 5
  if subtype == BinaryOld {
    if length < 4 ||
      raw_view_i32(self.document.bytes, payload, "$.binary") != length - 4 {
      raise bson_error(
        InvalidBinary,
        self.value_start,
        "$.binary",
        "invalid raw old binary length",
      )
    }
    return Some((subtype, self.document.bytes[payload + 4:payload + length]))
  }
  Some((subtype, self.document.bytes[payload:payload + length]))
}

///|
pub fn RawElementView::as_int32(self : RawElementView) -> Int? raise BsonError {
  if self.type_code == 0x10 {
    Some(raw_view_i32(self.document.bytes, self.value_start, "$.int32"))
  } else {
    None
  }
}

///|
pub fn RawElementView::as_int64(
  self : RawElementView,
) -> Int64? raise BsonError {
  if self.type_code == 0x12 {
    Some(raw_view_i64(self.document.bytes, self.value_start, "$.int64"))
  } else {
    None
  }
}

///|
pub fn RawElementView::as_double(
  self : RawElementView,
) -> Double? raise BsonError {
  if self.type_code == 0x01 {
    Some(
      raw_view_i64(self.document.bytes, self.value_start, "$.double").reinterpret_as_double(),
    )
  } else {
    None
  }
}

///|
pub fn RawElementView::as_datetime_millis(
  self : RawElementView,
) -> Int64? raise BsonError {
  if self.type_code == 0x09 {
    Some(raw_view_i64(self.document.bytes, self.value_start, "$.datetime"))
  } else {
    None
  }
}

///|
pub fn RawElementView::as_bool(self : RawElementView) -> Bool? raise BsonError {
  if self.type_code != 0x08 {
    return None
  }
  if self.value_start >= self.value_end {
    raise bson_error(
      UnexpectedEnd,
      self.value_start,
      "$.bool",
      "missing raw boolean byte",
    )
  }
  match self.document.bytes[self.value_start] {
    0 => Some(false)
    1 => Some(true)
    _ =>
      raise bson_error(
        InvalidBoolean,
        self.value_start,
        "$.bool",
        "invalid raw boolean byte",
      )
  }
}

///|
pub fn RawElementView::to_bson(self : RawElementView) -> Bson raise BsonError {
  let decoder = Decoder::new(self.document.bytes, DecodeOptions::new())
  decoder.position = self.value_start
  decoder.read_element(
    self.type_code,
    self.value_end,
    0,
    field_path("$", self.key()),
  )
}

///|
/// A stateful iterator over borrowed top-level elements.
pub struct RawElementViewIter {
  document : RawDocumentView
  mut position : Int
  end : Int
}

///|
pub fn RawElementViewIter::next(
  self : RawElementViewIter,
) -> RawElementView? raise BsonError {
  if self.position >= self.end {
    return None
  }
  let type_offset = self.position
  let type_code = self.document.bytes[self.position]
  self.position += 1
  if type_code == 0 {
    raise bson_error(
      InvalidLength,
      type_offset,
      "$",
      "raw document terminator appears before its boundary",
    )
  }
  let key_start = self.position
  let key_end = raw_view_cstring_end(
    self.document.bytes,
    key_start,
    self.end,
    "$.\u{24}key",
  )
  self.position = key_end + 1
  let value_start = self.position
  let value_end = raw_view_skip_value(
    self.document.bytes,
    type_code,
    value_start,
    self.end,
    "$.\u{24}value",
  )
  self.position = value_end
  Some({
    document: self.document,
    key_start,
    key_end,
    type_code,
    value_start,
    value_end,
  })
}

///|
fn raw_view_document_end(
  bytes : BytesView,
  start : Int,
  path : String,
) -> Int raise BsonError {
  if start < 0 || start + 4 > bytes.length() {
    raise bson_error(UnexpectedEnd, start, path, "raw document is too short")
  }
  let length = raw_view_i32(bytes, start, path)
  if length < 5 || start + length > bytes.length() {
    raise bson_error(InvalidLength, start, path, "invalid raw document length")
  }
  let end = start + length
  if bytes[end - 1] != 0 {
    raise bson_error(
      InvalidLength,
      end - 1,
      path,
      "raw document is not NUL terminated",
    )
  }
  end
}

///|
fn raw_view_skip_value(
  bytes : BytesView,
  type_code : Byte,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  match type_code {
    0x01 => raw_view_require(start + 8, limit, path)
    0x02 | 0x0D | 0x0E => raw_view_skip_string(bytes, start, limit, path)
    0x03 | 0x04 => raw_view_skip_container(bytes, start, limit, path)
    0x05 => raw_view_skip_binary(bytes, start, limit, path)
    0x06 | 0x0A | 0x7F | 0xFF => start
    0x07 => raw_view_require(start + 12, limit, path)
    0x08 | 0x09 =>
      raw_view_require(
        start + (if type_code == 0x08 { 1 } else { 8 }),
        limit,
        path,
      )
    0x0B => {
      let first = raw_view_cstring_end(bytes, start, limit, path)
      raw_view_cstring_end(bytes, first + 1, limit, path) + 1
    }
    0x0C => {
      let collection_end = raw_view_skip_string(bytes, start, limit, path)
      raw_view_require(collection_end + 12, limit, path)
    }
    0x0F => {
      let total = raw_view_i32(bytes, start, path)
      if total < 14 || start + total > limit {
        raise bson_error(
          InvalidLength,
          start,
          path,
          "invalid raw code-with-scope length",
        )
      }
      let code_end = raw_view_skip_string(bytes, start + 4, start + total, path)
      raw_view_skip_container(bytes, code_end, start + total, path)
    }
    0x10 => raw_view_require(start + 4, limit, path)
    0x11 | 0x12 => raw_view_require(start + 8, limit, path)
    0x13 => raw_view_require(start + 16, limit, path)
    _ =>
      raise bson_error(
        UnsupportedType,
        start,
        path,
        "unsupported raw BSON type",
      )
  }
}

///|
fn raw_view_skip_container(
  bytes : BytesView,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let end = raw_view_document_end(bytes, start, path)
  if end > limit {
    raise bson_error(
      InvalidLength,
      start,
      path,
      "nested raw document exceeds parent",
    )
  }
  let mut position = start + 4
  while position < end - 1 {
    let type_code = bytes[position]
    position += 1
    let key_end = raw_view_cstring_end(bytes, position, end - 1, path)
    position = key_end + 1
    position = raw_view_skip_value(bytes, type_code, position, end - 1, path)
  }
  end
}

///|
fn raw_view_skip_string(
  bytes : BytesView,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let length = raw_view_i32(bytes, start, path)
  if length < 1 || start + 4 + length > limit {
    raise bson_error(InvalidLength, start, path, "invalid raw string length")
  }
  let end = start + 4 + length
  if bytes[end - 1] != 0 {
    raise bson_error(
      InvalidCString,
      end - 1,
      path,
      "raw string is not terminated",
    )
  }
  end
}

///|
fn raw_view_skip_binary(
  bytes : BytesView,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let length = raw_view_i32(bytes, start, path)
  if length < 0 || start + 5 + length > limit {
    raise bson_error(InvalidBinary, start, path, "invalid raw binary length")
  }
  let payload = start + 5
  if bytes[start + 4] == 2 {
    if length < 4 || raw_view_i32(bytes, payload, path) != length - 4 {
      raise bson_error(
        InvalidBinary,
        start,
        path,
        "invalid raw old binary length",
      )
    }
  }
  start + 5 + length
}

///|
fn raw_view_cstring_end(
  bytes : BytesView,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let mut position = start
  while position < limit {
    if bytes[position] == 0 {
      return position
    }
    position += 1
  }
  raise bson_error(UnexpectedEnd, position, path, "unterminated raw cstring")
}

///|
fn raw_view_require(
  end : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  if end > limit {
    raise bson_error(
      UnexpectedEnd,
      limit,
      path,
      "raw value exceeds its container",
    )
  }
  end
}

///|
fn raw_view_i32(
  bytes : BytesView,
  start : Int,
  path : String,
) -> Int raise BsonError {
  if start < 0 || start + 4 > bytes.length() {
    raise bson_error(UnexpectedEnd, start, path, "raw integer exceeds input")
  }
  let value : UInt = bytes[start].to_uint() |
    (bytes[start + 1].to_uint() << 8) |
    (bytes[start + 2].to_uint() << 16) |
    (bytes[start + 3].to_uint() << 24)
  value.reinterpret_as_int()
}

///|
fn raw_view_i64(
  bytes : BytesView,
  start : Int,
  path : String,
) -> Int64 raise BsonError {
  if start < 0 || start + 8 > bytes.length() {
    raise bson_error(UnexpectedEnd, start, path, "raw int64 exceeds input")
  }
  let mut value : Int64 = 0L
  for index in 0..<8 {
    value = value | (bytes[start + index].to_int64() << (index * 8))
  }
  value
}
