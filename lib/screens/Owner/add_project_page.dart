import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/services/supabase_service.dart';

class AddProjectPage extends StatefulWidget {
  final Map<String, dynamic>? existingProject;

  const AddProjectPage({super.key, this.existingProject});

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final supabaseService = SupabaseService();
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final locationController = TextEditingController();

  bool get isEditMode => widget.existingProject != null;

  String? selectedCity;
  String? selectedManagerId;

  List<Map<String, dynamic>> managers = [];
  bool isLoadingManagers = false;

  final Map<String, LatLng> cityLocations = {
    'Jeddah': const LatLng(21.543333, 39.172779),
    'Makkah': const LatLng(21.389082, 39.857912),
    'Riyadh': const LatLng(24.713552, 46.675297),
    'Dammam': const LatLng(26.420683, 50.088794),
    'Khobar': const LatLng(26.217191, 50.197138),
    'Madinah': const LatLng(24.524654, 39.569184),
    'Taif': const LatLng(21.437273, 40.512714),
    'Abha': const LatLng(18.246469, 42.511723),
    'Tabuk': const LatLng(28.383507, 36.566190),
    'NEOM': const LatLng(28.111073, 35.195820),
  };

  GoogleMapController? mapController;
  LatLng selectedLocation = const LatLng(21.543333, 39.172779);
  Marker? projectMarker;
  double? selectedLat;
  double? selectedLng;

  DateTime? startDate;
  DateTime? endDate;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;

