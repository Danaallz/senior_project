import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/screens/digital_twin_page.dart';
import 'package:senior_project/screens/Manager/Workers.dart';
import 'package:senior_project/screens/Manager/manager_attendance.dart';
import 'package:senior_project/screens/Manager/manager_home_screen.dart';
import 'package:senior_project/screens/Manager/manager_tasks_tab.dart';
import 'package:senior_project/screens/Manager/project_equipment_page.dart';
import 'package:senior_project/screens/Manager/project_materials_page.dart';
import '../notification_bell.dart';

class ProjectScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;
  int currentTabIndex = 0;

  Map<String, dynamic>? managerProfile;

  static const Color primaryColor = Color(0xff0d1b46);

  final List<String> tabs = [
    "Home",
    "Digital Twin",
    "Tasks",
    "Workers",
    "Attendance",
    "Material",
    "Equipment",
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: tabs.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => currentTabIndex = _tabController.index);
      }
    });

    loadManagerProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool isValidImageUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  String get projectId => widget.project['id'].toString();

  String get projectName {
    return cleanText(widget.project['name']).isEmpty
        ? "Project"
        : cleanText(widget.project['name']);
  }

  String get projectLocation {
    return cleanText(widget.project['location']).isEmpty
        ? cleanText(widget.project['city'])
        : cleanText(widget.project['location']);
  }

  String get projectStatus {
    return cleanText(widget.project['status']).isEmpty
        ? "In Progress"
        : cleanText(widget.project['status']);
  }

  String get projectImageUrl => cleanText(widget.project['image_url']);

  double? get projectLatitude {
    return double.tryParse(widget.project['latitude']?.toString() ?? '');
  }

  double? get projectLongitude {
    return double.tryParse(widget.project['longitude']?.toString() ?? '');
  }

  String get managerName {
    return cleanText(managerProfile?['full_name']).isNotEmpty
        ? cleanText(managerProfile?['full_name'])
        : cleanText(managerProfile?['name']).isNotEmpty
        ? cleanText(managerProfile?['name'])
        : "Manager";
  }

  String get managerImageUrl {
    return cleanText(managerProfile?['profile_image_url']).isNotEmpty
        ? cleanText(managerProfile?['profile_image_url'])
        : cleanText(managerProfile?['image_url']);
  }

  Future<void> loadManagerProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response =
        await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

    if (!mounted) return;

    setState(() {
      managerProfile = response;
    });
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget buildSidebar() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        isValidImageUrl(managerImageUrl)
                            ? NetworkImage(managerImageUrl)
                            : null,
                    child:
                        isValidImageUrl(managerImageUrl)
                            ? null
                            : const Icon(Icons.person, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      managerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              const Text(
                "MENUS",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text("Manager Home"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("Account Settings"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text("Customer Support"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/customerSupport');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("About us"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/aboutUs');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Log out",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(Icons.menu, size: 28),
                ),
                const Spacer(),
                // ================================
                // MANAGER NOTIFICATION BELL
                // Replaces the static alerts icon with the real notification bell.
                // It opens NotificationsPage and shows unread count for the manager.
                // ================================
                NotificationBell(
                  color: primaryColor,
                  onClosed: loadManagerProfile,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      isValidImageUrl(projectImageUrl)
                          ? Image.network(
                            projectImageUrl,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => projectPlaceholder(),
                          )
                          : projectPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Project management",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
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
                      statusChip(projectStatus),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget projectPlaceholder() {
    return Container(
      width: 78,
      height: 78,
      color: Colors.grey.shade200,
      child: const Icon(Icons.apartment, color: Colors.grey),
    );
  }

  Widget statusChip(String status) {
    final lower = status.toLowerCase();

    Color color = Colors.orange;

    if (lower == 'completed') {
      color = Colors.green;
    } else if (lower == 'rejected') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildTabBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: primaryColor,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
        tabs: tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget buildCurrentTab() {
    switch (currentTabIndex) {
      case 0:
        return ManagerHomeScreen(project: widget.project);
      case 1:
        return DigitalTwinPage(project: widget.project);
      case 2:
        return ManagerTasksTab(projectId: projectId);
      case 3:
        return WorkersTab(projectId: projectId);
      case 4:
        return ManagerAttendanceTab(projectId: projectId);
      case 5:
        return ProjectMaterialsPage(
          projectId: projectId,
          projectName: projectName,
        );
      case 6:
        return ProjectEquipmentPage(
          projectId: projectId,
          projectName: projectName,
          projectLatitude: projectLatitude,
          projectLongitude: projectLongitude,
        );
      default:
        return ManagerHomeScreen(project: widget.project);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildSidebar(),
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
                child: buildCurrentTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
