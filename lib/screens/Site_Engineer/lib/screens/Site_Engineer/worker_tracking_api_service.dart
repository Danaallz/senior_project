import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

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

class SiteWeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double rain;
  final String lastUpdate;

  SiteWeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.rain,
    required this.lastUpdate,
  });

  String get riskLevel {
    if (rain > 0 || temperature >= 42 || windSpeed >= 35) return 'High';
    if (temperature >= 36 || humidity >= 80 || windSpeed >= 28) return 'Medium';
    return 'Low';
  }

  int get alert {
    return riskLevel == 'High' ? 1 : 0;
  }
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
      latitude: _toDouble(json['latitude'] ?? json['gps_lat'] ?? json['lat']),
      longitude: _toDouble(json['longitude'] ?? json['gps_lng'] ?? json['lng']),
      temperature: _toDouble(json['temperature'], fallback: 32),
      alert: _toInt(json['alert']),
      riskLevel: json['risk_level']?.toString() ?? 'Low',
      lastUpdate:
          json['last_update']?.toString() ??
          json['timestamp']?.toString() ??
          DateTime.now().toIso8601String(),
    );
  }

  LiveWorker copyWith({
    String? workerId,
    String? workerName,
    String? role,
    String? status,
    double? latitude,
    double? longitude,
    double? temperature,
    int? alert,
    String? riskLevel,
    String? lastUpdate,
  }) {
    return LiveWorker(
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      role: role ?? this.role,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      temperature: temperature ?? this.temperature,
      alert: alert ?? this.alert,
      riskLevel: riskLevel ?? this.riskLevel,
      lastUpdate: lastUpdate ?? this.lastUpdate,
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
      latitude: _toDouble(json['latitude'] ?? json['lat']),
      longitude: _toDouble(json['longitude'] ?? json['lng']),
      radius: _toDouble(json['radius'], fallback: 55),
      riskLevel: json['risk_level']?.toString() ?? 'Low',
    );
  }
}

class WorkerTrackingDashboardData {
  final List<LiveWorker> liveWorkers;
  final List<SafetyAlert> alerts;
  final List<WorkerZone> zones;
  final SiteWeatherData? weather;

  WorkerTrackingDashboardData({
    required this.liveWorkers,
    required this.alerts,
    required this.zones,
    this.weather,
  });

  int get activeWorkers => liveWorkers.length;

  int get activeAlerts => alerts.length;

  int get highRiskZones =>
      zones.where((z) => z.riskLevel.toLowerCase() == 'high').length;

  double get averageTemperature {
    if (liveWorkers.isEmpty) return weather?.temperature ?? 0;
    final total = liveWorkers.fold<double>(
      0,
      (sum, worker) => sum + worker.temperature,
    );
    return total / liveWorkers.length;
  }
}

class WorkerTrackingApiService {
  static const String apiBaseUrl = 'https://randomuser.me/api/';

  final DatabaseReference firebaseRef = FirebaseDatabase.instance.ref('data');

