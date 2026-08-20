#!/usr/bin/env bash
set -euo pipefail

# Пересобирает скриншоты README из кадров example/bin/readme_examples/*.dart.
#
# Usage:
#   scripts/screenshots.sh                # все переведённые группы
#   scripts/screenshots.sh --only trace   # одну группу
#   scripts/screenshots.sh --check        # сравнить .ansi, ничего не писать
#
# Кадр — отдельный процесс: счётчики логов и trace id глобальны на изолят,
# и на картинках они всегда стартуют с единицы.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="$ROOT/example"
SHOTS="$ROOT/screenshots"

# Картинки, которые конвейер не делает и сиротами не считает.
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

  # Положительная проверка, а не отрицательная: файл, не знающий про кадры,
  # на `--list` не падает — он просто печатает все свои логи и выходит с
  # нулём, и такой вывод легко принять за список имён.
  if ! grep -q 'runFrames(' "$file"; then
    echo "skip: $group (кадры не объявлены)" >&2
    skipped=1
    continue
  fi

  list="$(cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" --list)"

  # Имя кадра — имя картинки: <группа>_<номер>. Строка, не похожая на имя,
  # означает, что `--list` вернул что-то другое, и дальше идти нельзя.
  while IFS= read -r frame; do
    [[ -z "$frame" ]] && continue
    if [[ ! "$frame" =~ ^${group}_[0-9]+$ ]]; then
      echo "$group: --list вернул не имя кадра: $frame" >&2
      exit 1
    fi
  done <<< "$list"

  while IFS= read -r frame; do
    [[ -z "$frame" ]] && continue
    claimed+=("$frame.png")
    echo "==> $frame"

    # Без script(1): pty не нужен, принтер отдаёт ANSI и в пайп.
    (cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" "$frame") \
      > "$OUT/$frame.ansi"

    if [[ "$CHECK" == 1 ]]; then
      if ! diff -q "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" >/dev/null 2>&1; then
        echo "изменился: $frame" >&2
        diff "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" || true
        failed=1
      fi
    else
      "$ROOT/scripts/ansi_screenshot.sh" \
        --input "$OUT/$frame.ansi" --output "$SHOTS/$frame.png" >/dev/null
    fi
  done <<< "$list"
done

# Сироты считаются только когда обойдены все группы и ни одна не пропущена,
# иначе непереведённые группы дали бы 37 ложных срабатываний.
if [[ -z "$ONLY" && "$CHECK" == 0 ]]; then
  if [[ "$skipped" == 1 ]]; then
    echo "проверка сирот пропущена: переведены не все группы" >&2
  else
    for png in "$SHOTS"/*.png; do
      name="$(basename "$png")"
      known=0
      for c in "${claimed[@]}" "${NOT_GENERATED[@]}"; do
        [[ "$name" == "$c" ]] && known=1 && break
      done
      [[ "$known" == 0 ]] && echo "сирота: $name" >&2
    done
  fi
fi

exit "$failed"
