import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:senior_project/screens/Site_Engineer/lib/screens/Site_Engineer/worker_tracking_api_service.dart';

class EngEnvironmentPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EngEnvironmentPage({super.key, required this.project});

  @override
  State<EngEnvironmentPage> createState() => _EngEnvironmentPageState();
}

class _EngEnvironmentPageState extends State<EngEnvironmentPage> {
  final WorkerTrackingApiService trackingService = WorkerTrackingApiService();

  bool isLoadingApi = true;

  double apiTemperature = 0;
  double apiHumidity = 0;
  double apiWind = 0;
  double apiRain = 0;

  double get latitude {
    return double.tryParse(widget.project['latitude']?.toString() ?? '') ??
        21.543333;
  }

  double get longitude {
    return double.tryParse(widget.project['longitude']?.toString() ?? '') ??
        39.172779;
  }

  @override
  void initState() {
    super.initState();
    loadWeatherApi();
  }

  Future<void> loadWeatherApi() async {
    setState(() => isLoadingApi = true);

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception("Weather API failed");
      }

      final decoded = jsonDecode(response.body);
      final current = decoded['current'];

      if (!mounted) return;

      setState(() {
        apiTemperature = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
        apiHumidity =
            (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0;
        apiWind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
        apiRain = (current['rain'] as num?)?.toDouble() ?? 0;
        isLoadingApi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingApi = false);
    }
  }

  String riskLabel({
    required double firebaseTemp,
    required double firebaseHumidity,
  }) {
    if (firebaseTemp >= 42 || apiWind >= 35 || apiRain > 0) {
      return "High Risk";
    }

    if (firebaseTemp >= 36 || firebaseHumidity >= 80) {
      return "Needs Attention";
    }

    return "Normal";
  }

  Color riskColor(String risk) {
    if (risk == "High Risk") return Colors.red;
    if (risk == "Needs Attention") return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        title: const Text("Environment Monitoring"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadWeatherApi,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<WorkerSensorReading>>(
        stream: trackingService.streamFirebaseSensorReadings(),
        builder: (context, snapshot) {
          final readings = snapshot.data ?? [];

          if (readings.isEmpty) {
            return const Center(
              child: Text("No Firebase environment data found."),
            );
          }

          final latest = readings.first;

          final risk = riskLabel(
            firebaseTemp: latest.temperature,
            firebaseHumidity: latest.humidity,
          );

          final color = riskColor(risk);

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xff0d1b46), color.withOpacity(0.85)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Environment Comparison",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      risk,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      latest.timestamp.isEmpty
                          ? "Firebase latest saved reading + Weather API"
                          : "Firebase: ${latest.timestamp}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                "Firebase Site Sensor Data",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: envCard(
                      title: "Site Temperature",
                      value: "${latest.temperature.toStringAsFixed(1)}°C",
                      icon: Icons.thermostat,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: envCard(
                      title: "Site Humidity",
                      value: "${latest.humidity.toStringAsFixed(0)}%",
                      icon: Icons.water_drop,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                "Weather API Data",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: envCard(
                      title: "API Temperature",
                      value:
                          isLoadingApi
                              ? "Loading"
                              : "${apiTemperature.toStringAsFixed(1)}°C",
                      icon: Icons.sunny,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: envCard(
                      title: "API Humidity",
                      value:
                          isLoadingApi
                              ? "Loading"
                              : "${apiHumidity.toStringAsFixed(0)}%",
                      icon: Icons.cloud,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: envCard(
                      title: "Wind Speed",
                      value:
                          isLoadingApi
                              ? "Loading"
                              : "${apiWind.toStringAsFixed(1)} km/h",
                      icon: Icons.air,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: envCard(
                      title: "Rain",
                      value:
                          isLoadingApi
                              ? "Loading"
                              : "${apiRain.toStringAsFixed(1)} mm",
                      icon: Icons.water,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Environment Analysis",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    analysisRow(
                      "Heat condition",
                      latest.temperature >= 40 ? "High heat" : "Normal",
                    ),
                    analysisRow(
                      "Humidity condition",
                      latest.humidity >= 80 ? "High humidity" : "Stable",
                    ),
                    analysisRow(
                      "Wind condition",
                      apiWind >= 30 ? "Strong wind" : "Normal",
                    ),
                    analysisRow(
                      "Rain condition",
                      apiRain > 0 ? "Rain detected" : "No rain",
                    ),
                    analysisRow(
                      "Recommendation",
                      risk == "High Risk"
                          ? "Reduce outdoor exposure"
                          : risk == "Needs Attention"
                          ? "Monitor workers closely"
                          : "Environment is stable",
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget analysisRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget envCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
