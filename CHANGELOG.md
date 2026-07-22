# Changelog

## 0.3.0 maintenance follow-up (unreleased)

### Added

- Schema-driven `ToBson`/`FromBson` codegen with stale-output checking; this is
  the serde-style integration supported by current MoonBit tooling because
  user-defined traits cannot be compiler-derived.
- Borrowed `RawDocumentView`/`RawElementView` APIs and a chunked
  `BsonStreamDecoder` for split BSON frames.
- OS/Web Crypto-backed `ObjectId::new` and `ObjectId::new_secure`; unsupported
  hosts return `UnsupportedEntropy` instead of using a deterministic PRNG.
- Rust `bson` 3.1.0 Decimal128 random bit-pattern differential oracle.
- Native AFL++ decoder driver and long-running fuzz command, with CI smoke
  coverage for the driver.

## 0.3.0 - 2026-07-22

### Added

- Typed `DateTime`, `ObjectId`, and `Uuid` APIs with RFC 3339, BSON subtype 4,
  and ObjectId component helpers.
- `ToBson`/`FromBson` traits plus generic byte serialization for common MoonBit
  collections and optional values.
- Lazy `RawDocument::elements`, `get_element`, and `RawElement` access without
  eagerly decoding selected values.
- Complete vendored MongoDB BSON Corpus validation, generated corpus tests,
  deterministic property tests, decoder fuzz smoke tests, and native benchmarks.
- Relaxed Extended JSON number inference, `$uuid`, strict known-wrapper shape
  errors, canonical regex options, and ISO-8601/RFC 3339 DateTime handling.

### Changed

- `Bson::DateTime` now carries the typed `DateTime` value instead of a bare
  `Int64` millisecond count.
- `decode_prefix` reads its input `BytesView` without copying the full frame.

### Breaking

- This release intentionally expands the 0.2 breaking API migration. Callers
  constructing DateTime values must use `DateTime::from_millis`.

## 0.2.0 - 2026-07-21

### Changed

- Replaced the old `BsonValue` API with `Bson` and an insertion-ordered `Document`.
- Replaced `Float`/`Int` BSON payloads with wire-correct `Double`/`Int64`.
- Removed `ZSeanYves/bufferutils`; all byte and UTF-8 operations use MoonBit core.
- Made decoding strict about document boundaries, Boolean bytes, UTF-8, nesting, and size.
- Made noncanonical array keys corpus-compatible by default with an optional strict mode.
- Replaced sentinel-returning safe wrappers with structured `BsonError` failures.

### Added

- BSON 1.1 types, deprecated wire types, RawDocument, prefix decoding, reusable Buffer APIs.
- Canonical and Relaxed Extended JSON, including RFC 3339 UTC DateTime support.
- Exact IEEE 754-2008 Decimal128 text conversion and `$numberDecimal` support.
- Embedded MongoDB BSON Corpus vectors, generated round-trip tests, and cross-target CI.

### Removed

- `BsonValue`, `bson_*` builders, `encode_bson`, `decode_bson`, and safe wrappers.
