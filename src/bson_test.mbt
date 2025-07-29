///|
test "Invalid Document Length" {
  // Declared length is 1, which is too short to be valid BSON
  let invalid_bytes = Bytes::from_array([0x01, 0x00, 0x00, 0x00])
  let res = try? decode_bson(invalid_bytes)
  assert_eq(res.is_err(), true)
}

///|
test "CString Missing Null Terminator" {
  // Missing 0x00 terminator after key
  let data : Array[Byte] = [0x05, 0x00, 0x00, 0x00, 0x02, 0x78, 0x79]
  let res = try? decode_bson(Bytes::from_array(data))
  assert_eq(res.is_err(), true)
}

///|
test "Unsupported Type Decode" {
  // 0xFF is not a valid BSON type code
  let data : Array[Byte] = [
    0x0A, 0x00, 0x00, 0x00, 0xFF, 0x61, 0x00, // key = "a"
     0x00,
  ] // document end
  let res = try? decode_bson(Bytes::from_array(data))
  assert_eq(res.is_err(), true)
}
