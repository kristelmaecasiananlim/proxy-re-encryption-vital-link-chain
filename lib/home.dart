import 'package:flutter/material.dart';
import 'patient.dart';
import 'doctor.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home - Secure Medical App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Patient Portal'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientPage()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Doctor Portal'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
