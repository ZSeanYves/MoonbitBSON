///|
fn decimal_hex(bytes : Bytes) -> String {
  let builder = StringBuilder()
  for byte in bytes {
    let text = byte.to_hex()
    if text.length() == 1 {
      builder.write_string("0")
    }
    builder.write_string(text)
  }
  builder.to_string()
}

///|
fn decimal_hex_nibble(value : UInt16) -> Int? {
  match value {
    '0'..='9' => Some(value.to_int() - 48)
    'a'..='f' => Some(value.to_int() - 87)
    'A'..='F' => Some(value.to_int() - 55)
    _ => None
  }
}

///|
fn decimal_parse_hex(value : String) -> Bytes {
  let bytes : Array[Byte] = []
  for index in 0..<16 {
    let high = decimal_hex_nibble(value[index * 2]).unwrap()
    let low = decimal_hex_nibble(value[index * 2 + 1]).unwrap()
    bytes.push((high * 16 + low).to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn main {
  for value in @env.args() {
    if value.length() == 32 {
      try {
        let bytes = decimal_parse_hex(value)
        let decimal = @bson.Decimal128::from_bytes(bytes)
        let text = decimal.to_string()
        let roundtrip = decimal_hex(@bson.Decimal128::from_string(text).bytes()) catch {
          _ => "ERROR"
        }
        println(value + "\t" + text + "\t" + roundtrip)
      } catch {
        _ => println(value + "\tERROR\tERROR")
      }
    }
  }
}
