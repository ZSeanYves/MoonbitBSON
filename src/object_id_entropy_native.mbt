///|
#borrow(buffer)
extern "c" fn object_id_secure_random_ffi(buffer : Bytes) -> Int = "moonbit_bson_secure_random"

///|
fn object_id_secure_random(count : Int) -> Bytes raise BsonError {
  match secure_entropy_from_provider(count) {
    Some(bytes) => return bytes
    None => ()
  }
  let buffer = Bytes::make(count, 0)
  if object_id_secure_random_ffi(buffer) != 0 {
    raise bson_error(
      UnsupportedEntropy,
      -1,
      "$.\u{24}oid",
      "native operating system secure entropy is unavailable",
    )
  }
  buffer
}
