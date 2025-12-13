import 'package:flutter/material.dart';
import 'dart:ui'; // Required for Blur effect

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Role State
  String? _selectedRole;
  List<String> roles = ['Admin', 'Engineer', 'Contractor', 'Client'];

  @override
  void dispose() {
    // Clean up controllers
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle form submission
  void _registerUserMock() {
    if (_formKey.currentState!.validate()) {
      // Data capture and mock submission
      print('--- Data VALIDATED and CAPTURED ---');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // Success message
          content: Text('Data verified successfully and ready for submission!'),
        ),
      );
    } else {
      // Validation failed message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
    }
  }

  // Helper Widget for TextFormField
  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
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
            // Changed to black for light container background
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword,
          // Input text color
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
          ),

          // Validator
          validator: (value) {
            // التحقق من أن الحقل ليس فارغًا
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Please enter your $label.';
            }
            // التحقق من طول الاسم
            if (label == 'Full Name' && value!.length < 2) {
              return 'Full Name must be at least 2 characters.';
            }
            // التحقق من صحة الإيميل
            if (isEmail) {
              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegExp.hasMatch(value!)) {
                return 'Please enter a valid email address.';
              }
            }
            // التحقق من طول كلمة المرور
            if (isPasswordValidation) {
              if (value!.length < 8) {
                return 'Password must be at least 8 characters long.';
              }
            }
            // التحقق من صحة رقم الجوال
            if (isMobileNumber) {
              final numberRegExp = RegExp(r'^[0-9]+$');
              // التأكد من أن الإدخال أرقام فقط
              if (!numberRegExp.hasMatch(value!)) {
                return 'Mobile number must contain digits only.';
              }
              // التحقق من نطاق طول رقم الجوال
              if (value.length < 9 || value.length > 15) {
                return 'Please enter a valid phone number (9-15 digits).';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  // Helper Widget for Role Selection
  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            // Changed to black for light container background
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            isExpanded: true,
            hint: const Text(
              'Select role',
              style: TextStyle(color: Colors.white54),
            ),
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color.fromARGB(255, 55, 54, 54),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items:
                roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(
                      role,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue;
              });
            },
            // Role validation
            validator: (value) {
              if (value == null) {
                return 'Please select a role.';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // Main Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Background Image
          Image.asset('assets/Background_building.png', fit: BoxFit.cover),

          // Overlay and Blur Effect
          Container(color: Colors.black.withOpacity(0.5)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),

          // Main Content Container
          Center(
            // Start of fixed header and scrollable form structure
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Logo (Static and does not scroll)
                Image.asset('assets/Logo_DTPCM.png', height: 250),
                const SizedBox(height: 10),

                // 2. Form Container (Scrollable)
                Expanded(
                  // Ensures the scrollable area takes the remaining vertical space
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 5.0, // Reduced vertical padding here
                    ),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          // Frosted Glass Effect color
                          color: const Color.fromARGB(
                            255,
                            133,
                            133,
                            133,
                          ).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Welcome Texts
                            const Text(
                              'Welcome to DTPCM',
                              style: TextStyle(
                                // Changed text color to black
                                color: Color.fromARGB(255, 254, 249, 249),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'filled below fields to login your account',
                              style: TextStyle(
                                // Changed text color to dark gray
                                color: Color.fromARGB(212, 251, 248, 248),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Input Fields
                            _buildInputField(
                              'Full Name',
                              'Enter full name',
                              _nameController,
                              isRequired: true,
                            ),
                            const SizedBox(height: 15),
                            _buildInputField(
                              'Email Address',
                              'Enter email address',
                              _emailController,
                              keyboardType: TextInputType.emailAddress,
                              isEmail: true,
                              isRequired: true,
                            ),
                            const SizedBox(height: 15),
                            _buildInputField(
                              'Mobile Number',
                              'Enter mobile number',
                              _mobileController,
                              keyboardType: TextInputType.phone,
                              isMobileNumber: true,
                              isRequired: true,
                            ),
                            const SizedBox(height: 15),

                            _buildRoleSelection(),
                            const SizedBox(height: 15),

                            _buildInputField(
                              'Password',
                              'Enter password',
                              _passwordController,
                              isPassword: true,
                              isRequired: true,
                              isPasswordValidation: true,
                            ),

                            const SizedBox(height: 40),

                            // Create account Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _registerUserMock,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    6,
                                    32,
                                    59,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Log in Link
                            GestureDetector(
                              onTap: () {
                                print('Log in link pressed');
                              },
                              child: const Text.rich(
                                TextSpan(
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                    // Changed text color to dark gray
                                    color: Colors.white,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: 'Log in',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ), // End of Expanded
              ],
            ),
          ),
        ],
      ),
    );
  }
}
