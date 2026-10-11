/// What [DfuTransfer] needs from a connection to the sole's DFU service.
///
/// `BleConnectionService.dfuLink()` provides it over BLE; tests use a fake
/// sole.
abstract interface class DfuLink {
  /// The negotiated ATT MTU. One write carries at most `mtu − 3` bytes.
  int get mtu;

  bool get isConnected;

  /// Enables `control` notifications and returns them as raw packets.
  Future<Stream<List<int>>> subscribeStatus();

  /// Writes a command to `control`, with response.
  Future<void> writeControl(List<int> bytes);

  /// Writes a data packet to `data`, without response.
  Future<void> writeData(List<int> bytes);
}
