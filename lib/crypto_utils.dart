import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class CryptoUtils {
  static const String publicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwJbF1D3n0E1AmfX2bFHe
4SuKTiVw8B9chDdGW2cqHXqI4obINXaoGlgQObdLpnAM4wHcBCXgjHT1cmu4xMuZ
-----END PUBLIC KEY-----
  ''';

  static const String privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDAlsXUPefQTUCZ
9fZsUd7hK4pOJXDwH1yEN0ZbZyodeojiZsg1dqgaWBA5t0umcAzjAdwEJeCMdPVy
-----END PRIVATE KEY-----
  ''';

  static String encryptData(String data) {
    final key = 'medical_encryption_key_2024';
    final encrypted = <int>[];

    for (int i = 0; i < data.length; i++) {
      encrypted.add(data.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }

    return base64Encode(encrypted);
  }

  static String decryptData(String encryptedData) {
    final key = 'medical_encryption_key_2024';
    final encrypted = base64Decode(encryptedData);
    final decrypted = <int>[];

    for (int i = 0; i < encrypted.length; i++) {
      decrypted.add(encrypted[i] ^ key.codeUnitAt(i % key.length));
    }

    return String.fromCharCodes(decrypted);
  }
}
