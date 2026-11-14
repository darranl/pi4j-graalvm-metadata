#!/usr/bin/env bash
# Compare the reachability-metadata.json of the latest release with a freshly generated one.
#
# Usage: compare-metadata.sh <released.json> <generated.json>
#
# The comparison is normalised: object keys are sorted and every array is sorted, so a change in
# key order, array order or formatting is not reported as a difference. The order of entries in
# reachability metadata has no meaning.
#
# Exit status:
#   0  identical (byte-for-byte, or the same content once normalised)
#   1  the content differs (a unified diff of the normalised files is printed)
#   2  usage error or unreadable/invalid input
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $(basename "$0") <released.json> <generated.json>" >&2
    exit 2
fi
RELEASED="$1"
GENERATED="$2"

for f in "$RELEASED" "$GENERATED"; do
    if [[ ! -s "$f" ]]; then
        echo "ERROR: $f does not exist or is empty" >&2
        exit 2
    fi
done

if cmp -s "$RELEASED" "$GENERATED"; then
    echo "RESULT: identical (byte-for-byte)"
    exit 0
fi

normalise() {
    jq -S 'walk(if type == "array" then sort_by(tojson) else . end)' "$1"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

normalise "$RELEASED" > "$TMP/released.json" || { echo "ERROR: $RELEASED is not valid JSON" >&2; exit 2; }
normalise "$GENERATED" > "$TMP/generated.json" || { echo "ERROR: $GENERATED is not valid JSON" >&2; exit 2; }

if cmp -s "$TMP/released.json" "$TMP/generated.json"; then
    echo "RESULT: identical content (only formatting or ordering differs)"
    exit 0
fi

echo "RESULT: DIFFERENT - the captured metadata no longer matches the latest release"
echo
echo "Unified diff of the normalised files (sorted keys and arrays; - released, + generated):"
diff -u --label released --label generated "$TMP/released.json" "$TMP/generated.json" || true
exit 1
