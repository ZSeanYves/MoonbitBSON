///|
/// Convert a MoonBit value into the BSON data model.
pub(open) trait ToBson {
  fn to_bson(Self) -> Bson raise BsonError
}

///|
/// Convert a BSON value into a MoonBit value.
pub(open) trait FromBson {
  fn from_bson(Bson) -> Self raise BsonError
}

///|
pub fn[T : ToBson] to_bson(value : T) -> Bson raise BsonError {
  ToBson::to_bson(value)
}

///|
pub fn[T : FromBson] from_bson(value : Bson) -> T raise BsonError {
  FromBson::from_bson(value)
}

///|
pub fn[T : ToBson] serialize_to_bytes(value : T) -> Bytes raise BsonError {
  match value.to_bson() {
    Document(document) => encode(document)
    value => serialization_type_error("document", value)
  }
}

///|
pub fn[T : FromBson] deserialize_from_bytes(value : Bytes) -> T raise BsonError {
  T::from_bson(Document(decode(value)))
}

///|
pub impl ToBson for Bson with fn to_bson(self) {
  self
}

///|
pub impl FromBson for Bson with fn from_bson(value) {
  value
}

///|
pub impl ToBson for Document with fn to_bson(self) {
  Document(self)
}

///|
pub impl FromBson for Document with fn from_bson(value) {
  match value {
    Document(document) => document
    value => serialization_type_error("document", value)
  }
}

///|
pub impl ToBson for String with fn to_bson(self) {
  String(self)
}

///|
pub impl FromBson for String with fn from_bson(value) {
  match value {
    String(value) => value
    value => serialization_type_error("string", value)
  }
}

///|
pub impl ToBson for Bool with fn to_bson(self) {
  Boolean(self)
}

///|
pub impl FromBson for Bool with fn from_bson(value) {
  match value {
    Boolean(value) => value
    value => serialization_type_error("boolean", value)
  }
}

///|
pub impl ToBson for Int with fn to_bson(self) {
  Int32(self)
}

///|
pub impl FromBson for Int with fn from_bson(value) {
  match value {
    Int32(value) => value
    value => serialization_type_error("int32", value)
  }
}

///|
pub impl ToBson for Int64 with fn to_bson(self) {
  Int64(self)
}

///|
pub impl FromBson for Int64 with fn from_bson(value) {
  match value {
    Int64(value) => value
    Int32(value) => value.to_int64()
    value => serialization_type_error("int64", value)
  }
}

///|
pub impl ToBson for Double with fn to_bson(self) {
  Double(self)
}

///|
pub impl FromBson for Double with fn from_bson(value) {
  match value {
    Double(value) => value
    value => serialization_type_error("double", value)
  }
}

///|
pub impl ToBson for Bytes with fn to_bson(self) {
  Binary(Binary::new(Generic, self))
}

///|
pub impl FromBson for Bytes with fn from_bson(value) {
  match value {
    Binary(value) if value.subtype() == Generic => value.bytes()
    value => serialization_type_error("generic binary", value)
  }
}

///|
pub impl ToBson for DateTime with fn to_bson(self) {
  DateTime(self)
}

///|
pub impl FromBson for DateTime with fn from_bson(value) {
  match value {
    DateTime(value) => value
    value => serialization_type_error("datetime", value)
  }
}

///|
pub impl ToBson for ObjectId with fn to_bson(self) {
  ObjectId(self)
}

///|
pub impl FromBson for ObjectId with fn from_bson(value) {
  match value {
    ObjectId(value) => value
    value => serialization_type_error("objectId", value)
  }
}

///|
pub impl ToBson for Decimal128 with fn to_bson(self) {
  Decimal128(self)
}

///|
pub impl FromBson for Decimal128 with fn from_bson(value) {
  match value {
    Decimal128(value) => value
    value => serialization_type_error("decimal128", value)
  }
}

///|
pub impl ToBson for Uuid with fn to_bson(self) {
  Binary(self.to_binary())
}

///|
pub impl FromBson for Uuid with fn from_bson(value) {
  match value {
    Binary(value) => Uuid::from_binary(value)
    value => serialization_type_error("UUID binary", value)
  }
}

///|
pub impl[T : ToBson] ToBson for Array[T] with fn to_bson(self) {
  Array(self.map(value => value.to_bson()))
}

///|
pub impl[T : FromBson] FromBson for Array[T] with fn from_bson(value) {
  match value {
    Array(values) => values.map(value => T::from_bson(value))
    value => serialization_type_error("array", value)
  }
}

///|
pub impl[T : ToBson] ToBson for T? with fn to_bson(self) {
  match self {
    Some(value) => value.to_bson()
    None => Null
  }
}

///|
pub impl[T : FromBson] FromBson for T? with fn from_bson(value) {
  match value {
    Null => None
    value => Some(T::from_bson(value))
  }
}

///|
pub impl[T : ToBson] ToBson for Map[String, T] with fn to_bson(self) {
  let document = Document::new()
  for key, value in self {
    document.set(key, value.to_bson()) |> ignore
  }
  Document(document)
}

///|
pub impl[T : FromBson] FromBson for Map[String, T] with fn from_bson(value) {
  match value {
    Document(document) => {
      let values : Map[String, T] = Map([])
      for entry in document.entries() {
        let (key, value) = entry
        values.set(key, T::from_bson(value))
      }
      values
    }
    value => serialization_type_error("document", value)
  }
}

///|
fn[T] serialization_type_error(
  expected : String,
  actual : Bson,
) -> T raise BsonError {
  raise bson_error(
    TypeMismatch,
    -1,
    "$",
    "expected " + expected + ", found " + actual.type_name(),
  )
}
