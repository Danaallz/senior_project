import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/screens/Manager/Workers.dart';
import 'package:senior_project/screens/Manager/alerts_page.dart';
import 'package:senior_project/screens/Manager/manager_attendance.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final supabase = Supabase.instance.client;

  final String projectImageUrl =
      "https://yourneighbourhood.com.au/wp-content/uploads/5-Hercules-Street-Hamilton-2.jpg";

  final List<String> tabs = [
    "Home",
    "Digital Twin",
    "Tasks",
    "Workers",
    "Attendance",
    "Material",
    "Equipment",
  ];

  List<Map<String, dynamic>> projects = [];
  Map<String, dynamic>? selectedProject;
  bool isLoadingProjects = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    loadAssignedProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String getText(
    Map<String, dynamic>? data,
    List<String> keys,
    String fallback,
  ) {
    if (data == null) return fallback;

    for (final key in keys) {
      if (data[key] != null && data[key].toString().trim().isNotEmpty) {
        return data[key].toString();
      }
    }

    return fallback;
  }

  Future<void> loadAssignedProjects() async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        setState(() {
          projects = [];
          selectedProject = null;
          isLoadingProjects = false;
        });
        return;
      }

      final response = await supabase
          .from('manager_projects')
          .select('projects(*)')
          .eq('manager_id', currentUser.id)
          .order('assigned_at', ascending: false);

      final assignedProjects = <Map<String, dynamic>>[];

      for (final item in response) {
        final project = item['projects'];
        if (project != null) {
          assignedProjects.add(Map<String, dynamic>.from(project));
        }
      }

      if (!mounted) return;

      setState(() {
        projects = assignedProjects;
        selectedProject =
            assignedProjects.isNotEmpty ? assignedProjects.first : null;
        isLoadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingProjects = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading assigned projects: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showProjectsDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Assigned Projects",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (projects.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No assigned projects found"),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];

                      final name = getText(project, [
                        'name',
                        'project_name',
                        'title',
                      ], 'Unnamed Project');

                      final location = getText(project, [
                        'location',
                        'address',
                        'project_location',
                      ], 'No location');

                      final status = getText(project, [
                        'status',
                        'project_status',
                      ], 'In Progress');

                      final selectedId = selectedProject?['id']?.toString();
                      final projectId = project['id']?.toString();
                      final isSelected = selectedId == projectId;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedProject = project;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.blue.withOpacity(0.08)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.blue
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                color: isSelected ? Colors.blue : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      location,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status.toLowerCase().contains("planning")
                                          ? Colors.blue.shade100
                                          : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color:
                                        status.toLowerCase().contains(
                                              "planning",
                                            )
                                            ? Colors.blue
                                            : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildHeader() {
    final projectName = getText(selectedProject, [
      'name',
      'project_name',
      'title',
    ], 'No Project Selected');

    final projectLocation = getText(selectedProject, [
      'location',
      'address',
      'project_location',
    ], 'No assigned project location');

    final projectStatus = getText(selectedProject, [
      'status',
      'project_status',
    ], 'Not Assigned');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu, size: 30),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlertsPage()),
                );
              },
              child: const Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_outlined, size: 28),
                  Positioned(
                    right: -4,
                    top: -5,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.red,
                      child: Text(
                        "3",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                projectImageUrl,
                width: 78,
                height: 78,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 78,
                    height: 78,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 32),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child:
                  isLoadingProjects
                      ? const LinearProgressIndicator()
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: showProjectsDropdown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Project management",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            projectLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  projectStatus.toLowerCase().contains(
                                        "planning",
                                      )
                                      ? Colors.blue.shade100
                                      : projectStatus.toLowerCase().contains(
                                        "not assigned",
                                      )
                                      ? Colors.grey.shade200
                                      : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              projectStatus,
                              style: TextStyle(
                                color:
                                    projectStatus.toLowerCase().contains(
                                          "planning",
                                        )
                                        ? Colors.blue
                                        : projectStatus.toLowerCase().contains(
                                          "not assigned",
                                        )
                                        ? Colors.grey
                                        : Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildTabBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.blue,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        buildSimpleTab(
          icon: Icons.dashboard_rounded,
          title: "Manager Home",
          subtitle:
              "Overview of ${getText(selectedProject, ['name', 'project_name', 'title'], 'the selected project')}.",
        ),
        buildSimpleTab(
          icon: Icons.view_in_ar_rounded,
          title: "Digital Twin",
          subtitle:
              "Connect your Digital Twin screen here. This tab can show project simulation, progress visualization, IoT site status, and real-time monitoring.",
        ),
        buildSimpleTab(
          icon: Icons.task_alt_rounded,
          title: "Tasks",
          subtitle: "View and manage project tasks.",
        ),
        const WorkersTab(),
        ManagerAttendanceTab(projectId: selectedProject?['id']),
        buildSimpleTab(
          icon: Icons.inventory_2_rounded,
          title: "Material",
          subtitle: "Monitor project materials and stock levels.",
        ),
        buildSimpleTab(
          icon: Icons.construction_rounded,
          title: "Equipment",
          subtitle: "View equipment status and maintenance needs.",
        ),
      ],
    );
  }

  Widget buildSimpleTab({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
            Icon(icon, size: 56, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
              child: buildHeader(),
            ),
            Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: buildTabBar(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
