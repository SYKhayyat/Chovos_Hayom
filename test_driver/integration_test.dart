import 'package:integration_test/integration_test_driver.dart';

/// Pulls the screenshots the harness took off the device and writes them to
/// `build/screenshots/` on the host.
///
/// **Needed because `flutter test` does not do it.** A screenshot taken on a
/// device is base64 in the binding's report data; on Android the Flutter surface
/// has to be converted first, and on every platform the bytes have to come back
/// across the wire. That is what this driver is for, and it is why the harness
/// takes screenshots only when `HARNESS_SHOTS=1` — without this file there is
/// nowhere for them to land, and a harness that silently swallowed them would be
/// worse than one that never took them.
Future<void> main() => integrationDriver();
