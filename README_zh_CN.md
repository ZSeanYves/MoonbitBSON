# 📦 BsonLite: MoonBit 轻量级 BSON 编/解码库

[English](https://github.com/ZSeanYves/BsonLite/blob/main/README.md) | [简体中文](https://github.com/ZSeanYves/BsonLite/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/ZSeanYves/BsonLite/bsonlite-ci.yml)](https://github.com/ZSeanYves/BsonLite/actions)
[![License](https://img.shields.io/github/license/ZSeanYves/BsonLite)](LICENSE)

**BsonLite** 是一个基于 MoonBit 言语的轻量级 BSON 工具库，支持基础类型的 BSON 编码和解码，包括字符串、整数、布尔、数组、字典等。库设计简洁，调用简单，适合学习、工程实验和辅助转换等场景。

---

## 🚀 功能特性

* 支持 BSON 格式皆必的类型：String、Int32、Bool、Document、Array
* 封装类 Rust-like 的 `BsonValue` 进行类型表示
* 支持嵌套文档和数组编解码
* 用户可维护字典、数组接口进行结构
* 简洁编/解码 API，自动处理结构长度
* 已分类编码错误，类型无效、缺少结束符、无效长度等均有包括
* 提供完备测试样例

---

## 📆 安装方式

```bash
moon add ZSeanYves/bsonlite
```

或编辑 `moon.mod.json`：

```json
"import": ["ZSeanYves/bsonlite"]
```

---

## 🔧 快速上手

### 创建 BSON 文档

```moonbit
let doc = bson_document()
  .set("name", bson_string("Alice"))
  .set("age", bson_int32(30))
  .set("vip", bson_bool(true))
```

### 编码和解码

```moonbit
let bin = encode_bson(doc)            # 转为 Bytes
let parsed = decode_bson(bin)         # 转回文档
```

---

## 🔍 支持类型

| BSON 类型  | MoonBit 表示形式            | API 调用示例                        |
| -------- | ----------------------- | ------------------------------- |
| String   | `bson_string(str)`      | `.set("key", bson_string(...))` |
| Int32    | `bson_int32(n)`         | `.set("age", bson_int32(42))`   |
| Bool     | `bson_bool(true/false)` | `.set("vip", bson_bool(true))`  |
| Document | `bson_document()`       | `.set("user", bson_document())` |
| Array    | `bson_array()`          | `.push(bson_int32(...))`        |

---

## 🚫 异常处理

所有异常使用一致的类型：

```moonbit
suberror BsonError {
  InvalidType(String)
  InvalidLength(String)
  MissingNullTerminator(String)
  UnsupportedType(Byte)
}
```

支持 `raise`, `?`, `match` 进行协调处理。

---

## 📊 测试表现

运行全量测试：

```bash
moon test -p ZSeanYves/bsonlite
```

或单独运行测试文件：

```bash
moon run ZSeanYves/bsonlite_test
```

包括测试组：

* 基础编/解码对等
* 嵌套字典和数组
* 空文档编/解码
* 非法结构长度
* 缺失 CString 终止符
* 未支持类型异常

---

## 📂 项目结构

```
BsonLite/
├── src/
│   ├── bsonlite.mbt          # 主模块托管编/解码
│   ├── bsonlite.mbti         # 全部类型/接口声明
│   ├── encode.mbt            # encode_bson 实现
│   ├── decode.mbt            # decode_bson 实现
│   ├── error.mbt             # BsonError 定义
│   └── bsonlite_test.mbt     # 测试模块
├── moon.mod.json             # MoonBit 模块描述
└── LICENSE
```

---

## 📄 许可协议

Apache-2.0 License
请参见 [LICENSE](./LICENSE) 以获取完整条款。
