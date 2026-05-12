import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'owner_project_materials_page.dart';
import 'package:senior_project/screens/digital_twin_page.dart';
import 'package:senior_project/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'owner_project_equipment_page.dart';
import 'owner_project_page.dart';
import '../notification_bell.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final SupabaseService supabaseService = SupabaseService();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> sitePhotos = [];
  bool isUploadingPhoto = false;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color greenColor = Color(0xff35c76b);

  bool isLoading = true;
  Map<String, dynamic>? project;
  Map<String, dynamic>? manager;
  Map<String, dynamic>? digitalTwinSnapshot;

  // ================================
  // PROJECT INSIGHTS COUNTERS
  // Stores real counts loaded from Supabase for this project.
  // ================================
  int materialCount = 0;
  int equipmentCount = 0;

  String selectedTab = "home";
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadProject();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // ================================
  // SAFE PROJECT RECORD COUNTER
  // Counts records by project_id.
  // If the table does not exist or the column name is different,
  // it returns 0 instead of crashing the page.
  // ================================
  Future<int> countProjectRows(String tableName) async {
    try {
      final response = await supabase
          .from(tableName)
          .select('id')
          .eq('project_id', widget.projectId);

      return List<Map<String, dynamic>>.from(response).length;
    } catch (e) {
      debugPrint("Count error in $tableName: $e");
      return 0;
    }
  }

  // ================================
  // MATERIAL + EQUIPMENT COUNTS
  // Tries the most common table names.
  // If your project uses different names, change them here only.
  // ================================
  Future<Map<String, int>> loadInsightCounts() async {
    int materials = await countProjectRows('project_materials');
    if (materials == 0) {
      materials = await countProjectRows('materials');
    }

    int equipment = await countProjectRows('project_equipment');
    if (equipment == 0) {
      equipment = await countProjectRows('equipment');
    }

    return {
      'materials': materials,
      'equipment': equipment,
    };
  }

  Future<void> loadProject() async {
    try {
      final projectData = await supabaseService.getProjectById(
        widget.projectId,
      );

      Map<String, dynamic>? managerData;
      // ================================
      // MANAGER ID COMPATIBILITY FIX
      // Supports both database column names:
      // - assigned_manager_id
      // - manager_id
      // This keeps your teammate's code working while supporting your latest schema.
      // ================================
      final managerId = cleanText(projectData?['assigned_manager_id']).isNotEmpty
          ? cleanText(projectData?['assigned_manager_id'])
          : cleanText(projectData?['manager_id']);

      final snapshotData = await supabaseService.getLatestDigitalTwinSnapshot(
        widget.projectId,
      );

      if (managerId.isNotEmpty) {
        managerData = await supabaseService.getProfileById(managerId);
      }

      final photosResponse = await supabase
          .from('project_photos')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false);

      // ================================
      // LOAD REAL MATERIAL + EQUIPMENT COUNTS
      // This fixes the issue where Materials and Equipment always show 0.
      // ================================
      final insightCounts = await loadInsightCounts();

      if (!mounted) return;

      setState(() {
        project = projectData;
        manager = managerData;
        digitalTwinSnapshot = snapshotData;
        sitePhotos = List<Map<String, dynamic>>.from(photosResponse);
        materialCount = insightCounts['materials'] ?? 0;
        equipmentCount = insightCounts['equipment'] ?? 0;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Load project error: $e");

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to load project details. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================================
  // WHATSAPP MANAGER CHAT
  // Opens WhatsApp chat with the assigned project manager
  // using the manager phone number from profiles.
  // ================================
  Future<void> openManagerWhatsApp() async {
    if (manager == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No manager assigned")));
      return;
    }

    String phone = cleanText(
      manager!['phone'],
    ).replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0')) {
      phone = '966${phone.substring(1)}';
    } else if (!phone.startsWith('966')) {
      phone = '966$phone';
    }

    final message = Uri.encodeComponent(
      "Hello, I want to discuss project: ${cleanText(project!['name'])}",
    );

    final url = Uri.parse("https://wa.me/$phone?text=$message");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp")));
    }
  }

  Future<void> loadSitePhotos() async {
    final response = await supabase
        .from('project_photos')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      sitePhotos = List<Map<String, dynamic>>.from(response);
    });
  }

  // ================================
  // SITE PHOTOS UPLOAD
  // Allows the owner to add site photos.
  // The image is uploaded to Supabase Storage and saved in project_photos.
  // ================================
  Future<void> pickAndUploadSitePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() => isUploadingPhoto = true);

      final Uint8List bytes = await image.readAsBytes();
      final fileName =
          'site_${widget.projectId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('project-images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage
          .from('project-images')
          .getPublicUrl(fileName);

      await supabase.from('project_photos').insert({
        'project_id': widget.projectId,
        'image_url': imageUrl,
      });

      await loadSitePhotos();
    } catch (e) {
      debugPrint("Upload site photo error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to upload photo")));
    } finally {
      if (mounted) setState(() => isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (project == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("Project not found.")),
      );
    }

    final projectName =
        cleanText(project!['name']).isEmpty
            ? "Project"
            : cleanText(project!['name']);

    final location =
        cleanText(project!['location']).isEmpty
            ? cleanText(project!['city'])
            : cleanText(project!['location']);

    final imageUrl = cleanText(project!['image_url']);

    final status =
        cleanText(project!['status']).isEmpty
            ? "In Progress"
            : cleanText(project!['status']);

    final progress =
        int.tryParse(
          digitalTwinSnapshot?['progress_percent']?.toString() ?? '',
        ) ??
        int.tryParse(cleanText(project!['progress'])) ??
        0;

    final totalLabor = project!['total_labor'] ?? 0;

    // ================================
    // HOME INSIGHTS VALUES
    // Use real Supabase counts loaded in loadProject().
    // ================================
    final totalMaterial = materialCount;
    final totalEquipment = equipmentCount;

    final managerName =
        manager == null
            ? "No manager assigned"
            : cleanText(manager!['full_name']).isEmpty
            ? "Manager"
            : cleanText(manager!['full_name']);

    final embeddedSectionHeight = (MediaQuery.of(context).size.height - 260)
        .clamp(520.0, 760.0);

    final projectLatitude = double.tryParse(
      cleanText(project!['latitude']).isEmpty
          ? cleanText(project!['lat'])
          : cleanText(project!['latitude']),
    );

    final projectLongitude = double.tryParse(
      cleanText(project!['longitude']).isEmpty
          ? cleanText(project!['lng'])
          : cleanText(project!['longitude']),
    );

    return Scaffold(
      backgroundColor: Colors.white,

      drawer: OwnerSidebar(
        ownerName: "Owner",
        profileImageUrl: null,
        onLogout: () async {
          await supabase.auth.signOut();

          if (!mounted) return;

          Navigator.pushReplacementNamed(context, '/login');
        },
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,

        title: Builder(
          builder: (context) {
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),

                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),

                const Spacer(),

                // ================================
                // NOTIFICATION BELL INTEGRATION
                // Replaces the static notification icon with a clickable bell.
                // Opens NotificationsPage and shows unread notification badge.
                // onClosed refreshes project data after returning.
                // ================================
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: NotificationBell(
                    color: primaryColor,
                    onClosed: loadProject,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadProject,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================================
              // CUSTOM PROJECT HEADER
              // Makes the status badge green when the project is In Progress.
              // ================================
              buildProjectHeader(
                projectName: projectName,
                location: location,
                imageUrl: imageUrl,
                status: status,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      buildTab("home", "Home"),
                      buildTab("digital_twin", "Digital Twin"),
                      buildTab("material", "Material"),
                      buildTab("equipment", "Equipment"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedTab == "home")
                buildHomeSection(
                  totalLabor: totalLabor,
                  totalMaterial: totalMaterial,
                  totalEquipment: totalEquipment,
                  managerName: managerName,
                  progress: progress,
                ),
              if (selectedTab == "digital_twin")
                SizedBox(
                  height: 1700,
                  child: DigitalTwinPage(project: project!),
                ),
              if (selectedTab == "material")
                SizedBox(
                  height: embeddedSectionHeight,
                  // ================================
                  // OWNER READ-ONLY MATERIALS PAGE
                  // The owner can view materials and totals only.
                  // No add, edit, or delete actions are available here.
                  // ================================
                  child: OwnerProjectMaterialsPage(
                    projectId: widget.projectId,
                    projectName: projectName,
                  ),
                ),
              if (selectedTab == "equipment")
                SizedBox(
                  height: embeddedSectionHeight,
                  // ================================
                  // OWNER READ-ONLY EQUIPMENT PAGE
                  // The owner can view equipment and live map only.
                  // No add, edit, or delete actions are available here.
                  // ================================
                  child: OwnerProjectEquipmentPage(
                    projectId: widget.projectId,
                    projectName: projectName,
                    projectLatitude: projectLatitude,
                    projectLongitude: projectLongitude,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  // ================================
  // PROJECT HEADER
  // Same content as OwnerProjectHeader, but with a green In Progress badge.
  // ================================
  Widget buildProjectHeader({
    required String projectName,
    required String location,
    required String imageUrl,
    required String status,
  }) {
    final normalizedStatus = status.toLowerCase();
    final isInProgress = normalizedStatus.contains('progress');

    final statusColor = isInProgress ? greenColor : const Color(0xffff8a00);
    final statusBg =
        isInProgress ? greenColor.withOpacity(.12) : const Color(0xfffff3e4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: isValidImageUrl(imageUrl)
              ? Image.network(
                  imageUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: primaryColor,
                    size: 40,
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildHomeSection({
    required dynamic totalLabor,
    required dynamic totalMaterial,
    required dynamic totalEquipment,
    required String managerName,
    required int progress,
  }) {
    final managerImage = cleanText(manager?['profile_image_url']);

    final approvalStatus =
        cleanText(project!['approval_status']).isEmpty
            ? "Approved"
            : cleanText(project!['approval_status']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchBox(),

        const SizedBox(height: 28),

        Row(
          children: const [
            Text(
              "Project Insights",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Spacer(),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            statCard("Total Labor", totalLabor.toString(), Colors.teal),
            const SizedBox(width: 12),
            statCard("Materials", totalMaterial.toString(), Colors.blue),
            const SizedBox(width: 12),
            statCard("Equipment", totalEquipment.toString(), Colors.orange),
          ],
        ),

        const SizedBox(height: 28),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: managerSection(
                      managerName: managerName,
                      managerImage: managerImage,
                    ),
                  ),
                  const SizedBox(width: 18),
                  progressCircle(progress),
                ],
              ),

              const SizedBox(height: 22),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: infoTile(
                      Icons.calendar_today_outlined,
                      "Start Date",
                      cleanText(project!['start_date']),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: infoTile(
                      Icons.event_available_outlined,
                      "End Date",
                      cleanText(project!['end_date']),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: infoTile(
                      Icons.location_on_outlined,
                      "Location",
                      cleanText(project!['location']).isEmpty
                          ? cleanText(project!['city'])
                          : cleanText(project!['location']),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: infoTile(
                      Icons.verified_outlined,
                      "Approval",
                      approvalStatus,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: greenColor.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: greenColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        progress >= 100
                            ? "Project completed successfully."
                            : "Project is currently $progress% complete and progressing normally.",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        Row(
          children: const [
            Text(
              "Site Photos",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Spacer(),
          ],
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              addPhotoBox(),
              const SizedBox(width: 12),
              ...sitePhotos.map((photo) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: photoBox(photo['image_url']?.toString() ?? ''),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildTab(String key, String title) {
    final isSelected = selectedTab == key;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = key;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isSelected ? primaryColor : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget searchBox() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: const InputDecoration(
          hintText: "Search project details...",
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 14),
        ),
      ),
    );
  }

  Widget managerSection({
    required String managerName,
    required String managerImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Assigned Manager",
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  isValidImageUrl(managerImage)
                      ? NetworkImage(managerImage)
                      : null,
              child:
                  !isValidImageUrl(managerImage)
                      ? const Icon(Icons.person, color: primaryColor)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    managerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cleanText(manager?['email']).isEmpty
                        ? "Project Manager"
                        : cleanText(manager?['email']),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: openManagerWhatsApp,
          icon: const Icon(Icons.chat_bubble_outline, size: 15),
          label: const Text("Chat with manager"),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ================================
  // ASSIGNED MANAGER PROGRESS CIRCLE
  // Displays project progress using latest digital_twin_snapshots
  // if available, otherwise falls back to projects.progress.
  // ================================
  Widget progressCircle(int progress) {
    final safeProgress = progress.clamp(0, 100);

    return SizedBox(
      width: 104,
      child: Column(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CircularProgressIndicator(
                    value: safeProgress / 100,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(greenColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$safeProgress%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    const Text("Complete", style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget infoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "-" : value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget photoBox(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child:
          isValidImageUrl(imageUrl)
              ? Image.network(
                imageUrl,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
              )
              : photoPlaceholder(),
    );
  }

  Widget photoPlaceholder() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // ================================
  // ADD PHOTO BUTTON
  // First item in Site Photos list.
  // Pressing it opens gallery and uploads selected image.
  // ================================
  Widget addPhotoBox() {
    return GestureDetector(
      onTap: isUploadingPhoto ? null : pickAndUploadSitePhoto,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child:
            isUploadingPhoto
                ? const Center(child: CircularProgressIndicator())
                : const Icon(Icons.add_a_photo_outlined, color: Colors.blue),
      ),
    );
  }
}
