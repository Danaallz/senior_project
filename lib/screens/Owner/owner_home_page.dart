import 'package:flutter/material.dart';

import 'package:senior_project/services/auth_service.dart';
import 'package:senior_project/services/supabase_service.dart';

import 'project_details_page.dart';
import 'add_project_page.dart';
import 'owner_project_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final AuthService auth = AuthService();
  final SupabaseService supabaseService = SupabaseService();

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> projects = [];

  bool isLoading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadOwnerData();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadOwnerData() async {
    final user = supabaseService.getCurrentUser();

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final ownerProfile = await supabaseService.getCurrentProfile();

      if (ownerProfile == null) {
        if (!mounted) return;

        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Owner profile not found."),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final ownerProjects = await supabaseService.getOwnerProjects(
        ownerProfile['id'].toString(),
      );

      if (!mounted) return;

      setState(() {
        profile = ownerProfile;
        projects = ownerProjects;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> logout() async {
    try {
      await auth.logout();

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to log out. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filteredProjects {
    return projects.where((project) {
      final name = cleanText(project['name']).toLowerCase();
      final location = cleanText(project['location']).toLowerCase();
      final city = cleanText(project['city']).toLowerCase();
      final status = cleanText(project['approval_status']).toLowerCase();
      final query = search.toLowerCase();

      return name.contains(query) ||
          location.contains(query) ||
          city.contains(query) ||
          status.contains(query);
    }).toList();
  }

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final ownerName =
        cleanText(profile?['full_name']).isEmpty
            ? cleanText(profile?['name']).isEmpty
                ? 'Owner'
                : cleanText(profile?['name'])
            : cleanText(profile?['full_name']);

    final profileImageUrl = cleanText(profile?['profile_image_url']);

    return OwnerProjectScreen(
      ownerName: ownerName,
      profileImageUrl: profileImageUrl,
      onLogout: logout,
      onProfileUpdated: loadOwnerData,
      onRefresh: loadOwnerData,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/addProject');

              if (result == true) {
                loadOwnerData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0d1b46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Add new project",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: loadOwnerData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildOwnerHeader(ownerName, profileImageUrl),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: InsightCard(
                              title: "Total Projects",
                              value: "${projects.length}",
                              color: const Color(0xff0d1b46),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InsightCard(
                              title: "Approved",
                              value:
                                  "${projects.where((p) => cleanText(p['approval_status']).toLowerCase() == 'approved').length}",
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: InsightCard(
                              title: "Pending",
                              value:
                                  "${projects.where((p) => cleanText(p['approval_status']).toLowerCase() == 'pending').length}",
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InsightCard(
                              title: "Rejected",
                              value:
                                  "${projects.where((p) => cleanText(p['approval_status']).toLowerCase() == 'rejected').length}",
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      Row(
                        children: const [
                          Text(
                            "My Projects",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          Text(
                            "View All",
                            style: TextStyle(
                              color: Color(0xff0d1b46),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (filteredProjects.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "No projects found.",
                            textAlign: TextAlign.center,
                          ),
                        ),

                      ...filteredProjects.map(
                        (project) => ProjectCard(
                          project: project,
                          onRefresh: loadOwnerData,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget buildOwnerHeader(String ownerName, String profileImageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff0d1b46),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0d1b46).withOpacity(0.18),
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
                    isValidImageUrl(profileImageUrl)
                        ? NetworkImage(profileImageUrl)
                        : null,
                child:
                    isValidImageUrl(profileImageUrl)
                        ? null
                        : const Icon(
                          Icons.person,
                          color: Color(0xff0d1b46),
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
                      ownerName,
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
                setState(() => search = value);
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
}

class InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const InsightCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(13),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback? onRefresh;

  const ProjectCard({super.key, required this.project, this.onRefresh});

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool canViewProject() {
    final status = cleanText(project['status']).toLowerCase();
    final approvalStatus = cleanText(project['approval_status']).toLowerCase();

    return status == 'approved' ||
        status == 'in progress' ||
        status == 'active' ||
        approvalStatus == 'approved';
  }

  void openDetails(BuildContext context) {
    if (!canViewProject()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Project is pending admin approval."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: cleanText(project['id'])),
      ),
    );
  }

  Future<void> deleteProject(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Project"),
          content: const Text("Are you sure you want to delete this project?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await SupabaseService().deleteProject(cleanText(project['id']));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Project deleted successfully."),
          backgroundColor: Colors.green,
        ),
      );

      onRefresh?.call();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to delete project: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editProject(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectPage(existingProject: project),
      ),
    );

    if (result == true) {
      onRefresh?.call();
    }
  }

  void showProjectOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                if (canViewProject())
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text("View Details"),
                    onTap: () {
                      Navigator.pop(context);
                      openDetails(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text("Edit"),
                  onTap: () {
                    Navigator.pop(context);
                    editProject(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    deleteProject(context);
                  },
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
    final imageUrl = cleanText(project['image_url']);

    final status =
        cleanText(project['status']).isEmpty
            ? cleanText(project['approval_status']).isEmpty
                ? 'Pending'
                : cleanText(project['approval_status'])
            : cleanText(project['status']);

    final projectName =
        cleanText(project['name']).isEmpty
            ? 'Project'
            : cleanText(project['name']);

    final location =
        cleanText(project['location']).isEmpty
            ? cleanText(project['city'])
            : cleanText(project['location']);

    return GestureDetector(
      onTap: () {
        if (canViewProject()) {
          openDetails(context);
        }
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        errorBuilder: (context, error, stackTrace) {
                          return projectImagePlaceholder();
                        },
                      )
                      : projectImagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  statusBadge(status),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: dateBox(
                          "Start",
                          cleanText(project['start_date']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: dateBox("End", cleanText(project['end_date'])),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.more_horiz,
                size: 22,
                color: Colors.black87,
              ),
              onPressed: () => showProjectOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget projectImagePlaceholder() {
    return Container(
      width: 76,
      height: 76,
      color: Colors.grey.shade200,
      child: const Icon(Icons.apartment, color: Colors.grey),
    );
  }

  Widget statusBadge(String status) {
    final value = status.toLowerCase();

    Color color = Colors.orange;

    if (value == 'approved' || value == 'in progress' || value == 'active') {
      color = Colors.green;
    } else if (value == 'rejected') {
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

  Widget dateBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
