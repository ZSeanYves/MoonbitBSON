# 📦 BsonLite: A Lightweight BSON Encoder/Decoder for MoonBit

[English](https://github.com/ZSeanYves/BsonLite/blob/main/README.md) | [简体中文](https://github.com/ZSeanYves/BsonLite/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/ZSeanYves/BsonLite/bsonlite-ci.yml)](https://github.com/ZSeanYves/BsonLite/actions)
[![License](https://img.shields.io/github/license/ZSeanYves/BsonLite)](LICENSE)

**BsonLite** is a lightweight BSON utility library for **MoonBit**. It supports encoding and decoding the core BSON types (strings, integers, booleans, arrays, and documents). The API is small and easy to use, suitable for learning, experiments, and format conversion tasks.

---

## 🚀 Features

* Supports core BSON types: **String**, **Int32**, **Bool**, **Document**, **Array**
* Rust-like `BsonValue` enum for type-safe construction & traversal
* Full support for nested documents and arrays
* Chainable, ergonomic APIs to build maps and arrays
* Simple encode/decode functions with automatic length handling
* Categorized errors: invalid types, missing terminator, invalid length, etc.
* Comes with test samples

---

## 📆 Installation

```bash
moon add ZSeanYves/MoonbitBSON
```

Or edit `moon.mod.json`:

```json
"import": ["ZSeanYves/MoonbitBSON"]
```

---

## 🧭 Supported BSON Types

| Variant    | Payload Type             | Tag  |
| ---------- | ------------------------ | ---- |
| `Double`   | `Float`                  | 0x01 |
| `String`   | `String`                 | 0x02 |
| `Document` | `Map[String, BsonValue]` | 0x03 |
| `Array`    | `Array[BsonValue]`       | 0x04 |
| `Boolean`  | `Bool`                   | 0x08 |
| `Null`     | `-`                      | 0x0A |
| `Int32`    | `Int`                    | 0x10 |
| `Int64`    | `Int`                    | 0x12 |

> **Not covered yet:** Binary, ObjectId, UTC datetime, Regex, Timestamp, Decimal128, and other extended BSON types.

---

## 🚀 Quick Start

### Build → Encode → Decode

```moonbit
use ZSeanYves/bsonlite

let user = bson_document()
  .set("name", bson_string("Ada"))
  .set("age",  bson_int32(30))
  .set("tags", bson_array().push(bson_string("engineer")).push(bson_string("math")))

let bin  = to_bson(user)      // Encode to Bytes
let back = from_bson(bin)     // Decode from Bytes back to BsonValue

assert(back.is_document())
assert(back.as_document().unwrap().get("age").unwrap().as_int32().unwrap() == 30)
```

### Safe Variants (No Exceptions)

```moonbit
let bin  = to_bson_safe(user)   // Returns empty Bytes on error
let back = from_bson_safe(bin)  // Returns BsonValue::Null on error
```

---

## 🔧 API Reference (Complete)

### 🏗 Builders

| Function        | Signature                          | Description                             |
| --------------- | ---------------------------------- | --------------------------------------- |
| `bson_array`    | `bson_array() -> BsonValue`        | Create an empty BSON **Array**.         |
| `bson_bool`     | `bson_bool(Bool) -> BsonValue`     | Create a BSON **Boolean** from a bool.  |
| `bson_document` | `bson_document() -> BsonValue`     | Create an empty BSON **Document**.      |
| `bson_double`   | `bson_double(Float) -> BsonValue`  | Create a BSON **Double** from a float.  |
| `bson_int32`    | `bson_int32(Int) -> BsonValue`     | Create a BSON **Int32** from an int.    |
| `bson_int64`    | `bson_int64(Int) -> BsonValue`     | Create a BSON **Int64** from an int.    |
| `bson_null`     | `bson_null() -> BsonValue`         | Create a BSON **Null**.                 |
| `bson_string`   | `bson_string(String) -> BsonValue` | Create a BSON **String** from a string. |

### 📤 Top-level Encode/Decode

| Function         | Signature                               | Description                                                         |
| ---------------- | --------------------------------------- | ------------------------------------------------------------------- |
| `decode_bson`    | `decode_bson(Bytes) -> BsonValue raise` | Decode `Bytes` into a `BsonValue` (top-level should be a Document). |
| `encode_bson`    | `encode_bson(BsonValue) -> Bytes raise` | Encode a top-level **Document** as `Bytes`.                         |
| `from_bson`      | `from_bson(Bytes) -> BsonValue raise`   | Convenience wrapper around `decode_bson`.                           |
| `from_bson_safe` | `from_bson_safe(Bytes) -> BsonValue`    | Safe decode wrapper: returns `BsonValue::Null` on failure.          |
| `to_bson`        | `to_bson(BsonValue) -> Bytes raise`     | Convenience wrapper around `encode_bson`.                           |
| `to_bson_safe`   | `to_bson_safe(BsonValue) -> Bytes`      | Safe encode wrapper: returns empty `Bytes` on failure.              |

### 🧱 `BsonValue` Methods

| Method                   | Signature                                           | Description                                      |
| ------------------------ | --------------------------------------------------- | ------------------------------------------------ |
| `BsonValue::as_array`    | `BsonValue::as_array(Self) -> Array[Self]?`         | If Array, return its elements; otherwise `None`. |
| `BsonValue::as_document` | `BsonValue::as_document(Self) -> Map[String,Self]?` | If Document, return the map; otherwise `None`.   |
| `BsonValue::as_int32`    | `BsonValue::as_int32(Self) -> Int?`                 | If Int32, return the integer; otherwise `None`.  |
| `BsonValue::as_int64`    | `BsonValue::as_int64(Self) -> Int?`                 | If Int64, return the integer; otherwise `None`.  |
| `BsonValue::as_string`   | `BsonValue::as_string(Self) -> String?`             | If String, return the string; otherwise `None`.  |
| `BsonValue::is_array`    | `BsonValue::is_array(Self) -> Bool`                 | Whether it’s an Array.                           |
| `BsonValue::is_document` | `BsonValue::is_document(Self) -> Bool`              | Whether it’s a Document.                         |
| `BsonValue::is_int`      | `BsonValue::is_int(Self) -> Bool`                   | Whether it’s an integer type (Int32/Int64).      |
| `BsonValue::is_string`   | `BsonValue::is_string(Self) -> Bool`                | Whether it’s a String.                           |
| `BsonValue::push`        | `BsonValue::push(Self, Self) -> Self`               | **Array only**: append an element (chainable).   |
| `BsonValue::set`         | `BsonValue::set(Self, String, Self) -> Self`        | **Document only**: set a field (chainable).      |

---

## ⚠️ Error Types

`BsonError` (a `suberror` enum) may be raised during encode/decode:

| Variant                 | Payload  |
| ----------------------- | -------- |
| `InvalidString`         | `String` |
| `UnsupportedType`       | `Byte`   |
| `InvalidUtf8`           | `String` |
| `InvalidDocumentLength` | `String` |
| `InvalidStringLength`   | `String` |

---

## 🧭 Common Patterns

```moonbit
// Build and read an array
let arr = bson_array().push(bson_int32(1)).push(bson_int32(2))
assert(arr.is_array())
let xs = arr.as_array().unwrap()
assert(xs.length() == 2)

// Nested documents
let profile = bson_document()
  .set("name", bson_string("Grace"))
  .set("likes", arr)
```

---

## ❗ Limitations

* Only the types listed above are implemented; extended BSON types (Binary, ObjectId, etc.) are not supported yet.
* `Int64` behavior may vary across environments—use with care when portability is required.

---

## 🧪 Tests

See `src/bson_test.mbt` and run with your usual MoonBit test commands.

---

## 📜 License

Licensed under **Apache-2.0**. See [LICENSE](LICENSE) for details.
