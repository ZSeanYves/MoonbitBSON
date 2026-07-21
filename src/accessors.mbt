///|
pub fn Bson::as_binary(self : Bson) -> Binary? {
  match self {
    Binary(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_object_id(self : Bson) -> ObjectId? {
  match self {
    ObjectId(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_datetime(self : Bson) -> DateTime? {
  match self {
    DateTime(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_decimal128(self : Bson) -> Decimal128? {
  match self {
    Decimal128(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_uuid(self : Bson) -> Uuid? {
  match self {
    Binary(value) => value.as_uuid()
    _ => None
  }
}

///|
pub fn Bson::as_regex(self : Bson) -> Regex? {
  match self {
    Regex(value) => Some(value)
    _ => None
  }
}

///|
pub fn Bson::as_timestamp(self : Bson) -> Timestamp? {
  match self {
    Timestamp(value) => Some(value)
    _ => None
  }
}

///|
pub fn Document::get_binary(self : Document, key : String) -> Binary? {
  match self.get(key) {
    Some(value) => value.as_binary()
    None => None
  }
}

///|
pub fn Document::get_object_id(self : Document, key : String) -> ObjectId? {
  match self.get(key) {
    Some(value) => value.as_object_id()
    None => None
  }
}

///|
pub fn Document::get_datetime(self : Document, key : String) -> DateTime? {
  match self.get(key) {
    Some(value) => value.as_datetime()
    None => None
  }
}

///|
pub fn Document::get_decimal128(self : Document, key : String) -> Decimal128? {
  match self.get(key) {
    Some(value) => value.as_decimal128()
    None => None
  }
}

///|
pub fn Document::get_uuid(self : Document, key : String) -> Uuid? {
  match self.get(key) {
    Some(value) => value.as_uuid()
    None => None
  }
}

///|
pub fn Document::get_regex(self : Document, key : String) -> Regex? {
  match self.get(key) {
    Some(value) => value.as_regex()
    None => None
  }
}

///|
pub fn Document::get_timestamp(self : Document, key : String) -> Timestamp? {
  match self.get(key) {
    Some(value) => value.as_timestamp()
    None => None
  }
}

///|
pub fn Document::require_binary(
  self : Document,
  key : String,
) -> Binary raise BsonError {
  match self.get_binary(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "binary")
  }
}

///|
pub fn Document::require_object_id(
  self : Document,
  key : String,
) -> ObjectId raise BsonError {
  match self.get_object_id(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "objectId")
  }
}

///|
pub fn Document::require_datetime(
  self : Document,
  key : String,
) -> DateTime raise BsonError {
  match self.get_datetime(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "datetime")
  }
}

///|
pub fn Document::require_decimal128(
  self : Document,
  key : String,
) -> Decimal128 raise BsonError {
  match self.get_decimal128(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "decimal128")
  }
}

///|
pub fn Document::require_uuid(
  self : Document,
  key : String,
) -> Uuid raise BsonError {
  match self.get_uuid(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "UUID")
  }
}

///|
pub fn Document::require_regex(
  self : Document,
  key : String,
) -> Regex raise BsonError {
  match self.get_regex(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "regex")
  }
}

///|
pub fn Document::require_timestamp(
  self : Document,
  key : String,
) -> Timestamp raise BsonError {
  match self.get_timestamp(key) {
    Some(value) => value
    None => raise_type_mismatch(key, "timestamp")
  }
}
