import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/worker_service.dart';

class AddWorkerPage extends StatefulWidget {
  final String? projectId;

  const AddWorkerPage({super.key, this.projectId});

  @override
  State<AddWorkerPage> createState() => _AddWorkerPageState();
}

class _AddWorkerPageState extends State<AddWorkerPage> {
  final _formKey = GlobalKey<FormState>();

  final supabase = Supabase.instance.client;
  final WorkerService workerService = WorkerService();

  String? selectedRole;
  String salaryType = "month";
  String shiftType = "day";
  File? selectedImage;

  bool isLoadingSiteEngineers = false;
  bool isSaving = false;

  List<Map<String, dynamic>> siteEngineers = [];
  Map<String, dynamic>? selectedSiteEngineer;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final salaryController = TextEditingController();
  final dateController = TextEditingController(text: "2024-10-25");

  bool get isSiteEngineerRole {
    return selectedRole?.toLowerCase().trim() == "site engineer";
  }

  @override
  void initState() {
    super.initState();
    salaryController.addListener(() {
      setState(() {});
    });
    loadSiteEngineers();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    salaryController.dispose();
    dateController.dispose();
    super.dispose();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadSiteEngineers() async {
    setState(() => isLoadingSiteEngineers = true);

    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, profile_image_url, role')
          .or('role.eq.site engineer,role.eq.site_engineer')
          .order('full_name', ascending: true);

      if (!mounted) return;

      setState(() {
        siteEngineers = List<Map<String, dynamic>>.from(response);
        isLoadingSiteEngineers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoadingSiteEngineers = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load site engineers: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void fillSiteEngineerInfo(Map<String, dynamic> engineer) {
    setState(() {
      selectedSiteEngineer = engineer;
      nameController.text = cleanText(engineer['full_name']);
      phoneController.text = cleanText(engineer['phone']);
      emailController.text = cleanText(engineer['email']);
      selectedImage = null;
    });
  }

  void clearPersonInfo() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    selectedSiteEngineer = null;
    selectedImage = null;
  }

  Future<void> pickImage(ImageSource source) async {
    if (isSiteEngineerRole) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        dateController.text =
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // ================================
  // MANAGER WORKER NOTIFICATION
  // Notifies the manager when a worker or site engineer is added to the project.
  // ================================
  Future<void> createWorkerNotification() async {
    try {
      final managerId = supabase.auth.currentUser?.id;
      final projectId = widget.projectId;

      if (managerId == null || managerId.isEmpty || projectId == null) {
        return;
      }

      final workerName = nameController.text.trim().isEmpty
          ? 'Worker'
          : nameController.text.trim();

      final role = selectedRole ?? 'Worker';

      final existing = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', managerId)
          .eq('project_id', projectId)
          .eq('type', 'worker_added')
          .eq('message', '$workerName - $role')
          .limit(1);

      if (existing.isNotEmpty) return;

      await supabase.from('notifications').insert({
        'user_id': managerId,
        'project_id': projectId,
        'type': 'worker_added',
        'title': 'Worker Added',
        'message': '$workerName has been added as $role.',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Worker notification error: $e');
    }
  }

  Future<void> saveWorker() async {
    try {
      if (!_formKey.currentState!.validate()) return;

      if (selectedRole == null) {
        showError("Please select worker role");
        return;
      }

      if (isSiteEngineerRole && selectedSiteEngineer == null) {
        showError("Please select a site engineer");
        return;
      }

      setState(() => isSaving = true);

      if (isSiteEngineerRole) {
        await saveSelectedSiteEngineerAsWorker();
      } else {
        await workerService.addWorker(
          name: nameController.text.trim(),
          role: selectedRole!,
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
          salary: salaryController.text.trim(),
          salaryType: salaryType,
          shiftType: shiftType,
          joiningDate: dateController.text.trim(),
          projectId: widget.projectId,
          imageFile: selectedImage,
        );
      }

      // ================================
      // CREATE MANAGER WORKER NOTIFICATION
      // Sent after the worker/site engineer is added successfully.
      // ================================
      await createWorkerNotification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Worker added successfully ✅"),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      showError("Error: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> saveSelectedSiteEngineerAsWorker() async {
    final imageUrl = cleanText(selectedSiteEngineer?['profile_image_url']);

    final insertedWorker =
        await supabase
            .from('workers')
            .insert({
              'name': nameController.text.trim(),
              'role': 'Site engineer',
              'phone': phoneController.text.trim(),
              'email': emailController.text.trim(),
              'salary': salaryController.text.trim(),
              'salary_type': salaryType,
              'shift_type': shiftType,
              'joining_date': dateController.text.trim(),
              'image_url': imageUrl.isEmpty ? null : imageUrl,
              'created_by': supabase.auth.currentUser?.id,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

    if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      await supabase.from('project_workers').insert({
        'project_id': widget.projectId,
        'worker_id': insertedWorker['id'],
        'assigned_by': supabase.auth.currentUser?.id,
      });

      await supabase
          .from('projects')
          .update({'assigned_site_engineer_id': selectedSiteEngineer!['id']})
          .eq('id', widget.projectId!);
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = cleanText(
      selectedSiteEngineer?['profile_image_url'],
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Add Worker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldTitle("Role"),
              roleDropdown(),

              if (isSiteEngineerRole) ...[
                fieldTitle("Choose Site Engineer"),
                siteEngineerDropdown(),
                const SizedBox(height: 8),
                if (selectedSiteEngineer != null)
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          profileImageUrl.startsWith('http')
                              ? NetworkImage(profileImageUrl)
                              : null,
                      child:
                          profileImageUrl.startsWith('http')
                              ? null
                              : const Icon(Icons.person, size: 42),
                    ),
                  ),
              ],

              fieldTitle("Name"),
              inputField(
                controller: nameController,
                hint: "Enter name",
                enabled: !isSiteEngineerRole,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Name is required";
                  }

                  final parts = value.trim().split(" ");
                  if (parts.length < 2) {
                    return "Please enter first and last name";
                  }

                  return null;
                },
              ),

              fieldTitle("Contact Number"),
              inputField(
                controller: phoneController,
                hint: "Enter contact number",
                enabled: !isSiteEngineerRole,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Contact number is required";
                  }

                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                    return "Only digits allowed";
                  }

                  if (value.length != 10) {
                    return "Must be exactly 10 digits";
                  }

                  return null;
                },
              ),

              fieldTitle("Email Address"),
              inputField(
                controller: emailController,
                hint: "Enter email address",
                enabled: !isSiteEngineerRole,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Email is required";
                  }

                  final regex = RegExp(
                    r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );

                  if (!regex.hasMatch(value)) {
                    return "Enter a valid email";
                  }

                  return null;
                },
              ),

              fieldTitle("Salary"),
              Row(
                children: [
                  radioOption("Per Month", "month"),
                  const SizedBox(width: 20),
                  radioOption("Per Day", "day"),
                ],
              ),

              TextFormField(
                controller: salaryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "EX: 15,000",
                  prefixIcon:
                      salaryController.text.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/SAR.svg',
                              color: const Color.fromARGB(255, 41, 106, 44),
                              width: 15,
                              height: 15,
                            ),
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Salary is required";
                  }

                  final salary = int.tryParse(value.replaceAll(',', ''));

                  if (salary == null || salary < 500) {
                    return "Enter valid salary (>= 500)";
                  }

                  return null;
                },
              ),

