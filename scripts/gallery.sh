#!/usr/bin/env bash
set -euo pipefail

# Builds the pub.dev screenshot gallery from frames already shot into
# screenshots/.
#
# Usage:
#   scripts/gallery.sh            # rebuild gallery/*.webp
#   scripts/gallery.sh --check    # verify they are present and current
#
# The pictures are declared in pubspec.yaml under `screenshots:`, so unlike
# screenshots/ they ship inside the pub archive and every `pub get` pays for
# them. Hence lossless WebP: identical pixels, a fraction of the bytes —
# these are terminal frames, flat colour and sharp text, which is what the
# format is best at. PNG would cost around 428 KB for the same four.
#
# gallery/ must stay out of .pubignore. screenshots/ is excluded there
# wholesale, and gitignore syntax cannot re-include a file whose parent
# directory is excluded — which is why the gallery lives in its own
# directory rather than beside the frames it is built from.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOTS="$ROOT/screenshots"
OUT="$ROOT/gallery"

# The four frames pub.dev shows, in the order the carousel walks them.
FRAMES=(quick_start_1 gallery_1 gallery_2 trace_1)

CHECK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '3,8p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

command -v cwebp >/dev/null || {
  echo "cwebp not found (brew install webp)" >&2
  exit 1
}

mkdir -p "$OUT"
failed=0

for frame in "${FRAMES[@]}"; do
  png="$SHOTS/$frame.png"
  webp="$OUT/$frame.webp"

  [[ -f "$png" ]] || {
    echo "missing frame: $png (run scripts/screenshots.sh)" >&2
    exit 1
  }

  if [[ "$CHECK" == 1 ]]; then
    if [[ ! -f "$webp" ]]; then
      echo "missing: $webp" >&2
      failed=1
    elif [[ "$png" -nt "$webp" ]]; then
      echo "stale: $webp is older than $png" >&2
      failed=1
    fi
    continue
  fi

  cwebp -quiet -lossless "$png" -o "$webp"
  echo "==> $frame.webp ($(( $(stat -f%z "$webp") / 1024 )) KB)"
done

if [[ "$CHECK" == 0 ]]; then
  # An orphan here is a picture the pubspec no longer lists.
  for f in "$OUT"/*.webp; do
    name="$(basename "$f" .webp)"
    known=0
    for c in "${FRAMES[@]}"; do
      [[ "$name" == "$c" ]] && known=1 && break
    done
    [[ "$known" == 0 ]] && echo "orphan: $name.webp" >&2
  done
fi

exit "$failed"
