///|
pub enum BsonValue {
  Double(Float) // 0x01
  String(String) // 0x02
  Document(Map[String, BsonValue]) // 0x03
  Array(Array[BsonValue]) // 0x04
  Boolean(Bool) // 0x08
  Null // 0x0A
  Int32(Int) // 0x10
  Int64(Int) // 0x12
}

// Optional helper constructor functions (can be moved to bson.mbt later)

///|
pub fn new_document() -> BsonValue {
  Document(Map::new(capacity=8))
}

///|
pub fn new_array() -> BsonValue {
  Array([])
}

///|
pub fn get_bson_type_code(v : BsonValue) -> Byte {
  match v {
    Double(_) => 0x01
    String(_) => 0x02
    Document(_) => 0x03
    Array(_) => 0x04
    Boolean(_) => 0x08
    Null => 0x0A
    Int32(_) => 0x10
    Int64(_) => 0x12
  }
}
