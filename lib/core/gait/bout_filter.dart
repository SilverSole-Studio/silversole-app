import 'package:silversole/core/gait/gait_config.dart';
import 'package:silversole/core/gait/step_detector.dart';

/// A contact that belongs to a walking bout, with its timing relative to the
/// previous contact of the same foot in that bout.
class BoutContact {
  const BoutContact({required this.contact, this.stride, this.swing});

  final Contact contact;

  /// Heel strike to heel strike from the previous contact; null on the first
  /// contact of a bout.
  final Duration? stride;

  /// Lift-off of the previous contact to this heel strike; null on the first
  /// contact of a bout.
  final Duration? swing;

  bool get startsBout => stride == null;
}

/// Lets through only the contacts of one foot that are part of continuous
/// walking.
///
/// A bout needs [GaitConfig.minBoutContacts] contacts in a row with every
/// stride inside [GaitConfig.minStride]–[GaitConfig.maxStride] and no stride
/// changing by more than [GaitConfig.maxStrideChange]. Contacts are held back
/// until the bout is confirmed, then released together; one that breaks the
/// rhythm starts a new candidate bout. Fidgeting while seated, shifting
/// weight while standing and a few odd steps therefore count for nothing.
class BoutFilter {
  BoutFilter([this.config = const GaitConfig()]);

  final GaitConfig config;

  /// The candidate bout while unconfirmed; once confirmed, only the last two
  /// contacts, which is all the rhythm check needs.
  final _held = <Contact>[];
  bool _confirmed = false;

  /// Feeds one contact; returns the contacts it lets through — none while the
  /// bout is unconfirmed, the whole backlog the moment it is confirmed.
  List<BoutContact> add(Contact contact) {
    if (_held.isNotEmpty && !_continues(contact)) {
      _held.clear();
      _confirmed = false;
    }
    _held.add(contact);

    if (_confirmed) {
      final released = _link(_held.length - 1);
      if (_held.length > 2) _held.removeRange(0, _held.length - 2);
      return [released];
    }
    if (_held.length < config.minBoutContacts) return const [];

    _confirmed = true;
    final released = [for (var i = 0; i < _held.length; i++) _link(i)];
    _held.removeRange(0, _held.length - 2);
    return released;
  }

  bool _continues(Contact contact) {
    final previous = _held.last;
    final stride = contact.start.difference(previous.start);
    if (stride < config.minStride || stride > config.maxStride) return false;
    if (_held.length < 2) return true;
    final before = previous.start.difference(_held[_held.length - 2].start);
    final change =
        (stride - before).inMicroseconds.abs() / before.inMicroseconds;
    return change <= config.maxStrideChange;
  }

  BoutContact _link(int i) {
    final contact = _held[i];
    // Index 0 of the held list is a bout's first contact only while the bout
    // is unconfirmed; afterwards _link is only ever called on the last index.
    if (i == 0) return BoutContact(contact: contact);
    final previous = _held[i - 1];
    return BoutContact(
      contact: contact,
      stride: contact.start.difference(previous.start),
      swing: contact.start.difference(previous.end),
    );
  }
}
