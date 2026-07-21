///|
/// A BSON UTC datetime with millisecond precision.
pub struct DateTime {
  milliseconds : Int64
} derive(Eq, Debug)

///|
pub fn DateTime::from_millis(milliseconds : Int64) -> DateTime {
  { milliseconds, }
}

///|
pub fn DateTime::to_millis(self : DateTime) -> Int64 {
  self.milliseconds
}

///|
pub fn DateTime::now() -> DateTime {
  DateTime::from_millis(@env.now().reinterpret_as_int64())
}

///|
pub fn DateTime::from_rfc3339(value : String) -> DateTime raise BsonError {
  DateTime::from_millis(parse_rfc3339_millis(value, "$")) catch {
    _ =>
      raise bson_error(
        InvalidDateTime,
        -1,
        "$",
        "invalid RFC 3339 BSON datetime",
      )
  }
}

///|
pub fn DateTime::to_rfc3339(self : DateTime) -> String raise BsonError {
  match rfc3339_datetime_string(self.milliseconds) {
    Some(value) => value
    None =>
      raise bson_error(
        InvalidDateTime,
        -1,
        "$",
        "BSON datetime is outside RFC 3339 four-digit year range",
      )
  }
}
