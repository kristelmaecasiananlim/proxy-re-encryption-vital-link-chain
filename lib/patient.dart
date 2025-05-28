import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});
  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final historyController = TextEditingController();
  final medsController = TextEditingController();

  String status = '';
  String? fileId;

  Future<Uint8List> generatePatientFile() async {
    final content =
        '''
Name: ${nameController.text}
DOB: ${dobController.text}
Medical History: ${historyController.text}
Medications: ${medsController.text}
''';
    return Uint8List.fromList(utf8.encode(content));
  }

  Future<void> uploadEncryptedFile() async {
    if (nameController.text.isEmpty || dobController.text.isEmpty) {
      setState(() => status = 'Name and DOB are required.');
      return;
    }

    final fileBytes = await generatePatientFile();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.225.48.203:5000/encrypt'),
    );

    final newFileId = DateTime.now().millisecondsSinceEpoch.toString();
    request.fields['file_id'] = newFileId;
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: 'patient.txt'),
    );

    setState(() {
      status = 'Uploading...';
    });

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final result = json.decode(body);
        setState(() {
          fileId = result['file_id'];
          status = 'Encrypted & Uploaded with File ID: $fileId';
        });
      } else {
        setState(() => status = 'Upload failed: $body');
      }
    } catch (e) {
      setState(() => status = 'Upload error: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    historyController.dispose();
    medsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Portal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(labelText: 'Date of Birth'),
              ),
              TextField(
                controller: historyController,
                decoration: const InputDecoration(labelText: 'Medical History'),
                maxLines: 3,
              ),
              TextField(
                controller: medsController,
                decoration: const InputDecoration(
                  labelText: 'Current Medications',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: uploadEncryptedFile,
                child: const Text('Encrypt & Upload'),
              ),
              const SizedBox(height: 20),
              if (status.isNotEmpty) Text(status),
              if (fileId != null)
                SelectableText(
                  'File ID: $fileId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
