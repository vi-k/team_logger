import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

/// Compiles inline BBCode (`[b]...[/b]`, `[success]...[/success]`) into
/// ANSI escape codes using the theme's message styles.
///
/// Properly nested tags, including identical tags, are supported. Unknown,
/// unclosed, and mismatched tag tokens are left as-is.
///
/// ESC is not escaped here: by the time this runs the safe mode has taken
/// the control sequences out of the text (`LoggableConfig.escapeAnsiCodes`,
/// on by default). See "Untrusted Text and Terminal Output" in the README.
final class BbCodeFormatter with Loggable implements LogPreFormatter {
  const BbCodeFormatter();

  @override
  String call(LogTheme theme, String text) {
    final tags = {
      ...theme.data.messageStyles.keys,
      ...theme.main.messageStyles.keys,
    };
    // With no styles there are no tags to recognize.
    if (tags.isEmpty) return text;

    final tagTokens = [for (final tag in tags) _BbCodeTagToken(tag)];
    final root = <_BbCodePart>[];
    final openTags = <_BbCodeTag>[];

    List<_BbCodePart> currentParts() =>
        openTags.isEmpty ? root : openTags.last.children;

    void addText(String value) {
      if (value.isEmpty) return;

      final parts = currentParts();
      if (parts.isNotEmpty && parts.last is _BbCodeText) {
        final text = parts.last as _BbCodeText;
        text.value.write(value);
      } else {
        parts.add(_BbCodeText(value));
      }
    }

    var offset = 0;
    while (offset < text.length) {
      final openingBracket = text.indexOf('[', offset);
      if (openingBracket < 0) {
        addText(text.substring(offset));
        break;
      }

      addText(text.substring(offset, openingBracket));

      _BbCodeTagToken? openingTag;
      for (final tag in tagTokens) {
        if (text.startsWith(tag.openingToken, openingBracket)) {
          openingTag = tag;
          break;
        }
      }

      if (openingTag != null) {
        final tag = _BbCodeTag(openingTag.name, openingTag.openingToken);
        currentParts().add(tag);
        openTags.add(tag);
        offset = openingBracket + openingTag.openingToken.length;
        continue;
      }

      _BbCodeTagToken? closingTag;
      for (final tag in tagTokens) {
        if (text.startsWith(tag.closingToken, openingBracket)) {
          closingTag = tag;
          break;
        }
      }

      if (closingTag == null) {
        addText('[');
        offset = openingBracket + 1;
        continue;
      }

      if (openTags.isNotEmpty && openTags.last.name == closingTag.name) {
        openTags.removeLast().closingToken = closingTag.closingToken;
      } else {
        addText(closingTag.closingToken);
      }

      offset = openingBracket + closingTag.closingToken.length;
    }

    return _render(theme, root);
  }

  String _render(LogTheme theme, List<_BbCodePart> parts) {
    final result = StringBuffer();
    final cursors = [_BbCodeRenderCursor(parts, result)];

    while (cursors.isNotEmpty) {
      final cursor = cursors.last;
      if (cursor.index == cursor.parts.length) {
        cursors.removeLast();

        final tag = cursor.tag;
        if (tag != null) {
          final style = theme.messageStyle(tag.name);
          final content = cursor.output.toString();
          if (style == null) {
            cursor.parentOutput!
              ..write(tag.openingToken)
              ..write(content)
              ..write(tag.closingToken);
          } else {
            cursor.parentOutput!.write(style(content));
          }
        }
        continue;
      }

      final part = cursor.parts[cursor.index++];
      switch (part) {
        case _BbCodeText(:final value):
          cursor.output.write(value);
        case _BbCodeTag() when !part.isClosed:
          cursor.output.write(part.openingToken);
          cursors.add(_BbCodeRenderCursor(part.children, cursor.output));
        case _BbCodeTag():
          cursors.add(
            _BbCodeRenderCursor(
              part.children,
              StringBuffer(),
              tag: part,
              parentOutput: cursor.output,
            ),
          );
      }
    }

    return result.toString();
  }

  @override
  void collectLoggableData(LoggableData data) {}
}

sealed class _BbCodePart {}

final class _BbCodeText implements _BbCodePart {
  final StringBuffer value = StringBuffer();

  _BbCodeText(String value) {
    this.value.write(value);
  }
}

final class _BbCodeTagToken {
  final String name;
  final String openingToken;
  final String closingToken;

  _BbCodeTagToken(this.name)
      : openingToken = '[$name]',
        closingToken = '[/$name]';
}

final class _BbCodeTag implements _BbCodePart {
  final String name;
  final String openingToken;
  final List<_BbCodePart> children = [];
  String? closingToken;

  _BbCodeTag(this.name, this.openingToken);

  bool get isClosed => closingToken != null;
}

final class _BbCodeRenderCursor {
  final List<_BbCodePart> parts;
  final StringBuffer output;
  final _BbCodeTag? tag;
  final StringBuffer? parentOutput;
  int index = 0;

  _BbCodeRenderCursor(
    this.parts,
    this.output, {
    this.tag,
    this.parentOutput,
  });
}
