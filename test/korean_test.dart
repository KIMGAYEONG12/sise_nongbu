import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/korean.dart';

void main() {
  test('받침에 따라 조사를 고른다', () {
    expect(withJosa('성장촉진제', '을', '를'), '성장촉진제를');
    expect(withJosa('물통', '이', '가'), '물통이');
    expect(withJosa('배추', '을', '를'), '배추를');
    expect(withJosa('양파', '이', '가'), '양파가');
    expect(withJosa('감자', '을', '를'), '감자를');
    expect(withJosa('사과', '을', '를'), '사과를');
    expect(withJosa('희귀 씨앗', '을', '를'), '희귀 씨앗을');
  });
  test('한글이 아니면 둘 다 보여준다', () {
    expect(withJosa('ABC', '을', '를'), 'ABC을(를)');
  });
}
