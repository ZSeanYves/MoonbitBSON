///|
/// A validated BSON element backed by its owning RawDocument.
pub struct RawElement {
  document : RawDocument
  key : String
  type_code : Byte
  value_start : Int
  value_end : Int
} derive(Eq, Debug)

///|
pub fn RawElement::key(self : RawElement) -> String {
  self.key
}

///|
pub fn RawElement::type_code(self : RawElement) -> Byte {
  self.type_code
}

///|
pub fn RawElement::raw_bytes(self : RawElement) -> BytesView {
  self.document.bytes()[self.value_start:self.value_end]
}

///|
pub fn RawElement::to_bson(self : RawElement) -> Bson raise BsonError {
  let decoder = Decoder::new(self.document.bytes(), DecodeOptions::new())
  decoder.position = self.value_start
  decoder.read_element(
    self.type_code,
    self.value_end,
    0,
    field_path("$", self.key),
  )
}

///|
/// Return the top-level elements without decoding their values.
pub fn RawDocument::elements(
  self : RawDocument,
) -> Array[RawElement] raise BsonError {
  raw_scan_document(self, self.bytes(), 0, "$")
}

///|
pub fn RawDocument::get_element(
  self : RawDocument,
  key : String,
) -> RawElement? raise BsonError {
  for element in self.elements() {
    if element.key() == key {
      return Some(element)
    }
  }
  None
}

///|
fn raw_scan_document(
  document : RawDocument,
  bytes : Bytes,
  start : Int,
  path : String,
) -> Array[RawElement] raise BsonError {
  let length = raw_i32(bytes, start, path)
  if length < 5 || start + length > bytes.length() {
    raise bson_error(InvalidLength, start, path, "invalid raw document length")
  }
  let end = start + length
  if bytes[end - 1] != 0 {
    raise bson_error(
      InvalidLength,
      end - 1,
      path,
      "missing raw document terminator",
    )
  }
  let elements : Array[RawElement] = []
  let mut position = start + 4
  while position < end - 1 {
    let type_offset = position
    let type_code = bytes[position]
    position += 1
    let key_start = position
    let key_end = raw_cstring_end(bytes, position, end - 1, path)
    let key = @utf8.decode(bytes[key_start:key_end].to_owned()) catch {
      _ =>
        raise bson_error(
          InvalidUtf8,
          key_start,
          path,
          "invalid raw element key",
        )
    }
    position = key_end + 1
    let value_start = position
    let value_end = raw_skip_value(bytes, type_code, position, end - 1, path)
    if value_end < value_start {
      raise bson_error(
        InvalidLength,
        type_offset,
        path,
        "invalid raw element length",
      )
    }
    elements.push({ document, key, type_code, value_start, value_end })
    position = value_end
  }
  elements
}

///|
fn raw_skip_value(
  bytes : Bytes,
  type_code : Byte,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  match type_code {
    0x01 => raw_require(start + 8, limit, path)
    0x02 | 0x0D | 0x0E => raw_skip_string(bytes, start, limit, path)
    0x03 | 0x04 => raw_skip_container(bytes, start, limit, path)
    0x05 => raw_skip_binary(bytes, start, limit, path)
    0x06 | 0x0A | 0x7F | 0xFF => start
    0x07 => raw_require(start + 12, limit, path)
    0x08 | 0x09 =>
      raw_require(start + (if type_code == 0x08 { 1 } else { 8 }), limit, path)
    0x0B => {
      let first = raw_cstring_end(bytes, start, limit, path)
      raw_cstring_end(bytes, first + 1, limit, path) + 1
    }
    0x0C => {
      let collection_end = raw_skip_string(bytes, start, limit, path)
      raw_require(collection_end + 12, limit, path)
    }
    0x0F => {
      let total = raw_i32(bytes, start, path)
      if total < 14 || start + total > limit {
        raise bson_error(
          InvalidLength,
          start,
          path,
          "invalid raw code-with-scope length",
        )
      }
      let code_end = raw_skip_string(bytes, start + 4, start + total, path)
      raw_skip_container(bytes, code_end, start + total, path)
    }
    0x10 => raw_require(start + 4, limit, path)
    0x11 => raw_require(start + 8, limit, path)
    0x12 => raw_require(start + 8, limit, path)
    0x13 => raw_require(start + 16, limit, path)
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
fn raw_skip_container(
  bytes : Bytes,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let length = raw_i32(bytes, start, path)
  if length < 5 || start + length > limit {
    raise bson_error(
      InvalidLength,
      start,
      path,
      "invalid raw nested document length",
    )
  }
  let end = start + length
  if bytes[end - 1] != 0 {
    raise bson_error(
      InvalidLength,
      end - 1,
      path,
      "missing raw nested terminator",
    )
  }
  let mut position = start + 4
  while position < end - 1 {
    let type_code = bytes[position]
    position += 1
    let key_end = raw_cstring_end(bytes, position, end - 1, path)
    position = key_end + 1
    position = raw_skip_value(bytes, type_code, position, end - 1, path)
  }
  end
}

///|
fn raw_skip_string(
  bytes : Bytes,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let length = raw_i32(bytes, start, path)
  if length < 1 || start + 4 + length > limit {
    raise bson_error(InvalidLength, start, path, "invalid raw string length")
  }
  if bytes[start + 4 + length - 1] != 0 {
    raise bson_error(
      InvalidLength,
      start + 4 + length - 1,
      path,
      "raw string is not terminated",
    )
  }
  start + 4 + length
}

///|
fn raw_skip_binary(
  bytes : Bytes,
  start : Int,
  limit : Int,
  path : String,
) -> Int raise BsonError {
  let length = raw_i32(bytes, start, path)
  if length < 0 || start + 5 + length > limit {
    raise bson_error(InvalidBinary, start, path, "invalid raw binary length")
  }
  let payload_start = start + 5
  if bytes[start + 4] == 2 {
    if length < 4 || raw_i32(bytes, payload_start, path) != length - 4 {
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
fn raw_cstring_end(
  bytes : Bytes,
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
fn raw_require(end : Int, limit : Int, path : String) -> Int raise BsonError {
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
fn raw_i32(bytes : Bytes, start : Int, path : String) -> Int raise BsonError {
  if start < 0 || start + 4 > bytes.length() {
    raise bson_error(UnexpectedEnd, start, path, "raw integer exceeds input")
  }
  let value : UInt = bytes[start].to_uint() |
    (bytes[start + 1].to_uint() << 8) |
    (bytes[start + 2].to_uint() << 16) |
    (bytes[start + 3].to_uint() << 24)
  value.reinterpret_as_int()
}
