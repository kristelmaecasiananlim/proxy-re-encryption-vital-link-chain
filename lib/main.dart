import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Umbral Web App',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final diagnosisController = TextEditingController();
  final doctorController = TextEditingController();
  final notesController = TextEditingController();

  String statusMessage = '';
  String? ipfsHash;
  String? decryptedText;

  final http.Client _client = http.Client();

  static const backendBaseUrl =
      'http://10.225.51.70:5000'; // Replace with your Flask IP
  static const apiKey = 'my_super_secret_api_key_123'; // Must match Flask

  @override
  void dispose() {
    diagnosisController.dispose();
    doctorController.dispose();
    notesController.dispose();
    _client.close();
    super.dispose();
  }

  Future<Uint8List> generatePlainTextFile(
    String diagnosis,
    String doctor,
    String notes,
  ) async {
    final content = 'Diagnosis: $diagnosis\nDoctor: $doctor\nNotes: $notes';
    return Uint8List.fromList(utf8.encode(content));
  }

  Future<Map<String, dynamic>> encryptData(Uint8List textBytes) async {
    final url = Uri.parse('$backendBaseUrl/encrypt');
    final request = http.MultipartRequest('POST', url)
      ..fields['file_id'] = DateTime.now().millisecondsSinceEpoch.toString()
      ..files.add(
        http.MultipartFile.fromBytes('file', textBytes, filename: 'record.txt'),
      );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Encrypt failed: $responseBody');
    }
  }

  Future<String> uploadToPinata(String encryptedData) async {
    final url = Uri.parse('$backendBaseUrl/upload_to_pinata');
    final resp = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'file_data': encryptedData,
        'file_name': 'encrypted.umbral',
      }),
    );
    if (resp.statusCode == 200) {
      final jsonResp = json.decode(resp.body);
      return jsonResp['ipfs_hash'];
    } else {
      throw Exception('Pinata upload failed: ${resp.body}');
    }
  }

  Future<Uint8List> downloadEncryptedFile(String hash) async {
    final gateways = [
      'https://ipfs.io/ipfs/',
      'https://gateway.pinata.cloud/ipfs/',
    ];
    for (final gw in gateways) {
      try {
        final r = await _client
            .get(Uri.parse('$gw$hash'))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) return r.bodyBytes;
      } catch (_) {}
    }
    throw Exception('All IPFS gateways failed');
  }

  Future<Uint8List> decryptEncryptedData(Uint8List encryptedBytes) async {
    final url = Uri.parse('$backendBaseUrl/decrypt');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'encrypted_data': base64Encode(encryptedBytes),
        'file_id': 'some_unique_id',
        'api_key': apiKey,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResp = json.decode(response.body);
      return base64Decode(jsonResp['decrypted_data']);
    } else {
      throw Exception('Decryption failed: ${response.body}');
    }
  }

  Future<void> handleGenerateAndUpload() async {
    if (diagnosisController.text.isEmpty ||
        doctorController.text.isEmpty ||
        notesController.text.isEmpty) {
      setState(() => statusMessage = 'Please fill out all fields.');
      return;
    }

    try {
      setState(() {
        statusMessage = 'Generating text...';
        decryptedText = null;
      });

      final textBytes = await generatePlainTextFile(
        diagnosisController.text,
        doctorController.text,
        notesController.text,
      );

      setState(() => statusMessage = 'Encrypting...');
      final result = await encryptData(textBytes);

      setState(() => statusMessage = 'Uploading to IPFS...');
      ipfsHash = await uploadToPinata(result['encrypted']);

      setState(() {
        statusMessage = 'Upload complete. IPFS Hash:\n$ipfsHash';
        diagnosisController.clear();
        doctorController.clear();
        notesController.clear();
      });
    } catch (e) {
      setState(() => statusMessage = 'Error: $e');
    }
  }

  Future<void> handleDownloadAndDisplay() async {
    if (ipfsHash == null) {
      setState(() => statusMessage = 'No IPFS hash available.');
      return;
    }
    try {
      setState(() {
        statusMessage = 'Downloading encrypted file...';
        decryptedText = null;
      });

      final encryptedData = await downloadEncryptedFile(ipfsHash!);

      setState(() => statusMessage = 'Decrypting...');
      final decrypted = await decryptEncryptedData(encryptedData);

      setState(() {
        decryptedText = utf8.decode(decrypted);
        statusMessage = 'Decryption complete.';
      });
    } catch (e) {
      setState(() => statusMessage = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Umbral Web')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: diagnosisController,
                decoration: const InputDecoration(labelText: 'Diagnosis'),
              ),
              TextField(
                controller: doctorController,
                decoration: const InputDecoration(labelText: 'Doctor'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: handleGenerateAndUpload,
                child: const Text('Generate & Upload'),
              ),
              const SizedBox(height: 20),
              if (ipfsHash != null)
                ElevatedButton(
                  onPressed: handleDownloadAndDisplay,
                  child: const Text('Decrypt & Show Info'),
                ),
              const SizedBox(height: 20),
              Text(statusMessage),
              const SizedBox(height: 20),
              if (decryptedText != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Decrypted Content:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(decryptedText!),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
