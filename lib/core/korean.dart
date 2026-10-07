// 한국어 조사 고르기 (순수 Dart). "성장촉진제을(를)" 같은 어색한 문구 대신 "성장촉진제를"로 보여준다.

/// 마지막 글자에 받침이 있으면 true. 한글이 아니면 null.
bool? hasBatchim(String word) {
  final t = word.trimRight();
  if (t.isEmpty) return null;
  final code = t.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return null;
  return (code - 0xAC00) % 28 != 0;
}

/// [word] 뒤에 알맞은 조사를 붙인다. 예) withJosa('배추', '을', '를') → '배추를', withJosa('물통', '이', '가') → '물통이'
String withJosa(String word, String batchim, String noBatchim) {
  final b = hasBatchim(word);
  if (b == null) return '$word$batchim($noBatchim)';
  return '$word${b ? batchim : noBatchim}';
}
