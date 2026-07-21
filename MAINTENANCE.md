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
- 不执行 `moon publish`，不创建 tag；本轮只推送提交并等待远端 CI 通过。

当前工具链 `moon 0.1.20260713` 的 `moon doc` 仍硬编码读取已废弃的
`moon.mod.json`。本地已验证临时兼容清单可以生成文档，但仓库和 CI 不保留该弃用文件，
待上游修复后再恢复 `moon doc` 门禁。

## 阶段 4：类型化与可组合 API

已完成：

- `DateTime`：UTC 毫秒值、RFC 3339 解析/格式化、Relaxed EJSON 转换。
- `Uuid`：16 字节值、canonical/compact/URN 解析、BSON binary subtype 4。
- `ObjectId`：12 字节构造、timestamp/process-unique/counter 分解和 hex 转换；
  `ObjectId::new` 是 best-effort 本地生成器，安全随机源由调用方通过 `from_parts`
  提供，避免把伪随机误标成密码学随机。
- `ToBson`/`FromBson` trait 和 bytes 序列化入口，覆盖常用标量、数组、Map、Option 以及
  BSON 专用类型。
- `RawDocument::elements`、`get_element` 和 `RawElement`，支持保留 wire bytes 并按需
  解码单个值。
- typed accessors、`require_*` 和结构化 `BsonError`，避免调用方重复写 variant 匹配。

## 阶段 5：性能、属性测试与模糊测试

已完成：

- `src/codec_bench_test.mbt` 固定 128-field/512-byte payload benchmark，覆盖 encode、
  decode 和 Raw lazy lookup。
- `src/property_test.mbt` 使用 core QuickCheck 生成 384 组标量/组合文档 round-trip，
  并运行 512 组可重复随机字节 decoder fuzz smoke。
- `decode_prefix` 改为直接读取 `BytesView`，消除前缀解码的整帧复制。

本机 native release 基线/优化后测量：编码约 `18.60 -> 18.49 us`，解码约
`15.67 -> 15.57 us`，Raw 定点读取约 `6.31 -> 6.17 us`。这些数字用于回归比较，
不是跨机器性能承诺。

## 与 Rust 成熟实现相比的后续方向

0.3.0 已覆盖本轮要求，但仍有明确差距：

1. 尚无 Rust `serde` 同等的 derive/codegen 集成；当前 trait 是手写 opt-in 转换。
2. 尚无真正 streaming encoder/decoder、borrowed typed views、RawBSON iterator 的
   完整 zero-copy 设计；Raw API 目前只做到元素范围扫描和按需解码。
3. ObjectId 默认生成器没有操作系统密码学熵源；跨进程生产环境应注入外部唯一的
   process-unique bytes 和 counter。
4. Decimal128 已覆盖文本转换和 corpus vectors，但仍应继续与更多语言实现做随机
   bit-pattern differential test，并补充性能测量。
5. 尚未接入长期运行的 libFuzzer/AFL harness、criterion 风格历史基线和自动兼容性
   报告；当前 fuzz/property 套件是确定性 CI smoke。

这些项目适合作为 0.4 的破坏性设计窗口，而不是在 0.3 发布前引入未验证的复杂依赖。

## 本地发布门禁

```bash
moon fmt --check src
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon test --release --target all --deny-warn --warn-list +73
moon bench --target native --release
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
