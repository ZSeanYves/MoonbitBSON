#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { generateBsonImpls } from "./bson-codegen-lib.mjs";

const args = process.argv.slice(2);
const check = args[0] === "--check";
if (check) args.shift();
if (args.length !== 2) {
  console.error("usage: bson-codegen.mjs [--check] schema.json output.mbt");
  process.exit(2);
}

const [schemaPath, outputPath] = args;
const schema = JSON.parse(fs.readFileSync(schemaPath, "utf8"));
const generated = generateBsonImpls(schema, "schema " + path.relative(process.cwd(), schemaPath));
if (check) {
  if (fs.readFileSync(outputPath, "utf8") !== generated) {
    console.error(`generated output is stale: ${path.relative(process.cwd(), outputPath)}`);
    process.exit(1);
  }
} else {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, generated);
}
