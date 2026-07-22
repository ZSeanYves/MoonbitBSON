# MoonbitBSON 0.3.0 维护计划与结果

本轮按“先完成兼容性和全量验证，再补齐 0.3 API，最后交给远端 CI”的顺序执行。
不创建 Git tag，也不执行 Mooncakes 发布。

## 阶段 1：Extended JSON 合规性

已完成：

- Relaxed JSON 整数按原始 JSON lexeme 推断为最小精确的 Int32/Int64；非整数保持
  Double，并保留 `1` 与 `1.0` 的语义差异。
- 已知 wrapper 出现错误类型、缺字段或额外字段时返回结构化错误，而不是静默当作普通
  document。
- 支持 `$uuid` 的 canonical、compact 和 URN 形式；Binary subtype 接受一位或两位
  十六进制文本。
- Regex options 统一验证、去重并规范为 `ilmsux` 顺序；文档 key 和 Regex pattern
  的 NUL 规则与 BSON wire 约束一致。
- Relaxed DateTime 使用 ISO-8601/RFC 3339 UTC 文本，无法无损表示的年份回退到
  `$numberLong`。

## 阶段 2：完整 BSON Corpus 与差分验证

已完成：

- `testdata/bson-corpus` 收录 MongoDB BSON Corpus JSON fixtures，来源固定到
  `bson-rust` v3.1.0 的 corpus commit，并保留生成脚本和 provenance README。
- 生成测试覆盖 728 个 valid、75 个 decode error、131 个 Decimal128 parse error
  和 49 个 Extended JSON parse error case。
- 每个 valid case 都验证 wire decode/encode、RawDocument、canonical EJSON、relaxed
  EJSON；degenerate array 按规范归一化，strict option 仍可拒绝非规范 key。
- debug/release 和 wasm、wasm-gc、JavaScript、native 目标纳入 CI 门禁。

## 阶段 3：0.3.0 发布工程

已完成本地发布准备：

- `moon.mod` 版本为 `0.3.0`，双语 README、CHANGELOG、包元数据和 CI 已更新。
- CI 使用现代 `moon.mod`/`moon.pkg`，执行 fmt、全目标 check/test、release test、
  native benchmark、coverage summary、info 和 package listing。
- 当前工具链的 `moon doc --dry-run` 可正确解析现代 `moon.mod`/`moon.pkg`；完整
  `moon doc` 仍会因文档命令以 wasm-gc 检查 native-only `src/fuzz_driver` 的
  `extern "C"` 而报 `E4156`。这与已经废弃的 `moon.mod.json` 无关，因此暂不把
  `moon doc` 纳入 CI 门禁，待上游支持按 package target 生成文档后再恢复。
- 不执行 `moon publish`，不创建 tag；本轮只推送提交并等待远端 CI 通过。

## 阶段 4：类型化与可组合 API

已完成：

- `DateTime`：UTC 毫秒值、RFC 3339 解析/格式化、Relaxed EJSON 转换。
- `Uuid`：16 字节值、canonical/compact/URN 解析、BSON binary subtype 4。
- `ObjectId`：12 字节构造、timestamp/process-unique/counter 分解和 hex 转换；
  `ObjectId::new`/`new_secure` 使用系统或 Web Crypto 安全熵；没有熵源时返回
  `UnsupportedEntropy`，`from_parts` 仍可用于注入外部唯一值。
- `ToBson`/`FromBson` trait 和 bytes 序列化入口，覆盖常用标量、数组、Map、Option 以及
  BSON 专用类型。
- `RawDocument::elements`、`get_element` 和 `RawElement`，支持保留 wire bytes 并按需
  解码单个值。
- `RawDocumentView`、`RawElementView`、`BsonStreamDecoder`、
  `BsonStreamRawDecoder` 和 `BsonStreamEncoder`：借用 `BytesView`，支持 zero-copy
  element ranges、任意 chunk 边界的 raw/owned frame 解码和 append-only frame 编码。
- `BsonStreamRawDecoder` 对完整 frame 只返回 borrowed view，不创建 `Document`；跨 chunk
  frame 必须在 decoder 内组装一次，返回的 view 会保留不可变 backing `Bytes`，后续 `push`
  不会使它失效；默认 16 MiB 的 `max_size` 会在缓存前拒绝超大声明长度。
- `RawBsonRef`、`RawStringRef`、`RawBinaryRef` 等 typed borrowed values：嵌套文档和数组
  仍然保持借用，调用方通过 `to_bson`/`to_document`/`to_array` 显式 materialize。
- typed accessors、`require_*` 和结构化 `BsonError`，避免调用方重复写 variant 匹配。
- `tools/bson-codegen.mjs` 根据 schema 生成 `ToBson`/`FromBson`，并在 CI 检查生成结果
  没有漂移。

## 阶段 5：性能、属性测试与模糊测试

已完成：

- `src/codec_bench_test.mbt` 固定 128-field/512-byte payload benchmark，覆盖 encode、
  decode 和 Raw lazy lookup。
