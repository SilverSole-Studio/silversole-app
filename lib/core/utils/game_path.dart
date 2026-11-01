/// Whether [next], a page the game web view is about to load, is still the
/// page it was opened with, [opened]: same scheme, host, port and path. A
/// trailing slash does not make a different path, and a change of query or
/// fragment on the same path is allowed (a game may rewrite its own URL).
///
/// A missing [next] or [opened] is allowed: with nothing to compare there is
/// nothing to stop.
bool staysOnGamePath(Uri? opened, Uri? next) {
  if (opened == null || next == null) return true;
  return opened.scheme.toLowerCase() == next.scheme.toLowerCase() &&
      opened.host.toLowerCase() == next.host.toLowerCase() &&
      _port(opened) == _port(next) &&
      _path(opened) == _path(next);
}

String _path(Uri u) {
  final p = u.path.isEmpty ? '/' : u.path;
  return p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}

int _port(Uri u) => u.hasPort
    ? u.port
    : switch (u.scheme.toLowerCase()) {
        'https' => 443,
        'http' => 80,
        _ => 0,
      };
