import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  bool isLoading = true;

  WorkerTrackingDashboardData? dashboardData;

  String get projectId => widget.project['id'].toString();

  double get projectLat {
    return double.tryParse(widget.project['latitude']?.toString() ?? '') ??
        21.543333;
  }

  double get projectLng {
    return double.tryParse(widget.project['longitude']?.toString() ?? '') ??
        39.172779;
  }

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() => isLoading = true);

    final data = await trackingService.getDashboardData(projectId: projectId);

    if (!mounted) return;

    setState(() {
      dashboardData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboardData;

    return RefreshIndicator(
      onRefresh: loadDashboard,
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
            childAspectRatio: 1.45,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              monitorCard(
                icon: Icons.groups_rounded,
                title: "Live Workers",
                value: isLoading ? "..." : "${data?.activeWorkers ?? 0}",
                subtitle: "From tracking API",
                color: Colors.blue,
                onTap: widget.onAttendanceTap,
              ),
              monitorCard(
                icon: Icons.warning_amber_rounded,
                title: "Safety Alerts",
                value: isLoading ? "..." : "${data?.activeAlerts ?? 0}",
                subtitle: "API safety alerts",
                color: Colors.red,
                onTap: () {},
              ),
              monitorCard(
                icon: Icons.map_rounded,
                title: "Heat Zones",
                value: isLoading ? "..." : "${data?.zones.length ?? 0}",
                subtitle: "Worker risk zones",
                color: Colors.purple,
                onTap: () {},
              ),
              monitorCard(
                icon: Icons.precision_manufacturing_rounded,
                title: "Equipment",
                value: "Open",
                subtitle: "View equipment tab",
                color: Colors.orange,
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

    final LatLng center =
        workers.isNotEmpty
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
      markers.add(
        Marker(
          markerId: MarkerId(worker.workerId),
          position: LatLng(worker.latitude, worker.longitude),
          infoWindow: InfoWindow(
            title: worker.workerName,
            snippet: "${worker.status} • ${worker.riskLevel}",
          ),
          icon:
              worker.alert == 1
                  ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  )
                  : BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
        ),
      );
    }

    final circles =
        zones.map((zone) {
          final isHigh = zone.riskLevel.toLowerCase() == 'high';

          return Circle(
            circleId: CircleId(zone.id),
            center: LatLng(zone.latitude, zone.longitude),
            radius: zone.radius,
            fillColor:
                isHigh
                    ? Colors.red.withOpacity(0.18)
                    : Colors.green.withOpacity(0.14),
            strokeColor: isHigh ? Colors.red : Colors.green,
            strokeWidth: 2,
          );
        }).toSet();

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: workers.isNotEmpty ? 16 : 14,
            ),
            markers: markers,
            circles: circles,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    workers.any((w) => w.alert == 1)
                        ? Icons.warning_amber
                        : Icons.location_on,
                    color:
                        workers.any((w) => w.alert == 1)
                            ? Colors.red
                            : Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isLoading
                        ? "Loading worker API..."
                        : workers.isEmpty
                        ? "No live workers"
                        : "Live Worker Tracking",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
              Icon(Icons.analytics_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Worker Tracking API Summary",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          statusRow("Live workers", "${data?.activeWorkers ?? 0}"),
          statusRow("Safety alerts", "${data?.activeAlerts ?? 0}"),
          statusRow("Heat / risk zones", "${data?.zones.length ?? 0}"),
          statusRow(
            "Avg temperature",
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
