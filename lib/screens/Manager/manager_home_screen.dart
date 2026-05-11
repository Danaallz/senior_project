import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerHomeScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ManagerHomeScreen({super.key, required this.project});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  int tasksCount = 0;
  int workersCount = 0;
  int materialsCount = 0;
  int equipmentCount = 0;

  static const Color primaryColor = Color(0xff0d1b46);

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadDashboardData() async {
    try {
      final projectId = widget.project['id'].toString();

      final tasks = await supabase
          .from('tasks')
          .select('id')
          .eq('project_id', projectId);

      final workers = await supabase
          .from('project_workers')
          .select('id')
          .eq('project_id', projectId);

      final materials = await supabase
          .from('project_materials')
          .select('id')
          .eq('project_id', projectId);

      final equipment = await supabase
          .from('project_equipment')
          .select('id')
          .eq('project_id', projectId);

      if (!mounted) return;

      setState(() {
        tasksCount = tasks.length;
        workersCount = workers.length;
        materialsCount = materials.length;
        equipmentCount = equipment.length;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load dashboard: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int get projectProgress {
    return int.tryParse(widget.project['progress']?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final projectName =
        cleanText(widget.project['name']).isEmpty
            ? "Project"
            : cleanText(widget.project['name']);

    final location =
        cleanText(widget.project['location']).isEmpty
            ? cleanText(widget.project['city'])
            : cleanText(widget.project['location']);

    final startDate = cleanText(widget.project['start_date']).split('T').first;
    final endDate = cleanText(widget.project['end_date']).split('T').first;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Project Dashboard",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  projectName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(location, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: darkInfoBox("Start", startDate)),
                    const SizedBox(width: 10),
                    Expanded(child: darkInfoBox("End", endDate)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Progress",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: projectProgress.clamp(0, 100) / 100,
                  minHeight: 10,
                  color: primaryColor,
                  backgroundColor: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 10),
                Text(
                  "$projectProgress% completed",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: dashboardCard(
                  title: "Tasks",
                  value: "$tasksCount",
                  icon: Icons.task_alt,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: dashboardCard(
                  title: "Workers",
                  value: "$workersCount",
                  icon: Icons.people_alt,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: dashboardCard(
                  title: "Materials",
                  value: "$materialsCount",
                  icon: Icons.inventory_2,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: dashboardCard(
                  title: "Equipment",
                  value: "$equipmentCount",
                  icon: Icons.construction,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              border: Border.all(color: Colors.orange.withOpacity(0.18)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Use the tabs above to manage tasks, workers, attendance, materials, equipment, and digital twin monitoring.",
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget darkInfoBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? "-" : value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.16)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
