///| BSON Type enumeration
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

//
// ==== Constructor functions ====
//

///|
pub fn bson_double(f : Float) -> BsonValue {
  Double(f)
}

///|
pub fn bson_string(s : String) -> BsonValue {
  String(s)
}

///|
pub fn bson_int32(i : Int) -> BsonValue {
  Int32(i)
}

///|
pub fn bson_int64(i : Int) -> BsonValue {
  Int64(i)
}

///|
pub fn bson_bool(b : Bool) -> BsonValue {
  Boolean(b)
}

///|
pub fn bson_null() -> BsonValue {
  Null
}

///|
pub fn bson_document() -> BsonValue {
  Document(Map::new(capacity=8))
}

///|
pub fn bson_array() -> BsonValue {
  Array([])
}

//
// ==== Type judgment ====
//

///|
pub fn is_string(self : BsonValue) -> Bool {
  match self {
    String(_) => true
    _ => false
  }
}

///|
pub fn is_int(self : BsonValue) -> Bool {
  match self {
    Int32(_) | Int64(_) => true
    _ => false
  }
}

///|
pub fn is_document(self : BsonValue) -> Bool {
  match self {
    Document(_) => true
    _ => false
  }
}

///|
pub fn is_array(self : BsonValue) -> Bool {
  match self {
    Array(_) => true
    _ => false
  }
}

//
// ==== Type Extraction ====
//

///|
pub fn as_string(self : BsonValue) -> String? {
  match self {
    String(s) => Some(s)
    _ => None
  }
}

///|
pub fn as_int32(self : BsonValue) -> Int? {
  match self {
    Int32(i) => Some(i)
    _ => None
  }
}

///|
pub fn as_int64(self : BsonValue) -> Int? {
  match self {
    Int64(i) => Some(i)
    _ => None
  }
}

///|
pub fn as_document(self : BsonValue) -> Map[String, BsonValue]? {
  match self {
    Document(m) => Some(m)
    _ => None
  }
}

///|
pub fn as_array(self : BsonValue) -> Array[BsonValue]? {
  match self {
    Array(arr) => Some(arr)
    _ => None
  }
}

//
// ==== Chain construction ====
//

///| If it is a Document, set the field value (chain writing)
pub fn set(self : BsonValue, key : String, val : BsonValue) -> BsonValue {
  match self {
    Document(m) => {
      m.set(key, val)
      Document(m)
    }
    _ => self
  }
}

///| If it is Array, add elements (chain writing)
pub fn push(self : BsonValue, val : BsonValue) -> BsonValue {
  match self {
    Array(arr) => {
      arr.push(val)
      Array(arr)
    }
    _ => self
  }
}

//
// ==== Print debugging ====
//

///|
impl Show for BsonValue with to_string(self : BsonValue) -> String {
  match self {
    Double(f) => "Double(" + f.to_string() + ")"
    String(s) => "String(" + s + ")"
    Document(_) => "Document{...}"
    Array(_) => "Array[...]"
    Boolean(b) => "Boolean(" + b.to_string() + ")"
    Null => "Null"
    Int32(i) => "Int32(" + i.to_string() + ")"
    Int64(i) => "Int64(" + i.to_string() + ")"
  }
}

///|
impl Eq for BsonValue with op_equal(self, other) {
  match (self, other) {
    (Double(f1), Double(f2)) => f1 == f2
    (String(s1), String(s2)) => s1 == s2
    (Boolean(b1), Boolean(b2)) => b1 == b2
    (Null, Null) => true
    (Int32(i1), Int32(i2)) => i1 == i2
    (Int64(i1), Int64(i2)) => i1 == i2
    (Document(m1), Document(m2)) => m1 == m2
    (Array(a1), Array(a2)) => a1 == a2
    _ => false
  }
}

///|
impl Show for BsonValue with output(self, logger) {
  match self {
    Double(f) => logger.write_object("Double(" + f.to_string() + ")")
    String(s) => logger.write_object("String(" + s + ")")
    Boolean(b) => logger.write_object("Boolean(" + b.to_string() + ")")
    Null => logger.write_object("Null")
    Int32(i) => logger.write_object("Int32(" + i.to_string() + ")")
    Int64(i) => logger.write_object("Int64(" + i.to_string() + ")")
    Document(m) => {
      let parts = m
        .keys()
        .map(fn(k) {
          let v = m.get(k).unwrap_or(Null)
          "\"" + k + "\": " + Show::to_string(v)
        })
      logger.write_object("Document{" + parts.join(", ") + "}")
    }
    Array(arr) => {
      let strs = arr.map(Show::to_string)
      logger.write_object("Array[" + strs.join(", ") + "]")
    }
  }
}

///|
test "Basic Document Encode/Decode" {
  let doc = bson_document()
    .set("name", bson_string("Alice"))
    .set("age", bson_int32(30))
    .set("vip", bson_bool(true))
  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

///|
test "Nested Document" {
  let inner = bson_document().set("city", bson_string("Shanghai"))
  let doc = bson_document().set("user", inner)
  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

///|
test "Array Encode/Decode" {
  let arr = bson_array().push(bson_string("A")).push(bson_int64(1234567890))
  let doc = bson_document().set("list", arr)
  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

///|
test "Empty Document Roundtrip" {
  let doc = bson_document()
  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

///|
test "check decode_cstring result" {
  let raw : Array[Byte] = [0x6E, 0x61, 0x6D, 0x65, 0x00] // "name"
  let reader = @buffer.new_reader(Bytes::from_array(raw))
  let result = decode_cstring(reader)
  println(result)
  assert_eq(result, "name")
}

test "Basic Types Roundtrip" {
  let doc = bson_document()
    .set("str", bson_string("hello"))
    .set("i32", bson_int32(123))
    .set("fake_i64", bson_string("9876543210123456789")) // Int64 as string
    .set("bool", bson_bool(true))
    .set("null", bson_null())

  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

test "Deeply Nested Document" {
  let inner = bson_document().set("level3", bson_string("deep"))
  let mid = bson_document().set("level2", inner)
  let outer = bson_document().set("level1", mid)

  let bin = encode_bson(outer)
  let result = decode_bson(bin)
  assert_eq(result, outer)
}

test "Empty Array Encode/Decode" {
  let arr = bson_array() // 空数组
  let doc = bson_document().set("emptyList", arr)

  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

test "Array of Mixed Types" {
  let inner = bson_document().set("id", bson_int32(1))
  let arr = bson_array()
    .push(bson_string("item"))
    .push(bson_int64(123456))
    .push(inner)

  let doc = bson_document().set("mixed", arr)

  let bin = encode_bson(doc)
  let result = decode_bson(bin)
  assert_eq(result, doc)
}

test "BufferWriter Overflow" {
  let writer = @buffer.new_writer(4)
  let result = try? writer.write_all([0x01, 0x02, 0x03, 0x04, 0x05]) // 长度 5 > 容量 4
  assert_eq(result.is_err(), true)
}
