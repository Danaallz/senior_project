import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:senior_project/screens/Manager/project_materials_page.dart';
import 'package:senior_project/screens/digital_twin_page.dart';
import 'package:senior_project/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Manager/project_equipment_page.dart';
import 'owner_project_page.dart';

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

  Future<void> loadProject() async {
    try {
      final projectData = await supabaseService.getProjectById(
        widget.projectId,
      );

      Map<String, dynamic>? managerData;
      final managerId = cleanText(projectData?['assigned_manager_id']);

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

      if (!mounted) return;

      setState(() {
        project = projectData;
        manager = managerData;
        digitalTwinSnapshot = snapshotData;
        sitePhotos = List<Map<String, dynamic>>.from(photosResponse);
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
            ? "pending"
            : cleanText(project!['status']);

    final progress =
        int.tryParse(
          digitalTwinSnapshot?['progress_percent']?.toString() ?? '',
        ) ??
        int.tryParse(cleanText(project!['progress'])) ??
        0;

    final totalLabor = project!['total_labor'] ?? 0;
    final totalMaterial = project!['total_material'] ?? 0;
    final totalEquipment = project!['total_equipment'] ?? 0;

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none, color: primaryColor),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadProject,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OwnerProjectHeader(
                projectName: projectName,
                location: location,
                imageUrl: imageUrl,
                status: status,
              ),
              const SizedBox(height: 22),
              OwnerProjectTabBar(
                selectedTab: selectedTab,
                onTabSelected: (value) {
                  setState(() {
                    selectedTab = value;
                  });
                },
              ),
              const SizedBox(height: 20),
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
                  child: ProjectMaterialsPage(
                    projectId: widget.projectId,
                    projectName: projectName,
                  ),
                ),
              if (selectedTab == "equipment")
                SizedBox(
                  height: embeddedSectionHeight,
                  child: ProjectEquipmentPage(
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

  Widget buildHomeSection({
    required dynamic totalLabor,
    required dynamic totalMaterial,
    required dynamic totalEquipment,
    required String managerName,
    required int progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            statCard("Total Labor", totalLabor.toString(), Colors.teal),
            const SizedBox(width: 8),
            statCard("Total Material", totalMaterial.toString(), Colors.blue),
            const SizedBox(width: 8),
            statCard(
              "Total Equipment",
              totalEquipment.toString(),
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Assigned Manager",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      managerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: openManagerWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline, size: 12),
                      label: const Text("Chat with manager"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      progress >= 100
                          ? "Project completed"
                          : "Project is $progress% complete",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Start: ${cleanText(project!['start_date'])}\nEnd: ${cleanText(project!['end_date'])}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0, 100) / 100,
                      strokeWidth: 9,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(greenColor),
                    ),
                    Text(
                      "$progress%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Text(
              "Site Photos",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Spacer(),
            Text(
              "view all >",
              style: TextStyle(color: primaryColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              addPhotoBox(),
              const SizedBox(width: 10),
              ...sitePhotos.map((photo) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: photoBox(photo['image_url']?.toString() ?? ''),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
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
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              )
              : photoPlaceholder(),
    );
  }

  Widget photoPlaceholder() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget addPhotoBox() {
    return GestureDetector(
      onTap: isUploadingPhoto ? null : pickAndUploadSitePhoto,
      child: Container(
        width: 88,
        height: 88,
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
