import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'eng_home_page.dart';

class EngWelcomePage extends StatefulWidget {
  const EngWelcomePage({super.key});

  @override
  State<EngWelcomePage> createState() => _EngWelcomePageState();
}

class _EngWelcomePageState extends State<EngWelcomePage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> projects = [];

  bool isLoading = true;
  String search = '';

  static const Color primaryColor = Color(0xff0d1b46);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool validImage(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final profileResponse =
          await supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      final projectsResponse = await supabase
          .from('projects')
          .select()
          .eq('assigned_site_engineer_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        profile = profileResponse;
        projects = List<Map<String, dynamic>>.from(projectsResponse);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load projects: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filteredProjects {
    final q = search.toLowerCase();

    return projects.where((project) {
      final name = cleanText(project['name']).toLowerCase();
      final location = cleanText(project['location']).toLowerCase();
      final city = cleanText(project['city']).toLowerCase();
      final status = cleanText(project['status']).toLowerCase();

      return name.contains(q) ||
          location.contains(q) ||
          city.contains(q) ||
          status.contains(q);
    }).toList();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final name =
        cleanText(profile?['full_name']).isEmpty
            ? 'Site Engineer'
            : cleanText(profile?['full_name']);

    final imageUrl = cleanText(profile?['profile_image_url']);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: buildSidebar(name, imageUrl),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      buildTopBar(),
                      const SizedBox(height: 18),
                      buildHeader(name, imageUrl),
                      const SizedBox(height: 18),
                      buildStatsRow(),
                      const SizedBox(height: 24),
                      const Text(
                        'Assigned Projects',
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
                            child: Text('No assigned projects found'),
                          ),
                        ),
                      ...filteredProjects.map(projectCard),
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
                      '3',
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

  Widget buildHeader(String name, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage:
                    validImage(imageUrl) ? NetworkImage(imageUrl) : null,
                child:
                    validImage(imageUrl)
                        ? null
                        : const Icon(Icons.engineering, color: primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
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
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                hintText: 'Search project...',
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
    return Row(
      children: [
        statCard(
          'Projects',
          '${projects.length}',
          Icons.apartment,
          primaryColor,
        ),
        const SizedBox(width: 10),
        statCard(
          'Active',
          '${projects.where((p) => cleanText(p['status']).toLowerCase() == 'in progress').length}',
          Icons.timelapse,
          Colors.orange,
        ),
        const SizedBox(width: 10),
        statCard(
          'Done',
          '${projects.where((p) => cleanText(p['status']).toLowerCase() == 'completed').length}',
          Icons.check_circle,
          Colors.green,
        ),
      ],
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 112,
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
      ),
    );
  }

  Widget projectCard(Map<String, dynamic> project) {
    final name =
        cleanText(project['name']).isEmpty
            ? 'Project'
            : cleanText(project['name']);
    final location =
        cleanText(project['location']).isEmpty
            ? cleanText(project['city'])
            : cleanText(project['location']);
    final status =
        cleanText(project['status']).isEmpty
            ? 'In Progress'
            : cleanText(project['status']);
    final imageUrl = cleanText(project['image_url']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EngHomePage(project: project)),
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
                  validImage(imageUrl)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildSidebar(String name, String imageUrl) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        validImage(imageUrl) ? NetworkImage(imageUrl) : null,
                    child:
                        validImage(imageUrl)
                            ? null
                            : const Icon(
                              Icons.engineering,
                              color: primaryColor,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Account Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Customer Support'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/customerSupport');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About us'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/aboutUs');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Log out',
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
