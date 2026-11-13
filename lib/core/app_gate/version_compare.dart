/// Compares dotted versions such as `1.13.4` and `1.14.0`.
///
/// Missing parts count as 0. A `-rc.N` style suffix and a `+build` suffix are
/// ignored, so `1.14.0-rc.2+7` equals `1.14.0`. Returns a negative number when
/// [a] is older than [b], 0 when equal, positive when newer. Parts that are not
/// numbers count as 0.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

List<int> _parts(String v) {
  var s = v.trim();
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  final dash = s.indexOf('-');
  if (dash >= 0) s = s.substring(0, dash);
  if (s.isEmpty) return const [0];
  return s.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
}