- `src/property_test.mbt` 使用 core QuickCheck 生成 384 组标量/组合文档 round-trip，
  并运行 512 组可重复随机字节 decoder fuzz smoke。
- `decode_prefix` 改为直接读取 `BytesView`，消除前缀解码的整帧复制。
- `tools/decimal128-differential.mjs` 对 Rust `bson` 3.1.0 运行随机 128-bit pattern
  差分，比较文本输出和重新编码结果。
- `src/fuzz_driver` 加入 AFL++ 可执行 harness；CI 运行 native driver smoke，长期运行
  由 `tools/fuzz-afl.sh` 启动；`.github/workflows/fuzz.yml` 每日运行 sanitizer 和
  AFL++，push 事件执行 30 秒烟测并上传 findings artifact。

本机 native release 最近一次测量：编码约 `18.53 us`，完整 Document 解码约 `16.00 us`，
owned Raw 定点读取约 `6.37 us`，borrowed RawDocumentView 定点读取约 `3.45 us`。
这些数字用于回归比较，不是跨机器性能承诺。

## 与 Rust 成熟实现相比的后续方向

0.3.0 follow-up 的 1、2、3 项已完成本轮可落地范围；第 4 项已完成 Rust oracle
基线，跨语言扩展仍保留为后续项；第 5 项的长期 seed 固化仍待运行积累：

1. MoonBit 仍不支持用户自定义 trait 的编译器 derive；新增 `tools/bson-derive.mjs` 提供
   注释驱动的 serde-like 生成步骤，但它仍是显式 codegen，不是编译器原生
   `derive(ToBson)` 语法。
2. `RawBsonRef` 已覆盖 BSON value enum、嵌套 document/array、字符串和 binary payload
   的 borrowed view；`BsonStreamRawDecoder` 现已按完整 frame 返回 `RawDocumentView`，
   不 materialize `Document`。跨 chunk 的输入仍需在内部组装，这是独立 transport allocation
   下无法避免的；背压和更高级的 scatter/gather 仍可在后续版本设计。
3. `install_secure_entropy_provider` 允许 WASM/WASM-GC 宿主注入安全随机源；配套
   `src/wasm_entropy` 使用 WebAssembly import（宿主可接 WASI `random_get` 或 crypto）。
   未安装 provider 时仍显式返回 `UnsupportedEntropy`，不会回退伪随机。
4. Decimal128 已接入 Rust 随机 bit-pattern oracle，并纳入 CI；仍可扩展 Java/Go 实现并
   保存长期历史结果。
5. 已配置 nightly/push sanitizer 与 AFL++ workflow、可配置 fuzz 时长和 findings artifact；
   仍建议在仓库长期运行后把发现的 seeds 固化到 `testdata/bson-corpus`。

### 原生 derive(ToBson) 审计结论

本机 `moon 0.1.20260713` 的最小实验：

```mbt
struct NativeDeriveAudit { value : Int } derive(ToBson)
```

`moon check --target native --deny-warn --warn-list +73` 明确返回 `E4077`：
`Don't know how to derive trait ToBson for type NativeDeriveAudit`。这不是本包 trait
签名或可见性问题，而是编译器 derive 白名单不包含用户自定义 trait。当前公开的
`#custom.*` 属性也只会被编译器忽略、供外部工具解析；它不能注册新的 derive handler。
因此本仓库无法仅通过 MoonBit 源码实现编译器原生 `derive(ToBson)`，也不应伪装成已经
支持。可行路径只有：

- 继续使用 `tools/bson-derive.mjs`/schema codegen，并将生成物纳入版本控制和 CI 漂移检查；
- 等 MoonBit 提供稳定的用户 derive/macro 扩展点后，再评估迁移，并保留当前生成器作为
  兼容 fallback。

官方依据：[E4077 用户 trait derive 限制](https://docs.moonbitlang.com/en/latest/language/error_codes/E4077.html)
和 [属性与外部工具](https://docs.moonbitlang.com/en/stable/language/attributes.html)。

这些项目适合作为 0.4 的破坏性设计窗口，而不是在 0.3 发布前引入未验证的复杂依赖。

## 本地发布门禁

```bash
moon fmt --check src
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon test --release --target all --deny-warn --warn-list +73
moon bench --target native --release
node tools/bson-codegen.mjs --check codegen/example.schema.json src/codegen_generated_test.mbt
node tools/bson-derive.mjs --check src/derive_types_test.mbt src/derive_generated_test.mbt
node tools/decimal128-differential.mjs
moon build --target native --release src/fuzz_driver
moon coverage analyze -- -f summary
moon info --target all
moon package --list
git diff --check
```

## 参考

- BSON 1.1 specification: <https://bsonspec.org/spec.html>
- Extended JSON specification: <https://github.com/mongodb/specifications/blob/master/source/extended-json/extended-json.md>
- MongoDB BSON Corpus: <https://github.com/mongodb/specifications/tree/master/source/bson-corpus>
- MongoDB Rust BSON: <https://github.com/mongodb/bson-rust>
- Rust `bson` API: <https://docs.rs/bson/latest/bson/>
