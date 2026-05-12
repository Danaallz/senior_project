import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class DigitalTwinPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const DigitalTwinPage({super.key, required this.project});

  @override
  State<DigitalTwinPage> createState() => _DigitalTwinPageState();
}

class _DigitalTwinPageState extends State<DigitalTwinPage> {
  final Flutter3DController controller = Flutter3DController();
  final supabase = Supabase.instance.client;
  final NotificationService notificationService = NotificationService();

  double timeProgress = 0.0;
  bool autoRotate = true;
  bool isLoadingLiveData = true;
  bool isLoadingAI = false;
  DateTime? selectedTimelineDate;

  double? weatherTemperature;
  double? weatherHumidity;
  double? weatherWind;
  double? weatherRain;

  double? sensorTemperature;
  double? sensorHumidity;
  double? sensorWater;
  double? sensorGpsLat;
  double? sensorGpsLng;
  int? sensorAlert;
  int? sensorPir;
  bool usingFirebaseSensors = false;

  String? riskLevel;
  String? riskLabel;
  double? delayProbability;
  double? predictedDelayDays;
  bool? delayPredicted;
  List<String> recommendations = [];

  static const primaryColor = Color(0xff0d1b46);
  static const navy = Color(0xff071225);
  static const softBg = Color(0xfff4f7fb);
  static const greenColor = Color(0xff22c55e);
  static const orangeColor = Color(0xffff9800);
  static const redColor = Color(0xffef4444);
  static const blueColor = Color(0xff2563eb);
  static const purpleColor = Color(0xff7c3aed);

  static const String aiApiBaseUrl = 'https://construction-ai-api.onrender.com';

  DateTime getTodayWithinProjectRange() {
    final today = DateTime.now();
    final start = getProjectStartDate();
    final end = getProjectEndDate();

    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day);

