///|
/// BSON binary subtypes, including the subtypes added by BSON 1.1.
pub(all) enum BinarySubtype {
  Generic
  Function
  BinaryOld
  UuidOld
  Uuid
  Md5
  Encrypted
  Column
  Sensitive
  Vector
  Reserved(Byte)
  UserDefined(Byte)
} derive(Eq, Debug)

///|
pub fn BinarySubtype::from_byte(value : Byte) -> BinarySubtype {
  match value {
    0x00 => Generic
    0x01 => Function
    0x02 => BinaryOld
    0x03 => UuidOld
    0x04 => Uuid
    0x05 => Md5
    0x06 => Encrypted
    0x07 => Column
    0x08 => Sensitive
    0x09 => Vector
    0x80..=0xFF => UserDefined(value)
    _ => Reserved(value)
  }
}

///|
pub fn BinarySubtype::to_byte(self : BinarySubtype) -> Byte {
  match self {
    Generic => 0x00
    Function => 0x01
    BinaryOld => 0x02
    UuidOld => 0x03
    Uuid => 0x04
    Md5 => 0x05
    Encrypted => 0x06
    Column => 0x07
    Sensitive => 0x08
    Vector => 0x09
    Reserved(value) | UserDefined(value) => value
  }
}

///|
pub struct Binary {
  subtype : BinarySubtype
  bytes : Bytes
} derive(Eq, Debug)

///|
pub fn Binary::new(subtype : BinarySubtype, bytes : Bytes) -> Binary {
  { subtype, bytes }
}

///|
pub fn Binary::subtype(self : Binary) -> BinarySubtype {
  self.subtype
}

///|
pub fn Binary::bytes(self : Binary) -> Bytes {
  self.bytes
}

///|
/// A 12-byte BSON ObjectId.
pub struct ObjectId {
  bytes : Bytes
} derive(Eq, Debug)

///|
pub fn ObjectId::from_bytes(bytes : Bytes) -> ObjectId raise BsonError {
  if bytes.length() != 12 {
    raise bson_error(
      InvalidObjectId,
      -1,
      "$",
      "ObjectId must contain exactly 12 bytes",
    )
  }
  { bytes, }
}

///|
fn ObjectId::from_valid_bytes(bytes : Bytes) -> ObjectId {
  { bytes, }
}

///|
pub fn ObjectId::bytes(self : ObjectId) -> Bytes {
  self.bytes
}

///|
pub fn ObjectId::to_hex(self : ObjectId) -> String {
  let builder = StringBuilder()
  for byte in self.bytes {
    builder.write_string(byte.to_hex())
  }
  builder.to_string()
}

///|
pub fn ObjectId::from_hex(value : String) -> ObjectId raise BsonError {
  if value.length() != 24 {
    raise bson_error(
      InvalidObjectId,
      -1,
      "$",
      "ObjectId hexadecimal text must contain 24 characters",
    )
  }
  let bytes : Array[Byte] = []
  for index in 0..<12 {
    let high = hex_nibble(value[index * 2])
    let low = hex_nibble(value[index * 2 + 1])
    match (high, low) {
      (Some(high), Some(low)) => bytes.push((high * 16 + low).to_byte())
      _ =>
        raise bson_error(
          InvalidObjectId,
          -1,
          "$",
          "ObjectId contains a non-hexadecimal character",
        )
    }
  }
  ObjectId::from_valid_bytes(Bytes::from_array(bytes))
}

///|
fn hex_nibble(value : UInt16) -> Int? {
  match value {
    '0'..='9' => Some(value.to_int() - 48)
    'a'..='f' => Some(value.to_int() - 87)
    'A'..='F' => Some(value.to_int() - 55)
    _ => None
  }
}

///|
pub struct Regex {
  pattern : String
  options : String
} derive(Eq, Debug)

///|
pub fn Regex::new(pattern : String, options : String) -> Regex {
  { pattern, options }
}

///|
pub fn Regex::pattern(self : Regex) -> String {
  self.pattern
}

///|
pub fn Regex::options(self : Regex) -> String {
  self.options
}

///|
/// BSON timestamps store an increment followed by seconds since the epoch.
pub struct Timestamp {
  time : UInt
  increment : UInt
} derive(Eq, Debug)

///|
pub fn Timestamp::new(time : UInt, increment : UInt) -> Timestamp {
  { time, increment }
}

