import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/step_detector.dart';

final _origin = DateTime(2026, 11, 2, 9);

/// Contacts starting at [seconds] from the origin, 600 ms each.
List<Contact> _at(List<double> seconds) => [
  for (final s in seconds)
    Contact(
      start: _origin.add(Duration(milliseconds: (s * 1000).round())),
      end: _origin.add(Duration(milliseconds: (s * 1000).round() + 600)),
    ),
];

void main() {
  test('holds four contacts back and releases the fifth with them', () {
    final filter = BoutFilter();
    final contacts = _at([0, 1.1, 2.2, 3.3, 4.4]);

    for (final c in contacts.take(4)) {
      expect(filter.add(c), isEmpty);
    }
    final released = filter.add(contacts[4]);

    expect(released.map((b) => b.contact), contacts);
    expect(released.first.startsBout, isTrue);
    expect(released.first.stride, isNull);
    for (final b in released.skip(1)) {
      expect(b.stride, const Duration(milliseconds: 1100));
      expect(b.swing, const Duration(milliseconds: 500));
    }
  });

  test('once confirmed, each contact goes straight through', () {
    final filter = BoutFilter();
    final contacts = _at([0, 1.1, 2.2, 3.3, 4.4, 5.5]);
    for (final c in contacts.take(5)) {
      filter.add(c);
    }

    final released = filter.add(contacts[5]);

    expect(released, hasLength(1));
    expect(released.single.contact, contacts[5]);
    expect(released.single.stride, const Duration(milliseconds: 1100));
  });

  test('a stride over two seconds ends the bout', () {
    final filter = BoutFilter();
    for (final c in _at([0, 1.1, 2.2, 3.3, 4.4])) {
      filter.add(c);
    }
    // 3.6 s after the last one: a new bout has to build up again.
    final after = _at([8.0, 9.1, 10.2, 11.3, 12.4]);

    for (final c in after.take(4)) {
      expect(filter.add(c), isEmpty);
    }
    final released = filter.add(after[4]);
    expect(released, hasLength(5));
    expect(released.first.startsBout, isTrue);
  });

  test('a sudden change of rhythm ends the bout', () {
    final filter = BoutFilter();
    for (final c in _at([0, 1.0, 2.0, 3.0, 4.0])) {
      filter.add(c);
    }
    // 1.5 s after a 1.0 s stride: 50 %, over the 40 % limit.
    expect(filter.add(_at([5.5]).single), isEmpty);
  });

  test('strides too short to be walking never make a bout', () {
    final filter = BoutFilter();
    for (final c in _at([for (var i = 0; i < 12; i++) i * 0.5])) {
      expect(filter.add(c), isEmpty);
    }
  });
}
