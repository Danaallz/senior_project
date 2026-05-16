import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:senior_project/screens/Admin/add_user_page.dart';
import 'package:senior_project/services/notification_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final NotificationService notificationService = NotificationService();
  late TabController _tabController;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color orangeColor = Color(0xffff8a00);
  static const Color greenColor = Color(0xff35c76b);

  final List<String> tabs = ["Home", "Projects", "User Management"];

  bool isLoading = true;
  String projectSearchQuery = "";
  String userSearchQuery = "";

  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> users = [];
  Map<String, dynamic>? adminProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String get adminName {
    final fullName = cleanText(adminProfile?['full_name']);
    final name = cleanText(adminProfile?['name']);

    if (fullName.isNotEmpty) return fullName;
    if (name.isNotEmpty) return name;
    return "Admin";
  }

  String get adminImageUrl {
    return cleanText(adminProfile?['profile_image_url']);
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    try {
      final projectsResponse = await supabase
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      final usersResponse = await supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final currentUserId = supabase.auth.currentUser?.id;

      Map<String, dynamic>? adminProfileResponse;

      if (currentUserId != null) {
        adminProfileResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', currentUserId)
            .maybeSingle();
      }

      if (!mounted) return;

      setState(() {
        projects = List<Map<String, dynamic>>.from(projectsResponse);
        users = List<Map<String, dynamic>>.from(usersResponse);
        adminProfile = adminProfileResponse;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showError("Error loading data: $e");
    }
  }

  int countProjects(String approvalStatus) {
    return projects.where((project) {
      return (project['approval_status'] ?? 'Pending').toString() ==
          approvalStatus;
    }).length;
  }

  int countUsers(String role) {
    return users.where((user) {
      return (user['role'] ?? '').toString().toLowerCase() == role;
    }).length;
  }

  Future<void> approveProject(String projectId) async {
    try {
      final project = await supabase
          .from('projects')
          .select('id, name, owner_id')
          .eq('id', projectId)
          .maybeSingle();

      await supabase
          .from('projects')
          .update({
            'approval_status': 'Approved',
            'status': 'In Progress',
            'approved_by': supabase.auth.currentUser?.id,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', projectId);

      final ownerId = project?['owner_id']?.toString();
      final projectName = project?['name']?.toString() ?? 'Your project';

      if (ownerId != null && ownerId.isNotEmpty) {
        await notificationService.createNotification(
          userId: ownerId,
          projectId: projectId,
          type: 'approved',
          title: 'Good News!',
          message: '$projectName has been approved and is now in progress.',
        );
      }

      await loadData();
    } catch (e) {
      showError("Error approving project: $e");
    }
  }

  Future<void> rejectProject(String projectId) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Reject Project"),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Write rejection reason",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context, reasonController.text.trim());
              },
              child: const Text(
                "Reject",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final project = await supabase
          .from('projects')
          .select('id, name, owner_id')
          .eq('id', projectId)
          .maybeSingle();

      await supabase
          .from('projects')
          .update({
            'approval_status': 'Rejected',
            'status': 'Rejected',
            'rejection_reason': reason,
          })
          .eq('id', projectId);

      final ownerId = project?['owner_id']?.toString();
      final projectName = project?['name']?.toString() ?? 'Your project';

      if (ownerId != null && ownerId.isNotEmpty) {
        await notificationService.createNotification(
          userId: ownerId,
          projectId: projectId,
          type: 'rejected',
          title: 'Project Rejected',
          message: '$projectName was rejected. Reason: $reason',
        );
      }

      await loadData();
    } catch (e) {
      showError("Error rejecting project: $e");
    }
  }

  Future<void> removeProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Remove Project"),
          content: const Text("Are you sure you want to remove this project?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Remove",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.from('projects').delete().eq('id', projectId);
      await loadData();
    } catch (e) {
      showError("Error removing project: $e");
    }
  }

  Future<void> editProject(Map<String, dynamic> project) async {
    final nameController = TextEditingController(
      text: project['name']?.toString() ?? "",
    );
    final locationController = TextEditingController(
      text: project['location']?.toString() ?? "",
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Edit Project"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Project Name"),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: "Location"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    if (nameController.text.trim().isEmpty) {
      showError("Project name cannot be empty");
      return;
    }

    try {
      await supabase
          .from('projects')
          .update({
            'name': nameController.text.trim(),
            'location': locationController.text.trim(),
          })
          .eq('id', project['id']);

      await loadData();
    } catch (e) {
      showError("Error updating project: $e");
    }
  }

  Future<void> deleteUser(String userId) async {
    final currentUserId = supabase.auth.currentUser?.id;

    if (userId == currentUserId) {
      showError("You cannot delete your own admin profile.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Delete User"),
          content: const Text(
            "Are you sure you want to delete this user from the app users list?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.from('profiles').delete().eq('id', userId);
      await loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      showError("Error deleting user: $e");
    }
  }

  Future<void> editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(
      text: user['full_name']?.toString() ?? "",
    );
    final emailController = TextEditingController(
      text: user['email']?.toString() ?? "",
    );
    final phoneController = TextEditingController(
      text: user['phone']?.toString() ?? "",
    );

    String selectedRole = user['role']?.toString().toLowerCase() ?? 'manager';

    final allowedRoles = ['manager', 'owner', 'site engineer', 'admin'];

    if (!allowedRoles.contains(selectedRole)) {
      selectedRole = 'manager';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Edit User"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: "Phone"),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: "Role"),
                      items: const [
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(value: 'owner', child: Text('Owner')),
                        DropdownMenuItem(
                          value: 'site engineer',
                          child: Text('Site Engineer'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedRole = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (nameController.text.trim().isEmpty) {
      showError("User name cannot be empty");
      return;
    }

    if (emailController.text.trim().isEmpty ||
        !emailController.text.trim().contains("@")) {
      showError("Enter a valid email");
      return;
    }

    try {
      await supabase
          .from('profiles')
          .update({
            'full_name': nameController.text.trim(),
            'email': emailController.text.trim().toLowerCase(),
            'phone': phoneController.text.trim(),
            'role': selectedRole,
          })
          .eq('id', user['id']);

      await loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User updated successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      showError("Error updating user: $e");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildSidebar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            buildTabBar(),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          buildHomeTab(),
                          buildProjectsTab(),
                          buildUsersTab(),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const Icon(Icons.menu, size: 30),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget buildAdminProfileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: Colors.grey.shade200,
            backgroundImage:
                isValidImageUrl(adminImageUrl)
                    ? NetworkImage(adminImageUrl)
                    : null,
            child:
                isValidImageUrl(adminImageUrl)
                    ? null
                    : const Icon(
                      Icons.admin_panel_settings,
                      color: primaryColor,
                      size: 38,
                    ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              adminName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Column(
      children: [
        buildAdminProfileHeader(),
        Container(
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            labelPadding: const EdgeInsets.symmetric(horizontal: 18),
            tabs: tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
      ],
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
                        isValidImageUrl(adminImageUrl)
                            ? NetworkImage(adminImageUrl)
                            : null,
                    child:
                        isValidImageUrl(adminImageUrl)
                            ? null
                            : const Icon(
                              Icons.admin_panel_settings,
                              color: primaryColor,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "Admin",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
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
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text("Projects"),
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text("User Management"),
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(2);
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
                onTap: () async {
                  await supabase.auth.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Overview",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.25,
          children: [
            statCard(
              Icons.apartment_rounded,
              "Total Projects",
              "${projects.length}",
              Colors.blue,
            ),
            statCard(
              Icons.pending_actions_rounded,
              "Pending",
              "${countProjects('Pending')}",
              orangeColor,
            ),
            statCard(
              Icons.check_circle_rounded,
              "Approved",
              "${countProjects('Approved')}",
              greenColor,
            ),
            statCard(
              Icons.cancel_rounded,
              "Rejected",
              "${countProjects('Rejected')}",
              Colors.red,
            ),
            statCard(
              Icons.people_alt_rounded,
              "Users",
              "${users.length}",
              Colors.purple,
            ),
            statCard(
              Icons.engineering_rounded,
              "Managers",
              "${countUsers('manager')}",
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget statCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget buildProjectsTab() {
    final approvedProjects =
        projects.where((project) {
          final approval = (project['approval_status'] ?? '').toString();
          final status = (project['status'] ?? '').toString();
          final name = (project['name'] ?? '').toString().toLowerCase();

          return approval == 'Approved' &&
              status == 'In Progress' &&
              name.contains(projectSearchQuery.toLowerCase());
        }).toList();

    final pendingProjects =
        projects.where((project) {
          return (project['approval_status'] ?? 'Pending').toString() ==
              'Pending';
        }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Projects",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) {
            setState(() => projectSearchQuery = value);
          },
          decoration: InputDecoration(
            hintText: "Search approved projects...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "Approved Projects - In Progress",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (approvedProjects.isEmpty)
          const Text("No approved in-progress projects found"),
        ...approvedProjects.map((project) => approvedProjectCard(project)),
        const SizedBox(height: 24),
        const Text(
          "Project Approval",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "Pending project requests from owners.",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        if (pendingProjects.isEmpty) const Text("No pending project requests"),
        ...pendingProjects.map((project) => pendingProjectCard(project)),
      ],
    );
  }

  Widget approvedProjectCard(Map<String, dynamic> project) {
    final name =
        cleanText(project['name']).isEmpty
            ? "Unnamed Project"
            : cleanText(project['name']);

    final location =
        cleanText(project['location']).isEmpty
            ? cleanText(project['city']).isEmpty
                ? "No location"
                : cleanText(project['city'])
            : cleanText(project['location']);

    final imageUrl = cleanText(project['image_url']);
    final startDate = cleanText(project['start_date']);
    final endDate = cleanText(project['end_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child:
                isValidImageUrl(imageUrl)
                    ? Image.network(
                      imageUrl,
                      height: 135,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => projectImagePlaceholder(),
                    )
                    : projectImagePlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    statusChip("In Progress", orangeColor),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                if (startDate.isNotEmpty || endDate.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: smallInfoBox("Start", startDate)),
                      const SizedBox(width: 10),
                      Expanded(child: smallInfoBox("End", endDate)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => editProject(project),
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => removeProject(project['id'].toString()),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          "Remove",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget pendingProjectCard(Map<String, dynamic> project) {
    final name =
        cleanText(project['name']).isEmpty
            ? "Unnamed Project"
            : cleanText(project['name']);

    final location =
        cleanText(project['location']).isEmpty
            ? cleanText(project['city']).isEmpty
                ? "No location"
                : cleanText(project['city'])
            : cleanText(project['location']);

    final imageUrl = cleanText(project['image_url']);
    final startDate = cleanText(project['start_date']);
    final endDate = cleanText(project['end_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child:
                isValidImageUrl(imageUrl)
                    ? Image.network(
                      imageUrl,
                      height: 125,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => projectImagePlaceholder(),
                    )
                    : projectImagePlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    statusChip("Pending", orangeColor),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                if (startDate.isNotEmpty || endDate.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: smallInfoBox("Start", startDate)),
                      const SizedBox(width: 10),
                      Expanded(child: smallInfoBox("End", endDate)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenColor,
                        ),
                        onPressed:
                            () => approveProject(project['id'].toString()),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          "Approve",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed:
                            () => rejectProject(project['id'].toString()),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text(
                          "Reject",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget projectImagePlaceholder() {
    return Container(
      height: 135,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.apartment_rounded,
        color: primaryColor,
        size: 42,
      ),
    );
  }

  Widget smallInfoBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? "-" : value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget buildUsersTab() {
    final filteredUsers =
        users.where((user) {
          final role = (user['role'] ?? '').toString().toLowerCase();

          if (role == 'admin') return false;

          final name = (user['full_name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final phone = (user['phone'] ?? '').toString().toLowerCase();
          final query = userSearchQuery.toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              phone.contains(query) ||
              role.contains(query);
        }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "User Management",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddUserPage()),
                );

                if (result == true) {
                  await loadData();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Add User",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) {
            setState(() => userSearchQuery = value);
          },
          decoration: InputDecoration(
            hintText: "Search users by name, email, phone, or role...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredUsers.isEmpty) const Text("No users found"),
        ...filteredUsers.map((user) => userCard(user)),
      ],
    );
  }

  Widget userCard(Map<String, dynamic> user) {
    final name = user['full_name']?.toString() ?? "Unnamed User";
    final email = user['email']?.toString() ?? "No email";
    final phone = user['phone']?.toString() ?? "No phone";
    final role = user['role']?.toString() ?? "user";
    final userId = user['id']?.toString() ?? "";
    final imageUrl = user['profile_image_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: primaryColor.withOpacity(0.12),
            backgroundImage:
                imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
            child:
                imageUrl == null || imageUrl.isEmpty
                    ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "U",
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: Colors.grey.shade700)),
                Text(phone, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 5),
                statusChip(role, primaryColor),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => editUser(user),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: userId.isEmpty ? null : () => deleteUser(userId),
          ),
        ],
      ),
    );
  }

  Widget statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}