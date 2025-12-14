import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Role state
  String? _selectedRole;
  final List<String> roles = ['Admin', 'Engineer', 'Contractor', 'Client'];

  // Firebase services
  final AuthService auth = AuthService();
  final UserService userService = UserService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = await auth.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      if (user != null) {
        // save additional user info to Firestore
        await userService.addUser(
          user.uid,
          _nameController.text.trim(),
          user.email!,
          _mobileController.text.trim(),
          _selectedRole ?? '',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully 🎉"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // Input Field Widget
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool isRequired = false,
    bool isEmail = false,
    bool isPasswordValidation = false,
    bool isMobileNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isMobileNumber ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) return 'Please enter $label';
            if (isEmail) {
              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegExp.hasMatch(value!)) return 'Enter a valid email';
            }
            if (isPasswordValidation) {
              if (value!.length < 8) return 'Password must be at least 8 characters';
            }
            if (isMobileNumber) {
              final numberRegExp = RegExp(r'^[0-9]+$');
              if (!numberRegExp.hasMatch(value!)) return 'Mobile number must contain digits only';
              if (value.length < 9 || value.length > 15) return 'Please enter a valid phone number (9-15 digits)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            isExpanded: true,
            hint: const Text('Select role', style: TextStyle(color: Colors.white54)),
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color.fromARGB(255, 55, 54, 54),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: roles.map((role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (newValue) => setState(() => _selectedRole = newValue),
            validator: (value) => value == null ? 'Please select a role' : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Background_building.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.5)),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Container(color: Colors.black.withOpacity(0.1))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    children: [
                      Image.asset('assets/Logo_DTPCM.png', height: 200),
                      const SizedBox(height: 20),
                      _buildInputField(label: 'Full Name', controller: _nameController, isRequired: true),
                      const SizedBox(height: 15),
                      _buildInputField(label: 'Email Address', controller: _emailController, isRequired: true, isEmail: true),
                      const SizedBox(height: 15),
                      _buildInputField(label: 'Mobile Number', controller: _mobileController, isRequired: true, isMobileNumber: true),
                      const SizedBox(height: 15),
                      _buildRoleSelection(),
                      const SizedBox(height: 15),
                      _buildInputField(label: 'Password', controller: _passwordController, isRequired: true, isPassword: true, isPasswordValidation: true),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0d1b46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Create account', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: Colors.white),
                            children: [TextSpan(text: 'Log in', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
