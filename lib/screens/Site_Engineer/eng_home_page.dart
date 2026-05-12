import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String searchQuery = '';

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

  List<Map<String, dynamic>> get filteredTasks {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return tasks;

    return tasks.where((task) {
      final description = task['description']?.toString().toLowerCase() ?? '';
      final status = task['status']?.toString().toLowerCase() ?? '';
      final unit = task['progress_unit']?.toString().toLowerCase() ?? '';

      return description.contains(query) ||
          status.contains(query) ||
          unit.contains(query);
    }).toList();
  }

  Color progressColor(int percent) {
    if (percent >= 88) return Colors.green;
    if (percent >= 50) return const Color.fromARGB(255, 139, 209, 47);
    if (percent >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search tasks...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        Expanded(
          child:
              filteredTasks.isEmpty
                  ? const Center(
                    child: Text(
                      'No tasks found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: loadTasks,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];

                        final description =
                            task['description']?.toString() ?? 'Task';

                        final status =
                            task['status']?.toString() ?? 'Not Started';

                        final percent =
                            int.tryParse(
                              task['progress_percent']?.toString() ?? '0',
                            ) ??
                            0;

                        final estimated =
                            double.tryParse(
                              task['est_quantity']?.toString() ?? '0',
                            ) ??
                            0;

                        final completed =
                            double.tryParse(
                              task['completed_quantity']?.toString() ?? '0',
                            ) ??
                            0;

                        final unit =
                            task['progress_unit']?.toString() ?? 'unit';

                        final color = progressColor(percent);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: color.withOpacity(0.18)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: (percent / 100).clamp(0.0, 1.0),
                                  minHeight: 9,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    color,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Text(
                                    '$percent% completed',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$completed / $estimated $unit',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => EngTaskProgressUpdate(
                                              task: task,
                                            ),
                                      ),
                                    );

                                    if (result == true) {
                                      loadTasks();
                                    }
                                  },
                                  child: const Text(
                                    'Update Progress >',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}
