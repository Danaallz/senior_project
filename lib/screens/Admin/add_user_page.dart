import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final supabase = Supabase.instance.client;

  // Use the same URL and anon key from your main.dart / .env
  static const String supabaseUrl = 'https://obiwgenpodvxcdgfjkyc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iaXdnZW5wb2R2eGNkZ2Zqa3ljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjIwMzksImV4cCI6MjA5MTYzODAzOX0.EAEuUgG-W0p5o3-114jxWk5Ge3phxJjMJvOeUcHxaaY';

  late final SupabaseClient createUserClient = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final ImagePicker picker = ImagePicker();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = 'manager';

  XFile? selectedImage;
  Uint8List? selectedImageBytes;

  bool isSaving = false;
  bool obscurePassword = true;

  final List<Map<String, String>> roles = [
    {'label': 'Manager', 'value': 'manager'},
    {'label': 'Owner', 'value': 'owner'},
    {'label': 'Site Engineer', 'value': 'site engineer'},
  ];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final image = await picker.pickImage(source: source);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      selectedImage = image;
      selectedImageBytes = bytes;
    });
  }

  Future<String?> uploadUserImage(String userId) async {
    if (selectedImageBytes == null) return null;

    final fileName =
        'user_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('manager-images')
        .uploadBinary(
          fileName,
          selectedImageBytes!,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('manager-images').getPublicUrl(fileName);
  }

  Future<void> saveUser() async {
    final adminUserIdBefore = supabase.auth.currentUser?.id;

    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      showError("Name is required");
      return;
    }

    if (email.isEmpty || !email.contains("@")) {
      showError("Enter a valid email");
      return;
    }

    if (password.length < 8) {
      showError("Password must be at least 8 characters");
      return;
    }

    setState(() => isSaving = true);

    try {
      final authResponse = await createUserClient.auth.signUp(
        email: email,
        password: password,
      );

      final newUser = authResponse.user;

      if (newUser == null) {
        throw Exception("Unable to create user login account.");
      }

      final imageUrl = await uploadUserImage(newUser.id);

      await supabase.from('profiles').insert({
        'id': newUser.id,
        'full_name': name,
        'email': email,
        'phone': phone,
        'role': selectedRole,
        'profile_image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      final adminUserIdAfter = supabase.auth.currentUser?.id;

      if (adminUserIdBefore != adminUserIdAfter) {
        throw Exception("Admin session changed. Please log in as admin again.");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${roles.firstWhere((r) => r['value'] == selectedRole)['label']} account created successfully ✅",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } on AuthException catch (e) {
      showError("Auth error: ${e.message}");
    } on PostgrestException catch (e) {
      showError("Database error: ${e.message}");
    } catch (e) {
      showError("Error adding user: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String pageTitle() {
    final roleLabel =
        roles.firstWhere((r) => r['value'] == selectedRole)['label'];
    return "Add $roleLabel";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(pageTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  selectedImageBytes != null
                      ? MemoryImage(selectedImageBytes!)
                      : null,
              child:
                  selectedImageBytes == null
                      ? const Icon(Icons.person, size: 45, color: Colors.grey)
                      : null,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: imageButton(
                  title: "Take Photo",
                  icon: Icons.camera_alt_outlined,
                  color: Colors.blue,
                  onTap: () => pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: imageButton(
                  title: "Add Photo",
                  icon: Icons.cloud_upload_outlined,
                  color: Colors.deepPurple,
                  onTap: () => pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text("Role", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: inputDecoration(Icons.admin_panel_settings),
            items:
                roles.map((role) {
                  return DropdownMenuItem<String>(
                    value: role['value'],
                    child: Text(role['label']!),
                  );
                }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedRole = value);
            },
          ),

          const SizedBox(height: 18),

          const Text(
            "Full Name",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          textField(nameController, "Enter full name", Icons.person),

          const SizedBox(height: 18),

          const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          textField(emailController, "Enter email", Icons.email),

          const SizedBox(height: 18),

          const Text("Phone", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          textField(phoneController, "Enter phone number", Icons.phone),

          const SizedBox(height: 18),

          const Text(
            "Temporary Password",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: inputDecoration(Icons.lock).copyWith(
              hintText: "Enter temporary password",
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blue.withOpacity(0.15)),
            ),
            child: const Text(
              "The admin creates the account here. The user can then log in using this email and temporary password.",
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff0d1b46),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isSaving ? null : saveUser,
          child:
              isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                    "Create User Account",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xff0d1b46)),
      filled: true,
      fillColor: const Color(0xfff8f9fb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget imageButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(title, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: color.withOpacity(0.55)),
        backgroundColor: color.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget textField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: inputDecoration(icon).copyWith(hintText: hint),
    );
  }
}
