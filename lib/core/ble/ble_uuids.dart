const serviceUuid = '83BFF893-8E7C-4530-9BB8-18EBA983E660';
const notifyCharUuid = 'B8863299-8492-4C76-ACF4-514965B1A747';
const baseTimestampCharUuid = '3B3D5734-1E0A-4F5B-9C3A-6F7A0B62B901';
const deviceStatusCharUuid = '5DA3F2A1-7F67-43BB-8AA5-63D0B3B8D162';
const recordRequestCharUuid = '1369A5E5-7B2A-4FA0-8C80-3670FB05F278';
const recordNotifyCharUuid = '0A7EA8DD-87A6-4794-ADEF-5D609D9A75F3';
const fallDetectCharUuid = 'AC89603B-7273-486A-8B17-33E543D50E1B';

// Bluetooth SIG Device Information Service. Its Serial Number String carries
// the sole's chip ID — the same 16 hex characters the advertisement does.
const deviceInfoServiceUuid = '180A';
const serialNumberCharUuid = '2A25';

// SilverSole DFU service: OTA protocol v2, the firmware repo's
// docs/ota-ble-protocol.md. All four share one 128-bit base.
const dfuServiceUuid = '01E00001-71D9-44B3-840E-7F6C6478CC8C';
const dfuControlCharUuid = '01E00002-71D9-44B3-840E-7F6C6478CC8C';
const dfuDataCharUuid = '01E00003-71D9-44B3-840E-7F6C6478CC8C';
const dfuVersionCharUuid = '01E00004-71D9-44B3-840E-7F6C6478CC8C';
