use bson::Decimal128;
use std::env;
use std::str::FromStr;

fn nibble(value: u8) -> Option<u8> {
    match value {
        b'0'..=b'9' => Some(value - b'0'),
        b'a'..=b'f' => Some(value - b'a' + 10),
        b'A'..=b'F' => Some(value - b'A' + 10),
        _ => None,
    }
}

fn parse_hex(value: &str) -> Option<[u8; 16]> {
    let bytes = value.as_bytes();
    if bytes.len() != 32 {
        return None;
    }
    let mut output = [0u8; 16];
    for index in 0..16 {
        output[index] = (nibble(bytes[index * 2])? << 4) | nibble(bytes[index * 2 + 1])?;
    }
    Some(output)
}

fn hex(bytes: [u8; 16]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn main() {
    for value in env::args().skip(1).filter(|value| value.len() == 32) {
        let Some(bytes) = parse_hex(&value) else { continue };
        let decimal = Decimal128::from_bytes(bytes);
        let text = decimal.to_string();
        let roundtrip = Decimal128::from_str(&text)
            .map(|value| hex(value.bytes()))
            .unwrap_or_else(|_| "ERROR".to_string());
        println!("{value}\t{text}\t{roundtrip}");
    }
}
