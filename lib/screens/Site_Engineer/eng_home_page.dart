import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:senior_project/screens/Manager/alerts_page.dart';
import 'package:senior_project/screens/Site_Engineer/Eng_main_layout.dart';
import 'package:senior_project/screens/Site_Engineer/eng_attendance.dart';
import 'package:senior_project/screens/Site_Engineer/eng_workers_tab.dart';

class EngHomePage extends StatefulWidget {
  const EngHomePage({super.key});

  @override
  State<EngHomePage> createState() => _EngHomePageState();
}

class _EngHomePageState extends State<EngHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> tabs = [
    "Home",
    "Tasks",
    "Workers",
    "Attendance",
    "Equipment",
  ];

  static const LatLng projectLocation = LatLng(21.5851, 39.1925);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return EngMainLayout(
      tabController: _tabController,
      tabs: tabs,

      tabContent: (selectedProjectId) {
        return TabBarView(
          controller: _tabController,
          children: [
            buildHomeTab(),

            const Center(
              child: Text("Assigned Tasks", style: TextStyle(fontSize: 18)),
            ),

            EngWorkersTab(projectId: selectedProjectId),

            EngAttendanceTab(projectId: selectedProjectId),

            const Center(
              child: Text("Equipment Status", style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },

      onMenuTap: () {},

      onNotificationTap: () {
        openPage(const AlertsPage());
      },

      onIotTap: () {
        openPage(
          const SimpleEngineerPage(
            title: "IoT Sensors Dashboard",
            icon: Icons.sensors_rounded,
            description:
                "Monitor all connected IoT sensors in the construction site including GPS devices, motion sensors, smoke sensors, gas sensors, vibration sensors, and equipment sensor status.",
          ),
        );
      },

      onDigitalTwinTap: () {
        openPage(
          const SimpleEngineerPage(
            title: "Real-Time Digital Twin",
            icon: Icons.view_in_ar_rounded,
            description:
                "View the live digital twin of the construction site including worker locations, equipment movement, restricted zones, and real-time monitoring data.",
          ),
        );
      },

      onEnvironmentTap: () {
        openPage(
          const SimpleEngineerPage(
            title: "Environment Data",
            icon: Icons.thermostat_rounded,
            description:
                "View real-time site environment readings such as temperature, humidity, air quality, dust level, wind speed, and heat risk conditions from IoT sensors.",
          ),
        );
      },
    );
  }

  Widget buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        buildLiveWorkersMap(),
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
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            buildMonitorCard(
              icon: Icons.groups_rounded,
              title: "Attendance",
              value: "42 / 50",
              subtitle: "Workers checked in",
              color: Colors.blue,
              onTap: () => _tabController.animateTo(3),
            ),
            buildMonitorCard(
              icon: Icons.warning_amber_rounded,
              title: "Safety Alerts",
              value: "3",
              subtitle: "Needs review",
              color: Colors.red,
              onTap: () => openPage(const AlertsPage()),
            ),
            buildMonitorCard(
              icon: Icons.precision_manufacturing_rounded,
              title: "Equipment",
              value: "12 Active",
              subtitle: "2 need inspection",
              color: Colors.orange,
              onTap: () => _tabController.animateTo(4),
            ),
            buildMonitorCard(
              icon: Icons.thermostat_rounded,
              title: "Environment",
              value: "34°C",
              subtitle: "Normal humidity",
              color: Colors.green,
              onTap: () {
                openPage(
                  const SimpleEngineerPage(
                    title: "Environment Data",
                    icon: Icons.thermostat_rounded,
                    description:
                        "Live temperature, humidity, air quality, and site environment readings from IoT sensors.",
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        buildSectionCard(
          title: "Current Site Status",
          icon: Icons.sensors_rounded,
          children: const [
            StatusRow(label: "IoT sensors", value: "Online"),
            StatusRow(label: "GPS tracking", value: "Active"),
            StatusRow(label: "Restricted zones", value: "2 alerts"),
            StatusRow(label: "Last update", value: "Live"),
          ],
        ),
      ],
    );
  }

  Widget buildLiveWorkersMap() {
    final databaseRef = FirebaseDatabase.instance.ref();

    return Container(
      height: 220,
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
      child: StreamBuilder<DatabaseEvent>(
        stream: databaseRef.onValue,
        builder: (context, snapshot) {
          final Set<Marker> markers = {
            const Marker(
              markerId: MarkerId("project"),
              position: projectLocation,
              infoWindow: InfoWindow(title: "Monte Tower Project"),
              icon: BitmapDescriptor.defaultMarker,
            ),
          };

          double temperature = 0;
          double humidity = 0;
          int alert = 0;

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            data.forEach((key, value) {
              if (value is Map) {
                final lat = double.tryParse(value['gps_lat'].toString()) ?? 0;
                final lng = double.tryParse(value['gps_lng'].toString()) ?? 0;

                temperature =
                    double.tryParse(value['temperature'].toString()) ?? 0;

                humidity = double.tryParse(value['humidity'].toString()) ?? 0;

                alert = int.tryParse(value['alert'].toString()) ?? 0;

                if (lat != 0 && lng != 0) {
                  markers.add(
                    Marker(
                      markerId: MarkerId(key.toString()),
                      position: LatLng(lat, lng),
                      infoWindow: InfoWindow(
                        title: "Worker Device",
                        snippet:
                            alert == 1
                                ? "Safety Alert Detected"
                                : "Worker Active",
                      ),
                      icon:
                          alert == 1
                              ? BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              )
                              : BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure,
                              ),
                    ),
                  );
                }
              }
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: projectLocation,
                  zoom: 15,
                ),
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        alert == 1
                            ? "Live Alert Active"
                            : "Live Worker Locations",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: sensorOverlayCard(
                        icon: Icons.thermostat,
                        title: "Temperature",
                        value: "${temperature.toStringAsFixed(1)}°C",
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: sensorOverlayCard(
                        icon: Icons.water_drop,
                        title: "Humidity",
                        value: "${humidity.toStringAsFixed(0)}%",
                        color: Colors.blue,
                      ),
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

  Widget sensorOverlayCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMonitorCard({
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const StatusRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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

class SimpleEngineerPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const SimpleEngineerPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(title),
      ),

      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.blue.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: Colors.blue),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
