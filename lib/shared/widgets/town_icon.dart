import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silversole/shared/widgets/town_icons_data.dart';

/// One of the town's hand-drawn icons (brown outline, flat fills), the same
/// art as in the games. Look A uses these where the other looks use Lucide line
/// icons. The names are the keys of [kTownIconPaths].
class TownIcon extends StatelessWidget {
  const TownIcon(this.name, {super.key, this.size = 28});

  final String name;
  final double size;

  static final Map<String, String> _svg = {};

  static String _source(String name) => _svg.putIfAbsent(name, () {
    final body = kTownIconPaths[name];
    assert(body != null, 'no town icon called $name');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<g stroke="#3b3325" stroke-width="2" stroke-linecap="round" '
        'stroke-linejoin="round" fill="none">${body ?? ''}</g></svg>';
  });

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_source(name), width: size, height: size);
}
