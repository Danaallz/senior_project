import 'package:flutter/material.dart';

import 'package:senior_project/screens/digital_twin_page.dart';
import 'package:senior_project/screens/Manager/alerts_page.dart';
import 'Eng_main_layout.dart';
import 'eng_attendance.dart';
import 'eng_workers_tab.dart';
import 'eng_task_progress_update.dart';
import 'eng_sensors_dashboard.dart';
import 'eng_environment_page.dart';
import 'eng_materials_page.dart';
import 'eng_equipment_page.dart';
import 'eng_project_home_tab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClient = Supabase.instance.client;

class EngHomePage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EngHomePage({super.key, required this.project});

  @override
  State<EngHomePage> createState() => _EngHomePageState();
}

class _EngHomePageState extends State<EngHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> tabs = [
    'Home',
    'Tasks',
    'Workers',
    'Attendance',
    'Material',
    'Equipment',
  ];

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
    final projectId = widget.project['id']?.toString() ?? '';

    return EngMainLayout(
      project: widget.project,
      tabController: _tabController,
      tabs: tabs,
      tabContent: () {
        return TabBarView(
          controller: _tabController,
          children: [
            EngProjectHomeTab(
              project: widget.project,
              onAttendanceTap: () => _tabController.animateTo(3),
              onEquipmentTap: () => _tabController.animateTo(5),
            ),
            EngTasksTab(projectId: projectId),
            EngWorkersTab(projectId: projectId),
            EngAttendanceTab(projectId: projectId),
            EngMaterialsPage(project: widget.project),
            EngEquipmentPage(project: widget.project),
          ],
        );
      },
      onNotificationTap: () => openPage(const AlertsPage()),
      onIotTap: () => openPage(const EngSensorsDashboard()),
      onDigitalTwinTap:
          () => openPage(DigitalTwinPage(project: widget.project)),
      onEnvironmentTap:
          () => openPage(EngEnvironmentPage(project: widget.project)),
    );
  }
}

class EngTasksTab extends StatefulWidget {
  final String projectId;

  const EngTasksTab({super.key, required this.projectId});

  @override
  State<EngTasksTab> createState() => _EngTasksTabState();
}

class _EngTasksTabState extends State<EngTasksTab> {
  final supabase = supabaseClient;
  bool isLoading = true;
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final response = await supabase
          .from('tasks')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        tasks = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load tasks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (tasks.isEmpty) return const Center(child: Text('No assigned tasks'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final description = task['description']?.toString() ?? 'Task';
        final status = task['status']?.toString() ?? 'Not Started';
        final percent =
            int.tryParse(task['progress_percent']?.toString() ?? '0') ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: percent / 100),
              const SizedBox(height: 8),
              Text('$percent% completed • $status'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EngTaskProgressUpdate(task: task),
                      ),
                    );

                    if (result == true) loadTasks();
                  },
                  child: const Text('Update Progress'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
