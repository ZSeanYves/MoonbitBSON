# 📦 MoonbitBSON: A Lightweight BSON Encode/Decode Library for MoonBit

[English](https://github.com/YOUR_USERNAME/MoonbitBSON/blob/main/README.md) | [简体中文](https://github.com/YOUR_USERNAME/MoonbitBSON/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/YOUR_USERNAME/MoonbitBSON/bson-ci.yml)](https://github.com/YOUR_USERNAME/MoonbitBSON/actions)
[![License](https://img.shields.io/github/license/YOUR_USERNAME/MoonbitBSON)](LICENSE)

**MoonbitBSON** is a minimal, robust BSON encoder/decoder library for [MoonBit](https://moonbitlang.cn). It enables BSON-compatible serialization and deserialization of MoonBit types, supporting key BSON elements like nested documents, arrays, UTF-8 strings, integers, booleans, nulls, and more.

---

## 🚀 Features

* ✅ Encode/Decode Documents, Arrays, Strings, Int32, Boolean, Null, Double, Int64 (experimental)
* ✅ Composable API for BSON construction and traversal
* ✅ Reader/writer powered by [`BufferUtils`](https://github.com/ZSeanYves/BufferUtils)
* ✅ Error-safe decoding with unified error enum
* ✅ Comprehensive test suite for edge cases and type coverage
* ✅ Compact and dependency-light

---

## 📦 Installation

```bash
moon add YOUR_USERNAME/bson
```

or manually in `moon.mod.json`:

```json
"import": ["YOUR_USERNAME/bson"]
```

---

## ✍️ Usage Example

```moonbit
let doc = bson_document()
  .set("name", bson_string("Alice"))
  .set("age", bson_int32(30))
  .set("vip", bson_bool(true))

let bytes = encode_bson(doc)
let restored = decode_bson(bytes)
assert_eq(restored, doc)
```

### 🔁 Nested Document

```moonbit
let inner = bson_document().set("city", bson_string("Shanghai"))
let doc = bson_document().set("user", inner)
let bin = encode_bson(doc)
let result = decode_bson(bin)
assert_eq(result, doc)
```

---

## 🔧 API Overview

### 🏗 BSON Builders

| Function          | Description                   |
| ----------------- | ----------------------------- |
| `bson_document()` | Create empty document         |
| `bson_array()`    | Create empty array            |
| `bson_string(s)`  | BSON string                   |
| `bson_int32(i)`   | BSON 32-bit integer           |
| `bson_int64(i)`   | BSON 64-bit integer (limited) |
| `bson_bool(b)`    | BSON boolean                  |
| `bson_null()`     | BSON null                     |
| `bson_double(f)`  | BSON float (IEEE 754)         |

### 🧠 Encode/Decode Functions

| Function                       | Description                     |
| ------------------------------ | ------------------------------- |
| `encode_bson(doc)`             | Convert BSON document → `Bytes` |
| `decode_bson(bytes)`           | Convert `Bytes` → BSON document |
| `decode_element(type, reader)` | Decode element by type code     |

### 📚 BSON Core Types

```moonbit
type BsonValue {
  Double(Float)
  String(String)
  Document(BsonDocument)
  Array(BsonArray)
  Boolean(Bool)
  Null
  Int32(Int)
  Int64(Int)
}
```

---

## ⚠️ Error Handling

Unified error enum:

```moonbit
suberror Error {
  InvalidDocumentLength(String)
  UnexpectedEOF(String)
  UnsupportedType(Byte)
  MalformedCString(String)
}
```

Use `?`, `!`, or `match` to safely propagate decoding errors.

---

## 🧪 Testing

Run tests:

```bash
moon test -p YOUR_USERNAME/bson
```

Test cases include:

* ✅ Empty document encode/decode
* ✅ Nested documents and arrays
* ✅ Unsupported BSON type code
* ✅ Malformed cstring (missing null terminator)
* ✅ Declared length mismatch
* ✅ Int32 / Double / Bool / Null / String coverage

---

## 🗂 Project Structure

```
MoonbitBSON/
├── src/
│   ├── bson.mbt             # Main encode/decode logic
│   ├── bson.mbti            # Exported interfaces & types
│   ├── encode.mbt           # Encode logic per BSON type
│   ├── decode.mbt           # Decode logic per BSON type
│   ├── builder.mbt          # BSON value constructors
│   ├── error.mbt            # Error types
│   └── bson_test.mbt        # Tests
├── moon.mod.json            # Module manifest
└── LICENSE
```

---

## 📜 License

Apache-2.0 License.
See [LICENSE](./LICENSE) for full terms.
