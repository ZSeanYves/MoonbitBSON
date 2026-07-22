#!/usr/bin/env node
import { spawnSync } from "node:child_process";

function vectors(count) {
  let state = 0x9e3779b97f4a7c15n;
  const output = [];
  for (let index = 0; index < count; index++) {
    let hex = "";
    for (let byte = 0; byte < 16; byte++) {
      state ^= state >> 12n;
      state ^= (state << 25n) & 0xffffffffffffffffn;
      state ^= state >> 27n;
      const value = Number((state * 0x2545f4914f6cdd1dn) & 0xffn);
      hex += value.toString(16).padStart(2, "0");
    }
    output.push(hex);
  }
  return output;
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  if (result.error) {
    throw new Error(`cannot run ${command}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    process.stderr.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    process.exit(result.status ?? 1);
  }
  return (result.stdout ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.split("\t").length === 3);
}

const values = vectors(Number(process.env.BSON_DECIMAL128_CASES ?? 256));
const moon = run("moon", ["run", "--target", "native", "src/decimal128_oracle", "--", ...values]);
const rust = run("cargo", ["run", "--quiet", "--manifest-path", "tools/decimal128-rust-oracle/Cargo.toml", "--", ...values]);

if (moon.length !== rust.length) {
  throw new Error(`oracle output length differs: MoonBit=${moon.length}, Rust=${rust.length}`);
}
for (let index = 0; index < moon.length; index++) {
  if (moon[index] !== rust[index]) {
    throw new Error(`Decimal128 differential mismatch at case ${index}:\nMoonBit ${moon[index]}\nRust   ${rust[index]}`);
  }
}
console.log(`Decimal128 differential oracle passed ${moon.length} random bit-pattern cases`);
