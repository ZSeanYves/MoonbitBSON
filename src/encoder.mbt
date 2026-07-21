///|
/// Encode an owned BSON document using the default safety limits.
pub fn encode(document : Document) -> Bytes raise BsonError {
  encode_with_options(document, EncodeOptions::new())
}

///|
pub fn encode_with_options(
  document : Document,
  options : EncodeOptions,
) -> Bytes raise BsonError {
  encode_document(document, options, 0, "$")
}

///|
pub fn Document::to_bytes(self : Document) -> Bytes raise BsonError {
  encode(self)
}

///|
/// Append this document to an existing official MoonBit Buffer.
pub fn Document::write_to(
  self : Document,
  buffer : @buffer.Buffer,
) -> Unit raise BsonError {
  buffer.write_bytes(encode(self))
}

///|
pub fn encode_to(
  document : Document,
  buffer : @buffer.Buffer,
) -> Unit raise BsonError {
  document.write_to(buffer)
}

///|
pub fn encode_to_with_options(
  document : Document,
  buffer : @buffer.Buffer,
  options : EncodeOptions,
) -> Unit raise BsonError {
  buffer.write_bytes(encode_with_options(document, options))
}

///|
fn encode_document(
  document : Document,
  options : EncodeOptions,
  depth : Int,
  path : String,
) -> Bytes raise BsonError {
  if depth > options.max_depth {
    raise bson_error(
      DepthLimit,
      -1,
      path,
      "maximum BSON nesting depth exceeded",
    )
  }
  let writer = @buffer.Buffer(size_hint=128)
  writer.write_int_le(0)
  for entry in document.to_array() {
    let (key, value) = entry
    let value_path = field_path(path, key)
    let payload = @buffer.Buffer(size_hint=32)
    let type_code = write_element(payload, value, options, depth, value_path)
    let element = @buffer.Buffer(size_hint=payload.length() + key.length() + 2)
    element.write_byte(type_code)
    write_cstring(element, key, value_path)
    element.write_bytes(payload.to_bytes())
    writer.write_bytes(element.to_bytes())
    if writer.length() + 1 > options.max_size {
      raise bson_error(SizeLimit, -1, path, "BSON document exceeds max_size")
    }
  }
  writer.write_byte(0x00)
  finish_sized_value(writer, options, path)
}

///|
fn write_element(
  writer : @buffer.Buffer,
  value : Bson,
  options : EncodeOptions,
  depth : Int,
  path : String,
) -> Byte raise BsonError {
  match value {
    Double(value) => {
      writer.write_double_le(value)
      0x01
    }
    String(value) => {
      write_string(writer, value, options, path)
      0x02
    }
    Document(value) => {
      writer.write_bytes(encode_document(value, options, depth + 1, path))
      0x03
    }
    Array(value) => {
      writer.write_bytes(encode_array(value, options, depth + 1, path))
      0x04
    }
    Binary(value) => {
      write_binary(writer, value, options, path)
      0x05
    }
    Undefined => 0x06
    ObjectId(value) => {
      writer.write_bytes(value.bytes())
      0x07
    }
    Boolean(value) => {
      writer.write_byte(if value { 1 } else { 0 })
      0x08
    }
    DateTime(value) => {
      writer.write_int64_le(value.to_millis())
      0x09
    }
    Null => 0x0A
    Regex(value) => {
      write_regex(writer, value, path)
      0x0B
    }
    DbPointer(value) => {
      write_string(writer, value.collection(), options, path)
      writer.write_bytes(value.id().bytes())
      0x0C
    }
    JavaScript(value) => {
      write_string(writer, value, options, path)
      0x0D
    }
    Symbol(value) => {
      write_string(writer, value, options, path)
      0x0E
    }
    JavaScriptWithScope(value) => {
      write_javascript_with_scope(writer, value, options, depth + 1, path)
      0x0F
    }
    Int32(value) => {
      writer.write_int_le(value)
      0x10
    }
    Timestamp(value) => {
      writer.write_uint_le(value.increment())
      writer.write_uint_le(value.time())
      0x11
    }
    Int64(value) => {
      writer.write_int64_le(value)
      0x12
    }
    Decimal128(value) => {
      writer.write_bytes(value.bytes())
      0x13
    }
    MinKey => 0xFF
    MaxKey => 0x7F
  }
}

