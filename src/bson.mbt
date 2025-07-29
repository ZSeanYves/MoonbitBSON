///| Top-level convenience API: encode to Bytes
/// Raises BsonError if encoding fails
pub fn to_bson(value : BsonValue) -> Bytes raise Error {
  encode_bson(value)
}

///| Top-level convenience API: decode from Bytes
/// Raises BsonError if decoding fails
pub fn from_bson(bytes : Bytes) -> BsonValue raise Error {
  decode_bson(bytes)
}

///| Safe wrapper: encode to Bytes
/// Returns empty Bytes on failure
pub fn to_bson_safe(value : BsonValue) -> Bytes {
  match (try? encode_bson(value)) {
    Ok(b) => b
    Err(_) => Bytes::from_array([])
  }
}

///| Safe wrapper: decode from Bytes
/// Returns Null on failure
pub fn from_bson_safe(bytes : Bytes) -> BsonValue {
  match (try? decode_bson(bytes)) {
    Ok(v) => v
    Err(_) => BsonValue::Null
  }
}
