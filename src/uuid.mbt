///|
/// A standard RFC 4122 UUID encoded as BSON Binary subtype 4.
pub struct Uuid {
  bytes : Bytes
} derive(Eq, Debug)

///|
pub fn Uuid::from_bytes(bytes : Bytes) -> Uuid raise BsonError {
  if bytes.length() != 16 {
    raise bson_error(InvalidUuid, -1, "$", "UUID must contain exactly 16 bytes")
  }
  { bytes, }
}

///|
pub fn Uuid::from_string(value : String) -> Uuid raise BsonError {
  let text = if value.has_prefix("urn:uuid:") {
    value[9:].to_owned()
  } else {
    value
  }
  let compact = StringBuilder()
  for index, code in text.code_units() {
    if code == '-' {
      if text.length() != 36 || !(index is (8 | 13 | 18 | 23)) {
        raise bson_error(InvalidUuid, -1, "$", "invalid UUID hyphen placement")
      }
    } else if hex_nibble(code) is Some(_) {
      compact.write_string(text[index:index + 1].to_owned())
    } else {
      raise bson_error(InvalidUuid, -1, "$", "invalid hexadecimal UUID digit")
    }
  }
  let hex = compact.to_string()
  if hex.length() != 32 {
    raise bson_error(
      InvalidUuid,
      -1,
      "$",
      "UUID must contain 32 hexadecimal digits",
    )
  }
  let bytes : Array[Byte] = []
  for index in 0..<16 {
    let high = hex_nibble(hex[index * 2]).unwrap()
    let low = hex_nibble(hex[index * 2 + 1]).unwrap()
    bytes.push((high * 16 + low).to_byte())
  }
  { bytes: Bytes::from_array(bytes) }
}

///|
pub fn Uuid::bytes(self : Uuid) -> Bytes {
  self.bytes
}

///|
pub fn Uuid::to_string(self : Uuid) -> String {
  let result = StringBuilder()
  for index, byte in self.bytes {
    if index is (4 | 6 | 8 | 10) {
      result.write_string("-")
    }
    result.write_string(byte.to_hex())
  }
  result.to_string()
}

///|
pub fn Uuid::to_binary(self : Uuid) -> Binary {
  Binary::new(Uuid, self.bytes)
}

///|
pub fn Uuid::from_binary(binary : Binary) -> Uuid raise BsonError {
  if binary.subtype() != Uuid {
    raise bson_error(InvalidUuid, -1, "$", "UUID requires Binary subtype 4")
  }
  Uuid::from_bytes(binary.bytes())
}

///|
pub fn Binary::as_uuid(self : Binary) -> Uuid? {
  try Uuid::from_binary(self) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}
