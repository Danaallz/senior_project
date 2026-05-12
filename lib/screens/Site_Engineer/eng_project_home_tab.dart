import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/screens/Site_Engineer/lib/screens/Site_Engineer/worker_tracking_api_service.dart';

class EngProjectHomeTab extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback onAttendanceTap;
  final VoidCallback onEquipmentTap;

  const EngProjectHomeTab({
    super.key,
    required this.project,
    required this.onAttendanceTap,
    required this.onEquipmentTap,
  });

  @override
  State<EngProjectHomeTab> createState() => _EngProjectHomeTabState();
}

class _EngProjectHomeTabState extends State<EngProjectHomeTab> {
  final WorkerTrackingApiService trackingService = WorkerTrackingApiService();
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  WorkerTrackingDashboardData? dashboardData;
  List<Map<String, dynamic>> presentWorkers = [];

  GoogleMapController? workerMapController;
  BitmapDescriptor? safeWorkerIcon;
  BitmapDescriptor? riskWorkerIcon;
  Timer? liveRefreshTimer;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color blueColor = Color(0xff1e9cf0);
  static const Color redColor = Color(0xffef4444);
  static const Color purpleColor = Color(0xff9c27b0);
  static const Color orangeColor = Color(0xffff9800);

  String get projectId => widget.project['id'].toString();

  double get projectLat {
    return double.tryParse(widget.project['latitude']?.toString() ?? '') ??
        21.543333;
  }

  double get projectLng {
    return double.tryParse(widget.project['longitude']?.toString() ?? '') ??
        39.172779;
  }

