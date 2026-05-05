import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';

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

  final List<String> roles = [
    'Project Manager',
    'Owner',
    'Site Engineer',
  ];

  // Firebase services
  final AuthService auth = AuthService();
  final UserService userService = UserService();
  final SupabaseService supabaseService = SupabaseService();

  bool _isLoading = false;

  String cleanInput(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

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

    setState(() => _isLoading = true);

    final fullName = cleanInput(_nameController.text);
    final email = _emailController.text.trim().toLowerCase();
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final user = await auth.register(
        email,
        password,
        fullName,
      );

      if (user != null) {
      // save additional user info to Firestore
        await userService.addUser(
          user.uid,
          fullName,
          user.email ?? email,
          mobile,
          _selectedRole ?? '',
        );

        await supabaseService.addProfile(
          firebaseUid: user.uid,
          fullName: fullName,
          email: user.email ?? email,
          phone: mobile,
          role: _selectedRole ?? '',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully 🎉"),
            backgroundColor: Colors.green,
          ),
        );

        if (_selectedRole == 'Project Manager') {
          Navigator.pushReplacementNamed(context, '/managerHome');
        } else if (_selectedRole == 'Owner') {
          Navigator.pushReplacementNamed(context, '/ownerHome');
        } else if (_selectedRole == 'Site Engineer') {
          Navigator.pushReplacementNamed(context, '/engineerHome');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          'Unable to create account. Please check your information.';

      if (e.code == 'email-already-in-use') {
        errorMessage =
            'This email is already registered. Please log in instead.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Something went wrong. Please try again.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          maxLength: isPassword ? 64 : 100,
          keyboardType: isMobileNumber
              ? TextInputType.phone
              : isEmail
                  ? TextInputType.emailAddress
                  : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterText: "",
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (isRequired &&
                (value == null || value.trim().isEmpty)) {
              return 'Please enter $label';
            }

            if (isEmail && value != null) {
              final emailRegExp =
                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

              if (!emailRegExp.hasMatch(value.trim())) {
                return 'Enter a valid email';
              }
            }

            if (isPasswordValidation &&
                value != null &&
                value.length < 8) {
              return 'Password must be at least 8 characters';
            }

            if (isMobileNumber && value != null) {
              final numberRegExp =
                  RegExp(r'^[0-9]{9,15}$');

              if (!numberRegExp.hasMatch(value.trim())) {
                return 'Enter a valid mobile number';
              }
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      dropdownColor:
          const Color.fromARGB(255, 55, 54, 54),
      hint: const Text(
        'Select role',
        style: TextStyle(color: Colors.white54),
      ),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: roles.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (value) =>
          setState(() => _selectedRole = value),
      validator: (value) =>
          value == null ? 'Please select a role' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Background_building.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 5,
              sigmaY: 5,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        182, 145, 144, 144),
                    borderRadius:
                        BorderRadius.circular(25),
                    border:
                        Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/Logo_DTPCM.png',
                        height: 60,
                      ),
                      const SizedBox(height: 20),

                      _buildInputField(
                        label: 'Full Name',
                        controller: _nameController,
                        isRequired: true,
                      ),

                      const SizedBox(height: 15),

                      _buildInputField(
                        label: 'Email Address',
                        controller: _emailController,
                        isRequired: true,
                        isEmail: true,
                      ),

                      const SizedBox(height: 15),

                      _buildInputField(
                        label: 'Mobile Number',
                        controller: _mobileController,
                        isRequired: true,
                        isMobileNumber: true,
                      ),

                      const SizedBox(height: 15),

                      _buildRoleSelection(),

                      const SizedBox(height: 15),

                      _buildInputField(
                        label: 'Password',
                        controller: _passwordController,
                        isRequired: true,
                        isPassword: true,
                        isPasswordValidation: true,
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xff0d1b46),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/login',
                          );
                        },
                        child: const Text.rich(
                          TextSpan(
                            text:
                                'Already have an account? ',
                            style:
                                TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              )
                            ],
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
