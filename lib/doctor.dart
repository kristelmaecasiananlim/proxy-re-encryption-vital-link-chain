import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});
  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  final fileIdController = TextEditingController();
  String result = '';
  bool isLoading = false;

  Future<void> decryptFile() async {
    if (fileIdController.text.isEmpty) {
      setState(() => result = 'Please enter a File ID');
      return;
    }

    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.225.48.203:5000/decrypt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_id': fileIdController.text,
          'api_key': 'my_super_secret_api_key_123',
        }),
      );

      if (response.statusCode == 200) {
        try {
          final decoded = base64Decode(
            json.decode(response.body)['decrypted_data'],
          );
          setState(() => result = utf8.decode(decoded));
        } catch (e) {
          setState(() => result = 'Failed to decode decrypted data.');
        }
      } else {
        setState(() => result = 'Error: ${response.body}');
      }
    } catch (e) {
      setState(() => result = 'An error occurred: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    fileIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Portal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: fileIdController,
              decoration: const InputDecoration(labelText: 'Enter File ID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : decryptFile,
              child: const Text('Request & Decrypt'),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(child: SingleChildScrollView(child: Text(result))),
          ],
        ),
      ),
    );
  }
}