  PlatformFile? selectedBimFile;
  Uint8List? bimBytes;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadExistingProject();
    loadManagers();
  }

  void loadExistingProject() {
    if (!isEditMode) return;

    final p = widget.existingProject!;

    nameController.text = p['name']?.toString() ?? '';
    locationController.text = p['location']?.toString() ?? '';
    selectedCity = p['city']?.toString();
    selectedManagerId = p['assigned_manager_id']?.toString();

    final lat = double.tryParse(p['latitude']?.toString() ?? '');
    final lng = double.tryParse(p['longitude']?.toString() ?? '');

    if (lat != null && lng != null) {
      selectedLat = lat;
      selectedLng = lng;
      selectedLocation = LatLng(lat, lng);

      projectMarker = Marker(
        markerId: const MarkerId("project_location"),
        position: selectedLocation,
      );
    } else if (selectedCity != null && cityLocations[selectedCity] != null) {
      selectedLocation = cityLocations[selectedCity]!;
    }

    startDate = DateTime.tryParse(p['start_date']?.toString() ?? '');
    endDate = DateTime.tryParse(p['end_date']?.toString() ?? '');
  }

  Future<void> loadManagers() async {
    setState(() => isLoadingManagers = true);

    try {
      final response = await supabaseService.getManagers();

      if (!mounted) return;

      setState(() {
        managers = response;
      });
    } catch (e) {
      debugPrint("Load managers error: $e");
      if (!mounted) return;
      showMessage("Unable to load managers: $e");
    } finally {
      if (mounted) {
        setState(() => isLoadingManagers = false);
      }
    }
  }

  String cleanInput(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[<>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? validateText(String? value, String fieldName) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return "$fieldName is required";
    if (text.length < 2) return "$fieldName is too short";
    if (text.length > 120) return "$fieldName is too long";

    if (RegExp(r'[<>]').hasMatch(text)) {
      return "$fieldName contains invalid characters";
    }

    return null;
  }

  Future<void> moveMapToCity(String city) async {
    final cityLatLng = cityLocations[city];
    if (cityLatLng == null) return;

    setState(() {
      selectedCity = city;
      selectedLocation = cityLatLng;
      selectedLat = null;
      selectedLng = null;
      projectMarker = null;
      locationController.clear();
    });

    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: cityLatLng, zoom: 11),
      ),
    );
  }

  Future<void> selectLocation(LatLng position) async {
    setState(() {
      selectedLocation = position;
      selectedLat = position.latitude;
      selectedLng = position.longitude;

      projectMarker = Marker(
        markerId: const MarkerId("project_location"),
        position: position,
      );
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        locationController.text = [
          place.street ?? '',
          place.locality ?? '',
          place.country ?? '',
        ].where((item) => item.trim().isNotEmpty).join(', ');
      }
    } catch (_) {
      locationController.text =
          "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
    }
  }

  Future<void> pickProjectImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();

      setState(() {
        selectedImage = image;
        selectedImageBytes = bytes;
      });
    }
  }

  Future<void> pickBimFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedBimFile = result.files.first;
        bimBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? startDate ?? DateTime.now() : endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select date";

    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<String?> uploadProjectImage(String projectTempId) async {
    if (selectedImage == null || selectedImageBytes == null) return null;

    final fileName =
        'project_${projectTempId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('project-images')
        .uploadBinary(
          fileName,
          selectedImageBytes!,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('project-images').getPublicUrl(fileName);
  }

  Future<String?> uploadBimFile(String projectTempId) async {
    if (selectedBimFile == null || bimBytes == null) return null;

    final originalName = selectedBimFile!.name.replaceAll(' ', '_');

    final fileName =
        'bim_${projectTempId}_${DateTime.now().millisecondsSinceEpoch}_$originalName';

    await supabase.storage
        .from('bim-files')
        .uploadBinary(
          fileName,
          bimBytes!,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('bim-files').getPublicUrl(fileName);
  }

  Future<void> createProject() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCity == null) {
      showMessage("Please select city");
      return;
    }

    if (selectedLat == null || selectedLng == null) {
      showMessage("Please select project location from the map");
      return;
    }

    if (selectedManagerId == null) {
      showMessage("Please select project manager");
      return;
    }

    if (startDate == null || endDate == null) {
      showMessage("Please select start and end dates");
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      showMessage("End date must be after start date");
      return;
    }

    if (!isEditMode && selectedImage == null) {
      showMessage("Please upload project image");
      return;
    }

    if (!isEditMode && selectedBimFile == null) {
      showMessage("Please upload BIM file");
      return;
    }

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final currentProfile = await supabaseService.getCurrentProfile();

      if (currentProfile == null) {
        throw Exception("Owner profile not found");
      }

      final projectData = <String, dynamic>{
        'name': cleanInput(nameController.text),
        'location': cleanInput(locationController.text),
        'city': selectedCity,
        'latitude': selectedLat,
        'longitude': selectedLng,
        'start_date': formatDate(startDate),
        'end_date': formatDate(endDate),
        'status': 'Pending',
        'approval_status': 'Pending',
        'assigned_manager_id': selectedManagerId,
      };

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      if (selectedImage != null) {
        final imageUrl = await uploadProjectImage(tempId);
        projectData['image_url'] = imageUrl;
      }

      if (selectedBimFile != null) {
        final bimUrl = await uploadBimFile(tempId);
        projectData['bim_file_url'] = bimUrl;
      }

      if (isEditMode) {
        await supabaseService.updateProject(
          projectId: widget.existingProject!['id'].toString(),
          data: projectData,
        );
      } else {
        projectData.addAll({
          'owner_id': currentProfile['id'],
          'progress': 0,
          'total_labor': 0,
          'total_material': 0,
          'total_equipment': 0,
        });

        await supabaseService.createProject(data: projectData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? "Project updated and sent for admin approval."
                : "Project submitted for admin approval ✅",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Save project error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to save project: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Widget inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: (value) => validateText(value, label),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }

  Widget managerDropdown() {
    final managerIds = managers.map((m) => m['id'].toString()).toList();

    final safeValue =
        managerIds.contains(selectedManagerId) ? selectedManagerId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Project Manager",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          hint: Text(
            isLoadingManagers ? "Loading managers..." : "Select manager",
          ),
          validator:
              (value) => value == null ? "Project manager is required" : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          items:
              managers.map((manager) {
                final managerName =
                    manager['full_name']?.toString().trim().isNotEmpty == true
                        ? manager['full_name'].toString()
                        : manager['email']?.toString() ?? 'Manager';

                return DropdownMenuItem<String>(
                  value: manager['id'].toString(),
                  child: Text(managerName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
          onChanged:
              isLoadingManagers
                  ? null
                  : (value) {
                    setState(() {
                      selectedManagerId = value;
                    });
                  },
        ),
      ],
    );
  }

  Widget cityDropdown() {
    final cityNames = cityLocations.keys.toList();

    final safeValue = cityNames.contains(selectedCity) ? selectedCity : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("City", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          hint: const Text("Select city"),
          validator: (value) => value == null ? "City is required" : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          items:
              cityNames.map((city) {
                return DropdownMenuItem<String>(value: city, child: Text(city));
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              moveMapToCity(value);
            }
          },
        ),
      ],
    );
  }

  Widget googleMapPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Project Location",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: selectedLocation,
                zoom: 11,
              ),
              onMapCreated: (controller) {
                mapController = controller;

                if (isEditMode) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: selectedLocation, zoom: 11),
                    ),
                  );
                }
              },
              markers: projectMarker == null ? {} : {projectMarker!},
              onTap: selectLocation,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Move, zoom, then tap on the map to select the exact project location.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget uploadBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff0d1b46)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.upload_file),
          ],
        ),
      ),
    );
  }

  Widget dateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(formatDate(date))),
                  const Icon(Icons.calendar_month),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageSubtitle =
        selectedImage == null
            ? isEditMode
                ? "Keep current image or upload new one"
                : "Upload project image"
            : selectedImage!.name;

    final bimSubtitle =
        selectedBimFile == null
            ? isEditMode
                ? "Keep current BIM file or upload new one"
                : "Upload BIM / GLB file"
            : selectedBimFile!.name;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Project" : "Add New Project",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              inputField(
                label: "Project Name",
                hint: "Enter project name",
                controller: nameController,
              ),
              const SizedBox(height: 16),
              managerDropdown(),
              const SizedBox(height: 16),
              cityDropdown(),
              const SizedBox(height: 16),
              googleMapPicker(),
              const SizedBox(height: 16),
              inputField(
                label: "Selected Location",
                hint: "Tap on map to select location",
                controller: locationController,
                readOnly: true,
                suffixIcon: const Icon(Icons.location_on_outlined),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  dateBox(
                    label: "Start Date",
                    date: startDate,
                    onTap: () => pickDate(isStart: true),
                  ),
                  const SizedBox(width: 12),
                  dateBox(
                    label: "End Date",
                    date: endDate,
                    onTap: () => pickDate(isStart: false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              uploadBox(
                title: "Project Image",
                subtitle: imageSubtitle,
                icon: Icons.image_outlined,
                onTap: pickProjectImage,
              ),
              const SizedBox(height: 14),
              uploadBox(
                title: "BIM / Digital Twin File",
                subtitle: bimSubtitle,
                icon: Icons.view_in_ar_outlined,
                onTap: pickBimFile,
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : createProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0d1b46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child:
                      isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            isEditMode ? "Save Changes" : "Submit Project",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
