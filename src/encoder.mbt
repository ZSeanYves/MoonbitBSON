///| Encode a complete BsonValue document
pub fn encode_bson(doc : BsonValue) -> Bytes raise Error {
  match doc {
    Document(map) => encode_document(map)
    _ =>
      raise BsonError::InvalidDocumentLength("Top-level value must be Document")
  }
}

///| Encode a BSON document from Map
fn encode_document(map : Map[String, BsonValue]) -> Bytes raise Error {
  let writer = @buffer.new_writer(128)
  writer.write_all([0, 0, 0, 0]) // placeholder for length
  for k in map.keys() {
    match map.get(k) {
      Some(v) => {
        let type_code = get_type_code(v)
        writer.write_byte(type_code)
        write_cstring(writer, k)
        write_element(writer, v)
      }
      None =>
        raise BsonError::InvalidDocumentLength("Missing value in document map")
    }
  }
  writer.write_byte(0x00) // document end
  let result = writer.flush()
  let len = result.length()
  let len_bytes = encode_i32(len)
  for i in 0..<4 {
    result[i] = len_bytes[i]
  }
  Bytes::from_array(result)
}

///| Get BSON type code for a BsonValue
fn get_type_code(v : BsonValue) -> Byte {
  match v {
    Double(_) => 0x01
    String(_) => 0x02
    Document(_) => 0x03
    Array(_) => 0x04
    Boolean(_) => 0x08
    Null => 0x0A
    Int32(_) => 0x10
    Int64(_) => 0x12
  }
}

///| Write a BSON element
fn write_element(
  writer : @buffer.BufferWriter,
  v : BsonValue,
) -> Unit raise Error {
  match v {
    Double(_) => raise BsonError::UnsupportedType(0x01) // not implemented
    String(s) => write_string(writer, s)
    Document(m) => writer.write_all(encode_document(m).to_array())
    Array(arr) => write_array(writer, arr)
    Boolean(b) => writer.write_byte(if b { 1 } else { 0 })
    Null => () // no content
    Int32(i) => writer.write_all(encode_i32(i))
    Int64(i) => writer.write_all(encode_i64(i))
  }
}

///| Write a BSON array (index as string keys)
fn write_array(
  writer : @buffer.BufferWriter,
  arr : Array[BsonValue],
) -> Unit raise Error {
  let inner = Map::new(capacity=arr.length())
  for i in 0..<arr.length() {
    inner.set(i.to_string(), arr[i])
  }
  writer.write_all(encode_document(inner).to_array())
}

///| Write a CString (null-terminated)
fn write_cstring(writer : @buffer.BufferWriter, s : String) -> Unit raise Error {
  let bytes = @buffer.string_to_utf8_bytes(s).to_array()
  writer.write_all(bytes)
  writer.write_byte(0x00)
}

///| Write a BSON string (length + content + null)
fn write_string(writer : @buffer.BufferWriter, s : String) -> Unit raise Error {
  let bytes = @buffer.string_to_utf8_bytes(s).to_array()
  let len = bytes.length() + 1
  writer.write_all(encode_i32(len))
  writer.write_all(bytes)
  writer.write_byte(0x00)
}

///| Encode Int32 to 4 bytes (little endian)
fn encode_i32(v : Int) -> Array[Byte] {
  [
    (v & 0xFF).to_byte(),
    ((v >> 8) & 0xFF).to_byte(),
    ((v >> 16) & 0xFF).to_byte(),
    ((v >> 24) & 0xFF).to_byte(),
  ]
}

///| Encode Int64 to 8 bytes (little endian)
fn encode_i64(v : Int) -> Array[Byte] {
  [
    (v & 0xFF).to_byte(),
    ((v >> 8) & 0xFF).to_byte(),
    ((v >> 16) & 0xFF).to_byte(),
    ((v >> 24) & 0xFF).to_byte(),
    ((v >> 32) & 0xFF).to_byte(),
    ((v >> 40) & 0xFF).to_byte(),
    ((v >> 48) & 0xFF).to_byte(),
    ((v >> 56) & 0xFF).to_byte(),
  ]
}
