import 'dart:convert';
import 'package:http/http.dart' as http;

class KeyService {
  static const String baseUrl = 'http://192.168.100.159:5000';

  static Future<Map<String, dynamic>> generateKeys(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate-keys'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to generate keys: ${response.body}');
    }
  }

  static Future<String> getPublicKey(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get-public-key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['public_key'];
    } else {
      throw Exception('Failed to get public key: ${response.body}');
    }
  }
}