    if (cleanToday.isBefore(cleanStart)) return cleanStart;
    if (cleanToday.isAfter(cleanEnd)) return cleanEnd;
    return cleanToday;
  }

  @override
  void initState() {
    super.initState();

    final initialDate = getTodayWithinProjectRange();

    selectedTimelineDate = initialDate;
    timeProgress = calculateProgressFromDate(initialDate);

    loadLiveData();

    controller.onModelLoaded.addListener(() {
      controller.playAnimation();
      controller.startRotation(rotationSpeed: 8);
    });
  }

  Future<void> loadLiveData() async {
    final todayDate = getTodayWithinProjectRange();

    setState(() {
      selectedTimelineDate = todayDate;
      timeProgress = calculateProgressFromDate(todayDate);
      isLoadingLiveData = true;
      isLoadingAI = false;
      usingFirebaseSensors = false;
    });

    final hasFirebaseSensorData = await loadLatestFirebaseSensorReading();

    if (!hasFirebaseSensorData) {
      await loadWeatherFromApi();
    }

    if (!mounted) return;
    setState(() => isLoadingLiveData = false);

    await callAIPrediction();

    // Save one complete digital twin snapshot every time the page loads or refreshes.
    await saveDigitalTwinSnapshot();
  }


  double? toDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? toIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  // ================================
  // FIREBASE IOT SENSOR INTEGRATION
  // Reads the latest sensor record from Firebase Realtime Database
  // only if the selected project has sensor_enabled = true.
  // If no sensor data is found, the system falls back to Weather API.
  // ================================
  Future<bool> loadLatestFirebaseSensorReading() async {
    try {
      final sensorEnabled = widget.project['sensor_enabled'] == true ||
          widget.project['sensor_enabled']?.toString().toLowerCase() == 'true';

      final sensorPath = widget.project['firebase_sensor_path']?.toString();

      if (!sensorEnabled || sensorPath == null || sensorPath.trim().isEmpty) {
        return false;
      }

      final snapshot = await FirebaseDatabase.instance
          .ref(sensorPath)
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      if (!snapshot.exists || snapshot.value == null) return false;

      Map<String, dynamic>? latestReading;

      if (snapshot.value is Map) {
        final rawMap = Map<dynamic, dynamic>.from(snapshot.value as Map);

        if (rawMap.containsKey('temperature') || rawMap.containsKey('humidity')) {
          latestReading = Map<String, dynamic>.from(rawMap);
        } else {
          final values = rawMap.values.toList();
          if (values.isNotEmpty && values.last is Map) {
            latestReading = Map<String, dynamic>.from(values.last as Map);
          }
        }
      }

      if (latestReading == null) return false;

      final temp = toDoubleValue(latestReading['temperature']);
      final hum = toDoubleValue(latestReading['humidity']);
      final water = toDoubleValue(latestReading['water']);
      final gpsLat = toDoubleValue(latestReading['gps_lat']);
      final gpsLng = toDoubleValue(latestReading['gps_lng']);
      final alert = toIntValue(latestReading['alert']);
      final pir = toIntValue(latestReading['pir']);

      if (temp == null || hum == null) return false;

      if (!mounted) return false;

      setState(() {
        sensorTemperature = temp;
        sensorHumidity = hum;
        sensorWater = water ?? 0;
        sensorGpsLat = gpsLat;
        sensorGpsLng = gpsLng;
        sensorAlert = alert;
        sensorPir = pir;

        weatherTemperature = temp;
        weatherHumidity = hum;
        weatherRain = water ?? 0;
        usingFirebaseSensors = true;
      });

      return true;
    } catch (e) {
      debugPrint('Firebase sensor error: $e');
      return false;
    }
  }

  // ================================
  // WEATHER API FALLBACK
  // Used when Firebase IoT sensor data is unavailable.
  // Retrieves live weather data based on project latitude/longitude.
  // ================================
  Future<void> loadWeatherFromApi() async {
    try {
      final lat = widget.project['latitude'] ?? 21.5433;
      final lng = widget.project['longitude'] ?? 39.1728;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final current = data['current'];

      setState(() {
        weatherTemperature = (current['temperature_2m'] as num?)?.toDouble();
        weatherHumidity = (current['relative_humidity_2m'] as num?)?.toDouble();
        weatherWind = (current['wind_speed_10m'] as num?)?.toDouble();
        weatherRain = (current['rain'] as num?)?.toDouble();
      });
    } catch (e) {
      debugPrint('Weather API error: $e');
    }
  }

  String getProjectId() {
    return widget.project['id']?.toString() ?? '';
  }

  // ================================
  // AI ADJUSTED END DATE
  // Keeps the original project end date as baseline.
  // If AI predicts a delay, the adjusted end date is calculated
  // by adding the predicted delay days.
  // ================================
  DateTime getAdjustedEndDate() {
    if (delayPredicted == true && predictedDelayDays != null) {
      return getProjectEndDate().add(
        Duration(days: predictedDelayDays!.round()),
      );
    }
    return getProjectEndDate();
  }



  // ================================
  // NOTIFICATION DUPLICATION CONTROL
  // Prevents sending the same AI warning repeatedly on every refresh/login.
  // It checks if a similar notification was already created for this project
  // within the last 6 hours.
  // ================================
  Future<bool> hasRecentSimilarNotification({
    required String userId,
    required String projectId,
    required String type,
  }) async {
    try {
      final since = DateTime.now().subtract(const Duration(hours: 6));

      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('project_id', projectId)
          .eq('type', type)
          .gte('created_at', since.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Notification duplicate check error: $e');
      return false;
    }
  }

  // ================================
  // DIGITAL TWIN NOTIFICATIONS
  // Sends AI prediction alerts to both:
  // - Owner
  // - Assigned Manager / current manager
  //
  // Notifications are created only for high risk or delay risk.
  // Similar notifications are limited to once every 6 hours per user.
  // ================================
  Future<void> createDigitalTwinNotification() async {
    try {
      final ownerId = widget.project['owner_id']?.toString();
      final assignedManagerId =
          widget.project['assigned_manager_id']?.toString() ??
          widget.project['manager_id']?.toString();

      // ================================
      // SITE ENGINEER AI NOTIFICATION RECIPIENT
      // The assigned site engineer also receives AI risk/delay alerts.
      // ================================
      final assignedSiteEngineerId =
          widget.project['assigned_site_engineer_id']?.toString();

      final currentUserId = supabase.auth.currentUser?.id;

      final projectId = widget.project['id']?.toString();
      final projectName = widget.project['name']?.toString() ?? 'Project';

      if (projectId == null || projectId.isEmpty) {
        return;
      }

      // ================================
      // AI NOTIFICATION RECIPIENTS
      // Adds the owner and the assigned/current manager.
      // toSet() prevents sending duplicate notifications to the same user.
      // ================================
      final recipients = <String>{
        if (ownerId != null && ownerId.isNotEmpty) ownerId,
        if (assignedManagerId != null && assignedManagerId.isNotEmpty)
          assignedManagerId,
        if (assignedSiteEngineerId != null && assignedSiteEngineerId.isNotEmpty)
          assignedSiteEngineerId,
        if (currentUserId != null && currentUserId.isNotEmpty) currentUserId,
      };

      if (recipients.isEmpty) return;

      final risk = riskLevel?.toLowerCase() ?? '';
      final delayProb = delayProbability ?? 0;

      String? type;
      String? title;
      String? message;

      if (risk.contains('high') || risk.contains('risk')) {
        type = 'ai_prediction';
        title = 'AI Risk Alert';
        message =
            '$projectName has a high AI risk level. Immediate review is recommended.';
      } else if (delayPredicted == true || delayProb >= 0.40) {
        type = 'ai_prediction';
        title = 'AI Delay Prediction';
        message =
            '$projectName may face schedule delay. Estimated delay: ${predictedDelayDays?.toStringAsFixed(1) ?? '0'} days.';
      }

      if (type == null || title == null || message == null) return;

      for (final userId in recipients) {
        final exists = await hasRecentSimilarNotification(
          userId: userId,
          projectId: projectId,
          type: type,
        );

        if (exists) continue;

        await notificationService.createNotification(
          userId: userId,
          projectId: projectId,
          type: type,
          title: title,
          message: message,
        );
      }
    } catch (e) {
      debugPrint('Notification creation error: $e');
    }
  }

  // ================================
  // DIGITAL TWIN SNAPSHOT STORAGE
  // Saves the current live state of the Digital Twin in Supabase,
  // including progress, weather/sensor data, AI results,
  // adjusted end date, and schedule status.
  // ================================
  Future<void> saveDigitalTwinSnapshot() async {
    try {
      final projectId = widget.project['id']?.toString();

      if (projectId == null || projectId.isEmpty) {
        debugPrint("Snapshot skipped: missing project id");
        return;
      }

      final adjustedEndDate =
          delayPredicted == true && predictedDelayDays != null
              ? getProjectEndDate().add(
                Duration(days: predictedDelayDays!.round()),
              )
              : getProjectEndDate();

      final payload = {
        'project_id': projectId,
        'progress_percent': (timeProgress * 100).round(),
        'selected_date': _dateLabel(getSelectedDate()),
        'weather_temperature': weatherTemperature,
        'weather_humidity': weatherHumidity,
        'weather_wind': weatherWind,
        'weather_rain': weatherRain,
        'data_source': usingFirebaseSensors ? 'Firebase IoT Sensors' : 'Weather API',
        'sensor_gps_lat': sensorGpsLat,
        'sensor_gps_lng': sensorGpsLng,
        'sensor_alert': sensorAlert,
        'sensor_pir': sensorPir,
        'risk_level': riskLevel,
        'risk_label': riskLabel,
        'delay_probability': delayProbability,
        'predicted_delay_days': predictedDelayDays,
        'delay_predicted': delayPredicted,
        'adjusted_end_date': _dateLabel(adjustedEndDate),
        'recommendations': recommendations,
        'current_phase': getStageName(),
        'current_activity': getCurrentActivity(),
        'schedule_status': delayPredicted == true ? 'At Risk' : 'On Track',
      };

      final saved =
          await supabase
              .from('digital_twin_snapshots')
              .insert(payload)
              .select();

      debugPrint("Digital twin snapshot saved successfully: $saved");
      await createDigitalTwinNotification();
    } catch (e) {
      debugPrint("SNAPSHOT SAVE ERROR: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Digital twin snapshot was not saved: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================================
  // AI PREDICTION API INTEGRATION
  // Sends live site data to FastAPI /predict endpoint.
  // Uses Firebase sensor readings when available,
  // otherwise uses weather API data.
  // ================================
  Future<void> callAIPrediction() async {
    final temp = sensorTemperature ?? weatherTemperature;
    final hum = sensorHumidity ?? weatherHumidity;
    final rain = ((sensorWater ?? weatherRain ?? 0) > 0) ? 1 : 0;

    if (temp == null || hum == null) return;

    final alertCount = sensorAlert ?? [
      if (temp > 45) 1,
      if (hum > 80) 1,
      if (rain == 1) 1,
    ].length;

    final pir = sensorPir ?? 1;

    final equipmentAvailability = temp > 45 || rain == 1 ? 0.60 : 0.95;
    final actualWorkers = temp > 45 || rain == 1 ? 35 : 48;
    final complexity = temp > 45 || hum > 80 || rain == 1 ? 0.80 : 0.30;

    setState(() => isLoadingAI = true);

    try {
      final response = await http
          .post(
            Uri.parse('$aiApiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'project_id':
                  int.tryParse(widget.project['id']?.toString() ?? '') ?? 1,
              'temperature': temp,
              'humidity': hum,
              'rainfall': rain,
              'pir': pir,
              'alert_count': alertCount,
              'equipment_availability': equipmentAvailability,
              'equipment_breakdown': 0,
              'planned_workers': 50,
              'actual_workers': actualWorkers,
              'activity_type': getStageName().contains('Foundation')
                  ? 'excavation'
                  : 'concrete',
              'planned_duration': 7,
              'complexity': complexity,
              'project_type': 'commercial',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      String finalRiskLevel = data['risk']?['level']?.toString() ?? 'Low';
      String finalRiskLabel = data['risk']?['label']?.toString() ?? 'Safe';

      if (temp < 40 && hum < 75 && rain == 0 && equipmentAvailability >= 0.85) {
        finalRiskLevel = 'Low';
        finalRiskLabel = 'Safe';
      }

      if (temp > 45 || rain == 1 || equipmentAvailability < 0.70) {
        finalRiskLevel = 'High';
        finalRiskLabel = 'High Risk';
      }

      setState(() {
        delayPredicted = data['delay']?['predicted'];
        delayProbability = (data['delay']?['probability'] as num?)?.toDouble();
        predictedDelayDays =
            (data['delay']?['estimated_days'] as num?)?.toDouble();
        riskLevel = finalRiskLevel;

        // ================================
        // SIMPLIFIED RISK LABEL
        // Shows one clean word in the UI: Safe, Warning, or Risk.
        // ================================
        if (finalRiskLevel.toLowerCase().contains('high')) {
          riskLabel = 'Risk';
        } else if (finalRiskLevel.toLowerCase().contains('medium')) {
          riskLabel = 'Warning';
        } else {
          riskLabel = 'Safe';
        }

        recommendations = List<String>.from(data['recommendations'] ?? []);
      });
    } catch (e) {
      debugPrint('AI API error: $e');
    } finally {
      if (mounted) setState(() => isLoadingAI = false);
    }
  }

  DateTime getProjectStartDate() {
    return DateTime.tryParse(widget.project['start_date']?.toString() ?? '') ??
        DateTime.now();
  }

  DateTime getProjectEndDate() {
    return DateTime.tryParse(widget.project['end_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 90));
  }

  DateTime getSelectedDate() => selectedTimelineDate ?? getProjectStartDate();

  double calculateProgressFromDate(DateTime date) {
    final start = getProjectStartDate();
    final end = getProjectEndDate();
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 0;
    final passedDays = date.difference(start).inDays;
    return (passedDays / totalDays).clamp(0.0, 1.0);
  }

  String _dateLabel(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String getStageName() {
    if (timeProgress < 0.20) return 'Foundation Works';
    if (timeProgress < 0.45) return 'Structural Works';
    if (timeProgress < 0.70) return 'Facade Installation';
    if (timeProgress < 0.90) return 'MEP Installation';
    return 'Finishing & Handover';
  }

  String getCurrentActivity() {
    if (timeProgress < 0.20) {
      return 'Excavation, footings, and foundation preparation';
    }
    if (timeProgress < 0.45) return 'Concrete frame, slabs, and columns';
    if (timeProgress < 0.70) {
      return 'Facade, exterior envelope, and glazing works';
    }
    if (timeProgress < 0.90) {
      return 'Mechanical, electrical, and plumbing systems';
    }
    return 'Interior finishing, inspection, and handover';
  }

  Color getRiskColor() {
    final risk = riskLevel?.toLowerCase() ?? riskLabel?.toLowerCase() ?? '';
    if (risk.contains('high') || risk.contains('critical')) return redColor;
    if (risk.contains('medium') || risk.contains('warning')) return orangeColor;
    if (risk.contains('low') || risk.contains('safe')) return greenColor;
    return Colors.grey;
  }

  Color getDelayColor() {
    final prob = delayProbability ?? 0;
    if (prob > 0.7) return redColor;
    if (prob > 0.4) return orangeColor;
    return greenColor;
  }

  void toggleRotation() {
    setState(() => autoRotate = !autoRotate);
    if (autoRotate) {
      controller.startRotation(rotationSpeed: 8);
    } else {
      controller.stopRotation();
    }
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ================================
  // BIM PROGRESS OVERLAY
  // Visually hides the unfinished part of the BIM model
  // based on calculated construction progress.
  // ================================
  Widget _constructionProgressOverlay() {
    final hiddenPart = (1 - timeProgress).clamp(0.0, 1.0);
    if (hiddenPart <= 0.02) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          height: 540 * hiddenPart,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(46),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xfff6f8fc).withOpacity(0.92),
                const Color(0xfff6f8fc).withOpacity(0.74),
                const Color(0xfff6f8fc).withOpacity(0.48),
                const Color(0xfff6f8fc).withOpacity(0.18),
                Colors.transparent,
              ],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _phaseLegend() {
    return _glassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIM Status Legend',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _legendRow(greenColor, 'Completed'),
          _legendRow(blueColor, 'Current phase'),
          _legendRow(Colors.grey, 'Planned'),
          _legendRow(getRiskColor(), 'Risk signal'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _riskStatusPill(String riskText) {
    final color = getRiskColor();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_alt, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                riskText,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniToolChip(IconData icon, String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBimViewer(String bimUrl, String projectName, String riskText) {
    return Container(
      height: 575,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffeaf2ff), Color(0xffffffff)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Flutter3DViewer(
            controller: controller,
            src: bimUrl,
            enableTouch: true,
            onProgress: (progress) => debugPrint('3D loading: $progress'),
            onLoad: (modelAddress) => debugPrint('3D loaded: $modelAddress'),
            onError: (error) => debugPrint('3D error: $error'),
          ),
          _constructionProgressOverlay(),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: _glassContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: primaryColor.withOpacity(0.10),
                    child: const Icon(Icons.hub_outlined, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Digital Twin Live Model',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          projectName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${getStageName()} • ${_dateLabel(getSelectedDate())}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: timeProgress,
                          strokeWidth: 6,
                          color: primaryColor,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        Text(
                          '${(timeProgress * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _miniToolChip(Icons.view_in_ar, 'BIM + 4D Schedule'),
          ),
          Positioned(right: 16, bottom: 16, child: _riskStatusPill(riskText)),
        ],
      ),
    );
  }

  Widget _floatingModelButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: navy.withOpacity(0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveStrip() {
    final progress = (timeProgress * 100).round();
    final delayStatus = delayPredicted == true ? 'At Risk' : 'On Track';
    final delayDays =
        delayPredicted == true
            ? '${predictedDelayDays?.toStringAsFixed(1) ?? '--'} days'
            : '0 days';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _darkMetric('Overall Progress', '$progress%', Icons.donut_large),
              _darkDivider(),
              _darkMetric('Schedule Status', delayStatus, Icons.timeline),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _darkMetric('Predicted Delay', delayDays, Icons.schedule),
              _darkDivider(),
              _darkMetric(
                'Current Activity',
                getCurrentActivity(),
                Icons.engineering,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkDivider() =>
      Container(width: 1, height: 42, color: Colors.white12);

  Widget _darkMetric(String title, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.10),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isLoading = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withOpacity(0.12),
              child:
                  isLoading
                      ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      )
                      : Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoading ? 'Loading...' : value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayProbabilityCard() {
    if (delayProbability == null) return const SizedBox.shrink();

    final prob = delayProbability!.clamp(0.0, 1.0);
    final color = getDelayColor();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: color, size: 19),
              const SizedBox(width: 8),
              Text(
                'AI Delay Prediction',
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
              const Spacer(),
              Text(
                delayPredicted == true ? 'Risk Detected' : 'On Track',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: prob,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 9,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 8),
          Text(
            '${(prob * 100).toStringAsFixed(1)}% delay probability',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  // ================================
  // AI SCHEDULE ADJUSTMENT CARD
  // Displays the original project end date and the AI-adjusted end date.
  // If AI predicts a delay, the adjusted date adds the predicted delay days.
  // If the project returns to On Track, the adjusted date returns to baseline.
  // ================================
  Widget _buildAdjustedScheduleCard() {
    final originalEnd = getProjectEndDate();
    final adjustedEnd = getAdjustedEndDate();
    final delayDays =
        delayPredicted == true ? predictedDelayDays?.round() ?? 0 : 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available, color: primaryColor, size: 19),
              SizedBox(width: 8),
              Text(
                'AI Schedule Adjustment',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Original End Date: ${_dateLabel(originalEnd)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjusted End Date: ${_dateLabel(adjustedEnd)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            delayDays > 0
                ? 'Delay Impact: +$delayDays days'
                : 'Schedule is on track',
            style: TextStyle(
              color: delayDays > 0 ? orangeColor : greenColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffffd166)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: orangeColor,
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'AI Recommendations',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: orangeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: greenColor, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================
  // 4D CONSTRUCTION CALENDAR
  // Allows selecting dates to simulate construction progress
  // directly on the BIM model and update the progress overlay.
  // ================================
  Widget _buildCalendarTimeline() {
    final start = getProjectStartDate();
    final end = getProjectEndDate();
    final selected = getSelectedDate();
    final totalDays = (end.difference(start).inDays + 1).clamp(1, 365);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '4D Construction Calendar',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const Spacer(),
              Text(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                '${(timeProgress * 100).round()}%',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select a date to simulate construction progress directly on the BIM model.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              controller: ScrollController(
                initialScrollOffset:
                    getSelectedDate()
                        .difference(getProjectStartDate())
                        .inDays *
                    75,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: totalDays,
              itemBuilder: (context, index) {
                final date = start.add(Duration(days: index));

                // ================================
                // 4D CALENDAR DATE STATE FIX
                // Past days are completed and disabled.
                // Today is highlighted in navy.
                // Future days remain clickable for simulation.
                // ================================
                final today = getTodayWithinProjectRange();

                final cleanToday = DateTime(
                  today.year,
                  today.month,
                  today.day,
                );

                final cleanDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                );

                final isCompleted = cleanDate.isBefore(cleanToday);
                final isCurrentDay = cleanDate == cleanToday;
                final isFutureDay = cleanDate.isAfter(cleanToday);

                final isSelected =
                    date.year == selected.year &&
                    date.month == selected.month &&
                    date.day == selected.day;

                return GestureDetector(
                  onTap: isCompleted
                      ? null
                      : () {
                          setState(() {
                            selectedTimelineDate = date;
                            timeProgress = calculateProgressFromDate(date);
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 68,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xffecfdf5)
                          : isCurrentDay
                              ? primaryColor
                              : isSelected && isFutureDay
                                  ? primaryColor.withOpacity(0.10)
                                  : Colors.white,

                      borderRadius: BorderRadius.circular(18),

                      border: Border.all(
                        color: isCurrentDay
                            ? primaryColor
                            : isCompleted
                                ? greenColor.withOpacity(.35)
                                : isSelected && isFutureDay
                                    ? primaryColor.withOpacity(.55)
                                    : Colors.grey.shade300,
                      ),

                      boxShadow: [
                        if (isCurrentDay)
                          BoxShadow(
                            color: primaryColor.withOpacity(.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ][date.weekday - 1],

                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isCurrentDay
                                ? Colors.white70
                                : isCompleted
                                    ? greenColor.withOpacity(.75)
                                    : Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isCurrentDay
                                ? Colors.white
                                : isCompleted
                                    ? greenColor
                                    : navy,
                          ),
                        ),

                        Text(
                          '${date.month}/${date.year}',
                          style: TextStyle(
                            fontSize: 9,
                            color: isCurrentDay
                                ? Colors.white70
                                : isCompleted
                                    ? greenColor.withOpacity(.75)
                                    : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _buildActivityGantt(),
        ],
      ),
    );
  }

  Widget _buildActivityGantt() {
    final activities = [
      ('Foundation', (timeProgress / .20).clamp(0.0, 1.0), greenColor),

      (
        'Structure',
        timeProgress < .20 ? 0.0 : ((timeProgress - .20) / .25).clamp(0.0, 1.0),
        blueColor,
      ),

      (
        'Facade',
        timeProgress < .45 ? 0.0 : ((timeProgress - .45) / .25).clamp(0.0, 1.0),
        orangeColor,
      ),

      (
        'MEP',
        timeProgress < .70 ? 0.0 : ((timeProgress - .70) / .20).clamp(0.0, 1.0),
        purpleColor,
      ),

      (
        'Finishing',
        timeProgress < .90 ? 0.0 : ((timeProgress - .90) / .10).clamp(0.0, 1.0),
        greenColor,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Progress vs Plan',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...activities.map((item) {
          final name = item.$1;
          final value = item.$2;
          final color = item.$3;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 9,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiveDataPanel({
    required String rainText,
    required String tempText,
    required String humidityText,
    required String windText,
    required String riskText,
    required String delayText,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Live Site Intelligence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: greenColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: greenColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statusCard(
                title: 'Rain',
                value: rainText,
                icon: Icons.water,
                color: orangeColor,
                isLoading: isLoadingLiveData,
              ),
              const SizedBox(width: 10),
              _statusCard(
                title: 'Temperature',
                value: tempText,
                icon: Icons.thermostat,
                color: blueColor,
                isLoading: isLoadingLiveData,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusCard(
                title: 'Humidity',
                value: humidityText,
                icon: Icons.water_drop,
                color: Colors.teal,
                isLoading: isLoadingLiveData,
              ),
              const SizedBox(width: 10),
              _statusCard(
                title: 'Wind Speed',
                value: windText,
                icon: Icons.air,
                color: purpleColor,
                isLoading: isLoadingLiveData,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusCard(
                title: 'AI Risk',
                value: riskText,
                icon: Icons.warning_amber_rounded,
                color: getRiskColor(),
                isLoading: isLoadingAI,
              ),
              const SizedBox(width: 10),
              _statusCard(
                title: 'Delay',
                value: delayText,
                icon: Icons.schedule,
                color: delayPredicted == true ? redColor : greenColor,
                isLoading: isLoadingAI,
              ),
            ],
          ),
          _buildDelayProbabilityCard(),
          _buildAdjustedScheduleCard(),
          _buildRecommendationsCard(),
          _buildCalendarTimeline(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bimUrl = widget.project['bim_file_url']?.toString() ?? '';
    final projectName = widget.project['name']?.toString() ?? 'Project';

    final rainText =
        weatherRain == null
            ? 'Waiting'
            : '${weatherRain!.toStringAsFixed(1)} mm';
    final tempText =
        weatherTemperature == null
            ? 'Waiting'
            : '${weatherTemperature!.toStringAsFixed(1)}°C';
    final humidityText =
        weatherHumidity == null
            ? 'Waiting'
            : '${weatherHumidity!.toStringAsFixed(1)}%';
    final windText =
        weatherWind == null
            ? 'Waiting'
            : '${weatherWind!.toStringAsFixed(1)} km/h';

    final riskText =
        isLoadingAI
            ? 'Analyzing...'
            : riskLevel == null
            ? 'Waiting AI'
            : '${riskLabel ?? ''}';

    final delayText =
        isLoadingAI
            ? 'Analyzing...'
            : predictedDelayDays == null
            ? 'Waiting AI'
            : delayPredicted == true
            ? '${predictedDelayDays!.toStringAsFixed(1)} days'
            : 'On Track';

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Text(
              projectName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const Text(
              'Digital Twin Control Center',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadLiveData,
            icon: const Icon(Icons.refresh, color: primaryColor),
          ),
          IconButton(
            onPressed: toggleRotation,
            icon: Icon(
              autoRotate
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              color: primaryColor,
            ),
          ),
        ],
      ),
      body:
          bimUrl.isEmpty
              ? const Center(child: Text('No BIM model uploaded.'))
              : RefreshIndicator(
                onRefresh: loadLiveData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildBimViewer(bimUrl, projectName, riskText),
                      _buildExecutiveStrip(),
                      _buildLiveDataPanel(
                        rainText: rainText,
                        tempText: tempText,
                        humidityText: humidityText,
                        windText: windText,
                        riskText: riskText,
                        delayText: delayText,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
