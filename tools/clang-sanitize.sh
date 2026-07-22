#!/usr/bin/env bash
set -euo pipefail
exec clang -fsanitize=address,undefined -fno-omit-frame-pointer "$@"
