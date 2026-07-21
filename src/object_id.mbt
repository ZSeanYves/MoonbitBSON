///|
let object_id_process_unique : Bytes = {
  let time = @env.now()
  let seed = Bytes::makei(32, index => {
    let mixed = time ^ (index.to_uint64() * 0x9E3779B97F4A7C15UL)
    (mixed >> (index % 8 * 8)).to_byte()
  })
  let random = @random.Rand::chacha8(seed~)
  Bytes::makei(5, _ => random.uint(limit=256U).to_byte())
}

///|
let object_id_counter : Ref[UInt] = @ref.new(@env.now().to_uint() & 0xFFFFFFU)

///|
/// Generate a best-effort local ObjectId from the current Unix time, a process
/// value, and a monotonically increasing 24-bit counter. Callers that require
/// externally sourced process uniqueness should use `ObjectId::from_parts`.
pub fn ObjectId::new() -> ObjectId {
  let timestamp = (@env.now() / 1000UL).to_uint()
  let counter = object_id_counter.val
  object_id_counter.val = (counter + 1U) & 0xFFFFFFU
  ObjectId::from_valid_bytes(
    object_id_bytes(timestamp, object_id_process_unique, counter),
  )
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
