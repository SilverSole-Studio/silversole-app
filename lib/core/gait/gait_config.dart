/// Every threshold in the gait pipeline, in one place.
///
/// Each one is a starting value, not a derived one: they are tuned against
/// real recordings (`tool/gait_replay.dart`, design §7.2). Durations rather
/// than sample counts throughout, because the live notify rate is not pinned
/// down (20 Hz and 50 Hz both appear in the code) and the timing comes from
/// the phone clock anyway.
class GaitConfig {
  const GaitConfig({
    this.window = const Duration(seconds: 5),
    this.onFraction = 0.6,
    this.offFraction = 0.4,
    this.minLoadRange = 200,
    this.minContact = const Duration(milliseconds: 200),
    this.maxContact = const Duration(seconds: 2),
    this.maxSampleGap = const Duration(milliseconds: 500),
    this.minStride = const Duration(milliseconds: 700),
    this.maxStride = const Duration(seconds: 2),
    this.maxStrideChange = 0.4,
    this.minBoutContacts = 5,
    this.otherFootActive = const Duration(seconds: 3),
  }) : assert(minBoutContacts >= 2, 'a bout needs at least two contacts'),
       assert(offFraction < onFraction, 'off threshold must sit below on');

  // Duration comparisons are not constant expressions, so the checks on
  // [minContact]/[maxContact] and [minStride]/[maxStride] live in the
  // constructors of the classes that use them (StepDetector, BoutFilter).

  /// How far back the detector looks for the foot's low and high load.
  final Duration window;

  /// Where between that low and high a contact starts and ends. The gap
  /// between them is the hysteresis that stops noise near one line from
  /// counting twice.
  final double onFraction;
  final double offFraction;

  /// Below this spread (raw FSR counts summed over the three sensors) the
  /// sole is not being stepped on and off — standing still, sitting, not
  /// worn — and nothing is reported.
  final int minLoadRange;

  /// Contacts outside this range are not steps.
  final Duration minContact;
  final Duration maxContact;

  /// A longer silence (link loss, dropped packets) resets the detector.
  final Duration maxSampleGap;

  /// Heel strike to heel strike of the same foot, for a contact to continue
  /// a bout. A stride over [maxStride] also ends the bout.
  final Duration minStride;
  final Duration maxStride;

  /// Largest change between consecutive strides, as a fraction of the
  /// earlier one, for the walk to count as continuous.
  final double maxStrideChange;

  /// Contacts from one foot before a bout counts as walking: five landings
  /// of one foot is about ten steps.
  final int minBoutContacts;

  /// How recently another sole must have registered a contact for both feet
  /// to count as walking together.
  final Duration otherFootActive;
}
