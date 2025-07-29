// 模拟 Array.slice(from, to)：从索引 from（含）到 to（不含）

///|
fn slice_array(arr : Array[Byte], from : Int, to : Int) -> Array[Byte] {
  let result : Array[Byte] = []
  let n = arr.length()
  let start = if from < 0 { 0 } else { from }
  let end = if to > n { n } else { to }
  let mut i = start
  while i < end {
    result.push(arr[i])
    i += 1
  }
  result
}

// Entry point: decode BSON from Bytes

///| This function is commented out because decode_document requires trait BufReadable 
pub fn decode_bson(data : Bytes) -> BsonValue raise Error {
  let reader = @buffer.new_reader(data)
  decode_document(reader)
}

// Decode a BSON document from reader

///|
fn decode_document(reader : @buffer.BufferReader) -> BsonValue raise Error {
  let total_len = decode_i32(reader)
  if total_len < 5 {
    raise InvalidDocumentLength("BSON document too short")
  }
  let map = Map::new(capacity=8)
  while true {
    let type_code = reader.read_byte() // use trait method
    if type_code == 0x00 {
      break
    } // End of document
    let key = decode_cstring(reader)
    let value = decode_element(type_code, reader)
    map.set(key, value)
  }
  Document(map)
}

// Decode BSON element based on type

///|
fn decode_element(
  type_code : Byte,
  reader : @buffer.BufferReader,
) -> BsonValue raise Error {
  match type_code {
    0x01 => {
      let b = read_n(reader, 8)
      let f = bytes_to_f64(b)
      Double(f)
    }
    0x02 => {
      let s = decode_string(reader)
      String(s)
    }
    0x03 => decode_document(reader)
    0x04 => decode_array(reader)
    0x08 => {
      let b = reader.read_byte()
      Boolean(b != 0)
    }
    0x0A => Null
    0x10 => {
      let b = read_n(reader, 4)
      Int32(bytes_to_i32(b))
    }
    0x12 => {
      let b = read_n(reader, 8)
      Int64(bytes_to_i64(b))
    }
    _ => raise UnsupportedType(type_code)
  }
}

// Decode BSON array: keys are "0", "1", ...

///|
fn decode_array(reader : @buffer.BufferReader) -> BsonValue raise Error {
  let total_len = decode_i32(reader)
  if total_len < 5 {
    raise InvalidDocumentLength("BSON array too short")
  }
  let arr : Array[BsonValue] = []
  while true {
    let type_code = reader.read_byte()
    if type_code == 0x00 {
      break
    }
    let _ = decode_cstring(reader) // skip index
    let value = decode_element(type_code, reader)
    arr.push(value)
  }
  Array(arr)
}

// Read CString: null-terminated UTF-8

///|
fn decode_cstring(reader : @buffer.BufferReader) -> String raise Error {
  let bytes : Array[Byte] = []
  while true {
    if reader.is_empty() {
      raise InvalidString("未找到CString的结尾(缺少 0x00 终止符)")
    }
    let b = reader.read_byte()
    if b == 0x00 {
      break
    }
    bytes.push(b)
  }
  @buffer.utf8_bytes_to_string(Bytes::from_array(bytes))
}

// Decode UTF-8 String (Int32 length + content + 0x00)

///|
fn decode_string(reader : @buffer.BufferReader) -> String raise Error {
  let len = decode_i32(reader)
  if len <= 0 {
    raise InvalidStringLength("字符串长度无效")
  }
  let raw = read_n(reader, len)
  if raw.length() != len {
    raise InvalidStringLength("读取字符串时超出缓冲区长度")
  }
  if raw[len - 1] != 0x00 {
    raise InvalidUtf8("字符串未以 null (0x00) 结尾")
  }
  let byte = Bytes::from_array(slice_array(raw, 0, len - 1))
  @buffer.utf8_bytes_to_string(byte)
}

// Read n bytes from reader

///|
fn read_n(reader : @buffer.BufferReader, n : Int) -> Array[Byte] raise Error {
  let buf : Array[Byte] = []
  for i in 0..<n {
    let b = reader.read_byte()
    buf.push(b)
  }
  buf
}

// Decode little-endian Int32

///|
fn decode_i32(reader : @buffer.BufferReader) -> Int raise Error {
  let b = read_n(reader, 4)
  bytes_to_i32(b)
}

// Byte array to Int32 (little-endian)

///|
fn bytes_to_i32(b : Array[Byte]) -> Int {
  b[0].to_int() |
  (b[1].to_int() << 8) |
  (b[2].to_int() << 16) |
  (b[3].to_int() << 24)
}

// Byte array to Int64 (little-endian)

///|
fn bytes_to_i64(b : Array[Byte]) -> Int {
  let lo = bytes_to_i32(slice_array(b, 0, 4))
  let hi = bytes_to_i32(slice_array(b, 4, 8))
  (hi << 32) | (lo & 0xFFFFFFFF)
}

// Byte array to Float (placeholder)

///|
fn bytes_to_f64(_b : Array[Byte]) -> Float {
  // TODO: implement real conversion
  0.0
}
