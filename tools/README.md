# Developer Tools

`bson-codegen.mjs` generates `ToBson`/`FromBson` implementations from a small
schema. Check the committed example with:

```bash
node tools/bson-codegen.mjs --check \
  codegen/example.schema.json src/codegen_generated_test.mbt
```

`bson-derive.mjs` provides a serde-like annotation workflow for MoonBit structs.
Annotate a struct with `/// @bson.derive` and optional fields with
`/// @bson.rename("wire_name")`, then generate and check the companion file:

```bash
node tools/bson-derive.mjs src/derive_types_test.mbt src/derive_generated_test.mbt
node tools/bson-derive.mjs --check src/derive_types_test.mbt src/derive_generated_test.mbt
```

This is external code generation, not a compiler derive. The current compiler
rejects user-defined `derive(ToBson)` with `E4077`; `#custom.*` attributes are
ignored by the compiler and are only an input convention for tools such as this
one.

`decimal128-differential.mjs` compares deterministic random Decimal128
bit-patterns with Rust `bson` 3.1.0. It requires Node.js and Cargo:

```bash
node tools/decimal128-differential.mjs
```

The long-running native decoder harness is AFL++-compatible. CI runs the
native, non-instrumented driver with AFL++ `-n` mode and `AFL_NO_FORKSRV=1`;
the script still treats a target crash or unexpected AFL++ exit as a failure:

```bash
BSON_FUZZ_DURATION=900 ./tools/fuzz-afl.sh
```

The driver treats every decode failure as an expected input result. A process
crash, sanitizer finding, or non-zero exit is therefore a fuzz regression. The
nightly GitHub Actions workflow runs the native driver with ASan/UBSan and
uploads `tools/fuzz-findings` and sanitizer logs as artifacts. Push-triggered
runs use a short 30-second smoke duration; scheduled runs use 900 seconds.
