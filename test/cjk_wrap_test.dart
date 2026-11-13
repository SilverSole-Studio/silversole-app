import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-13：中文標題最後一個字不要單獨掉到下一行（strings.csv 在最後兩字之間放 U+2060 WORD JOINER）。
void main() {
  List<String> linesOf(String text, double width) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final lines = <String>[];
    var start = 0;
    for (final m in tp.computeLineMetrics()) {
      final end = tp.getLineBoundary(TextPosition(offset: start)).end;
      lines.add(text.substring(start, end));
      start = end;
      if (lines.length > m.lineNumber + 5) break;
    }
    return lines;
  }

  test('最後一個字不會自己一行', () {
    const s = '尚未做過足部健⁠檢';
    final l = linesOf(s, 20.0 * 7 + 1); // 一行剛好放得下 7 個字
    expect(l.length, 2);
    expect(l.last.replaceAll('⁠', '').length, greaterThanOrEqualTo(2));
  });
}
