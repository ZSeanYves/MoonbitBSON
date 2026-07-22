#!/usr/bin/env bash
set -euo pipefail

if ! command -v afl-fuzz >/dev/null 2>&1; then
  echo "afl-fuzz is required; install AFL++ before running this harness" >&2
  exit 2
fi

moon build --target native --release src/fuzz_driver

mkdir -p tools/fuzz-findings
binary="$(find _build -type f \( -name 'fuzz_driver' -o -name 'fuzz_driver.exe' \) -perm -111 | head -n 1)"
if [[ -z "${binary}" ]]; then
  find _build -type f -path '*fuzz_driver*' -print >&2 || true
  echo "MoonBit fuzz driver executable was not found under _build" >&2
  exit 1
fi

mkdir -p tools/fuzz-corpus
duration="${BSON_FUZZ_DURATION:-0}"
afl_mode=()
if [[ "${AFL_QEMU_MODE:-0}" == "1" ]]; then
  afl_mode+=("-Q")
fi
if [[ "${AFL_DUMB_MODE:-0}" == "1" ]]; then
  afl_mode=("-n")
fi
if [[ "${duration}" == "0" ]]; then
  exec afl-fuzz "${afl_mode[@]}" -i tools/fuzz-corpus -o tools/fuzz-findings -- "${binary}" @@
fi

set +e
# Let AFL++ own the timed stop so its child and fuzzer exit codes are not
# confused by an external timeout wrapper.
started_at=${SECONDS}
afl-fuzz "${afl_mode[@]}" -V "${duration}" \
  -i tools/fuzz-corpus \
  -o tools/fuzz-findings \
  -- "${binary}" @@
status=$?
elapsed=$((SECONDS - started_at))
set -e
if [[ "${status}" -eq 1 && "${elapsed}" -ge "${duration}" ]]; then
  echo "AFL++ returned 1 after the timed smoke window; treating SIGINT stop as normal"
  status=0
fi
if [[ "${status}" -ne 0 && "${status}" -ne 124 && "${status}" -ne 130 && "${status}" -ne 143 ]]; then
  echo "AFL++ exited with status ${status}" >&2
  exit "${status}"
fi
