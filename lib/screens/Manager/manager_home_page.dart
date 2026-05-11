import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'project_screen.dart';

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? managerProfile;
  List<Map<String, dynamic>> projects = [];

  bool isLoading = true;
  String searchQuery = "";

  static const Color primaryColor = Color(0xff0d1b46);

  @override
  void initState() {
    super.initState();
    loadManagerData();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool isValidImageUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> loadManagerData() async {
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final profileResponse =
          await supabase
              .from('profiles')
              .select()
              .eq('id', currentUser.id)
              .maybeSingle();

      final projectsResponse = await supabase
          .from('projects')
          .select()
          .eq('assigned_manager_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        managerProfile = profileResponse;
        projects = List<Map<String, dynamic>>.from(projectsResponse);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load manager projects: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filteredProjects {
    final query = searchQuery.toLowerCase();

    return projects.where((project) {
      final name = cleanText(project['name']).toLowerCase();
      final location = cleanText(project['location']).toLowerCase();
      final city = cleanText(project['city']).toLowerCase();
      final status = cleanText(project['status']).toLowerCase();

      return name.contains(query) ||
          location.contains(query) ||
          city.contains(query) ||
          status.contains(query);
    }).toList();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final managerName =
        cleanText(managerProfile?['full_name']).isNotEmpty
            ? cleanText(managerProfile?['full_name'])
            : cleanText(managerProfile?['name']).isNotEmpty
            ? cleanText(managerProfile?['name'])
            : "Manager";

    final imageUrl =
        cleanText(managerProfile?['profile_image_url']).isNotEmpty
            ? cleanText(managerProfile?['profile_image_url'])
            : cleanText(managerProfile?['image_url']);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: buildSidebar(managerName, imageUrl),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: loadManagerData,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      buildTopBar(),
                      const SizedBox(height: 18),
                      buildHeader(managerName, imageUrl),
                      const SizedBox(height: 18),
                      buildStatsRow(),
                      const SizedBox(height: 24),
                      const Text(
                        "Assigned Projects",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filteredProjects.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text("No assigned projects found"),
                          ),
                        ),
                      ...filteredProjects.map((project) {
                        return managerProjectCard(project);
                      }),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget buildTopBar() {
    return Builder(
      builder: (context) {
        return Row(
          children: [
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const Icon(Icons.menu, size: 30),
            ),
            const Spacer(),
            const Stack(
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
          ],
        );
      },
    );
  }

  Widget buildHeader(String managerName, String imageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 29,
                backgroundColor: Colors.white,
                backgroundImage:
                    isValidImageUrl(imageUrl) ? NetworkImage(imageUrl) : null,
                child:
                    isValidImageUrl(imageUrl)
                        ? null
                        : const Icon(
                          Icons.person,
                          color: primaryColor,
                          size: 30,
                        ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      managerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
              decoration: const InputDecoration(
                hintText: "Search project...",
                hintStyle: TextStyle(fontSize: 13),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatsRow() {
    final activeCount =
        projects.where((project) {
          final status = cleanText(project['status']).toLowerCase();
          return status == 'in progress' || status == 'active';
        }).length;

    final completedCount =
        projects.where((project) {
          final status = cleanText(project['status']).toLowerCase();
          return status == 'completed';
        }).length;

    return Row(
      children: [
        Expanded(
          child: statCard(
            title: "Projects",
            value: "${projects.length}",
            icon: Icons.apartment_rounded,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: statCard(
            title: "Active",
            value: "$activeCount",
            icon: Icons.timelapse_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: statCard(
            title: "Completed",
            value: "$completedCount",
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget managerProjectCard(Map<String, dynamic> project) {
    final name =
        cleanText(project['name']).isEmpty
            ? "Project"
            : cleanText(project['name']);

    final location =
        cleanText(project['location']).isEmpty
            ? cleanText(project['city'])
            : cleanText(project['location']);

    final status =
        cleanText(project['status']).isEmpty
            ? "In Progress"
            : cleanText(project['status']);

    final imageUrl = cleanText(project['image_url']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectScreen(project: project)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child:
                  isValidImageUrl(imageUrl)
                      ? Image.network(
                        imageUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => projectPlaceholder(),
                      )
                      : projectPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 9),
                  statusBadge(status),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Widget projectPlaceholder() {
    return Container(
      width: 76,
      height: 76,
      color: Colors.grey.shade200,
      child: const Icon(Icons.apartment, color: Colors.grey),
    );
  }

  Widget statusBadge(String status) {
    final lower = status.toLowerCase();

    Color color = Colors.orange;

    if (lower == 'completed') {
      color = Colors.green;
    } else if (lower == 'rejected') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildSidebar(String managerName, String imageUrl) {
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
                        isValidImageUrl(imageUrl)
                            ? NetworkImage(imageUrl)
                            : null,
                    child:
                        isValidImageUrl(imageUrl)
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
                title: const Text("Home"),
                onTap: () => Navigator.pop(context),
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
}
