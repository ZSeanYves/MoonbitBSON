///|
/// A BSON string whose UTF-8 payload remains borrowed.
pub struct RawStringRef {
  bytes : BytesView
} derive(Eq, Debug)

///|
pub fn RawStringRef::bytes(self : RawStringRef) -> BytesView {
  self.bytes
}

///|
pub fn RawStringRef::to_string(self : RawStringRef) -> String raise BsonError {
  @utf8.decode(self.bytes) catch {
    _ =>
      raise bson_error(
        InvalidUtf8,
        self.bytes.start_offset(),
        "$.string",
        "invalid raw UTF-8 string",
      )
  }
}

///|
/// Borrowed BSON binary payload.
pub struct RawBinaryRef {
  subtype : BinarySubtype
  bytes : BytesView
} derive(Eq, Debug)

///|
pub fn RawBinaryRef::subtype(self : RawBinaryRef) -> BinarySubtype {
  self.subtype
}

///|
pub fn RawBinaryRef::bytes(self : RawBinaryRef) -> BytesView {
  self.bytes
}

///|
/// Borrowed BSON regular expression.
pub struct RawRegexRef {
  pattern : BytesView
  options : BytesView
} derive(Eq, Debug)

///|
pub fn RawRegexRef::pattern(self : RawRegexRef) -> BytesView {
  self.pattern
}

///|
pub fn RawRegexRef::options(self : RawRegexRef) -> BytesView {
  self.options
}

///|
pub fn RawRegexRef::to_regex(self : RawRegexRef) -> Regex raise BsonError {
  let pattern = @utf8.decode(self.pattern) catch {
    _ =>
      raise bson_error(
        InvalidUtf8,
        self.pattern.start_offset(),
        "$.regex.pattern",
        "raw regex pattern is not valid UTF-8",
      )
  }
  let options = @utf8.decode(self.options) catch {
    _ =>
      raise bson_error(
        InvalidUtf8,
        self.options.start_offset(),
        "$.regex.options",
        "raw regex options are not valid UTF-8",
      )
  }
  Regex::new(pattern, options)
}

///|
/// Borrowed BSON DBPointer.
pub struct RawDbPointerRef {
  namespace_value : RawStringRef
  id : BytesView
} derive(Eq, Debug)

///|
pub fn RawDbPointerRef::namespace_value(self : RawDbPointerRef) -> RawStringRef {
  self.namespace_value
}

///|
pub fn RawDbPointerRef::id_bytes(self : RawDbPointerRef) -> BytesView {
  self.id
}

///|
/// Borrowed JavaScript-with-scope value.
pub struct RawJavaScriptWithScopeRef {
  code : RawStringRef
  scope : RawDocumentView
} derive(Eq, Debug)

///|
pub fn RawJavaScriptWithScopeRef::code(
  self : RawJavaScriptWithScopeRef,
) -> RawStringRef {
  self.code
}

///|
pub fn RawJavaScriptWithScopeRef::scope(
  self : RawJavaScriptWithScopeRef,
) -> RawDocumentView {
  self.scope
}

///|
/// A BSON value that borrows all byte payloads from its source document.
pub(all) enum RawBsonRef {
  Double(Double)
  String(RawStringRef)
  Document(RawDocumentView)
  Array(RawArrayView)
  Binary(RawBinaryRef)
  Undefined
  ObjectId(BytesView)
  Boolean(Bool)
  DateTime(Int64)
  Null
  Regex(RawRegexRef)
  DbPointer(RawDbPointerRef)
  JavaScript(RawStringRef)
  Symbol(RawStringRef)
  JavaScriptWithScope(RawJavaScriptWithScopeRef)
  Int32(Int)
  Timestamp(Timestamp)
  Int64(Int64)
  Decimal128(BytesView)
  MinKey
  MaxKey
} derive(Eq, Debug)

///|
/// A borrowed BSON array, represented by its wire document view.
pub struct RawArrayView {
  document : RawDocumentView
} derive(Eq, Debug)

///|
pub fn RawArrayView::from_bytes(
  bytes : BytesView,
) -> RawArrayView raise BsonError {
  { document: RawDocumentView::from_bytes(bytes) }
}

///|
pub fn RawArrayView::document(self : RawArrayView) -> RawDocumentView {
  self.document
}

///|
pub fn RawArrayView::iter(self : RawArrayView) -> RawElementViewIter {
  self.document.iter()
}

///|
pub fn RawArrayView::get(
  self : RawArrayView,
  index : Int,
) -> RawBsonRef? raise BsonError {
  let expected = index.to_string()
  let iterator = self.iter()
  while iterator.next() is Some(element) {
    if element.key() == expected {
      return Some(element.value())
    }
  }
  None
}

///|
/// Convert a borrowed array to owned values explicitly.
pub fn RawArrayView::to_array(
  self : RawArrayView,
) -> Array[Bson] raise BsonError {
  let values : Array[Bson] = []
  let iterator = self.iter()
  while iterator.next() is Some(element) {
    values.push(element.value().to_bson())
  }
  values
}

