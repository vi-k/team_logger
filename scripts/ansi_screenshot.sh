#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  some_command | scripts/ansi_screenshot.sh --output <output.png> [--ansi-file <output.ansi>]
  scripts/ansi_screenshot.sh --command "<shell command>" --output <output.png> [--ansi-file <output.ansi>]
  scripts/ansi_screenshot.sh --input <input.ansi> --output <output.png>

Options:
  --command      Command to run in a pseudo-TTY so ANSI codes are preserved.
  --input        Existing file with ANSI output.
  --output       Output PNG path.
  --line-spacing Extra line spacing in points (default: 2).
  --ansi-file    Optional path for captured ANSI output.
  --help         Show this help.

If neither --command nor --input is specified,
ANSI content is read from stdin by default.
EOF
}

COMMAND=""
INPUT=""
OUTPUT=""
ANSI_FILE=""
LINE_SPACING="2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --command)
      [[ $# -ge 2 ]] || { echo "Missing value for --command" >&2; exit 1; }
      COMMAND="$2"
      shift 2
      ;;
    --input)
      [[ $# -ge 2 ]] || { echo "Missing value for --input" >&2; exit 1; }
      INPUT="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "Missing value for --output" >&2; exit 1; }
      OUTPUT="$2"
      shift 2
      ;;
    --ansi-file)
      [[ $# -ge 2 ]] || { echo "Missing value for --ansi-file" >&2; exit 1; }
      ANSI_FILE="$2"
      shift 2
      ;;
    --line-spacing)
      [[ $# -ge 2 ]] || { echo "Missing value for --line-spacing" >&2; exit 1; }
      LINE_SPACING="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required." >&2
  usage
  exit 1
fi

MODE_COUNT=0
[[ -n "$COMMAND" ]] && ((MODE_COUNT+=1))
[[ -n "$INPUT" ]] && ((MODE_COUNT+=1))

if [[ "$MODE_COUNT" -gt 1 ]]; then
  echo "Error: use only one of --command or --input." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: swift is required but not found." >&2
  exit 1
fi

if [[ -n "$COMMAND" ]]; then
  if ! command -v script >/dev/null 2>&1; then
    echo "Error: script(1) is required but not found." >&2
    exit 1
  fi
  if [[ -z "$ANSI_FILE" ]]; then
    ANSI_FILE="${OUTPUT%.png}.ansi.txt"
  fi
  mkdir -p "$(dirname "$ANSI_FILE")"
  /usr/bin/script -q "$ANSI_FILE" /bin/zsh -lc "$COMMAND"
  echo "ANSI: $ANSI_FILE"
  INPUT="$ANSI_FILE"
elif [[ -z "$INPUT" ]]; then
  if [[ -z "$ANSI_FILE" ]]; then
    TMP_ANSI="$(mktemp /tmp/ansi_screenshot.XXXXXX.ansi)"
    cat > "$TMP_ANSI"
    trap 'rm -f "$TMP_ANSI"' EXIT
    INPUT="$TMP_ANSI"
  else
    cat > "$ANSI_FILE"
    echo "ANSI: $ANSI_FILE"
    INPUT="$ANSI_FILE"
  fi
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: ANSI input file not found: $INPUT" >&2
  exit 1
fi

if [[ ! "$LINE_SPACING" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: --line-spacing must be a non-negative number." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

swift - "$INPUT" "$OUTPUT" "$LINE_SPACING" <<'SWIFT'
import Foundation
import AppKit

struct Style {
    var fg: NSColor
    var bg: NSColor?
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: swift render.swift <input.ansi> <output.png> <line-spacing>\n", stderr)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let lineSpacing = max(0, Double(args[3]) ?? 2.0)

let defaultFG = NSColor(calibratedWhite: 0.88, alpha: 1.0)
let canvasBG = NSColor(calibratedWhite: 0.10, alpha: 1.0)

func ansi256Color(_ n: Int) -> NSColor {
    if n < 0 { return defaultFG }
    if n < 16 {
        let table: [(CGFloat, CGFloat, CGFloat)] = [
            (0,0,0), (128,0,0), (0,128,0), (128,128,0),
            (0,0,128), (128,0,128), (0,128,128), (192,192,192),
            (128,128,128), (255,0,0), (0,255,0), (255,255,0),
            (0,0,255), (255,0,255), (0,255,255), (255,255,255)
        ]
        let (r,g,b) = table[max(0, min(15, n))]
        return NSColor(calibratedRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
    }
    if n <= 231 {
        let idx = n - 16
        let r = idx / 36
        let g = (idx % 36) / 6
        let b = idx % 6
        let levels: [CGFloat] = [0, 95, 135, 175, 215, 255]
        return NSColor(calibratedRed: levels[r]/255.0, green: levels[g]/255.0, blue: levels[b]/255.0, alpha: 1.0)
    }
    if n <= 255 {
        let v = CGFloat(8 + (n - 232) * 10)
        return NSColor(calibratedRed: v/255.0, green: v/255.0, blue: v/255.0, alpha: 1.0)
    }
    return defaultFG
}

func basicColor(_ code: Int, bright: Bool) -> NSColor {
    let normal: [(CGFloat, CGFloat, CGFloat)] = [
        (0,0,0), (205,49,49), (13,188,121), (229,229,16),
        (36,114,200), (188,63,188), (17,168,205), (229,229,229)
    ]
    let brightTable: [(CGFloat, CGFloat, CGFloat)] = [
        (102,102,102), (241,76,76), (35,209,139), (245,245,67),
        (59,142,234), (214,112,214), (41,184,219), (255,255,255)
    ]
    let i = max(0, min(7, code))
    let (r,g,b) = bright ? brightTable[i] : normal[i]
    return NSColor(calibratedRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
}

func parseAnsiLine(_ line: String) -> [(String, Style)] {
    var segments: [(String, Style)] = []
    var style = Style(fg: defaultFG, bg: nil)
    var buffer = ""
    let chars = Array(line)
    var i = 0

    while i < chars.count {
        if chars[i] == "\u{001B}", i + 1 < chars.count, chars[i + 1] == "[" {
            if !buffer.isEmpty {
                segments.append((buffer, style))
                buffer = ""
            }

            i += 2
            var codeText = ""
            while i < chars.count {
                let c = chars[i]
                if c == "m" { break }
                codeText.append(c)
                i += 1
            }
            if i < chars.count, chars[i] == "m" { i += 1 }

            let rawCodes = codeText.isEmpty ? [0] : codeText.split(separator: ";").compactMap { Int($0) }
            var idx = 0
            while idx < rawCodes.count {
                let c = rawCodes[idx]
                switch c {
                case 0:
                    style = Style(fg: defaultFG, bg: nil)
                case 39:
                    style.fg = defaultFG
                case 49:
                    style.bg = nil
                case 30...37:
                    style.fg = basicColor(c - 30, bright: false)
                case 90...97:
                    style.fg = basicColor(c - 90, bright: true)
                case 40...47:
                    style.bg = basicColor(c - 40, bright: false)
                case 100...107:
                    style.bg = basicColor(c - 100, bright: true)
                case 38 where idx + 2 < rawCodes.count && rawCodes[idx + 1] == 5:
                    style.fg = ansi256Color(rawCodes[idx + 2])
                    idx += 2
                case 48 where idx + 2 < rawCodes.count && rawCodes[idx + 1] == 5:
                    style.bg = ansi256Color(rawCodes[idx + 2])
                    idx += 2
                default:
                    break
                }
                idx += 1
            }
            continue
        }

        buffer.append(chars[i])
        i += 1
    }

    if !buffer.isEmpty {
        segments.append((buffer, style))
    }
    return segments
}

let raw = try String(contentsOfFile: inputPath, encoding: .utf8)
let normalized = raw
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")

var lines = normalized.components(separatedBy: "\n")
while lines.last == "" {
    _ = lines.popLast()
}

if lines.isEmpty {
    lines = [""]
}

let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
let padX: CGFloat = 18
let padY: CGFloat = 16
let lineHeight = ceil(font.ascender - font.descender + font.leading + CGFloat(lineSpacing))
let parsed = lines.map(parseAnsiLine)

func textWidth(_ text: String, _ fg: NSColor) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: fg
    ]
    return ceil((text as NSString).size(withAttributes: attrs).width)
}

var maxLineWidth: CGFloat = 0

for segs in parsed {
    let w = segs.reduce(CGFloat(0)) { $0 + textWidth($1.0, $1.1.fg) }
    if w > maxLineWidth {
        maxLineWidth = w
    }
}

let imageSize = NSSize(
    width: maxLineWidth + padX * 2,
    height: CGFloat(max(1, parsed.count)) * lineHeight + padY * 2
)

let image = NSImage(size: imageSize)

image.lockFocus()

canvasBG.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

for (lineIndex, segs) in parsed.enumerated() {
    var x = padX
    let y = imageSize.height - padY - CGFloat(lineIndex + 1) * lineHeight + 3

    for (text, st) in segs {
        let w = textWidth(text, st.fg)

        if let bg = st.bg {
            bg.setFill()
            NSBezierPath(
                rect: NSRect(
                    x: x,
                    y: y - 2,
                    width: w,
                    height: lineHeight - 1
                )
            ).fill()
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: st.fg
        ]

        (text as NSString).draw(
            at: NSPoint(x: x, y: y),
            withAttributes: attrs
        )

        x += w
    }
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("PNG rendering failed\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))

// print("Rendered: \(outputPath)")
SWIFT

echo "PNG: $OUTPUT"
