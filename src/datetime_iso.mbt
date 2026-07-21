///|
fn relaxed_datetime_string(milliseconds : Int64) -> String? {
  if milliseconds < 0L || milliseconds >= 253402300800000L {
    return None
  }
  rfc3339_datetime_string(milliseconds)
}

///|
fn rfc3339_datetime_string(milliseconds : Int64) -> String? {
  if milliseconds < -62167219200000L || milliseconds >= 253402300800000L {
    return None
  }
  let mut days = milliseconds / 86400000L
  let mut remainder = milliseconds % 86400000L
  if remainder < 0L {
    days -= 1L
    remainder += 86400000L
  }
  let (year, month, day) = civil_from_days(days.to_int())
  let hour = (remainder / 3600000L).to_int()
  let minute = (remainder % 3600000L / 60000L).to_int()
  let second = (remainder % 60000L / 1000L).to_int()
  let millis = (remainder % 1000L).to_int()
  let fraction = if millis == 0 { "" } else { "." + pad_decimal(millis, 3) }
  Some(
    pad_decimal(year, 4) +
    "-" +
    pad_decimal(month, 2) +
    "-" +
    pad_decimal(day, 2) +
    "T" +
    pad_decimal(hour, 2) +
    ":" +
    pad_decimal(minute, 2) +
    ":" +
    pad_decimal(second, 2) +
    fraction +
    "Z",
  )
}

///|
fn parse_rfc3339_millis(value : String, path : String) -> Int64 raise BsonError {
  if value.length() < 20 ||
    value[4] != '-' ||
    value[7] != '-' ||
    !(value[10] is ('T' | 't')) ||
    value[13] != ':' ||
    value[16] != ':' {
    return invalid_datetime(path, "invalid RFC 3339 date-time layout")
  }
  let year = parse_datetime_digits(value, 0, 4, path)
  let month = parse_datetime_digits(value, 5, 2, path)
  let day = parse_datetime_digits(value, 8, 2, path)
  let hour = parse_datetime_digits(value, 11, 2, path)
  let minute = parse_datetime_digits(value, 14, 2, path)
  let second = parse_datetime_digits(value, 17, 2, path)
  if month < 1 || month > 12 {
    return invalid_datetime(path, "RFC 3339 month is out of range")
  }
  if day < 1 || day > days_in_month(year, month) {
    return invalid_datetime(path, "RFC 3339 day is out of range")
  }
  if hour > 23 || minute > 59 || second > 59 {
    return invalid_datetime(path, "RFC 3339 time is out of range")
  }
  let mut index = 19
  let mut millis = 0
  if index < value.length() && value[index] == '.' {
    index += 1
    let fraction_start = index
    while index < value.length() && value[index] is ('0'..='9') {
      index += 1
    }
    let fraction_length = index - fraction_start
    if fraction_length < 1 || fraction_length > 9 {
      return invalid_datetime(
        path, "RFC 3339 fractional seconds require one to nine digits",
      )
    }
    let used = if fraction_length < 3 { fraction_length } else { 3 }
    millis = parse_datetime_digits(value, fraction_start, used, path)
    if used == 1 {
      millis *= 100
    } else if used == 2 {
      millis *= 10
    }
  }
  let offset_seconds = if index == value.length() - 1 &&
    value[index] is ('Z' | 'z') {
    0
  } else if index + 6 == value.length() &&
    value[index] is ('+' | '-') &&
    value[index + 3] == ':' {
    let offset_hour = parse_datetime_digits(value, index + 1, 2, path)
    let offset_minute = parse_datetime_digits(value, index + 4, 2, path)
    if offset_hour > 23 || offset_minute > 59 {
      return invalid_datetime(path, "RFC 3339 UTC offset is out of range")
    }
    let offset = offset_hour * 3600 + offset_minute * 60
    if value[index] == '+' {
      offset
    } else {
      -offset
    }
  } else {
    return invalid_datetime(path, "RFC 3339 date-time requires a UTC offset")
  }
  let days = days_from_civil(year, month, day)
  let seconds = Int64::from_int(days) * 86400L +
    Int64::from_int(hour * 3600 + minute * 60 + second - offset_seconds)
  seconds * 1000L + Int64::from_int(millis)
}

///|
fn parse_datetime_digits(
  value : String,
  start : Int,
  length : Int,
  path : String,
) -> Int raise BsonError {
  if start < 0 || length < 1 || start + length > value.length() {
    return invalid_datetime(path, "incomplete RFC 3339 numeric component")
  }
  let mut result = 0
  for index = start; index < start + length; index = index + 1 {
    let code = value[index]
    if !(code is ('0'..='9')) {
      return invalid_datetime(path, "non-digit in RFC 3339 numeric component")
    }
    result = result * 10 + code.to_int() - '0'.to_int()
  }
  result
}

///|
fn civil_from_days(epoch_days : Int) -> (Int, Int, Int) {
  let days = epoch_days + 719468
  let era = if days >= 0 { days / 146097 } else { (days - 146096) / 146097 }
  let day_of_era = days - era * 146097
  let year_of_era = (
      day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096
    ) /
    365
  let mut year = year_of_era + era * 400
  let day_of_year = day_of_era -
    (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
  let month_prime = (5 * day_of_year + 2) / 153
  let day = day_of_year - (153 * month_prime + 2) / 5 + 1
  let month = month_prime + (if month_prime < 10 { 3 } else { -9 })
  if month <= 2 {
    year += 1
  }
  (year, month, day)
}

///|
fn days_from_civil(input_year : Int, month : Int, day : Int) -> Int {
  let year = input_year - (if month <= 2 { 1 } else { 0 })
  let era = if year >= 0 { year / 400 } else { (year - 399) / 400 }
  let year_of_era = year - era * 400
  let month_prime = month + (if month > 2 { -3 } else { 9 })
  let day_of_year = (153 * month_prime + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  era * 146097 + day_of_era - 719468
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 => if is_leap_year(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn pad_decimal(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn[T] invalid_datetime(path : String, message : String) -> T raise BsonError {
  raise bson_error(InvalidExtendedJson, -1, path, message)
}