///|
/// Return the borrowed value represented by this element.
pub fn RawElementView::value(
  self : RawElementView,
) -> RawBsonRef raise BsonError {
  let bytes = self.document.bytes
  let start = self.value_start
  let path = field_path("$", self.key())
  match self.type_code {
    0x01 => Double(raw_view_i64(bytes, start, path).reinterpret_as_double())
    0x02 =>
      String({
        bytes: raw_view_string_payload(bytes, start, self.value_end, path),
      })
    0x03 => Document(RawDocumentView::from_bytes(self.raw_bytes()))
    0x04 => Array(RawArrayView::from_bytes(self.raw_bytes()))
    0x05 => {
      let length = raw_view_i32(bytes, start, path)
      let subtype = BinarySubtype::from_byte(bytes[start + 4])
      let payload = start + 5
      if subtype == BinaryOld {
        if length < 4 || raw_view_i32(bytes, payload, path) != length - 4 {
          raise bson_error(
            InvalidBinary,
            start,
            path,
            "invalid raw old binary length",
          )
        }
        Binary({ subtype, bytes: bytes[payload + 4:payload + length] })
      } else {
        Binary({ subtype, bytes: bytes[payload:payload + length] })
      }
    }
    0x06 => Undefined
    0x07 => ObjectId(bytes[start:start + 12])
    0x08 =>
      match bytes[start] {
        0 => Boolean(false)
        1 => Boolean(true)
        _ =>
          raise bson_error(
            InvalidBoolean,
            start,
            path,
            "invalid raw boolean byte",
          )
      }
    0x09 => DateTime(raw_view_i64(bytes, start, path))
    0x0A => Null
    0x0B => {
      let pattern_end = raw_view_cstring_end(bytes, start, self.value_end, path)
      let options_start = pattern_end + 1
      let options_end = raw_view_cstring_end(
        bytes,
        options_start,
        self.value_end,
        path,
      )
      Regex({
        pattern: bytes[start:pattern_end],
        options: bytes[options_start:options_end],
      })
    }
    0x0C => {
      let namespace_end = raw_view_skip_string(
        bytes,
        start,
        self.value_end,
        path,
      )
      DbPointer({
        namespace_value: {
          bytes: raw_view_string_payload(bytes, start, namespace_end, path),
        },
        id: bytes[namespace_end:namespace_end + 12],
      })
    }
    0x0D =>
      JavaScript({
        bytes: raw_view_string_payload(bytes, start, self.value_end, path),
      })
    0x0E =>
      Symbol({
        bytes: raw_view_string_payload(bytes, start, self.value_end, path),
      })
    0x0F => {
      let code_end = raw_view_skip_string(
        bytes,
        start + 4,
        start + raw_view_i32(bytes, start, path),
        path,
      )
      let scope = RawDocumentView::from_bytes(bytes[code_end:self.value_end])
      JavaScriptWithScope({
        code: {
          bytes: raw_view_string_payload(bytes, start + 4, code_end, path),
        },
        scope,
      })
    }
    0x10 => Int32(raw_view_i32(bytes, start, path))
    0x11 => {
      let increment = raw_view_i32(bytes, start, path).reinterpret_as_uint()
      let time = raw_view_i32(bytes, start + 4, path).reinterpret_as_uint()
      Timestamp(Timestamp::new(time, increment))
    }
    0x12 => Int64(raw_view_i64(bytes, start, path))
    0x13 => Decimal128(bytes[start:start + 16])
    0x7F => MaxKey
    0xFF => MinKey
    _ =>
      raise bson_error(
        UnsupportedType,
        start,
        path,
        "unsupported raw BSON type",
      )
  }
}

///|
pub fn RawDocumentView::get(
  self : RawDocumentView,
  key : String,
) -> RawBsonRef? raise BsonError {
  let iterator = self.iter()
  while iterator.next() is Some(element) {
    if element.key() == key {
      return Some(element.value())
    }
  }
  None
}

///|
pub fn RawDocumentView::to_document(
  self : RawDocumentView,
) -> Document raise BsonError {
  decode(self.bytes.to_owned())
}

///|
/// Explicitly materialize a borrowed value into the owned BSON model.
pub fn RawBsonRef::to_bson(self : RawBsonRef) -> Bson raise BsonError {
  match self {
    Double(value) => Double(value)
    String(value) => String(value.to_string())
    Document(value) => Document(value.to_document())
    Array(value) => Array(value.to_array())
    Binary(value) => Binary(Binary::new(value.subtype, value.bytes.to_owned()))
    Undefined => Undefined
    ObjectId(value) => ObjectId(ObjectId::from_bytes(value.to_owned()))
    Boolean(value) => Boolean(value)
    DateTime(value) => DateTime(DateTime::from_millis(value))
    Null => Null
    Regex(value) => Regex(value.to_regex())
    DbPointer(value) =>
      DbPointer(
        DbPointer::new(
          value.namespace_value.to_string(),
          ObjectId::from_bytes(value.id.to_owned()),
        ),
      )
    JavaScript(value) => JavaScript(value.to_string())
    Symbol(value) => Symbol(value.to_string())
    JavaScriptWithScope(value) =>
      JavaScriptWithScope(
        JavaScriptWithScope::new(
          value.code.to_string(),
          value.scope.to_document(),
        ),
      )
    Int32(value) => Int32(value)
    Timestamp(value) => Timestamp(value)
    Int64(value) => Int64(value)
    Decimal128(value) => Decimal128(Decimal128::from_bytes(value.to_owned()))
    MinKey => MinKey
    MaxKey => MaxKey
  }
}

///|
fn raw_view_string_payload(
  bytes : BytesView,
  start : Int,
  limit : Int,
  path : String,
) -> BytesView raise BsonError {
  let length = raw_view_i32(bytes, start, path)
  if length < 1 || start + 4 + length > limit {
    raise bson_error(InvalidLength, start, path, "invalid raw string length")
  }
  let end = start + 4 + length
  if bytes[end - 1] != 0 {
    raise bson_error(
      InvalidCString,
      end - 1,
      path,
      "raw string is not terminated",
    )
  }
  bytes[start + 4:end - 1]
}
