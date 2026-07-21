///|
priv enum Decimal128Value {
  DecimalNaN(Bool)
  DecimalInfinity
  DecimalFinite(Int, BigInt)
}

///|
priv struct ParsedDecimal128 {
  negative : Bool
  value : Decimal128Value
}

///|
let decimal128_max_coefficient : BigInt = BigInt::from_string(
  "9999999999999999999999999999999999",
)

///|
let decimal128_coefficient_mask : BigInt = (1N << 113) - 1N

///|
fn parse_decimal128(input : String) -> Decimal128 raise BsonError {
  if input.is_empty() {
    return invalid_decimal128("empty Decimal128 string")
  }
  let (negative, unsigned) = strip_decimal_sign(input)
  if unsigned.is_empty() {
    return invalid_decimal128("Decimal128 contains only a sign")
  }
  let lower = unsigned.to_lower()
  let parsed = match lower {
    "nan" => { negative, value: DecimalNaN(false) }
    "snan" => { negative, value: DecimalNaN(true) }
    "infinity" | "inf" => { negative, value: DecimalInfinity }
    _ => parse_finite_decimal128(negative, lower)
  }
  pack_decimal128(parsed)
}

///|
fn strip_decimal_sign(input : String) -> (Bool, String) {
  match input[0] {
    '-' => (true, input[1:].to_owned())
    '+' => (false, input[1:].to_owned())
    _ => (false, input)
  }
}

///|
fn parse_finite_decimal128(
  negative : Bool,
  input : String,
) -> ParsedDecimal128 raise BsonError {
  let (decimal, exponent_text) = split_decimal_exponent(input)
  let mut exponent = parse_wide_exponent(exponent_text)
  let (digits_with_zeros, fractional_digits) = remove_decimal_point(decimal)
  exponent = exponent - BigInt::from_int(fractional_digits)
  let mut digits = strip_decimal_leading_zeros(digits_with_zeros)
  if digits.length() > 34 {
    let original_length = digits.length()
    digits = truncate_decimal_exact(digits, 34)
    exponent = exponent + BigInt::from_int(original_length - digits.length())
  }
  if exponent < BigInt::from_int(-6176) {
    if digits != "0" {
      let delta_big = BigInt::from_int(-6176) - exponent
      if delta_big > BigInt::from_int(digits.length()) {
        return invalid_decimal128(
          "Decimal128 underflow requires inexact rounding",
        )
      }
      let precision = digits.length() - delta_big.to_int()
      digits = truncate_decimal_exact(digits, precision)
    }
    exponent = BigInt::from_int(-6176)
  }
  if exponent > BigInt::from_int(6111) {
    if digits != "0" {
      let delta_big = exponent - BigInt::from_int(6111)
      if delta_big > BigInt::from_int(34 - digits.length()) {
        return invalid_decimal128("Decimal128 exponent overflow")
      }
      let delta = delta_big.to_int()
      digits = digits + "0".repeat(delta)
    }
    exponent = BigInt::from_int(6111)
  }
  let coefficient = BigInt::from_string(digits)
  if coefficient > decimal128_max_coefficient {
    return invalid_decimal128("Decimal128 coefficient exceeds 34 digits")
  }
  { negative, value: DecimalFinite(exponent.to_int(), coefficient) }
}

///|
fn split_decimal_exponent(input : String) -> (String, String) raise BsonError {
  let mut exponent_index = -1
  for index, code in input.code_units() {
    if code == 'e' {
      if exponent_index >= 0 {
        return invalid_decimal128("Decimal128 contains multiple exponents")
      }
      exponent_index = index
    }
  }
  if exponent_index < 0 {
    (input, "0")
  } else {
    let decimal = input[0:exponent_index].to_owned()
    let exponent = input[exponent_index + 1:].to_owned()
    if exponent.is_empty() {
      return invalid_decimal128("Decimal128 exponent is empty")
    }
    (decimal, exponent)
  }
}

///|
fn parse_wide_exponent(input : String) -> BigInt raise BsonError {
  let (negative, unsigned) = strip_decimal_sign(input)
  if unsigned.is_empty() || !is_ascii_digits(unsigned) {
    return invalid_decimal128("invalid Decimal128 exponent")
  }
  let exponent = BigInt::from_string(unsigned)
  if negative {
    -exponent
  } else {
    exponent
  }
}

