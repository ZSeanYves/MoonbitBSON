# MoonbitBSON

[English](README.md) | [简体中文](README_zh_CN.md)

[![License](https://img.shields.io/github/license/ZSeanYves/MoonbitBSON)](LICENSE)

Strict BSON 1.1 encoding and decoding for MoonBit. The package uses only
MoonBit core libraries and supports wasm, wasm-gc, JavaScript, and native.
The 0.3 API adds typed DateTime, ObjectId, UUID, raw element access, and
generic BSON serialization traits.

## Install

```bash
moon add ZSeanYves/MoonbitBSON
```

```moonbit
import {
  "ZSeanYves/MoonbitBSON",
}
```

## Usage

```moonbit
let user = @MoonbitBSON.Document::new()
  .set("name", @MoonbitBSON.Bson::String("Ada"))
  .set("age", @MoonbitBSON.Bson::Int32(37))
  .set("active", @MoonbitBSON.Bson::Boolean(true))
  .set(
    "scores",
    @MoonbitBSON.Bson::Array([
      @MoonbitBSON.Bson::Double(9.5),
      @MoonbitBSON.Bson::Double(10.0),
    ]),
  )

let bytes = user.to_bytes()
let decoded = @MoonbitBSON.Document::from_bytes(bytes)

assert_eq(decoded.require_string("name"), "Ada")
assert_eq(decoded.require_int32("age"), 37)
```

`decode` rejects trailing bytes. For framed data, use `decode_prefix`, which
returns the decoded document and consumed byte count. `RawDocument` validates
and preserves the original wire bytes, including order and duplicate keys.
Use `RawDocument::elements` or `get_element` when a caller needs to inspect or
decode only selected fields.

## Supported BSON types

Double, String, Document, Array, Binary (including modern subtypes), Undefined,
ObjectId, Boolean, UTC DateTime, Null, Regex, DBPointer, JavaScript, Symbol,
JavaScript with scope, Int32, Timestamp, Int64, Decimal128, MinKey, and MaxKey.

Deprecated BSON wire types remain decodable for interoperability.

## Safety and errors

- Declared document and array lengths are hard boundaries.
- Exact decoding rejects trailing bytes and invalid terminators.
- UTF-8, Boolean bytes, old binary lengths, ObjectId/Decimal128 sizes, Regex
  options, depth, and total size are validated.
- Every `BsonError` carries a category, byte offset, document path, and message.
- Degenerate BSON array keys are accepted and normalized as required by the
  MongoDB BSON Corpus. Strict applications can enable
  `DecodeOptions::new(require_canonical_array_keys=true)`.

## Extended JSON

Canonical Extended JSON encoding and parsing is available through
`Document::to_extended_json`, `to_extended_json_string`,
`from_extended_json`, and `from_extended_json_string`.

Relaxed output is available through `to_relaxed_extended_json` and
`to_relaxed_extended_json_string`. It emits finite numbers as native JSON and
UTC DateTime values from 1970 through year 9999 as RFC 3339 strings; dates
outside that range retain the lossless `$numberLong` wrapper.

Decimal128 supports exact IEEE 754-2008 text conversion through
`Decimal128::from_string` and `Decimal128::to_string`, including signed zero,
subnormal values, exponent clamping, NaN, and infinity. Canonical and Relaxed
Extended JSON both use the standard `$numberDecimal` representation.

`DateTime` is a typed UTC millisecond value with RFC 3339 parsing and
formatting. `Uuid` supports canonical, compact, and URN text forms and BSON
binary subtype 4. `ObjectId::from_parts` accepts caller-controlled timestamp,
process-unique bytes, and counter values; `ObjectId::new` provides a
best-effort local generator.

`ToBson` and `FromBson` provide opt-in generic conversions for application
types, including arrays, maps, options, and the typed BSON values.

## Development

```bash
moon fmt --check src
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon test --release --target all --deny-warn --warn-list +73
moon bench --target native --release
moon coverage analyze -- -f summary
moon info --target all
moon package --list
```

Tests include the complete MongoDB BSON Corpus JSON suite vendored under
`testdata/bson-corpus`, all truncation points for mixed documents, generated
property cases, bounded decoder fuzz smoke cases, strict malformed-input cases,
Decimal128 text vectors, and Canonical/Relaxed Extended JSON.

See [CHANGELOG.md](CHANGELOG.md) for the breaking 0.3.0 migration and
[MAINTENANCE.md](MAINTENANCE.md) for implementation status and remaining work.

## License

Apache-2.0. See [LICENSE](LICENSE).
