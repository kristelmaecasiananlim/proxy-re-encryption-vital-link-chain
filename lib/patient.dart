// patient.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'crypto_utils.dart';

class PatientPage extends StatefulWidget {
  final String patientId;
  final String token;

  const PatientPage({super.key, required this.patientId, required this.token});

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
  Map<String, List<String>> accessRequests = {};
  List<String> availableDoctors = ['genine.cabantug', 'kristel.lim'];
  String? selectedDoctor;

  @override
  void initState() {
    super.initState();
    fetchAccessRequests();
  }

  Future<Uint8List> generatePatientFile() async {
    final content =
        '''
PATIENT MEDICAL RECORD
=====================
Name: ${nameController.text}
Date of Birth: ${dobController.text}
Medical History: ${historyController.text}
Current Medications: ${medsController.text}
Record Generated: ${DateTime.now().toString()}
Patient ID: ${widget.patientId}
''';
    return Uint8List.fromList(utf8.encode(content));
  }

  Future<void> uploadEncryptedFile() async {
    if (nameController.text.isEmpty || dobController.text.isEmpty) {
      setState(() => status = 'Name and DOB are required.');
      return;
    }

    if (selectedDoctor == null) {
      setState(() => status = 'Please select a doctor.');
      return;
    }

    final fileBytes = await generatePatientFile();
    final content = utf8.decode(fileBytes);

    // Encrypt the content using our predefined encryption
    final encryptedContent = CryptoUtils.encryptData(content);

    final newFileId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() => status = 'Uploading...');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/encrypt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_id': newFileId,
          'owner': widget.patientId,
          'patient_name': nameController.text,
          'selected_doctor': selectedDoctor,
          'encrypted_data': encryptedContent,
          'public_key': CryptoUtils.publicKey,
          'upload_date': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          fileId = result['file_id'];
          status =
              'Document encrypted & uploaded successfully!\nFile ID: $fileId\nVisible to: Dr. $selectedDoctor';
        });

        // Clear form after successful upload
        nameController.clear();
        dobController.clear();
        historyController.clear();
        medsController.clear();
        selectedDoctor = null;
      } else {
        setState(() => status = 'Upload failed: ${response.body}');
      }
    } catch (e) {
      setState(() => status = 'Upload error: $e');
    }
  }

  Future<void> fetchAccessRequests() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/view-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'owner': widget.patientId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          accessRequests = Map<String, List<String>>.from(
            data.map((k, v) => MapEntry(k, List<String>.from(v))),
          );
        });
      }
    } catch (e) {
      print('Error fetching access requests: $e');
    }
  }

  Future<void> grantAccess(String fileId, String doctor) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/grant-access'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_id': fileId,
          'owner': widget.patientId,
          'doctor': doctor,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access granted to Dr. $doctor')),
        );
        fetchAccessRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error granting access: $e')));
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
      appBar: AppBar(title: Text('Patient Portal - ${widget.patientId}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Medical Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Doctor Selection
              const Text(
                'Select Doctor:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDoctor,
                    hint: const Text('Choose a doctor'),
                    isExpanded: true,
                    onChanged: (value) =>
                        setState(() => selectedDoctor = value),
                    items: availableDoctors.map((doctor) {
                      return DropdownMenuItem(
                        value: doctor,
                        child: Text('Dr. $doctor'),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth *',
                  border: OutlineInputBorder(),
                  hintText: 'MM/DD/YYYY',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: historyController,
                decoration: const InputDecoration(
                  labelText: 'Medical History',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medsController,
                decoration: const InputDecoration(
                  labelText: 'Current Medications',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploadEncryptedFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Encrypt & Upload Document',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              if (status.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status.contains('successfully')
                        ? Colors.green[50]
                        : Colors.red[50],
                    border: Border.all(
                      color: status.contains('successfully')
                          ? Colors.green
                          : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status.contains('successfully')
                          ? Colors.green[800]
                          : Colors.red[800],
                    ),
                  ),
                ),

              const SizedBox(height: 30),
              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Access Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: fetchAccessRequests,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              if (accessRequests.isEmpty)
                const Center(
                  child: Text(
                    'No pending access requests',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              else
                for (final entry in accessRequests.entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File ID: ${entry.key}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final doctor in entry.value)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.person,
                                color: Colors.blue,
                              ),
                              title: Text('Dr. $doctor'),
                              subtitle: const Text(
                                'Requesting access to your medical document',
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => grantAccess(entry.key, doctor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Grant Access'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
