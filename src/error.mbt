///|
/// Stable categories for BSON encoding, decoding, and Extended JSON failures.
pub(all) enum BsonErrorKind {
  UnexpectedEnd
  InvalidLength
  InvalidUtf8
  InvalidCString
  InvalidBoolean
  InvalidArrayIndex
  InvalidBinary
  InvalidObjectId
  InvalidUuid
  InvalidDateTime
  InvalidDecimal128
  InvalidRegex
  UnsupportedType
  TrailingData
  DepthLimit
  SizeLimit
  InvalidExtendedJson
  TypeMismatch
} derive(Eq, Debug)

///|
/// Structured context attached to every BSON error.
pub struct BsonErrorInfo {
  kind : BsonErrorKind
  offset : Int
  path : String
  message : String
} derive(Eq, Debug)

///|
/// The single error raised by the public BSON APIs.
pub suberror BsonError {
  Failure(BsonErrorInfo)
} derive(Eq, Debug)

///|
pub fn BsonErrorInfo::kind(self : BsonErrorInfo) -> BsonErrorKind {
  self.kind
}

///|
pub fn BsonErrorInfo::offset(self : BsonErrorInfo) -> Int {
  self.offset
}

///|
pub fn BsonErrorInfo::path(self : BsonErrorInfo) -> String {
  self.path
}

///|
pub fn BsonErrorInfo::message(self : BsonErrorInfo) -> String {
  self.message
}

///|
pub fn BsonError::info(self : BsonError) -> BsonErrorInfo {
  match self {
    Failure(info) => info
  }
}

///|
fn bson_error(
  kind : BsonErrorKind,
  offset : Int,
  path : String,
  message : String,
) -> BsonError {
  Failure({ kind, offset, path, message })
}

///|
fn field_path(parent : String, key : String) -> String {
  parent + "." + key
}

///|
fn index_path(parent : String, index : Int) -> String {
  parent + "[" + index.to_string() + "]"
}
