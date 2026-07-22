# Developer Tools

`bson-codegen.mjs` generates `ToBson`/`FromBson` implementations from a small
schema. Check the committed example with:

```bash
node tools/bson-codegen.mjs --check \
  codegen/example.schema.json src/codegen_generated_test.mbt
```

`decimal128-differential.mjs` compares deterministic random Decimal128
bit-patterns with Rust `bson` 3.1.0. It requires Node.js and Cargo:

```bash
node tools/decimal128-differential.mjs
```

The long-running native decoder harness is AFL++-compatible:

```bash
./tools/fuzz-afl.sh
```

The driver treats every decode failure as an expected input result. A process
crash, sanitizer finding, or non-zero exit is therefore a fuzz regression.
