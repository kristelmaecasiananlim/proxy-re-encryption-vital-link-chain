import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pdf/widgets.dart' as pw;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pinata IPFS Upload',
    theme: ThemeData(primarySwatch: Colors.blue),
    home: const CertificatePage(),
  );
}

class CertificatePage extends StatefulWidget {
  const CertificatePage();
  @override
  _CertificatePageState createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  final _formKey = GlobalKey<FormState>();
  final _diagCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = '';

  @override
  void dispose() {
    _diagCtrl.dispose();
    _docCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Generate PDF in-memory
  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Diagnosis: ${_diagCtrl.text}'),
                pw.SizedBox(height: 8),
                pw.Text('Doctor: ${_docCtrl.text}'),
                pw.SizedBox(height: 8),
                pw.Text('Date: ${_dateCtrl.text}'),
                pw.SizedBox(height: 8),
                pw.Text('Notes: ${_notesCtrl.text}'),
              ],
            ),
      ),
    );
    return pdf.save();
  }

  /// Encrypt PDF using Flask API
  Future<Uint8List?> _encryptPdf(Uint8List originalBytes) async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/encrypt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'file_name': 'certificate.pdf',
        'file_data': base64Encode(originalBytes),
      }),
    );

    if (response.statusCode == 200) {
      final encryptedBase64 = jsonDecode(response.body)['encrypted'];
      return base64Decode(encryptedBase64);
    } else {
      setState(() => _status = 'Encryption failed: ${response.body}');
      return null;
    }
  }

  /// Upload to Pinata
  Future<String> _uploadToPinata(Uint8List bytes) async {
    const apiKey = 'f9fb7f2c754da8fc8513';
    const apiSecret =
        'c3a4453ffc9f1c52ea3d87fb0048aec08d16ce056967c52a3ffbf34177532808';
    final uri = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');

    final req =
        http.MultipartRequest('POST', uri)
          ..headers.addAll({
            'pinata_api_key': apiKey,
            'pinata_secret_api_key': apiSecret,
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: 'certificate_encrypted.pdf',
              contentType: MediaType('application', 'pdf'),
            ),
          );

    final res = await req.send();
    final body = await http.Response.fromStream(res);
    if (res.statusCode == 200) {
      final data = jsonDecode(body.body);
      return data['IpfsHash'] as String;
    }
    throw Exception('Pinata upload failed: ${res.statusCode}\n${body.body}');
  }

  /// Full process: Generate → Encrypt → Upload
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _status = 'Generating PDF…');
    Uint8List pdfBytes;
    try {
      pdfBytes = await _generatePdfBytes();
    } catch (e) {
      setState(() => _status = 'PDF generation failed: $e');
      return;
    }

    setState(() => _status = 'Encrypting PDF…');
    Uint8List? encryptedBytes;
    try {
      encryptedBytes = await _encryptPdf(pdfBytes);
      if (encryptedBytes == null) return;
    } catch (e) {
      setState(() => _status = 'Encryption failed: $e');
      return;
    }

    setState(() => _status = 'Uploading to IPFS via Pinata…');
    try {
      final cid = await _uploadToPinata(encryptedBytes);
      setState(
        () =>
            _status =
                '✅ Uploaded!\nCID: $cid\n\nView: https://gateway.pinata.cloud/ipfs/$cid',
      );
    } catch (e) {
      setState(() => _status = 'Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Document → IPFS')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _diagCtrl,
                      decoration: const InputDecoration(labelText: 'Diagnosis'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _docCtrl,
                      decoration: const InputDecoration(labelText: 'Doctor'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _dateCtrl,
                      decoration: const InputDecoration(labelText: 'Date'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Generate & Upload'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
