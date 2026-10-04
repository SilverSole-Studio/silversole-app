/// Corrects the FSR channel order coming off the sole.
///
/// **This is a hardware workaround, not a feature.** On the current dev board
/// the heel and big-toe-ball sensors are soldered to each other's pads, so the
/// heel's reading arrives in the slot the app reads as the big-toe ball and
/// vice versa. Everything downstream — the heat map's sensor anchors, the
/// readouts, the chart channels — assumes the documented order:
///
///   index 0 -> 大拇趾球 (hallux / big-toe ball)
///   index 1 -> 小拇趾   (little toe)
///   index 2 -> 腳跟     (heel)
///
/// so the swap happens once, where packets are decoded, rather than in each
/// consumer. Set [swapHeelAndHallux] to false (and delete this file) once a
/// board with the pads the right way round is in use.
library;

/// Whether the board in use has the two pads swapped.
const swapHeelAndHallux = true;

/// Returns [pressure] with the heel and big-toe-ball readings put back in their
/// documented slots.
///
/// Leaves anything that is not a full three-sensor reading alone: a short
/// payload is already broken and silently reordering it would only confuse the
/// next person reading a chart.
List<int> fixPressureChannels(List<int> pressure) {
  if (!swapHeelAndHallux || pressure.length < 3) return pressure;
  return [pressure[2], pressure[1], pressure[0], ...pressure.skip(3)];
}