///|
fn remove_decimal_point(input : String) -> (String, Int) raise BsonError {
  let mut point = -1
  for index, code in input.code_units() {
    if code == '.' {
      if point >= 0 {
        return invalid_decimal128("Decimal128 contains multiple decimal points")
      }
      point = index
    } else if !(code is ('0'..='9')) {
      return invalid_decimal128("Decimal128 coefficient contains a non-digit")
    }
  }
  if point < 0 {
    if input.is_empty() {
      return invalid_decimal128("Decimal128 coefficient is empty")
    }
    (input, 0)
  } else {
    let before = input[0:point].to_owned()
    let after = input[point + 1:].to_owned()
    if before.is_empty() && after.is_empty() {
      return invalid_decimal128("Decimal128 coefficient has no digits")
    }
    (before + after, after.length())
  }
}

///|
fn strip_decimal_leading_zeros(input : String) -> String {
  let mut first = 0
  while first < input.length() && input[first] == '0' {
    first += 1
  }
  if first == input.length() {
    "0"
  } else {
    input[first:].to_owned()
  }
}

///|
fn truncate_decimal_exact(
  input : String,
  precision : Int,
) -> String raise BsonError {
  if precision < 0 || precision > input.length() {
    return invalid_decimal128("invalid Decimal128 precision")
  }
  for code in input[precision:].code_units() {
    if code != '0' {
      return invalid_decimal128("Decimal128 conversion would require rounding")
    }
  }
  input[0:precision].to_owned()
}

///|
fn is_ascii_digits(input : String) -> Bool {
  for code in input.code_units() {
    if !(code is ('0'..='9')) {
      return false
    }
  }
  true
}

///|
fn pack_decimal128(parsed : ParsedDecimal128) -> Decimal128 {
  let sign = if parsed.negative { 1N << 127 } else { 0N }
  let packed = match parsed.value {
    DecimalNaN(signalling) =>
      sign | (BigInt::from_int(if signalling { 0x7E } else { 0x7C }) << 120)
    DecimalInfinity => sign | (BigInt::from_int(0x78) << 120)
    DecimalFinite(exponent, coefficient) =>
      sign | (BigInt::from_int(exponent + 6176) << 113) | coefficient
  }
  let big_endian = packed.to_octets(length=16)
  let little_endian = Bytes::makei(16, index => big_endian[15 - index])
  Decimal128::from_valid_bytes(little_endian)
}

///|
fn unpack_decimal128(decimal : Decimal128) -> ParsedDecimal128 {
  let bytes = decimal.bytes()
  let negative = (bytes[15].to_int() & 0x80) != 0
  let high = bytes[15].to_int()
  if (high & 0x7C) == 0x7C {
    { negative, value: DecimalNaN((high & 0x02) != 0) }
  } else if (high & 0x78) == 0x78 {
    { negative, value: DecimalInfinity }
  } else {
    let big_endian = Bytes::makei(16, index => bytes[15 - index])
    let packed = BigInt::from_octets(big_endian[:])
    let steering = (high & 0x60) == 0x60
    let exponent_shift = if steering { 111 } else { 113 }
    let exponent = ((packed >> exponent_shift) & 0x3FFFN).to_int() - 6176
    let coefficient = if steering {
      0N
    } else {
      let value = packed & decimal128_coefficient_mask
      if value > decimal128_max_coefficient {
        0N
      } else {
        value
      }
    }
    { negative, value: DecimalFinite(exponent, coefficient) }
  }
}

///|
fn format_decimal128(decimal : Decimal128) -> String {
  let parsed = unpack_decimal128(decimal)
  match parsed.value {
    DecimalNaN(_) => "NaN"
    DecimalInfinity => if parsed.negative { "-Infinity" } else { "Infinity" }
    DecimalFinite(exponent, coefficient) => {
      let prefix = if parsed.negative { "-" } else { "" }
      let digits = coefficient.to_string()
      let adjusted_exponent = exponent + digits.length() - 1
      if exponent <= 0 && adjusted_exponent >= -6 {
        if exponent == 0 {
          prefix + digits
        } else {
          let decimal_places = -exponent
          if decimal_places >= digits.length() {
            prefix +
            "0." +
            "0".repeat(decimal_places - digits.length()) +
            digits
          } else {
            let split = digits.length() - decimal_places
            prefix +
            digits[0:split].to_owned() +
            "." +
            digits[split:].to_owned()
          }
        }
      } else {
        let rest = digits[1:].to_owned()
        let coefficient_text = if rest.is_empty() {
          digits[0:1].to_owned()
        } else {
          digits[0:1].to_owned() + "." + rest
        }
        let exponent_sign = if adjusted_exponent > 0 { "+" } else { "" }
        prefix +
        coefficient_text +
        "E" +
        exponent_sign +
        adjusted_exponent.to_string()
      }
    }
  }
}

///|
fn[T] invalid_decimal128(message : String) -> T raise BsonError {
  raise bson_error(InvalidDecimal128, -1, "$", message)
}
