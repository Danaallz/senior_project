import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notification_bell.dart';

class EngMainLayout extends StatefulWidget {
  final Map<String, dynamic> project;
  final TabController tabController;
  final List<String> tabs;
  final Widget Function() tabContent;
  final VoidCallback onNotificationTap;
  final VoidCallback onIotTap;
  final VoidCallback onDigitalTwinTap;
  final VoidCallback onEnvironmentTap;

  const EngMainLayout({
    super.key,
    required this.project,
    required this.tabController,
    required this.tabs,
    required this.tabContent,
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

  Map<String, dynamic>? engineerProfile;

  static const Color primaryColor = Color(0xff0d1b46);

  @override
  void initState() {
    super.initState();
    loadEngineerProfile();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool validImage(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> loadEngineerProfile() async {
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
      engineerProfile = response;
    });
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  String get projectName {
    return cleanText(widget.project['name']).isEmpty
        ? 'Project'
        : cleanText(widget.project['name']);
  }

  String get projectLocation {
    return cleanText(widget.project['location']).isEmpty
        ? cleanText(widget.project['city'])
        : cleanText(widget.project['location']);
  }

  String get projectStatus {
    return cleanText(widget.project['status']).isEmpty
        ? 'In Progress'
        : cleanText(widget.project['status']);
  }

  String get projectImage {
    return cleanText(widget.project['image_url']);
  }

  String get engineerName {
    return cleanText(engineerProfile?['full_name']).isEmpty
        ? 'Site Engineer'
        : cleanText(engineerProfile?['full_name']);
  }

  String get engineerImage {
    return cleanText(engineerProfile?['profile_image_url']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildSidebar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                buildHeader(),
                buildTabBar(),
                Expanded(child: widget.tabContent()),
              ],
            ),
            buildBottomNavBar(),
          ],
        ),
      ),
    );
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
                        validImage(engineerImage)
                            ? NetworkImage(engineerImage)
                            : null,
                    child:
                        validImage(engineerImage)
                            ? null
                            : const Icon(
                              Icons.engineering,
                              color: primaryColor,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      engineerName,
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
                title: const Text("Engineer Home"),
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
          child: Column(
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
                  // SITE ENGINEER NOTIFICATION BELL
                  // Replaces the static alert icon with the real notification bell.
                  // ================================
                  NotificationBell(
                    color: primaryColor,
                    onClosed: loadEngineerProfile,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child:
                        validImage(projectImage)
                            ? Image.network(
                              projectImage,
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => projectPlaceholder(),
                            )
                            : projectPlaceholder(),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Project monitoring",
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
                          style: TextStyle(color: Colors.grey.shade700),
                        ),

                        const SizedBox(height: 8),

                        statusChip(projectStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget projectPlaceholder() {
    return Container(
      width: 78,
      height: 78,
      color: Colors.grey.shade300,
      child: const Icon(Icons.apartment, size: 32),
    );
  }

  Widget statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildTabBar() {
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

  Widget buildBottomNavBar() {
    return Positioned(
      left: 30,
      right: 30,
      bottom: 8,
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
                bottomNavItem(
                  icon: Icons.sensors_rounded,
                  label: "IoT Sensors",
                  onTap: widget.onIotTap,
                ),

                const SizedBox(width: 80),

                bottomNavItem(
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

  Widget bottomNavItem({
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