///|
pub fn Timestamp::time(self : Timestamp) -> UInt {
  self.time
}

///|
pub fn Timestamp::increment(self : Timestamp) -> UInt {
  self.increment
}

///|
/// Decimal128 is kept in its canonical 16-byte IEEE 754-2008 representation.
pub struct Decimal128 {
  bytes : Bytes
} derive(Eq, Debug)

///|
pub fn Decimal128::from_bytes(bytes : Bytes) -> Decimal128 raise BsonError {
  if bytes.length() != 16 {
    raise bson_error(
      InvalidDecimal128,
      -1,
      "$",
      "Decimal128 must contain exactly 16 bytes",
    )
  }
  { bytes, }
}

///|
fn Decimal128::from_valid_bytes(bytes : Bytes) -> Decimal128 {
  { bytes, }
}

///|
pub fn Decimal128::bytes(self : Decimal128) -> Bytes {
  self.bytes
}

///|
/// Parse an exact IEEE 754 Decimal128 string.
pub fn Decimal128::from_string(value : String) -> Decimal128 raise BsonError {
  parse_decimal128(value)
}

///|
/// Format this Decimal128 using MongoDB's canonical text representation.
pub fn Decimal128::to_string(self : Decimal128) -> String {
  format_decimal128(self)
}

///|
pub struct DbPointer {
  collection : String
  id : ObjectId
} derive(Eq, Debug)

///|
pub fn DbPointer::new(collection : String, id : ObjectId) -> DbPointer {
  { collection, id }
}

///|
pub fn DbPointer::collection(self : DbPointer) -> String {
  self.collection
}

///|
pub fn DbPointer::id(self : DbPointer) -> ObjectId {
  self.id
}

///|
pub struct JavaScriptWithScope {
  code : String
  scope : Document
} derive(Eq, Debug)

///|
pub fn JavaScriptWithScope::new(
  code : String,
  scope : Document,
) -> JavaScriptWithScope {
  { code, scope }
}

///|
pub fn JavaScriptWithScope::code(self : JavaScriptWithScope) -> String {
  self.code
}

///|
pub fn JavaScriptWithScope::scope(self : JavaScriptWithScope) -> Document {
  self.scope
}

///|
/// An insertion-ordered, owned BSON document.
pub struct Document {
  values : Map[String, Bson]
} derive(Eq, Debug)

///|
pub fn Document::new() -> Document {
  { values: Map([], capacity=8) }
}

///|
pub fn Document::from_array(values : Array[(String, Bson)]) -> Document {
  { values: Map(values) }
}

///|
pub fn Document::set(self : Document, key : String, value : Bson) -> Document {
  self.values.set(key, value)
  self
}

///|
pub fn Document::remove(self : Document, key : String) -> Unit {
  self.values.remove(key)
}

///|
pub fn Document::get(self : Document, key : String) -> Bson? {
  self.values.get(key)
}

///|
pub fn Document::contains(self : Document, key : String) -> Bool {
  self.values.contains(key)
}

///|
pub fn Document::length(self : Document) -> Int {
  self.values.length()
}

///|
pub fn Document::is_empty(self : Document) -> Bool {
  self.values.is_empty()
}

///|
pub fn Document::to_array(self : Document) -> Array[(String, Bson)] {
  self.values.to_array()
}

///|
pub fn Document::entries(self : Document) -> Array[(String, Bson)] {
  self.values.to_array()
}

///|
pub fn Document::require(self : Document, key : String) -> Bson raise BsonError {
  match self.get(key) {
    Some(value) => value
    None =>
      raise bson_error(
        TypeMismatch,
        -1,
        field_path("$", key),
        "required BSON field is missing",
      )
  }
}

///|
pub fn Document::get_string(self : Document, key : String) -> String? {
  match self.get(key) {
    Some(value) => value.as_string()
    None => None
  }
}

///|
pub fn Document::get_document(self : Document, key : String) -> Document? {
  match self.get(key) {
    Some(value) => value.as_document()
    None => None
  }
}

///|
pub fn Document::get_array(self : Document, key : String) -> Array[Bson]? {
  match self.get(key) {
    Some(value) => value.as_array()
    None => None
  }
}

///|
pub fn Document::get_int32(self : Document, key : String) -> Int? {
  match self.get(key) {
    Some(value) => value.as_int32()
    None => None
  }
}