  // ================================
  // REAL WEATHER API DATA
  // Uses the same Open-Meteo API concept used in Digital Twin.
  // Temperature and risk are based on live weather, not static values.
  // ================================
  Future<SiteWeatherData?> getSiteWeather({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final lat = latitude ?? 21.543333;
      final lng = longitude ?? 39.172779;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final current = decoded['current'] ?? {};

      return SiteWeatherData(
        temperature: _toDouble(current['temperature_2m']),
        humidity: _toDouble(current['relative_humidity_2m']),
        windSpeed: _toDouble(current['wind_speed_10m']),
        rain: _toDouble(current['rain']),
        lastUpdate: current['time']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('Site weather error: $e');
      return null;
    }
  }

  Future<WorkerTrackingDashboardData> getDashboardData({
    required String projectId,
    int? workerCount,
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>> assignedWorkers = const [],
    SiteWeatherData? siteWeather,
  }) async {
    final siteWeather = await getSiteWeather(
      latitude: latitude,
      longitude: longitude,
    );

    final workers = await getLiveWorkers(
      projectId: projectId,
      workerCount: workerCount,
      latitude: latitude,
      longitude: longitude,
      assignedWorkers: assignedWorkers,
      siteWeather: siteWeather,
    );

    final alerts = await getSafetyAlerts(projectId: projectId, workers: workers);
    final zones = await getZones(projectId: projectId, workers: workers);

    return WorkerTrackingDashboardData(
      liveWorkers: workers,
      alerts: alerts,
      zones: zones,
      weather: siteWeather,
    );
  }

  // ================================
  // LIVE WORKERS GPS API
  // Shows ONLY present workers passed from the UI.
  // Priority:
  // 1) /workers/live API
  // 2) Firebase helmet GPS
  // 3) Moving demo simulation around project location
  // ================================
  Future<List<LiveWorker>> getLiveWorkers({
    required String projectId,
    int? workerCount,
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>> assignedWorkers = const [],
    SiteWeatherData? siteWeather,
  }) async {
    final safeCount = workerCount ?? assignedWorkers.length;

    if (safeCount <= 0) return [];

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl?results=$safeCount'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final List results = decoded['results'] ?? [];

        final baseLat = latitude ?? 21.543333;
        final baseLng = longitude ?? 39.172779;

        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

        final workers = results.asMap().entries.map((entry) {
          final index = entry.key;

          final Map<String, dynamic> assigned =
              index < assignedWorkers.length
                  ? Map<String, dynamic>.from(assignedWorkers[index])
                  : {};

          final angle = now * 0.18 + index * 1.4;
          final radius = 0.00012 + (index % 4) * 0.00005;

          final lat = baseLat + sin(angle) * radius;
          final lng = baseLng + cos(angle) * radius;

          final weatherRisk = siteWeather?.riskLevel ?? 'Low';
          final weatherAlert = siteWeather?.alert ?? 0;

          return LiveWorker(
            workerId: assigned['id']?.toString() ?? 'worker_$index',
            workerName: _firstNotEmpty(
              assigned,
              ['name', 'full_name', 'worker_name'],
              fallback: 'Worker ${index + 1}',
            ),
            role: _firstNotEmpty(
              assigned,
              ['role', 'job_title', 'job'],
              fallback: 'Worker',
            ),
            status: 'Present',
            latitude: lat,
            longitude: lng,
            temperature: siteWeather?.temperature ?? 0,
            alert: weatherAlert,
            riskLevel: weatherRisk,
            lastUpdate: siteWeather?.lastUpdate ?? DateTime.now().toIso8601String(),
          );
        }).toList();

        return workers;
      }
    } catch (e) {
      debugPrint("RandomUser GPS Error: $e");
    }

