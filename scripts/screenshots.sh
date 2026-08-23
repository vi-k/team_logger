#!/usr/bin/env bash
set -euo pipefail

# Rebuilds the README screenshots from the frames in example/bin/readme_examples.
#
# Usage:
#   scripts/screenshots.sh                # every group declaring frames
#   scripts/screenshots.sh --only trace   # one group
#   scripts/screenshots.sh --check        # diff the .ansi, write nothing
#
# A frame is its own process: log counters and trace ids are per-isolate
# globals, so in the pictures they always start from one.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="$ROOT/example"
SHOTS="$ROOT/screenshots"

# Pictures the pipeline does not make and does not count as orphans.
NOT_GENERATED=("flutter_team_logger.png")

ONLY=""
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      [[ $# -ge 2 ]] || { echo "Missing value for --only" >&2; exit 1; }
      ONLY="$2"
      shift 2
      ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '3,12p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$CHECK" == 1 ]]; then
  OUT="$(mktemp -d)"
  trap 'rm -rf "$OUT"' EXIT
else
  OUT="$SHOTS"
fi

claimed=()
skipped=0
failed=0

for file in "$EXAMPLE"/bin/readme_examples/*.dart; do
  group="$(basename "$file" .dart)"
  if [[ -n "$ONLY" && "$group" != "$ONLY" ]]; then
    continue
  fi

  # A positive check rather than a negative one: a file that knows nothing
  # about frames does not fail on `--list` — it just prints all of its logs
  # and exits zero, and that output is easy to mistake for a list of names.
  if ! grep -q 'runFrames(' "$file"; then
    echo "skip: $group (no frames declared)" >&2
    skipped=1
    continue
  fi

  list="$(cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" --list)"

  # A frame name is the picture name: <group>_<number>. A line that does not
  # look like one means `--list` returned something else, and we must stop.
  while IFS= read -r frame; do
    [[ -z "$frame" ]] && continue
    if [[ ! "$frame" =~ ^${group}_[0-9]+$ ]]; then
      echo "$group: --list returned something other than a frame name: $frame" >&2
      exit 1
    fi
  done <<< "$list"

  while IFS= read -r frame; do
    [[ -z "$frame" ]] && continue
    claimed+=("$frame.png")
    echo "==> $frame"

    # No script(1): a pty is not needed, the printer emits ANSI into a pipe.
    (cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" "$frame") \
      > "$OUT/$frame.ansi"

    if [[ "$CHECK" == 1 ]]; then
      if ! diff -q "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" >/dev/null 2>&1; then
        echo "changed: $frame" >&2
        diff "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" || true
        failed=1
      fi
    else
      "$ROOT/scripts/ansi_screenshot.sh" \
        --input "$OUT/$frame.ansi" --output "$SHOTS/$frame.png" >/dev/null
    fi
  done <<< "$list"
done

# Orphans are counted only once every group has been walked and none was
# skipped; otherwise groups without frames would raise 37 false positives.
if [[ -z "$ONLY" && "$CHECK" == 0 ]]; then
  if [[ "$skipped" == 1 ]]; then
    echo "orphan check skipped: not every group declares frames" >&2
  else
    for png in "$SHOTS"/*.png; do
      name="$(basename "$png")"
      known=0
      for c in "${claimed[@]}" "${NOT_GENERATED[@]}"; do
        [[ "$name" == "$c" ]] && known=1 && break
      done
      [[ "$known" == 0 ]] && echo "orphan: $name" >&2
    done
  fi
fi

exit "$failed"
