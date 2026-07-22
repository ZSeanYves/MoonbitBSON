#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { generateBsonImpls } from "./bson-codegen-lib.mjs";

function tokenize(source) {
  const tokens = [];
  let index = 0;
  let line = 1;
  while (index < source.length) {
    const start = index;
    const ch = source[index];
    if (ch === "\n") {
      tokens.push({ kind: "newline", value: "\n", line });
      line++;
      index++;
    } else if (/\s/.test(ch)) {
      index++;
    } else if (source.startsWith("//", index)) {
      const end = source.indexOf("\n", index);
      index = end < 0 ? source.length : end;
      tokens.push({ kind: "comment", value: source.slice(start, index), line });
    } else if (source.startsWith("/*", index)) {
      const end = source.indexOf("*/", index + 2);
      if (end < 0) throw new Error(`unterminated block comment at line ${line}`);
      const value = source.slice(index, end + 2);
      line += value.split("\n").length - 1;
      index = end + 2;
    } else if (/[A-Za-z_]/.test(ch)) {
      index++;
      while (index < source.length && /[A-Za-z0-9_]/.test(source[index])) index++;
      tokens.push({ kind: "identifier", value: source.slice(start, index), line });
    } else if (ch === '"') {
      index++;
      while (index < source.length && source[index] !== '"') {
        if (source[index] === "\\") index++;
        index++;
      }
      if (index >= source.length) throw new Error(`unterminated string at line ${line}`);
      index++;
      tokens.push({ kind: "string", value: source.slice(start, index), line });
    } else {
      tokens.push({ kind: "punct", value: ch, line });
      index++;
    }
  }
  return tokens;
}

function parseRename(comment) {
  const match = comment.match(/@bson\.rename\(\s*"([^"\0]+)"\s*\)/);
  return match?.[1];
}

function deriveSchema(source) {
  const tokens = tokenize(source);
  const types = [];
  let derivePending = false;
  for (let index = 0; index < tokens.length; index++) {
    const token = tokens[index];
    if (token.kind === "comment" && token.value.includes("@bson.derive")) {
      derivePending = true;
      continue;
    }
    if (!derivePending || token.value !== "struct") continue;
    const name = tokens[++index];
    if (name?.kind !== "identifier") throw new Error(`expected struct name at line ${token.line}`);
    while (tokens[index]?.value !== "{") index++;
    if (index >= tokens.length) throw new Error(`${name.value}: missing struct body`);
    const fields = [];
    let pendingRename;
    index++;
    while (index < tokens.length && tokens[index].value !== "}") {
      const current = tokens[index];
      if (current.kind === "comment") {
        pendingRename = parseRename(current.value) ?? pendingRename;
        index++;
        continue;
      }
      if (current.kind === "newline" || current.value === ",") {
        index++;
        continue;
      }
      if (["priv", "mut"].includes(current.value)) {
        index++;
        continue;
      }
      if (current.kind !== "identifier" || tokens[index + 1]?.value !== ":") {
        throw new Error(`${name.value}: unsupported field syntax at line ${current.line}`);
      }
      const fieldName = current.value;
      index += 2;
      const typeTokens = [];
      let depth = 0;
      while (index < tokens.length) {
        const part = tokens[index];
        if (part.kind === "newline" && depth === 0) break;
        if (part.value === "," && depth === 0) break;
        if (part.value === "}" && depth === 0) break;
        if (["[", "("].includes(part.value)) depth++;
        if (["]", ")"].includes(part.value)) depth--;
        typeTokens.push(part.value);
        index++;
      }
      const typeText = typeTokens.join("");
      const optional = typeText.endsWith("?");
      fields.push({
        name: fieldName,
        type: optional ? typeText.slice(0, -1) : typeText,
        optional,
        ...(pendingRename ? { rename: pendingRename } : {}),
      });
      pendingRename = undefined;
    }
    types.push({ name: name.value, fields });
    derivePending = false;
  }
  if (types.length === 0) throw new Error("no /// @bson.derive struct declarations found");
  return { types };
}

const args = process.argv.slice(2);
const check = args[0] === "--check";
if (check) args.shift();
if (args.length !== 2) {
  console.error("usage: bson-derive.mjs [--check] input.mbt output.mbt");
  process.exit(2);
}
const [inputPath, outputPath] = args;
const schema = deriveSchema(fs.readFileSync(inputPath, "utf8"));
const generated = generateBsonImpls(schema, "MoonBit " + path.relative(process.cwd(), inputPath));
if (check) {
  if (fs.readFileSync(outputPath, "utf8") !== generated) {
    console.error(`generated derive output is stale: ${path.relative(process.cwd(), outputPath)}`);
    process.exit(1);
  }
} else {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, generated);
}