///|
fn encode_array(
  values : Array[Bson],
  options : EncodeOptions,
  depth : Int,
  path : String,
) -> Bytes raise BsonError {
  if depth > options.max_depth {
    raise bson_error(
      DepthLimit,
      -1,
      path,
      "maximum BSON nesting depth exceeded",
    )
  }
  let writer = @buffer.Buffer(size_hint=128)
  writer.write_int_le(0)
  for index, value in values {
    let key = index.to_string()
    let value_path = index_path(path, index)
    let payload = @buffer.Buffer(size_hint=32)
    let type_code = write_element(payload, value, options, depth, value_path)
    writer.write_byte(type_code)
    write_cstring(writer, key, value_path)
    writer.write_bytes(payload.to_bytes())
    if writer.length() + 1 > options.max_size {
      raise bson_error(SizeLimit, -1, path, "BSON array exceeds max_size")
    }
  }
  writer.write_byte(0x00)
  finish_sized_value(writer, options, path)
}

///|
fn write_binary(
  writer : @buffer.Buffer,
  value : Binary,
  options : EncodeOptions,
  path : String,
) -> Unit raise BsonError {
  let bytes = value.bytes()
  let extra = if value.subtype() == BinaryOld { 4 } else { 0 }
  if bytes.length() > options.max_size - extra {
    raise bson_error(SizeLimit, -1, path, "BSON binary value exceeds max_size")
  }
  writer.write_int_le(bytes.length() + extra)
  writer.write_byte(value.subtype().to_byte())
  if value.subtype() == BinaryOld {
    writer.write_int_le(bytes.length())
  }
  writer.write_bytes(bytes)
}

///|
fn write_regex(
  writer : @buffer.Buffer,
  value : Regex,
  path : String,
) -> Unit raise BsonError {
  if !regex_is_valid(value) {
    raise bson_error(
      InvalidRegex,
      -1,
      path,
      "regex pattern/options contain NUL or options are not sorted",
    )
  }
  write_cstring(writer, value.pattern(), path)
  write_cstring(writer, value.options(), path)
}

///|
fn write_javascript_with_scope(
  writer : @buffer.Buffer,
  value : JavaScriptWithScope,
  options : EncodeOptions,
  depth : Int,
  path : String,
) -> Unit raise BsonError {
  let scoped = @buffer.Buffer(size_hint=64)
  scoped.write_int_le(0)
  write_string(scoped, value.code(), options, path)
  scoped.write_bytes(encode_document(value.scope(), options, depth, path))
  writer.write_bytes(finish_sized_value(scoped, options, path))
}

///|
fn write_cstring(
  writer : @buffer.Buffer,
  value : String,
  path : String,
) -> Unit raise BsonError {
  if value.contains_code_unit(0) {
    raise bson_error(
      InvalidCString,
      -1,
      path,
      "CString contains a NUL code unit",
    )
  }
  writer.write_bytes(@utf8.encode(value))
  writer.write_byte(0x00)
}

///|
fn write_string(
  writer : @buffer.Buffer,
  value : String,
  options : EncodeOptions,
  path : String,
) -> Unit raise BsonError {
  let bytes = @utf8.encode(value)
  if bytes.length() >= options.max_size {
    raise bson_error(SizeLimit, -1, path, "BSON string exceeds max_size")
  }
  writer.write_int_le(bytes.length() + 1)
  writer.write_bytes(bytes)
  writer.write_byte(0x00)
}

///|
fn finish_sized_value(
  writer : @buffer.Buffer,
  options : EncodeOptions,
  path : String,
) -> Bytes raise BsonError {
  let bytes = writer.to_bytes().to_array()
  if bytes.length() > options.max_size {
    raise bson_error(SizeLimit, -1, path, "BSON value exceeds max_size")
  }
  let length = bytes.length()
  bytes[0] = (length & 0xFF).to_byte()
  bytes[1] = ((length >> 8) & 0xFF).to_byte()
  bytes[2] = ((length >> 16) & 0xFF).to_byte()
  bytes[3] = ((length >> 24) & 0xFF).to_byte()
  Bytes::from_array(bytes)
}

///|
fn regex_is_valid(value : Regex) -> Bool {
  if value.pattern().contains_code_unit(0) ||
    value.options().contains_code_unit(0) {
    return false
  }
  let mut previous : UInt16 = 0
  for index, option in value.options().code_units() {
    let supported = match option {
      'i' | 'l' | 'm' | 's' | 'u' | 'x' => true
      _ => false
    }
    if !supported || (index > 0 && option <= previous) {
      return false
    }
    previous = option
  }
  true
}

///|
fn normalize_regex_options(options : String) -> String? {
  if options.contains_code_unit(0) {
    return None
  }
  let seen : Map[UInt16, Unit] = Map([])
  for option in options.code_units() {
    if !(option is ('i' | 'l' | 'm' | 's' | 'u' | 'x')) || seen.contains(option) {
      return None
    }
    seen.set(option, ())
  }
  let normalized = StringBuilder()
  for option in "ilmsux".code_units() {
    if seen.contains(option) {
      normalized.write_string(option.to_char().unwrap().to_string())
    }
  }
  Some(normalized.to_string())
}
