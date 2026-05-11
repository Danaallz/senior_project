import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("About Us", style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset("assets/Logo_DTPCM.png", height: 90)),
            const SizedBox(height: 25),
            const Text(
              "DTPCM",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xff0d1b46),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Digital Twin System for Predictive Construction Management",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const Text(
              "DTPCM is a smart construction management system designed to improve project monitoring, safety, and decision-making through digital twin technology, IoT sensor data, and AI-based prediction.",
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 18),
            const Text(
              "Our system helps project owners, managers, and site engineers monitor project progress, track resources, receive alerts, and make proactive decisions before risks become serious problems.",
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 30),
            const Text(
              "Key Features",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            featureItem(Icons.analytics_outlined, "Project progress tracking"),
            featureItem(Icons.sensors_outlined, "IoT-based site monitoring"),
            featureItem(Icons.warning_amber_outlined, "Risk and safety alerts"),
            featureItem(
              Icons.view_in_ar_outlined,
              "Digital twin visualization",
            ),
            featureItem(
              Icons.smart_toy_outlined,
              "AI-based prediction support",
            ),
            const SizedBox(height: 30),
            const Text(
              "Senior Project 2025–2026",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: Color(0xff0d1b46)),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
