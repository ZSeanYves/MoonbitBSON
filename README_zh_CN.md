# MoonbitBSON

[English](README.md) | [简体中文](README_zh_CN.md)

[![License](https://img.shields.io/github/license/ZSeanYves/MoonbitBSON)](LICENSE)

MoonBit 的严格 BSON 1.1 编解码库。仅使用 MoonBit core，支持 wasm、wasm-gc、
JavaScript 和 native 后端。0.3 API 新增类型化 DateTime、ObjectId、UUID、原始
字段访问和泛型 BSON 序列化 trait。

## 安装

```bash
moon add ZSeanYves/MoonbitBSON
```

```moonbit
import {
  "ZSeanYves/MoonbitBSON",
}
```

## 使用

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

`decode` 必须完整消费一个文档并拒绝尾随字节。处理带帧数据时使用
`decode_prefix`，它同时返回文档和已消费字节数。`RawDocument` 会验证输入并保留原始
wire bytes，包括字段顺序和重复键。需要只查看或解码部分字段时，可使用
`RawDocument::elements` 或 `get_element`。

## BSON 类型

支持 Double、String、Document、Array、Binary（含新子类型）、Undefined、
ObjectId、Boolean、UTC DateTime、Null、Regex、DBPointer、JavaScript、Symbol、
JavaScript with scope、Int32、Timestamp、Int64、Decimal128、MinKey、MaxKey。

为保证互操作性，已弃用的 BSON wire type 仍可解码。

## 安全性与错误

- 文档和数组的声明长度是不可越过的硬边界。
- 严格检查尾随数据、结束符、UTF-8、Boolean byte、旧 Binary 长度、
  ObjectId/Decimal128 大小、Regex options、嵌套深度和总大小。
- 每个 `BsonError` 都包含分类、byte offset、文档路径和消息。
- 按 MongoDB BSON Corpus 要求，默认接受并规范化退化数组键；严格场景可启用
  `DecodeOptions::new(require_canonical_array_keys=true)`。

## Extended JSON

通过 `Document::to_extended_json`、`to_extended_json_string`、
`from_extended_json` 和 `from_extended_json_string` 使用 Canonical Extended JSON。

通过 `to_relaxed_extended_json` 和 `to_relaxed_extended_json_string` 输出 Relaxed
Extended JSON。有限数值使用原生 JSON number；1970 年至 9999 年的 UTC DateTime
使用 RFC 3339 字符串，范围外日期保留无损的 `$numberLong` wrapper。

Decimal128 通过 `Decimal128::from_string` 和 `Decimal128::to_string` 提供精确的
IEEE 754-2008 文本转换，包括有符号零、subnormal、指数钳制、NaN 和 infinity。
Canonical 与 Relaxed Extended JSON 均使用标准 `$numberDecimal` 表示。

`DateTime` 是类型化的 UTC 毫秒值，支持 RFC 3339 解析和格式化。`Uuid` 支持
canonical、compact 和 URN 文本格式，以及 BSON binary subtype 4。`ObjectId::from_parts`
允许调用方提供 timestamp、process-unique bytes 和 counter；`ObjectId::new` 使用
OS/Web Crypto 安全熵，宿主无法提供时会明确失败。

`ToBson` 和 `FromBson` 提供可选的泛型转换，支持数组、Map、Option 以及类型化 BSON 值。

MoonBit 不允许把用户自定义 trait 放进编译器内置 `derive` 集合。需要类似 serde 的
生成实现时，可以使用 schema codegen，也可以使用注释驱动的结构体生成器：

```bash
node tools/bson-codegen.mjs codegen/example.schema.json src/codegen_generated_test.mbt
```

```bash
node tools/bson-derive.mjs src/derive_types_test.mbt src/derive_generated_test.mbt
```

生成文件会提交到仓库，并由 CI 使用 `--check` 检查是否漂移。

`RawDocumentView` 和 `RawElementView` 保留 `BytesView` 切片，只在显式请求时解码值。
`RawBsonRef` 让嵌套值、字符串 payload 和 binary payload 在调用 `to_bson` 前保持借用。
`BsonStreamDecoder` 和 `BsonStreamEncoder` 支持任意边界拆分和批量 frame。
`ObjectId::new` 使用 OS/Web Crypto 安全熵；没有安全熵的宿主会返回
`UnsupportedEntropy`。WASM 宿主可以通过 `install_secure_entropy_provider` 注入安全回调，
`src/wasm_entropy` 提供 `moonbit:bson` 模块中 `secure_random_u32` 函数的 import 适配器。

## 开发与验证

```bash
moon fmt --check src
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon test --release --target all --deny-warn --warn-list +73
moon bench --target native --release
moon coverage analyze -- -f summary
node tools/bson-codegen.mjs --check codegen/example.schema.json src/codegen_generated_test.mbt
node tools/decimal128-differential.mjs
moon info --target all
moon package --list
```

测试包含 `testdata/bson-corpus` 中完整的 MongoDB BSON Corpus JSON 套件、混合文档全部
截断点、property cases、有限 decoder fuzz smoke、畸形输入、Decimal128 文本向量以及
Canonical/Relaxed Extended JSON。

0.3.0 破坏性迁移见 [CHANGELOG.md](CHANGELOG.md)，实现状态和剩余工作见
[MAINTENANCE.md](MAINTENANCE.md)。
长期 native AFL++ decoder harness 见 [tools/README.md](tools/README.md)。

## 许可证

Apache-2.0，详见 [LICENSE](LICENSE)。
