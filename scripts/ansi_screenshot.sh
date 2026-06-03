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
  --line-spacing Extra line spacing in points (default: 0).
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
LINE_SPACING="0"

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
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false
    var isHidden: Bool = false
}

struct Cell {
    var text: String
    var style: Style
}

let args = CommandLine.arguments

guard args.count >= 4 else {
    fputs("Usage: swift render.swift <input.ansi> <output.png> <line-spacing>\n", stderr)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let lineSpacing = max(0, Double(args[3]) ?? 0.0)

let defaultFG = NSColor(calibratedWhite: 0.88, alpha: 1.0)
let canvasBG = NSColor(calibratedWhite: 0.10, alpha: 1.0)

let regularFont =
    NSFont(name: "Menlo-Regular", size: 13)
    ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

let boldFont =
    NSFont(name: "Menlo-Bold", size: 13)
    ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

let italicFont =
    NSFont(name: "Menlo-Italic", size: 13)
    ?? NSFontManager.shared.convert(regularFont, toHaveTrait: .italicFontMask)

let boldItalicFont =
    NSFont(name: "Menlo-BoldItalic", size: 13)
    ?? NSFontManager.shared.convert(boldFont, toHaveTrait: .italicFontMask)

func fontForStyle(_ style: Style) -> NSFont {
    if style.isBold && style.isItalic {
        return boldItalicFont
    }

    if style.isBold {
        return boldFont
    }

    if style.isItalic {
        return italicFont
    }

    return regularFont
}

let padX: CGFloat = 18
let padY: CGFloat = 16

let charAdvance = ceil(("W" as NSString).size(withAttributes: [.font: regularFont]).width)
let lineHeight = ceil(regularFont.ascender - regularFont.descender + regularFont.leading + CGFloat(lineSpacing))

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

        return NSColor(
            calibratedRed: r / 255.0,
            green: g / 255.0,
            blue: b / 255.0,
            alpha: 1.0
        )
    }

    if n <= 231 {
        let idx = n - 16
        let r = idx / 36
        let g = (idx % 36) / 6
        let b = idx % 6
        let levels: [CGFloat] = [0, 95, 135, 175, 215, 255]

        return NSColor(
            calibratedRed: levels[r] / 255.0,
            green: levels[g] / 255.0,
            blue: levels[b] / 255.0,
            alpha: 1.0
        )
    }

    if n <= 255 {
        let v = CGFloat(8 + (n - 232) * 10)

        return NSColor(
            calibratedRed: v / 255.0,
            green: v / 255.0,
            blue: v / 255.0,
            alpha: 1.0
        )
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

    return NSColor(
        calibratedRed: r / 255.0,
        green: g / 255.0,
        blue: b / 255.0,
        alpha: 1.0
    )
}

func stripScriptHeaderAndFooter(_ raw: String) -> String {
    var lines = raw
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .components(separatedBy: "\n")

    if let first = lines.first, first.hasPrefix("Script started") {
        lines.removeFirst()
    }

    if let last = lines.last, last.hasPrefix("Script done") {
        lines.removeLast()
    }

    return lines.joined(separator: "\n")
}

func parseAnsiLineToCells(_ line: String) -> [Cell] {
    var cells: [Cell] = []
    var style = Style(fg: defaultFG, bg: nil)

    let chars = Array(line)
    var i = 0

    while i < chars.count {
        if chars[i] == "\u{001B}", i + 1 < chars.count {
            if chars[i + 1] == "[" {
                i += 2
                var codeText = ""

                while i < chars.count {
                    let c = chars[i]
                    if c == "m" || c == "K" {
                        break
                    }

                    codeText.append(c)
                    i += 1
                }

                let final = i < chars.count ? chars[i] : Character("m")
                if i < chars.count {
                    i += 1
                }

                if final != "m" {
                    continue
                }

                let rawCodes = codeText.isEmpty
                    ? [0]
                    : codeText.split(separator: ";").compactMap { Int($0) }

                var idx = 0

                while idx < rawCodes.count {
                    let c = rawCodes[idx]

                    switch c {
                    case 0:
                        style = Style(fg: defaultFG, bg: nil)
                    case 1:
                        style.isBold = true
                    case 3:
                        style.isItalic = true
                    case 4:
                        style.isUnderline = true
                    case 8:
                        style.isHidden = true
                    case 9:
                        style.isStrikethrough = true
                    case 22:
                        style.isBold = false
                    case 23:
                        style.isItalic = false
                    case 24:
                        style.isUnderline = false
                    case 28:
                        style.isHidden = false
                    case 29:
                        style.isStrikethrough = false
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

            if chars[i + 1] == "]" {
                i += 2

                while i < chars.count {
                    if chars[i] == "\u{0007}" {
                        i += 1
                        break
                    }

                    if chars[i] == "\u{001B}", i + 1 < chars.count, chars[i + 1] == "\\" {
                        i += 2
                        break
                    }

                    i += 1
                }

                continue
            }
        }

        let s = String(chars[i])

        if s.unicodeScalars.allSatisfy({ $0.value == 0xFE0F }) {
            i += 1
            continue
        }

        cells.append(Cell(text: s, style: style))
        i += 1
    }

    return cells
}

let raw = try String(contentsOfFile: inputPath, encoding: .utf8)
let normalized = stripScriptHeaderAndFooter(raw)

var lines = normalized.components(separatedBy: "\n")

while lines.last == "" {
    _ = lines.popLast()
}

if lines.isEmpty {
    lines = [""]
}

let parsed = lines.map(parseAnsiLineToCells)
let maxColumns = parsed.map(\.count).max() ?? 0

let imageSize = NSSize(
    width: CGFloat(maxColumns) * charAdvance + padX * 2,
    height: CGFloat(max(1, parsed.count)) * lineHeight + padY * 2
)

let image = NSImage(size: imageSize)

image.lockFocus()

canvasBG.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.lineBreakMode = .byClipping

for (lineIndex, cells) in parsed.enumerated() {
    let y = imageSize.height - padY - CGFloat(lineIndex + 1) * lineHeight + 3

    for (col, cell) in cells.enumerated() {
        let x = padX + CGFloat(col) * charAdvance

        if let bg = cell.style.bg {
            bg.setFill()
            NSBezierPath(
                rect: NSRect(
                    x: x,
                    y: y + CGFloat(lineSpacing),
                    width: charAdvance,
                    height: lineHeight - CGFloat(lineSpacing)
                )
            ).fill()
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: fontForStyle(cell.style),
            .foregroundColor: cell.style.isHidden ? NSColor.clear : cell.style.fg,
            .paragraphStyle: paragraphStyle,
            .kern: 0
        ]

        if cell.style.isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if cell.style.isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        (cell.text as NSString).draw(
            in: NSRect(
                x: x,
                y: y,
                width: charAdvance,
                height: lineHeight
            ),
            withAttributes: attrs
        )
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
SWIFT

echo "PNG: $OUTPUT"
