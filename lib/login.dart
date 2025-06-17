import 'dart:convert';
import 'package:flutter/material.dart';
import 'patient.dart';
import 'doctor.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String role = 'patient';
  String error = '';

  final Map<String, Map<String, String>> predefinedUsers = {
    'doctor': {'genine.cabantug': 'password123', 'kristel.lim': 'password123'},
    'patient': {
      'ram.nacis': 'password123',
      'doane.horlador': 'password123',
      'jhules.maquiran': 'password123',
    },
  };

  Future<void> login() async {
    final username = userController.text.trim().toLowerCase();
    final password = passController.text;

    if (predefinedUsers[role] != null &&
        predefinedUsers[role]!.containsKey(username) &&
        predefinedUsers[role]![username] == password) {
      final token = 'mock_token_for_$username';
      if (role == 'doctor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorPage(doctorId: username, token: token),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PatientPage(patientId: username, token: token),
          ),
        );
      }
    } else {
      setState(() => error = 'Invalid credentials');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Portal Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: role,
              onChanged: (value) => setState(() => role = value!),
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patient')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
              ],
            ),
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text('Login')),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
