import 'dart:convert';
import 'package:http/http.dart' as http;

class EquipmentLocation {
  final String equipmentId;
  final String name;
  final String type;
  final String status;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final double? speed;
  final int? fuelLevel;
  final String? engineStatus;
  final double? engineTemperature;
  final double? engineHours;
  final String? faultCode;
  final bool maintenanceAlert;
  final String? lastUpdate;

  EquipmentLocation({
    required this.equipmentId,
    required this.name,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.speed,
    this.fuelLevel,
    this.engineStatus,
    this.engineTemperature,
    this.engineHours,
    this.faultCode,
    this.maintenanceAlert = false,
    this.lastUpdate,
  });

  factory EquipmentLocation.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int? toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    return EquipmentLocation(
      equipmentId:
          json['equipment_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Equipment',
      type: json['type']?.toString() ?? 'Equipment',
      status: json['status']?.toString() ?? 'Working',
      latitude: toDouble(json['latitude'], 21.543333),
      longitude: toDouble(json['longitude'], 39.172779),
      imageUrl: json['image_url']?.toString(),
      speed: json['speed'] == null ? null : toDouble(json['speed'], 0),
      fuelLevel: toInt(json['fuel_level']),
      engineStatus: json['engine_status']?.toString(),
      engineTemperature:
          json['engine_temperature'] == null
              ? null
              : toDouble(json['engine_temperature'], 0),
      engineHours:
          json['engine_hours'] == null
              ? null
              : toDouble(json['engine_hours'], 0),
      faultCode: json['fault_code']?.toString(),
      maintenanceAlert: json['maintenance_alert'] == true,
      lastUpdate: json['last_update']?.toString(),
    );
  }
}

class EquipmentTrackingApiService {
  static const String equipmentApiBaseUrl =
      'https://construction-ai-api.onrender.com';

  Future<List<EquipmentLocation>> getLiveEquipmentLocations(
    String projectId, {
    double? latitude,
    double? longitude,
  }) async {
    final query = <String, String>{
      'project_id': projectId,
      if (latitude != null) 'lat': latitude.toString(),
      if (longitude != null) 'lng': longitude.toString(),
    };

    final url = Uri.parse(
      '$equipmentApiBaseUrl/equipment/live',
    ).replace(queryParameters: query);

    final response = await http.get(url).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Equipment API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    final List data;
    if (decoded is List) {
      data = decoded;
    } else if (decoded is Map && decoded['equipment'] is List) {
      data = decoded['equipment'];
    } else {
      data = [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => EquipmentLocation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
