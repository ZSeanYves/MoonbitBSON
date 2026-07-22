///|
fn object_id_secure_random(_count : Int) -> Bytes raise BsonError {
  raise bson_error(
    UnsupportedEntropy,
    -1,
    "$.\u{24}oid",
    "this Wasm host does not provide a secure entropy source",
  )
}
