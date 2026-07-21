///|
fn decimal128_parsing_fails(value : String) -> Bool {
  try Decimal128::from_string(value) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "Decimal128 official corpus special values" {
  let nan = Decimal128::from_string("NaN")
  assert_eq(
    nan.bytes(),
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x7c",
  )
  assert_eq(Decimal128::from_string("-NaN").to_string(), "NaN")
  assert_eq(
    Decimal128::from_string("sNaN").bytes(),
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x7e",
  )
  assert_eq(Decimal128::from_string("+inf").to_string(), "Infinity")
  assert_eq(Decimal128::from_string("-Infinity").to_string(), "-Infinity")
}

///|
test "Decimal128 official corpus finite encodings" {
  let cases : Array[(String, Bytes, String)] = [
    (
      "0.1", b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3e\x30",
      "0.1",
    ),
    (
      "-0.0", b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3e\xb0",
      "-0.0",
    ),
    (
      "2.000", b"\xd0\x07\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3a\x30",
      "2.000",
    ),
    (
      "1234567890123456789012345678901234", b"\xf2\xaf\x96\x7e\xd0\x5c\x82\xde\x32\x97\xff\x6f\xde\x3c\x40\x30",
      "1234567890123456789012345678901234",
    ),
    (
      "1E-6176", b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
      "1E-6176",
    ),
    (
      "9.999999999999999999999999999999999E+6144", b"\xff\xff\xff\xff\x63\x8e\x8d\x37\xc0\x87\xad\xbe\x09\xed\xff\x5f",
      "9.999999999999999999999999999999999E+6144",
    ),
  ]
  for case in cases {
    let (input, expected_bytes, expected_text) = case
    let decimal = Decimal128::from_string(input)
    assert_eq(decimal.bytes(), expected_bytes)
    assert_eq(decimal.to_string(), expected_text)
    assert_eq(Decimal128::from_bytes(expected_bytes).to_string(), expected_text)
  }
}

///|
test "Decimal128 exact normalization and clamping" {
  assert_eq(Decimal128::from_string("-100E-10").to_string(), "-1.00E-8")
  assert_eq(Decimal128::from_string("10E-6177").to_string(), "1E-6176")
  assert_eq(Decimal128::from_string("1E6112").to_string(), "1.0E+6112")
  assert_eq(Decimal128::from_string("0E+2147483647").to_string(), "0E+6111")
  assert_eq(Decimal128::from_string("-0E-2147483647").to_string(), "-0E-6176")
}

///|
test "Decimal128 non-canonical binary coefficients become zero" {
  let invalid = Decimal128::from_bytes(
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x6c",
  )
  assert_eq(invalid.to_string(), "0")
}

///|
test "Decimal128 rejects invalid and inexact text" {
  for
    value in [
      "", ".", "1e", "E01", "1.2.3", "--1", "1E-6177", "7e10000", "10000000000000000000000000000000001",
    ] {
    assert_true(decimal128_parsing_fails(value))
  }
}
