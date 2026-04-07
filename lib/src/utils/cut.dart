extension StringCutExtension on String {
  // String ansiCut(
  //   int? maxLength,
  //   Constraints constraints, {
  //   String ellipsis = '…',
  // }) {
  //   assert(maxLength == null || maxLength >= 0);

  //   final parser = ansi.Parser(this);
  //   var newLength = parser.length;
  //   if (maxLength != null && maxLength < newLength) {
  //     newLength = maxLength;
  //   }

  //   newLength = constraints.apply(newLength);
  //   if (newLength >= parser.length) {
  //     return this;
  //   }

  //   if (newLength < ellipsis.length) {
  //     return parser.substring(0, maxLength: newLength);
  //   }

  //   return '${parser.substring(0, maxLength: newLength - ellipsis.length)}'
  //       '$ellipsis';
  // }
}
