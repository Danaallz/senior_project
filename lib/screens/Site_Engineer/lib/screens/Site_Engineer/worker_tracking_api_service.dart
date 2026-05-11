import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class WorkerSensorReading {
  final String id;
  final double latitude;
  final double longitude;
  final double temperature;
  final double humidity;
  final int alert;
  final int pir;
  final int water;
  final String timestamp;

  WorkerSensorReading({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.humidity,
    required this.alert,
    required this.pir,
    required this.water,
    required this.timestamp,
  });
}

class LiveWorker {
  final String workerId;
  final String workerName;
  final String role;
  final String status;
  final double latitude;
  final double longitude;
  final double temperature;
  final int alert;
  final String riskLevel;
  final String lastUpdate;

  LiveWorker({
    required this.workerId,
    required this.workerName,
    required this.role,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.alert,
    required this.riskLevel,
    required this.lastUpdate,
  });

  factory LiveWorker.fromJson(Map<String, dynamic> json) {
    return LiveWorker(
      workerId: json['worker_id']?.toString() ?? json['id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? 'Worker Device',
      role: json['role']?.toString() ?? 'Worker',
      status: json['status']?.toString() ?? 'Active',
      latitude: _toDouble(json['latitude'] ?? json['gps_lat']),
      longitude: _toDouble(json['longitude'] ?? json['gps_lng']),
      temperature: _toDouble(json['temperature']),
      alert: _toInt(json['alert']),
      riskLevel: json['risk_level']?.toString() ?? 'Low',
      lastUpdate:
          json['last_update']?.toString() ??
          json['timestamp']?.toString() ??
          '',
    );
  }
}

class SafetyAlert {
  final String id;
  final String workerName;
  final String message;
  final String riskLevel;
  final String timestamp;

  SafetyAlert({
    required this.id,
    required this.workerName,
    required this.message,
    required this.riskLevel,
    required this.timestamp,
  });

  factory SafetyAlert.fromJson(Map<String, dynamic> json) {
    return SafetyAlert(
      id: json['id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? 'Worker Device',
      message: json['message']?.toString() ?? 'Safety alert detected',
      riskLevel: json['risk_level']?.toString() ?? 'High',
      timestamp:
          json['timestamp']?.toString() ??
          json['last_update']?.toString() ??
          '',
    );
  }
}

class WorkerZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final String riskLevel;

  WorkerZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.riskLevel,
  });

  factory WorkerZone.fromJson(Map<String, dynamic> json) {
    return WorkerZone(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Work Zone',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radius: _toDouble(json['radius'], fallback: 60),
      riskLevel: json['risk_level']?.toString() ?? 'Low',
    );
  }
}

class WorkerTrackingDashboardData {
  final List<LiveWorker> liveWorkers;
  final List<SafetyAlert> alerts;
  final List<WorkerZone> zones;

  WorkerTrackingDashboardData({
    required this.liveWorkers,
    required this.alerts,
    required this.zones,
  });

  int get activeWorkers => liveWorkers.length;

  int get activeAlerts => alerts.length;

  int get highRiskZones =>
      zones.where((z) => z.riskLevel.toLowerCase() == 'high').length;

  double get averageTemperature {
    if (liveWorkers.isEmpty) return 0;
    final total = liveWorkers.fold<double>(
      0,
      (sum, worker) => sum + worker.temperature,
    );
    return total / liveWorkers.length;
  }
}

class WorkerTrackingApiService {
  static const String apiBaseUrl = 'https://construction-ai-api.onrender.com';

  final DatabaseReference firebaseRef = FirebaseDatabase.instance.ref('data');

  Future<WorkerTrackingDashboardData> getDashboardData({
    required String projectId,
  }) async {
    final workers = await getLiveWorkers(projectId: projectId);
    final alerts = await getSafetyAlerts(projectId: projectId);
    final zones = await getZones(projectId: projectId, workers: workers);

    return WorkerTrackingDashboardData(
      liveWorkers: workers,
      alerts: alerts,
      zones: zones,
    );
  }

