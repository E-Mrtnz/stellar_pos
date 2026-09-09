import 'dart:math';

/// Generates IDs that are safe to create independently on multiple devices.
/// UUID v4 format avoids collisions without requiring a network round-trip.
class IdGenerator {
  IdGenerator._();

  static final Random _random = Random.secure();
  static const String _hex = '0123456789abcdef';

  static String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(_hex[(bytes[i] >> 4) & 0x0f]);
      buffer.write(_hex[bytes[i] & 0x0f]);
    }
    return buffer.toString();
  }
}
