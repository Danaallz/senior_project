import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EngSensorsDashboard extends StatelessWidget {
  const EngSensorsDashboard({super.key});

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color greenColor = Color(0xff18b26b);
  static const Color redColor = Color(0xffef4444);
  static const Color orangeColor = Color(0xffff9800);
  static const Color blueColor = Color(0xff1e9cf0);
  static const Color purpleColor = Color(0xff9c27b0);
  static const Color tealColor = Color(0xff009688);

  // ================================
  // REAL FIREBASE REALTIME DATABASE
  // Reads live sensor data from:
  // /data in Firebase Realtime Database
  // No demo/static sensor values are used.
  // ================================
  DatabaseReference get sensorRef {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://dtpcm-eaec4-default-rtdb.europe-west1.firebasedatabase.app',
    ).ref('data');
  }

  double? toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String cleanText(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool looksLikeReading(Map<dynamic, dynamic> map) {
    return map.containsKey('temperature') ||
        map.containsKey('humidity') ||
        map.containsKey('alert') ||
        map.containsKey('pir') ||
        map.containsKey('water') ||
        map.containsKey('gps_lat') ||
        map.containsKey('gps_lng');
  }

  Map<String, dynamic> buildReading(String id, Map<dynamic, dynamic> item) {
    return {
      'id': id,
      'temperature': toDoubleOrNull(item['temperature']),
      'humidity': toDoubleOrNull(item['humidity']),
      'gps_lat': toDoubleOrNull(
        item['gps_lat'] ?? item['latitude'] ?? item['lat'],
      ),
      'gps_lng': toDoubleOrNull(
        item['gps_lng'] ?? item['longitude'] ?? item['lng'],
      ),
      'alert': toIntOrNull(item['alert']),
      'pir': toIntOrNull(item['pir']),
      'water': toIntOrNull(item['water']),
      'timestamp': cleanText(item['timestamp']),
    };
  }

  List<Map<String, dynamic>> parseReadings(dynamic rawData) {
    final readings = <Map<String, dynamic>>[];

    if (rawData == null || rawData is! Map) return readings;

    final root = Map<dynamic, dynamic>.from(rawData);

    if (looksLikeReading(root)) {
      readings.add(buildReading('latest', root));
    } else {
      root.forEach((key, value) {
        if (value is Map) {
          readings.add(
            buildReading(key.toString(), Map<dynamic, dynamic>.from(value)),
          );
        }
      });
    }

    // ================================
    // SORT FIREBASE RECORDS NEWEST FIRST
    // Firebase push IDs are time ordered, so newest ID is greater.
    // ================================
    readings.sort((a, b) {
      return cleanText(b['id']).compareTo(cleanText(a['id']));
    });

    return readings;
  }

  // ================================
  // GET LATEST VALID SENSOR READING
  // Some Firebase readings may contain only zeros.
  // This keeps realtime behavior but displays the latest useful reading.
  // ================================
  Map<String, dynamic> getLatestValidReading(
    List<Map<String, dynamic>> readings,
  ) {
    for (final item in readings) {
      final temp = toDoubleOrNull(item['temperature']) ?? 0;
      final humidity = toDoubleOrNull(item['humidity']) ?? 0;
      final lat = toDoubleOrNull(item['gps_lat']) ?? 0;
      final lng = toDoubleOrNull(item['gps_lng']) ?? 0;
      final water = toIntOrNull(item['water']) ?? 0;
      final pir = toIntOrNull(item['pir']) ?? 0;
      final alert = toIntOrNull(item['alert']) ?? 0;

      final hasRealData =
          temp != 0 ||
          humidity != 0 ||
          lat != 0 ||
          lng != 0 ||
          water != 0 ||
          pir != 0 ||
          alert != 0;

      if (hasRealData) return item;
    }

    return readings.first;
  }

  String numberText(dynamic value, {String suffix = '', int decimals = 1}) {
    final number = toDoubleOrNull(value);
    if (number == null) return 'No data';
    return '${number.toStringAsFixed(decimals)}$suffix';
  }

  String intStatus(
    dynamic value, {
    required String active,
    required String inactive,
  }) {
    final number = toIntOrNull(value);
    if (number == null) return 'No data';
    return number > 0 ? active : inactive;
  }

  String riskStatus(Map<String, dynamic> latest) {
    final temp = toDoubleOrNull(latest['temperature']);
    final humidity = toDoubleOrNull(latest['humidity']);
    final alert = toIntOrNull(latest['alert']);
    final water = toIntOrNull(latest['water']);

    if ((alert != null && alert > 0) ||
        (water != null && water > 0) ||
        (temp != null && temp >= 42)) {
      return 'High Risk';
    }

    if ((temp != null && temp >= 36) || (humidity != null && humidity >= 80)) {
      return 'Needs Attention';
    }

    return 'Normal';
  }

  Color riskColor(String risk) {
    if (risk == 'High Risk') return redColor;
    if (risk == 'Needs Attention') return orangeColor;
    return greenColor;
  }

  bool isSensorOnline(Map<String, dynamic> latest) {
    final timestamp = cleanText(latest['timestamp']);
    if (timestamp.isEmpty) return true;

    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return true;

    return DateTime.now().difference(parsed).inMinutes <= 5;
  }

  List<double> extractSeries(
    List<Map<String, dynamic>> readings,
    String key, {
    int limit = 12,
  }) {
    final values =
        readings
            .take(limit)
            .map((item) => toDoubleOrNull(item[key]))
            .whereType<double>()
            .toList();

    return values.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        title: const Text(
          'IoT Sensors Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        // Realtime listener: UI updates automatically whenever /data changes.
        stream: sensorRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return errorView('Unable to read Firebase sensor data.');
          }

          final readings = parseReadings(snapshot.data?.snapshot.value);

          if (readings.isEmpty) {
            return errorView(
              'No live sensor readings found in Firebase /data.',
            );
          }

          final latest = getLatestValidReading(readings);
          final risk = riskStatus(latest);
          final color = riskColor(risk);
          final online = isSensorOnline(latest);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              heroCard(latest, risk, color, online),
              const SizedBox(height: 14),
              warningCard(latest),
              const SizedBox(height: 14),
              latestReadingGrid(latest),
              const SizedBox(height: 18),
              chartsCard(readings),
              const SizedBox(height: 18),
              gpsMapCard(latest),
              const SizedBox(height: 18),
              analysisCard(latest, risk, color, online),
            ],
          );
        },
      ),
    );
  }

  Widget heroCard(
    Map<String, dynamic> latest,
    String risk,
    Color color,
    bool online,
  ) {
    final timestamp = cleanText(latest['timestamp']);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, color.withOpacity(.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live IoT Sensor Status',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              liveBadge(online),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            risk,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 31,
            ),
          ),
          const SizedBox(height: 12),
          infoLine(
            icon: Icons.access_time_rounded,
            text:
                timestamp.isEmpty
                    ? 'Last update: No timestamp'
                    : 'Last update: $timestamp',
          ),
          const SizedBox(height: 6),
          infoLine(
            icon: Icons.memory_rounded,
            text: 'Device: ${cleanText(latest['id'])}',
          ),
        ],
      ),
    );
  }

  Widget liveBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.17),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? Colors.greenAccent : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'LIVE' : 'OFFLINE',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget infoLine({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget warningCard(Map<String, dynamic> latest) {
    final temp = toDoubleOrNull(latest['temperature']);
    final water = toIntOrNull(latest['water']);
    final alert = toIntOrNull(latest['alert']);

    String title = 'Site conditions are normal';
    String message =
        'No active warning detected from the latest Firebase sensor reading.';
    Color color = greenColor;
    IconData icon = Icons.verified_rounded;

    if ((alert != null && alert > 0)) {
      title = 'Safety alert detected';
      message = 'The latest sensor reading contains an active alert signal.';
      color = redColor;
      icon = Icons.warning_amber_rounded;
    } else if ((water != null && water > 0)) {
      title = 'Water detected';
      message = 'The water sensor detected water at the site.';
      color = redColor;
      icon = Icons.water_damage_rounded;
    } else if (temp != null && temp >= 42) {
      title = 'Extreme temperature warning';
      message = 'High heat may affect worker safety and site operations.';
      color = redColor;
      icon = Icons.local_fire_department_rounded;
    } else if (temp != null && temp >= 36) {
      title = 'High temperature notice';
      message = 'Monitor workers and increase rest/hydration breaks.';
      color = orangeColor;
      icon = Icons.thermostat_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withOpacity(.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget latestReadingGrid(Map<String, dynamic> latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latest Sensor Reading',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: sensorCard(
                title: 'Temperature',
                value: numberText(latest['temperature'], suffix: '°C'),
                icon: Icons.thermostat_rounded,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: sensorCard(
                title: 'Humidity',
                value: numberText(latest['humidity'], suffix: '%', decimals: 0),
                icon: Icons.water_drop_rounded,
                color: blueColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: sensorCard(
                title: 'PIR Motion',
                value: intStatus(
                  latest['pir'],
                  active: 'Detected',
                  inactive: 'Clear',
                ),
                icon: Icons.motion_photos_on_rounded,
                color: purpleColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: sensorCard(
                title: 'Water Sensor',
                value: intStatus(
                  latest['water'],
                  active: 'Detected',
                  inactive: 'Clear',
                ),
                icon: Icons.water_rounded,
                color: tealColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        sensorCard(
          title: 'Safety Alert',
          value: intStatus(
            latest['alert'],
            active: 'Active',
            inactive: 'No alert',
          ),
          icon: Icons.warning_amber_rounded,
          color: redColor,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget chartsCard(List<Map<String, dynamic>> readings) {
    final temperatures = extractSeries(readings, 'temperature');
    final humidities = extractSeries(readings, 'humidity');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.show_chart_rounded, 'Live Trends', primaryColor),
          const SizedBox(height: 16),
          chartSection(
            title: 'Temperature Trend',
            values: temperatures,
            color: Colors.deepOrange,
            suffix: '°C',
          ),
          const SizedBox(height: 18),
          chartSection(
            title: 'Humidity Trend',
            values: humidities,
            color: blueColor,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget chartSection({
    required String title,
    required List<double> values,
    required Color color,
    required String suffix,
  }) {
    final latest = values.isEmpty ? null : values.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              latest == null
                  ? 'No data'
                  : '${latest.toStringAsFixed(1)}$suffix',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(.10)),
          ),
          child:
              values.length < 2
                  ? const Center(
                    child: Text(
                      'Need more readings for chart',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : CustomPaint(
                    painter: MiniLineChartPainter(values: values, color: color),
                  ),
        ),
      ],
    );
  }

  Widget gpsMapCard(Map<String, dynamic> latest) {
    final lat = toDoubleOrNull(latest['gps_lat']);
    final lng = toDoubleOrNull(latest['gps_lng']);

    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleRow(
              Icons.location_off_rounded,
              'Sensor GPS Location',
              Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'No valid GPS location was received from Firebase for the latest sensor reading.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      );
    }

    final position = LatLng(lat, lng);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.location_on_rounded, 'Sensor GPS Location', blueColor),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 210,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 17.5,
                  tilt: 25,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('latest_sensor'),
                    position: position,
                    infoWindow: const InfoWindow(
                      title: 'Latest sensor location',
                    ),
                  ),
                },
                mapType: MapType.hybrid,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget analysisCard(
    Map<String, dynamic> latest,
    String risk,
    Color color,
    bool online,
  ) {
    final temp = toDoubleOrNull(latest['temperature']);
    final humidity = toDoubleOrNull(latest['humidity']);
    final alert = toIntOrNull(latest['alert']);
    final water = toIntOrNull(latest['water']);
    final pir = toIntOrNull(latest['pir']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.analytics_outlined, 'Sensor Analysis', color),
          const SizedBox(height: 14),
          analysisRow(
            'Sensor status',
            online ? 'Online' : 'Offline',
            online ? greenColor : redColor,
          ),
          analysisRow(
            'Heat condition',
            temp == null
                ? 'No data'
                : temp >= 42
                ? 'Extreme heat'
                : temp >= 36
                ? 'High temperature'
                : 'Normal',
            temp != null && temp >= 36 ? orangeColor : greenColor,
          ),
          analysisRow(
            'Humidity condition',
            humidity == null
                ? 'No data'
                : humidity >= 80
                ? 'High humidity'
                : 'Stable',
            humidity != null && humidity >= 80 ? orangeColor : greenColor,
          ),
          analysisRow(
            'Water condition',
            water == null
                ? 'No data'
                : water > 0
                ? 'Water detected'
                : 'No water',
            water != null && water > 0 ? redColor : greenColor,
          ),
          analysisRow(
            'Motion condition',
            pir == null
                ? 'No data'
                : pir > 0
                ? 'Motion detected'
                : 'No motion',
            pir != null && pir > 0 ? blueColor : Colors.grey,
          ),
          analysisRow(
            'Safety alert',
            alert == null
                ? 'No data'
                : alert > 0
                ? 'Active alert'
                : 'No alert',
            alert != null && alert > 0 ? redColor : greenColor,
          ),
          analysisRow('Overall status', risk, color),
        ],
      ),
    );
  }

  Widget sensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      height: fullWidth ? 132 : 138,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget titleRow(IconData icon, String title, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget analysisRow(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sensors_off_rounded,
                size: 54,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'No live sensor data',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffeeeeee)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

class MiniLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  MiniLineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.001 ? 1 : maxValue - minValue;

    final linePaint =
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final fillPaint =
        Paint()
          ..color = color.withOpacity(.10)
          ..style = PaintingStyle.fill;

    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(.18)
          ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 24)) - 12;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
