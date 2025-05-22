import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class EncryptionService {
  static const String baseUrl = 'http://192.168.1.6:5000';

  static Future<String> encryptAndUpload(File file, String fileId) async {
    var request = http.MultipartRequest("POST", Uri.parse('$baseUrl/encrypt'));
    request.fields['file_id'] = fileId;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var response = await request.send();

    if (response.statusCode == 200) {
      final resp = await http.Response.fromStream(response);
      return jsonDecode(resp.body)['ipfs_hash'];
    } else {
      throw Exception('Encryption failed');
    }
  }

  static Future<String> decrypt(String base64Data, String fileId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/decrypt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'encrypted_data': base64Data, 'file_id': fileId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['decrypted_data'];
    } else {
      throw Exception('Decryption failed');
    }
  }
}
