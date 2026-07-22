///|
let object_id_initial : (Bytes, UInt)? = None

///|
let object_id_state : Ref[(Bytes, UInt)?] = @ref.new(object_id_initial)

///|
/// Generate an ObjectId using an OS/Web Crypto secure random process value and
/// counter seed. Portable Wasm without a host entropy provider raises
/// `UnsupportedEntropy`; it never falls back to a deterministic PRNG.
pub fn ObjectId::new() -> ObjectId raise BsonError {
  let timestamp = (@env.now() / 1000UL).to_uint()
  let (process_unique, counter) = match object_id_state.val {
    Some(state) => state
    None => {
      let entropy = object_id_secure_random(8)
      let process_unique = entropy[0:5].to_owned()
      let counter = (entropy[5].to_uint() << 16) |
        (entropy[6].to_uint() << 8) |
        entropy[7].to_uint()
      object_id_state.val = Some((process_unique, counter))
      (process_unique, counter)
    }
  }
  object_id_state.val = Some((process_unique, (counter + 1U) & 0xFFFFFFU))
  ObjectId::from_valid_bytes(
    object_id_bytes(timestamp, process_unique, counter),
  )
}

///|
/// Explicit alias for callers that want to document the entropy requirement.
pub fn ObjectId::new_secure() -> ObjectId raise BsonError {
  ObjectId::new()
}

///|
pub fn ObjectId::from_parts(
  timestamp : UInt,
  process_unique : Bytes,
  counter : UInt,
) -> ObjectId raise BsonError {
  if process_unique.length() != 5 {
    raise bson_error(
      InvalidObjectId,
      -1,
      "$",
      "ObjectId process-unique value must contain five bytes",
    )
  }
  if counter > 0xFFFFFFU {
    raise bson_error(
      InvalidObjectId,
      -1,
      "$",
      "ObjectId counter must fit in 24 bits",
    )
  }
  ObjectId::from_valid_bytes(
    object_id_bytes(timestamp, process_unique, counter),
  )
}

///|
pub fn ObjectId::timestamp(self : ObjectId) -> DateTime {
  let bytes = self.bytes()
  let seconds = (bytes[0].to_uint() << 24) |
    (bytes[1].to_uint() << 16) |
    (bytes[2].to_uint() << 8) |
    bytes[3].to_uint()
  DateTime::from_millis(seconds.to_int64() * 1000L)
}

///|
fn object_id_bytes(
  timestamp : UInt,
  process_unique : Bytes,
  counter : UInt,
) -> Bytes {
  Bytes::makei(12, index => {
    match index {
      0 => (timestamp >> 24).to_byte()
      1 => (timestamp >> 16).to_byte()
      2 => (timestamp >> 8).to_byte()
      3 => timestamp.to_byte()
      4..=8 => process_unique[index - 4]
      9 => (counter >> 16).to_byte()
      10 => (counter >> 8).to_byte()
      _ => counter.to_byte()
    }
  })
}
