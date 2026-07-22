///|
fn object_id_secure_random(count : Int) -> Bytes raise BsonError {
  match secure_entropy_from_provider(count) {
    Some(bytes) => return bytes
    None => ()
  }
  raise bson_error(
    UnsupportedEntropy,
    -1,
    "$.\u{24}oid",
    "this Wasm host does not provide a secure entropy source",
  )
}
