#!/usr/bin/env bash
set -euo pipefail

if ! command -v afl-fuzz >/dev/null 2>&1; then
  echo "afl-fuzz is required; install AFL++ before running this harness" >&2
  exit 2
fi

moon build --target native --release src/fuzz_driver

binary="$(find _build -type f \( -name 'fuzz_driver' -o -name 'fuzz_driver.exe' \) -perm -111 | head -n 1)"
if [[ -z "${binary}" ]]; then
  echo "MoonBit fuzz driver executable was not found under _build" >&2
  exit 1
fi

mkdir -p tools/fuzz-corpus tools/fuzz-findings
duration="${BSON_FUZZ_DURATION:-0}"
if [[ "${duration}" == "0" ]]; then
  exec afl-fuzz -i tools/fuzz-corpus -o tools/fuzz-findings -- "${binary}" @@
fi

set +e
timeout --signal=TERM "${duration}s" afl-fuzz \
  -i tools/fuzz-corpus \
  -o tools/fuzz-findings \
  -- "${binary}" @@
status=$?
set -e
if [[ "${status}" -ne 0 && "${status}" -ne 124 && "${status}" -ne 143 ]]; then
  echo "AFL++ exited with status ${status}" >&2
  exit "${status}"
fi