  Future<List<LiveWorker>> getLiveWorkers({required String projectId}) async {
    try {
      final url = Uri.parse(
        '$apiBaseUrl/workers/live',
      ).replace(queryParameters: {'project_id': projectId});

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['workers'] is List) {
          data = decoded['workers'];
        } else {
          data = [];
        }

        return data
            .whereType<Map>()
            .map((item) => LiveWorker.fromJson(Map<String, dynamic>.from(item)))
            .where((worker) => worker.latitude != 0 && worker.longitude != 0)
            .toList();
      }
    } catch (_) {}

    return getLiveWorkersFromFirebase();
  }

  Future<List<SafetyAlert>> getSafetyAlerts({required String projectId}) async {
    try {
      final url = Uri.parse(
        '$apiBaseUrl/workers/alerts',
      ).replace(queryParameters: {'project_id': projectId});

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['alerts'] is List) {
          data = decoded['alerts'];
        } else {
          data = [];
        }

        return data
            .whereType<Map>()
            .map(
              (item) => SafetyAlert.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (_) {}

    final workers = await getLiveWorkersFromFirebase();

    return workers
        .where((worker) => worker.alert == 1)
        .map(
          (worker) => SafetyAlert(
            id: worker.workerId,
            workerName: worker.workerName,
            message: 'Safety alert detected from Firebase sensor',
            riskLevel: 'High',
            timestamp: worker.lastUpdate,
          ),
        )
        .toList();
  }

  Future<List<WorkerZone>> getZones({
    required String projectId,
    required List<LiveWorker> workers,
  }) async {
    try {
      final url = Uri.parse(
        '$apiBaseUrl/workers/zones',
      ).replace(queryParameters: {'project_id': projectId});

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['zones'] is List) {
          data = decoded['zones'];
        } else {
          data = [];
        }

        return data
            .whereType<Map>()
            .map((item) => WorkerZone.fromJson(Map<String, dynamic>.from(item)))
            .where((zone) => zone.latitude != 0 && zone.longitude != 0)
            .toList();
      }
    } catch (_) {}

    if (workers.isEmpty) return [];

    return [
      WorkerZone(
        id: 'firebase-zone',
        name: 'Live Worker Zone',
        latitude: workers.first.latitude,
        longitude: workers.first.longitude,
        radius: 80,
        riskLevel: workers.any((w) => w.alert == 1) ? 'High' : 'Low',
      ),
    ];
  }

  Stream<List<WorkerSensorReading>> streamFirebaseSensorReadings() {
    return firebaseRef.onValue.map((event) {
      return _parseFirebaseReadings(event.snapshot.value);
    });
  }

  Future<List<WorkerSensorReading>> getLastFirebaseSensorReadings() async {
    final snapshot = await firebaseRef.get();
    return _parseFirebaseReadings(snapshot.value);
  }

  Future<List<LiveWorker>> getLiveWorkersFromFirebase() async {
    final readings = await getLastFirebaseSensorReadings();

    return readings
        .where((reading) => reading.latitude != 0 && reading.longitude != 0)
        .map(
          (reading) => LiveWorker(
            workerId: reading.id,
            workerName: 'Worker Device',
            role: 'Worker',
            status: reading.alert == 1 ? 'Alert' : 'Active',
            latitude: reading.latitude,
            longitude: reading.longitude,
            temperature: reading.temperature,
            alert: reading.alert,
            riskLevel: reading.alert == 1 ? 'High' : 'Low',
            lastUpdate: reading.timestamp,
          ),
        )
        .toList();
  }

  List<WorkerSensorReading> _parseFirebaseReadings(dynamic rawData) {
    final readings = <WorkerSensorReading>[];

    if (rawData == null || rawData is! Map) return readings;

    rawData.forEach((key, value) {
      if (value is Map) {
        readings.add(
          WorkerSensorReading(
            id: key.toString(),
            latitude: _toDouble(value['gps_lat']),
            longitude: _toDouble(value['gps_lng']),
            temperature: _toDouble(value['temperature']),
            humidity: _toDouble(value['humidity']),
            alert: _toInt(value['alert']),
            pir: _toInt(value['pir']),
            water: _toInt(value['water']),
            timestamp: value['timestamp']?.toString() ?? '',
          ),
        );
      }
    });

    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return readings;
  }
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
