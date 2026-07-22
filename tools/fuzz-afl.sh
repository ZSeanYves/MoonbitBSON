#!/usr/bin/env bash
set -euo pipefail

if ! command -v afl-fuzz >/dev/null 2>&1; then
  echo "afl-fuzz is required; install AFL++ before running this harness" >&2
  exit 2
fi

moon build --target native --release src/fuzz_driver

binary="$(find _build -type f -name 'fuzz_driver' -perm -111 | head -n 1)"
if [[ -z "${binary}" ]]; then
  echo "MoonBit fuzz driver executable was not found under _build" >&2
  exit 1
fi

mkdir -p tools/fuzz-corpus tools/fuzz-findings
afl-fuzz -i tools/fuzz-corpus -o tools/fuzz-findings -- "${binary}" @@