  String get todayDate {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    prepareWorkerMarkers();
    loadDashboard();

    // ================================
    // LIVE GPS REFRESH
    // Refreshes the worker positions every few seconds.
    // If the API is demo/simulation, this makes workers appear moving.
    // ================================
    liveRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) loadDashboard(showLoading: false);
    });
  }

  @override
  void dispose() {
    liveRefreshTimer?.cancel();
    workerMapController?.dispose();
    super.dispose();
  }

  Future<void> prepareWorkerMarkers() async {
    safeWorkerIcon = await createWorkerMarkerIcon(
      iconColor: blueColor,
      hasAlert: false,
    );

    riskWorkerIcon = await createWorkerMarkerIcon(
      iconColor: redColor,
      hasAlert: true,
    );

    if (mounted) setState(() {});
  }

  Future<void> loadDashboard({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => isLoading = true);
    }

    final workers = await loadPresentWorkers();

    final data = await trackingService.getDashboardData(
      projectId: projectId,
      workerCount: workers.length,
      latitude: projectLat,
      longitude: projectLng,
      assignedWorkers: workers,
    );

    if (!mounted) return;

    setState(() {
      presentWorkers = workers;
      dashboardData = data;
      isLoading = false;
    });

    final liveWorkers = data.liveWorkers;
    if (liveWorkers.isNotEmpty) {
      workerMapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(liveWorkers.first.latitude, liveWorkers.first.longitude),
        ),
      );
    }
  }

  // ================================
  // LOAD PRESENT WORKERS ONLY
  // First checks attendance table for today's Present workers.
  // If no attendance record exists today, it falls back to project_workers
  // for demo purposes so the map does not stay empty during presentation.
  // ================================
  Future<List<Map<String, dynamic>>> loadPresentWorkers() async {
    try {
      final attendanceResponse = await supabase
          .from('attendance')
          .select()
          .eq('project_id', projectId)
          .eq('attendance_date', todayDate)
          .eq('status', 'Present');

      final attendanceList =
          List<Map<String, dynamic>>.from(attendanceResponse);

      if (attendanceList.isNotEmpty) {
        final ids = attendanceList
            .map((item) => item['worker_id'])
            .where((id) => id != null)
            .toList();

        if (ids.isNotEmpty) {
          final workersResponse =
              await supabase.from('workers').select().inFilter('id', ids);

          final workers = List<Map<String, dynamic>>.from(workersResponse);

          return workers.map((worker) {
            return {
              ...worker,
              'attendance_status': 'Present',
            };
          }).toList();
        }

        // If attendance has names but no IDs, still show demo markers.
        return attendanceList.map((item) {
          return {
            'id': item['worker_id'] ?? item['id'],
            'name': item['worker_name'] ?? 'Worker',
            'role': item['role'] ?? 'Worker',
            'attendance_status': 'Present',
          };
        }).toList();
      }

      // ================================
      // PRESENT WORKERS ONLY FIX
      // If there are no Present attendance records today,
      // do NOT fallback to project_workers.
      // This prevents absent workers and the site engineer
      // from appearing on the live worker map.
      // ================================
      return [];
    } catch (e) {
      debugPrint('Present workers load error: $e');
      return [];
    }
  }

  Future<BitmapDescriptor> createWorkerMarkerIcon({
    required Color iconColor,
    required bool hasAlert,
  }) async {
    const double size = 126;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final colorPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    final softPaint = Paint()
      ..color = iconColor.withOpacity(.13)
      ..style = PaintingStyle.fill;

    final center = Offset(size / 2, 54);

    // Pin shape
    canvas.drawCircle(center.translate(0, 4), 38, shadowPaint);
    canvas.drawCircle(center, 38, whitePaint);
    canvas.drawCircle(center, 29, softPaint);

    final path = Path()
      ..moveTo(size / 2 - 13, 86)
      ..lineTo(size / 2 + 13, 86)
      ..lineTo(size / 2, 112)
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
    canvas.drawPath(path, colorPaint);

    final icon = hasAlert ? Icons.warning_amber_rounded : Icons.person_pin_circle;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 44,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: iconColor,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, center.dy - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboardData;

    return RefreshIndicator(
      onRefresh: () => loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
        children: [
          buildWorkerTrackingMap(),
          const SizedBox(height: 18),
          const Text(
            "Real-Time Monitoring",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.18,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              monitorCard(
                icon: Icons.groups_rounded,
                title: "Live Workers",
                value: isLoading ? "..." : "${data?.activeWorkers ?? 0}",
                subtitle: "Present workers only",
                color: blueColor,
                onTap: widget.onAttendanceTap,
              ),
              monitorCard(
                icon: Icons.warning_amber_rounded,
                title: "Safety Alerts",
                value: isLoading ? "..." : "${data?.activeAlerts ?? 0}",
                subtitle: "Helmet alerts",
                color: redColor,
                onTap: () {},
              ),
              monitorCard(
                icon: Icons.map_rounded,
                title: "Heat Zones",
                value: isLoading ? "..." : "${data?.zones.length ?? 0}",
                subtitle: "Worker risk zones",
                color: purpleColor,
                onTap: () {},
              ),
              monitorCard(
                icon: Icons.precision_manufacturing_rounded,
                title: "Equipment",
                value: "Open",
                subtitle: "Tracking map",
                color: orangeColor,
                onTap: widget.onEquipmentTap,
              ),
            ],
          ),
          const SizedBox(height: 18),
          buildStatusSection(),
        ],
      ),
    );
  }

  Widget buildWorkerTrackingMap() {
    final data = dashboardData;
    final workers = data?.liveWorkers ?? [];
    final zones = data?.zones ?? [];

    final center = workers.isNotEmpty
        ? LatLng(workers.first.latitude, workers.first.longitude)
        : LatLng(projectLat, projectLng);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId("project"),
        position: LatLng(projectLat, projectLng),
        infoWindow: const InfoWindow(title: "Project Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };

    for (final worker in workers) {
      final hasAlert =
          worker.alert == 1 || worker.riskLevel.toLowerCase() == 'high';

      markers.add(
        Marker(
          markerId: MarkerId(worker.workerId),
          position: LatLng(worker.latitude, worker.longitude),
          icon: hasAlert
              ? riskWorkerIcon ?? BitmapDescriptor.defaultMarker
              : safeWorkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: worker.workerName,
            snippet: "${worker.role} • ${worker.status} • ${worker.riskLevel}",
          ),
          onTap: () => showWorkerSheet(worker),
        ),
      );
    }

    final circles = zones.map((zone) {
      final isHigh = zone.riskLevel.toLowerCase() == 'high';

      return Circle(
        circleId: CircleId(zone.id),
        center: LatLng(zone.latitude, zone.longitude),
        radius: zone.radius,
        fillColor:
            isHigh ? Colors.red.withOpacity(0.14) : blueColor.withOpacity(0.10),
        strokeColor: isHigh ? Colors.red : blueColor,
        strokeWidth: 2,
      );
    }).toSet();

    return Container(
      height: 235,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xffe8f5ff), Color(0xffffffff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: workers.isNotEmpty ? 18.2 : 16,
              tilt: 35,
              bearing: 12,
            ),
            onMapCreated: (controller) {
              workerMapController = controller;

              Future.delayed(const Duration(milliseconds: 500), () {
                workerMapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: center,
                      zoom: workers.isNotEmpty ? 18.7 : 16.5,
                      tilt: 48,
                      bearing: 18,
                    ),
                  ),
                );
              });
            },
            markers: markers,
            // circles removed for cleaner map
            mapType: MapType.hybrid,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            buildingsEnabled: false,
            trafficEnabled: false,
            mapToolbarEnabled: false,
            indoorViewEnabled: false,
          ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: mapBadge(
                    icon: Icons.person_pin_circle,
                    text: isLoading
                        ? "Checking attendance + GPS..."
                        : workers.isEmpty
                            ? "No present workers today"
                            : "${workers.length} present workers live",
                    color: blueColor,
                  ),
                ),
                const SizedBox(width: 8),
                mapBadge(
                  icon: Icons.refresh,
                  text: "Refresh",
                  color: primaryColor,
                  onTap: () => loadDashboard(),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 12,
            left: 12,
            child: mapBadge(
              icon: Icons.sensors,
              text: "Helmet GPS API",
              color: primaryColor,
            ),
          ),

          Positioned(
            bottom: 12,
            right: 12,
            child: mapBadge(
              icon: Icons.how_to_reg,
              text: "Present only",
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget mapBadge({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.09),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showWorkerSheet(LiveWorker worker) {
    final hasAlert =
        worker.alert == 1 || worker.riskLevel.toLowerCase() == 'high';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor:
                      hasAlert ? Colors.red.withOpacity(.12) : blueColor.withOpacity(.12),
                  child: Icon(
                    hasAlert ? Icons.warning_amber_rounded : Icons.engineering,
                    color: hasAlert ? Colors.red : blueColor,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.workerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        worker.role,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      workerInfoRow("Attendance", "Present"),
                      workerInfoRow("Live status", worker.status),
                      workerInfoRow("Risk", worker.riskLevel),
                      workerInfoRow(
                        "Helmet temperature",
                        "${worker.temperature.toStringAsFixed(1)}°C",
                      ),
                      workerInfoRow(
                        "GPS",
                        "${worker.latitude.toStringAsFixed(5)}, ${worker.longitude.toStringAsFixed(5)}",
                      ),
                      if (worker.lastUpdate.isNotEmpty)
                        workerInfoRow("Last update", worker.lastUpdate),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget workerInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusSection() {
    final data = dashboardData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: blueColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Worker Tracking API Summary",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          statusRow("Present workers", "${presentWorkers.length}"),
          statusRow("Live GPS markers", "${data?.activeWorkers ?? 0}"),
          statusRow("Safety alerts", "${data?.activeAlerts ?? 0}"),
          statusRow("Heat / risk zones", "${data?.zones.length ?? 0}"),
          statusRow(
            "Avg helmet temperature",
            "${data?.averageTemperature.toStringAsFixed(1) ?? '0'}°C",
          ),
        ],
      ),
    );
  }

  Widget monitorCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
