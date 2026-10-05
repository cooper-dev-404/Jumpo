#!/bin/bash
set -euo pipefail
JUMPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$JUMPO_ROOT"
mkdir -p .build/module-cache .build/swiftpm-cache .build/swiftpm-config .build/swiftpm-security
export CLANG_MODULE_CACHE_PATH="$JUMPO_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$JUMPO_ROOT/.build/module-cache"
JUMPO_COMMAND="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
JUMPO_EXTRA_FLAGS=()
JUMPO_DEVELOPER="$(xcode-select -p)"
JUMPO_TEST_FRAMEWORKS="$JUMPO_DEVELOPER/Library/Developer/Frameworks"
# CLT 6.3 installs Testing outside the framework search path used by SwiftPM.
if [ "$JUMPO_COMMAND" = test ] && [ -d "$JUMPO_TEST_FRAMEWORKS/Testing.framework" ]; then
    JUMPO_EXTRA_FLAGS+=(
        -Xswiftc -F -Xswiftc "$JUMPO_TEST_FRAMEWORKS"
        -Xlinker -F -Xlinker "$JUMPO_TEST_FRAMEWORKS"
        -Xlinker -rpath -Xlinker "$JUMPO_TEST_FRAMEWORKS"
    )
fi
JUMPO_TEST_PLUGINS="$(dirname "$(xcrun --find swiftc)")/../lib/swift/host/plugins/testing"
if [ "$JUMPO_COMMAND" = test ] && [ -d "$JUMPO_TEST_PLUGINS" ]; then
    JUMPO_EXTRA_FLAGS+=(-Xswiftc -plugin-path -Xswiftc "$JUMPO_TEST_PLUGINS")
fi
# SwiftPM applies its own seatbelt profile, which cannot nest inside another
# sandbox (containers, CI agents, some IDE runners) and reports
# "sandbox-exec: sandbox_apply: Operation not permitted". Opt out explicitly.
if [ "${JUMPO_SWIFTPM_NO_SANDBOX:-0}" = "1" ]; then
    JUMPO_EXTRA_FLAGS+=(--disable-sandbox)
fi
exec swift "$JUMPO_COMMAND" \
    --build-system native \
    --scratch-path "$JUMPO_ROOT/.build" \
    --cache-path "$JUMPO_ROOT/.build/swiftpm-cache" \
    --config-path "$JUMPO_ROOT/.build/swiftpm-config" \
    --security-path "$JUMPO_ROOT/.build/swiftpm-security" ${JUMPO_EXTRA_FLAGS[@]+"${JUMPO_EXTRA_FLAGS[@]}"} "$@"
