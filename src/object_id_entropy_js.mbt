///|
extern "js" fn object_id_secure_random_ffi(buffer : Bytes) -> Bool =
  #| (buffer) => {
  #|   if (!globalThis.crypto || typeof globalThis.crypto.getRandomValues !== "function") {
  #|     return false;
  #|   }
  #|   globalThis.crypto.getRandomValues(buffer);
  #|   return true;
  #| }

///|
fn object_id_secure_random(count : Int) -> Bytes raise BsonError {
  match secure_entropy_from_provider(count) {
    Some(bytes) => return bytes
    None => ()
  }
  let buffer = Bytes::make(count, 0)
  if !object_id_secure_random_ffi(buffer) {
    raise bson_error(
      UnsupportedEntropy,
      -1,
      "$.\u{24}oid",
      "Web Crypto secure entropy is unavailable",
    )
  }
  buffer
}
