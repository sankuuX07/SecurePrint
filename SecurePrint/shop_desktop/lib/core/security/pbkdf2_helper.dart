import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Cryptographically secure password hashing helper implementing
/// PBKDF2 with HMAC-SHA256 according to RFC 2898 / PKCS #5 v2.0.
class Pbkdf2Helper {
  static const int defaultIterations = 100000;
  static const int defaultSaltBytes = 16;
  static const int defaultKeyLength = 32;

  /// Hashes a plaintext password using PBKDF2-HMAC-SHA256 with a secure random salt.
  /// Format: `pbkdf2_sha256$<iterations>$<base64_salt>$<base64_hash>`
  static String hashPassword(
    String password, {
    Uint8List? customSalt,
    int iterations = defaultIterations,
    int keyLength = defaultKeyLength,
  }) {
    final salt = customSalt ?? generateSecureSalt(defaultSaltBytes);
    final passwordBytes = utf8.encode(password);
    final derivedKey = pbkdf2(
      password: passwordBytes,
      salt: salt,
      iterations: iterations,
      keyLength: keyLength,
    );

    final saltB64 = base64.encode(salt);
    final hashB64 = base64.encode(derivedKey);
    return 'pbkdf2_sha256\$$iterations\$$saltB64\$$hashB64';
  }

  /// Verifies a plaintext password against a stored PBKDF2 hash.
  /// Uses constant-time comparison to prevent timing attacks.
  static bool verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split('\$');
      if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') {
        return false;
      }

      final iterations = int.parse(parts[1]);
      final salt = base64.decode(parts[2]);
      final expectedHash = base64.decode(parts[3]);

      final computedKey = pbkdf2(
        password: utf8.encode(password),
        salt: salt,
        iterations: iterations,
        keyLength: expectedHash.length,
      );

      return constantTimeEquals(computedKey, expectedHash);
    } catch (_) {
      return false;
    }
  }

  /// Generates cryptographically secure random bytes for salting.
  static Uint8List generateSecureSalt(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  /// Standard RFC 2898 PBKDF2 with PRF = HMAC-SHA256.
  static Uint8List pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    if (iterations < 1) {
      throw ArgumentError('Iterations must be at least 1');
    }
    if (keyLength < 1) {
      throw ArgumentError('Key length must be at least 1');
    }

    final hmac = Hmac(sha256, password);
    final hLen = 32; // SHA-256 output length in bytes
    final numBlocks = (keyLength + hLen - 1) ~/ hLen;
    final result = BytesBuilder(copy: false);

    for (int block = 1; block <= numBlocks; block++) {
      // U_1 = PRF(password, salt || INT_32_BE(block))
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      final initialData = <int>[...salt, ...blockBytes.buffer.asUint8List()];
      List<int> u = hmac.convert(initialData).bytes;
      final t = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < hLen; j++) {
          t[j] ^= u[j];
        }
      }

      result.add(t);
    }

    final fullBytes = result.takeBytes();
    return fullBytes.sublist(0, keyLength);
  }

  /// Constant-time byte-by-byte comparison to prevent timing attacks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
