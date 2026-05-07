import 'package:flutter/material.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  Widget alertCard({
    required String title,
    required String message,
    required Color titleColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          "Alerts",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 16),
        child: ListView(
          children: [
            alertCard(
              title: "Warning!",
              titleColor: Colors.orange,
              message:
                  "Electrician is facing delays risk due to lack in materials",
            ),
            alertCard(
              title: "Warning!",
              titleColor: Colors.orange,
              message: "Sensors are detecting low fuel on Lifter #1234567",
            ),
            alertCard(
              title: "Good News!",
              titleColor: Colors.green,
              message: "Wiring has start on its planed starting date",
            ),
          ],
        ),
      ),
    );
  }
}
