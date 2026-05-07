import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EngMainLayout extends StatefulWidget {
  final TabController tabController;
  final List<String> tabs;
  final Widget Function(String? selectedProjectId) tabContent;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onIotTap;
  final VoidCallback onDigitalTwinTap;
  final VoidCallback onEnvironmentTap;

  const EngMainLayout({
    super.key,
    required this.tabController,
    required this.tabs,
    required this.tabContent,
    required this.onMenuTap,
    required this.onNotificationTap,
    required this.onIotTap,
    required this.onDigitalTwinTap,
    required this.onEnvironmentTap,
  });

  @override
  State<EngMainLayout> createState() => _EngMainLayoutState();
}

class _EngMainLayoutState extends State<EngMainLayout> {
  final supabase = Supabase.instance.client;

  final String defaultProjectImageUrl =
      "https://yourneighbourhood.com.au/wp-content/uploads/5-Hercules-Street-Hamilton-2.jpg";

  List<Map<String, dynamic>> projects = [];
  Map<String, dynamic>? selectedProject;
  bool isLoadingProjects = true;

  @override
  void initState() {
    super.initState();
    loadAssignedProjects();
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
          .from('site_engineer_projects')
          .select('projects(*)')
          .eq('site_engineer_id', currentUser.id)
          .order('assigned_at', ascending: false);

      final List<Map<String, dynamic>> loadedProjects = [];

      for (final item in response) {
        final project = item['projects'];

        if (project != null) {
          loadedProjects.add(Map<String, dynamic>.from(project));
        }
      }

      if (!mounted) return;

      setState(() {
        projects = loadedProjects;
        selectedProject =
            loadedProjects.isNotEmpty ? loadedProjects.first : null;
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SafeArea(
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
                const SizedBox(height: 6),
                Text(
                  "Select one of the projects assigned to this site engineer",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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

                        final startDate = getText(project, [
                          'start_date',
                        ], 'No start date');

                        final isSelected =
                            selectedProject != null &&
                            selectedProject!['id'] == project['id'];

                        final isPlanning = status.toLowerCase().contains(
                          "planning",
                        );

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
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.blue.withOpacity(0.12)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    color:
                                        isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "Start: $startDate",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isPlanning
                                            ? Colors.blue.shade100
                                            : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color:
                                          isPlanning
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: widget.tabContent(selectedProject?['id']?.toString()),
                ),
              ],
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final projectName = getText(selectedProject, [
      'name',
      'project_name',
      'title',
    ], 'No Project Selected');

    final projectLocation = getText(selectedProject, [
      'location',
      'address',
      'project_location',
    ], 'No location available');

    final projectStatus = getText(selectedProject, [
      'status',
      'project_status',
    ], 'In Progress');

    final projectImageUrl = getText(selectedProject, [
      'image_url',
      'project_image',
    ], defaultProjectImageUrl);

    final isPlanning = projectStatus.toLowerCase().contains("planning");

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onMenuTap,
                child: const Icon(Icons.menu, size: 30),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onNotificationTap,
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
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image),
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
                                    "Project monitoring",
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
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isPlanning
                                        ? Colors.blue.shade100
                                        : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                projectStatus,
                                style: TextStyle(
                                  color:
                                      isPlanning ? Colors.blue : Colors.orange,
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
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: widget.tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.blue,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
        tabs: widget.tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      left: 30,
      right: 30,
      bottom: 20,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bottomNavItem(
                  icon: Icons.sensors_rounded,
                  label: "IoT Sensors",
                  onTap: widget.onIotTap,
                ),
                const SizedBox(width: 80),
                _bottomNavItem(
                  icon: Icons.thermostat_rounded,
                  label: "Environment",
                  onTap: widget.onEnvironmentTap,
                ),
              ],
            ),
            Positioned(
              top: -34,
              child: GestureDetector(
                onTap: widget.onDigitalTwinTap,
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Digital Twin",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
