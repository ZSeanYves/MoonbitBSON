///|
pub suberror BsonError {
  InvalidString(String)
  UnsupportedType(Byte)
  InvalidUtf8(String)
  InvalidDocumentLength(String)
  InvalidStringLength(String)
}
