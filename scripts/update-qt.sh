#!/usr/bin/env bash
# Switch to another Qt release: updates QT_VERSION in config.sh and pins the
# SHA-256 of every Qt module archive in sources.sha256, using the .sha256
# files published next to the archives on download.qt.io.
#
# Usage: scripts/update-qt.sh <version>     e.g. scripts/update-qt.sh 6.12.1
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NEW="${1:?usage: $0 <qt version>}"
[[ $NEW =~ ^6\.[0-9]+\.[0-9]+$ ]] || die "Expected a version like 6.12.1"

QT_VERSION="$NEW"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Keep the non-Qt entries, replace all Qt module entries.
grep -v -- '-everywhere-src-' "$ROOT/sources.sha256" > "$tmp.other" || true
: > "$tmp"
for entry in "${QT_MODULES[@]}"; do
    m="${entry%%:*}"
    url="$(qt_source_url "$m").sha256"
    line="$(curl -fsSL --retry 3 "$url")" || die "Can't fetch $url"
    hash="$(echo "$line" | awk '{print $1}')"
    [[ $hash =~ ^[0-9a-f]{64}$ ]] || die "Unexpected content in $url: $line"
    echo "$hash  $(qt_source_file "$m")" >> "$tmp"
    log "$m: $hash"
done
cat "$tmp" "$tmp.other" > "$ROOT/sources.sha256"
rm -f "$tmp.other"

sed -i.bak -E "s/^QT_VERSION=.*/QT_VERSION=$NEW/" "$ROOT/config.sh" && rm -f "$ROOT/config.sh.bak"
log "Updated to Qt $NEW. Review the diff, commit, then tag v$NEW-1 to release."