///|
pub fn Document::get_int64(self : Document, key : String) -> Int64? {
  match self.get(key) {
    Some(value) => value.as_int64()
    None => None
  }
}

///|
pub fn Document::get_double(self : Document, key : String) -> Double? {
  match self.get(key) {
    Some(value) => value.as_double()
    None => None
  }
}

///|
pub fn Document::get_bool(self : Document, key : String) -> Bool? {
  match self.get(key) {
    Some(value) => value.as_bool()
    None => None
  }
}

///|
pub fn Document::require_string(
  self : Document,
  key : String,
) -> String raise BsonError {
  match self.get_string(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "string")
  }
}

///|
pub fn Document::require_document(
  self : Document,
  key : String,
) -> Document raise BsonError {
  match self.get_document(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "document")
  }
}

///|
pub fn Document::require_array(
  self : Document,
  key : String,
) -> Array[Bson] raise BsonError {
  match self.get_array(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "array")
  }
}

///|
pub fn Document::require_int32(
  self : Document,
  key : String,
) -> Int raise BsonError {
  match self.get_int32(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "int32")
  }
}

///|
pub fn Document::require_int64(
  self : Document,
  key : String,
) -> Int64 raise BsonError {
  match self.get_int64(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "int64")
  }
}

///|
pub fn Document::require_double(
  self : Document,
  key : String,
) -> Double raise BsonError {
  match self.get_double(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "double")
  }
}

///|
pub fn Document::require_bool(
  self : Document,
  key : String,
) -> Bool raise BsonError {
  match self.get_bool(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "boolean")
  }
}

///|
fn[T] raise_type_mismatch(key : String, expected : String) -> T raise BsonError {
  raise bson_error(
    TypeMismatch,
    -1,
    field_path("$", key),
    "required field is missing or is not " + expected,
  )
}

///|
/// Complete BSON 1.1 value model, including deprecated wire types for decoding.
pub(all) enum Bson {
  Double(Double)
  String(String)
  Document(Document)
  Array(Array[Bson])
  Binary(Binary)
  Undefined
  ObjectId(ObjectId)
  Boolean(Bool)
  DateTime(DateTime)
  Null
  Regex(Regex)
  DbPointer(DbPointer)
  JavaScript(String)
  Symbol(String)
  JavaScriptWithScope(JavaScriptWithScope)
  Int32(Int)
  Timestamp(Timestamp)
  Int64(Int64)
  Decimal128(Decimal128)
  MinKey
  MaxKey
} derive(Eq, Debug)

///|
pub fn Bson::as_string(self : Bson) -> String? {
  match self {
    String(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_document(self : Bson) -> Document? {
  match self {
    Document(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_array(self : Bson) -> Array[Bson]? {
  match self {
    Array(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_int32(self : Bson) -> Int? {
  match self {
    Int32(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_int64(self : Bson) -> Int64? {
  match self {
    Int64(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_double(self : Bson) -> Double? {
  match self {
    Double(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_bool(self : Bson) -> Bool? {
  match self {
    Boolean(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::type_name(self : Bson) -> String {
  match self {
    Double(_) => "double"
    String(_) => "string"
    Document(_) => "document"
    Array(_) => "array"
    Binary(_) => "binary"
    Undefined => "undefined"
    ObjectId(_) => "objectId"
    Boolean(_) => "boolean"
    DateTime(_) => "dateTime"
    Null => "null"
    Regex(_) => "regex"
    DbPointer(_) => "dbPointer"
    JavaScript(_) => "javascript"
    Symbol(_) => "symbol"
    JavaScriptWithScope(_) => "javascriptWithScope"
    Int32(_) => "int32"
    Timestamp(_) => "timestamp"
    Int64(_) => "int64"
    Decimal128(_) => "decimal128"
    MinKey => "minKey"
    MaxKey => "maxKey"
  }
}

///|
/// Validated owned raw BSON. It preserves field order, duplicate keys, and bytes.
pub struct RawDocument {
  bytes : Bytes
} derive(Eq, Debug)

///|
fn RawDocument::from_valid_bytes(bytes : Bytes) -> RawDocument {
  { bytes, }
}

///|
pub fn RawDocument::bytes(self : RawDocument) -> Bytes {
  self.bytes
}

///|
pub fn RawDocument::view(self : RawDocument) -> BytesView {
  self.bytes[:]
}