              fieldTitle("Shift"),
              Row(
                children: [
                  shiftOption("Day Shift", "day"),
                  const SizedBox(width: 20),
                  shiftOption("Night Shift", "night"),
                ],
              ),

              fieldTitle("Joining Date"),
              TextFormField(
                controller: dateController,
                readOnly: false,
                decoration: InputDecoration(
                  hintText: "YYYY-MM-DD",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: pickDate,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Joining date is required";
                  }

                  final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                  if (!regex.hasMatch(value.trim())) {
                    return "Use date format YYYY-MM-DD";
                  }

                  if (DateTime.tryParse(value.trim()) == null) {
                    return "Enter a valid date";
                  }

                  return null;
                },
              ),

              if (!isSiteEngineerRole) ...[
                fieldTitle("Worker Photo"),
                if (selectedImage != null)
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: FileImage(selectedImage!),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    actionButton(
                      icon: Icons.camera_alt,
                      text: "Take Photo",
                      onTap: () => pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 10),
                    actionButton(
                      icon: Icons.cloud_upload_outlined,
                      text: "Add Photo",
                      onTap: () => pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0A1D44),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving ? null : saveWorker,
                  child:
                      isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            "Save Worker",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget fieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade200,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  Widget roleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: const Text("Select"),
          value: selectedRole,
          isExpanded: true,
          items:
              [
                "Site engineer",
                "Concrete worker",
                "Mason",
                "Painter",
                "Electrician",
                "Plumber / Pipefitter",
                "Carpenter",
                "HVAC tech",
                "Ironworker / Welder",
                "Tile and marble setter",
                "Laborer",
                "superintendents",
                "operators",
              ].map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
          onChanged: (value) {
            setState(() {
              selectedRole = value;

              if (value?.toLowerCase().trim() == "site engineer") {
                selectedSiteEngineer = null;
                nameController.clear();
                phoneController.clear();
                emailController.clear();
                selectedImage = null;
              } else {
                clearPersonInfo();
              }
            });
          },
        ),
      ),
    );
  }

  Widget siteEngineerDropdown() {
    if (isLoadingSiteEngineers) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: selectedSiteEngineer,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: "Select existing site engineer",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          siteEngineers.map((engineer) {
            final name =
                cleanText(engineer['full_name']).isNotEmpty
                    ? cleanText(engineer['full_name'])
                    : cleanText(engineer['name']).isNotEmpty
                    ? cleanText(engineer['name'])
                    : cleanText(engineer['email']);

            return DropdownMenuItem<Map<String, dynamic>>(
              value: engineer,
              child: Text(name),
            );
          }).toList(),
      onChanged: (value) {
        if (value == null) return;
        fillSiteEngineerInfo(value);
      },
      validator: (_) {
        if (isSiteEngineerRole && selectedSiteEngineer == null) {
          return "Please select a site engineer";
        }
        return null;
      },
    );
  }

  Widget radioOption(String title, String value) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: salaryType,
          onChanged: (val) {
            setState(() => salaryType = val!);
          },
        ),
        Text(title),
      ],
    );
  }

  Widget shiftOption(String title, String value) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: shiftType,
          onChanged: (val) {
            setState(() => shiftType = val!);
          },
        ),
        Text(title),
      ],
    );
  }

  Widget actionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.black),
              const SizedBox(height: 6),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
