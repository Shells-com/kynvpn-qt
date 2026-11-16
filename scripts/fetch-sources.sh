#!/usr/bin/env bash
# Download and verify every source archive needed on this platform.
# Archives are cached in out/cache/ and checked against sources.sha256.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

deps=(openssl)
if [ "$PLATFORM" = linux ]; then deps+=(patchelf icu); fi

for d in "${deps[@]}"; do
    fetch_verified "$(dep_source_file "$d")" "$(dep_source_url "$d")" >/dev/null
done
for m in $(qt_modules_for_platform); do
    fetch_verified "$(qt_source_file "$m")" "$(qt_source_url "$m")" >/dev/null
done
log "All sources present and verified in $CACHE_DIR"
