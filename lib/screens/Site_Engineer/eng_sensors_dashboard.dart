import 'package:flutter/material.dart';

import 'package:senior_project/screens/Site_Engineer/lib/screens/Site_Engineer/worker_tracking_api_service.dart';

class EngSensorsDashboard extends StatelessWidget {
  const EngSensorsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WorkerTrackingApiService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("IoT Sensors Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<WorkerSensorReading>>(
        stream: service.streamFirebaseSensorReadings(),
        builder: (context, snapshot) {
          final readings = snapshot.data ?? [];

          if (readings.isEmpty) {
            return const Center(child: Text("No Firebase sensor data found."));
          }

          final latest = readings.first;

          final alertCount = readings.where((r) => r.alert == 1).length;
          final pirCount = readings.where((r) => r.pir == 1).length;
          final waterCount = readings.where((r) => r.water == 1).length;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xff0d1b46),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Latest Firebase Sensor Reading",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latest.timestamp.isEmpty
                          ? "Last saved reading"
                          : latest.timestamp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: sensorCard(
                      title: "Temperature",
                      value: "${latest.temperature.toStringAsFixed(1)}°C",
                      icon: Icons.thermostat,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: sensorCard(
                      title: "Humidity",
                      value: "${latest.humidity.toStringAsFixed(0)}%",
                      icon: Icons.water_drop,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: sensorCard(
                      title: "PIR Motion",
                      value: "$pirCount detected",
                      icon: Icons.motion_photos_on,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: sensorCard(
                      title: "Water Sensor",
                      value: "$waterCount detected",
                      icon: Icons.water,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              sensorCard(
                title: "Safety Alerts",
                value: "$alertCount active",
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                "Firebase Sensor Records",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ...readings.map((reading) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Device: ${reading.id}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text("Temperature: ${reading.temperature}°C"),
                      Text("Humidity: ${reading.humidity}%"),
                      Text("GPS: ${reading.latitude}, ${reading.longitude}"),
                      Text("Alert: ${reading.alert}"),
                      Text("PIR: ${reading.pir}"),
                      Text("Water: ${reading.water}"),
                      Text("Timestamp: ${reading.timestamp}"),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget sensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