    return simulateLiveWorkers(
      count: safeCount,
      latitude: latitude,
      longitude: longitude,
      assignedWorkers: assignedWorkers,
      siteWeather: siteWeather,
    );
  }

  List<LiveWorker> attachAssignedWorkerInfo(
    List<LiveWorker> liveWorkers,
    List<Map<String, dynamic>> assignedWorkers,
  ) {
    if (assignedWorkers.isEmpty) return liveWorkers;

    return liveWorkers.asMap().entries.map((entry) {
      final index = entry.key;
      final live = entry.value;

      if (index >= assignedWorkers.length) return live;

      final worker = assignedWorkers[index];

      final name = _firstNotEmpty(worker, [
        'name',
        'full_name',
        'worker_name',
      ], fallback: 'Worker ${index + 1}');

      final role = _firstNotEmpty(worker, [
        'role',
        'job_title',
        'job',
        'specialization',
      ], fallback: 'Worker');

      return live.copyWith(
        workerId: _clean(worker['id']).isNotEmpty ? _clean(worker['id']) : live.workerId,
        workerName: name,
        role: role,
        status: _clean(worker['attendance_status']).isNotEmpty
            ? _clean(worker['attendance_status'])
            : live.status,
      );
    }).toList();
  }

  // ================================
  // MOVING DEMO GPS SIMULATION
  // Each refresh slightly changes the workers' positions,
  // so it looks like people are moving around the construction site.
  // ================================
  List<LiveWorker> simulateLiveWorkers({
    required int count,
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>> assignedWorkers = const [],
    SiteWeatherData? siteWeather,
  }) {
    if (count <= 0) return [];

    final baseLat = latitude ?? 21.543333;
    final baseLng = longitude ?? 39.172779;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    return List.generate(count, (index) {

    final Map<String, dynamic> worker =
        index < assignedWorkers.length
            ? Map<String, dynamic>.from(assignedWorkers[index])
            : <String, dynamic>{};
            
      final name = _firstNotEmpty(worker, [
        'name',
        'full_name',
        'worker_name',
      ], fallback: 'Worker ${index + 1}');

      final role = _firstNotEmpty(worker, [
        'role',
        'job_title',
        'job',
        'specialization',
      ], fallback: 'Worker');

      // Circular moving path around project location.
      final angle = now * 0.20 + index * 1.3;
      final radius = 0.00012 + (index % 4) * 0.000045;

      final lat = baseLat + sin(angle) * radius;
      final lng = baseLng + cos(angle) * radius;

      final weatherRisk = siteWeather?.riskLevel ?? 'Low';
      final weatherAlert = siteWeather?.alert ?? 0;

      return LiveWorker(
        workerId: _clean(worker['id']).isNotEmpty
            ? _clean(worker['id'])
            : 'demo-worker-${index + 1}',
        workerName: name,
        role: role,
        status: 'Present',
        latitude: lat,
        longitude: lng,
        temperature: siteWeather?.temperature ?? 0,
        alert: weatherAlert,
        riskLevel: weatherRisk,
        lastUpdate: siteWeather?.lastUpdate ?? DateTime.now().toIso8601String(),
      );
    });
  }

  Future<List<SafetyAlert>> getSafetyAlerts({
    required String projectId,
    List<LiveWorker> workers = const [],
  }) async {
    try {
      final url = Uri.parse(
        '$apiBaseUrl/workers/alerts',
      ).replace(queryParameters: {'project_id': projectId});

      final response = await http.get(url).timeout(const Duration(seconds: 8));

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

        final alerts = data
            .whereType<Map>()
            .map(
              (item) => SafetyAlert.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();

        if (alerts.isNotEmpty) return alerts;
      }
    } catch (_) {}

    return workers
        .where((worker) => worker.alert == 1)
        .map(
          (worker) => SafetyAlert(
            id: worker.workerId,
            workerName: worker.workerName,
            message: 'Helmet GPS safety alert detected',
            riskLevel: worker.riskLevel,
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

      final response = await http.get(url).timeout(const Duration(seconds: 8));

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

        final zones = data
            .whereType<Map>()
            .map((item) => WorkerZone.fromJson(Map<String, dynamic>.from(item)))
            .where((zone) => zone.latitude != 0 && zone.longitude != 0)
            .toList();

        if (zones.isNotEmpty) return zones;
      }
    } catch (_) {}

    if (workers.isEmpty) return [];

    return [
      WorkerZone(
        id: 'worker-zone',
        name: 'Active Worker Zone',
        latitude: workers.first.latitude,
        longitude: workers.first.longitude,
        radius: 75,
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
            status: reading.alert == 1 ? 'Alert' : 'Present',
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
            latitude: _toDouble(value['gps_lat'] ?? value['latitude'] ?? value['lat']),
            longitude: _toDouble(value['gps_lng'] ?? value['longitude'] ?? value['lng']),
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

String _clean(dynamic value) {
  return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
}

String _firstNotEmpty(
  Map<String, dynamic> data,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final value = _clean(data[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
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
