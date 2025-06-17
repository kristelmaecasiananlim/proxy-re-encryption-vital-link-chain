// doctor.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'crypto_utils.dart';

class DoctorPage extends StatefulWidget {
  final String doctorId;
  final String token;

  const DoctorPage({super.key, required this.doctorId, required this.token});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage>
    with SingleTickerProviderStateMixin {
  String result = '';
  bool isLoading = false;
  List<Map<String, dynamic>> availableDocuments = [];
  int selectedTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchAvailableDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAvailableDocuments() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/doctor-documents'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'doctor_id': widget.doctorId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          availableDocuments = List<Map<String, dynamic>>.from(
            data['documents'] ?? [],
          );
        });
      }
    } catch (e) {
      setState(() => result = 'Error fetching documents: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> requestAccess(String fileId, String patientName) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/request-access'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_id': fileId,
          'doctor': widget.doctorId,
          'patient_name': patientName,
        }),
      );

      setState(() {
        if (response.statusCode == 200) {
          result = 'Access requested for $patientName\'s document';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access requested successfully')),
          );
        } else {
          result = 'Failed to request access: ${response.body}';
        }
      });
    } catch (e) {
      setState(() => result = 'Error requesting access: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> decryptFile(String fileId) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.159:5000/decrypt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_id': fileId,
          'requester': widget.doctorId,
          'api_key': 'my_super_secret_api_key_123',
          'private_key': CryptoUtils.privateKey,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final encryptedData = responseData['encrypted_data'];

        final decryptedContent = CryptoUtils.decryptData(encryptedData);
        setState(() => result = decryptedContent);
      } else if (response.statusCode == 403) {
        setState(
          () => result =
              'Access denied. Request access first or wait for approval.',
        );
      } else {
        setState(() => result = 'Error: ${response.body}');
      }
    } catch (e) {
      setState(() => result = 'Decryption error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorId}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available Documents'),
            Tab(text: 'Decrypt Document'),
          ],
          onTap: (index) => setState(() => selectedTabIndex = index),
        ),
      ),
      body: IndexedStack(
        index: selectedTabIndex,
        children: [
          // Available Documents Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Patient Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: fetchAvailableDocuments,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (availableDocuments.isEmpty)
                  const Center(
                    child: Text(
                      'No documents available.\nPatients need to select you as their doctor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableDocuments.length,
                      itemBuilder: (context, index) {
                        final doc = availableDocuments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.medical_information,
                              color: Colors.blue,
                            ),
                            title: Text('${doc['patient_name']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Medical Information'),
                                Text(
                                  'Uploaded: ${doc['upload_date'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Status: ${doc['access_status'] ?? 'Pending'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: doc['access_status'] == 'Granted'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (doc['access_status'] != 'Granted')
                                  ElevatedButton(
                                    onPressed: () => requestAccess(
                                      doc['file_id'],
                                      doc['patient_name'],
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                    ),
                                    child: const Text('Request Access'),
                                  ),
                                if (doc['access_status'] == 'Granted')
                                  ElevatedButton(
                                    onPressed: () =>
                                        decryptFile(doc['file_id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('View Document'),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Decrypt Document Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Document Content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (result.isEmpty)
                  const Center(
                    child: Text(
                      'Select a document from the Available Documents tab to view its content.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          result,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
