import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  // Auth Service
  final AuthService auth = AuthService();

  // User Service
  final UserService userService = UserService();

  // Password visibility toggle
  bool _obscurePassword = true;

  bool _isLoading = false;

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = await auth.login(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text.trim(),
      );
    try {
      final user = await auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        final role =
            await userService.getUserRole(user.uid);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful 🎉"),
            backgroundColor: Colors.green,
          ),
        );

        if (role == 'Admin') {
          Navigator.pushReplacementNamed(
              context, '/adminHome');
        } else if (role == 'Project Manager') {
          Navigator.pushReplacementNamed(
              context, '/managerHome');
        } else if (role == 'Owner') {
          Navigator.pushReplacementNamed(
              context, '/ownerHome');
        } else if (role == 'Site Engineer') {
          Navigator.pushReplacementNamed(
              context, '/engineerHome');
        } else {
          Navigator.pushReplacementNamed(
              context, '/home');
        }
      }
    } on FirebaseAuthException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid email or password. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException {
      String errorMessage =
          'Invalid email or password. Please try again or create a new account.';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/Background_building.png",
            fit: BoxFit.cover,
          ),

          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          Center(
            child: SingleChildScrollView(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20),

                padding: const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(182, 145, 144, 144),

                  borderRadius:
                      BorderRadius.circular(25),

                  border:
                      Border.all(color: Colors.white30),
                ),

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [
                      Image.asset(
                        "assets/Logo_DTPCM.png",
                        height: 60,
                      ),

                      Image.asset("assets/Logo_DTPCM.png", height: 60),
                      const SizedBox(height: 20),

                      /// Email
                      _buildTextField(
                        label: "Email Address",
                        controller: _emailController,
                        isRequired: true,
                        isEmail: true,
                      ),

                      const SizedBox(height: 15),

                      /// Password
                      _buildTextField(
                        label: "Password",
                        controller:
                            _passwordController,
                        isRequired: true,
                        isPassword: true,
                        isPasswordValidation: true,
                        obscureText:
                            _obscurePassword,
                        toggleObscure: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,

                        child: ElevatedButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : _loginUser,

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(
                                    0xff0d1b46),

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      12),
                            ),
                          ),

                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Log In",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                          child: const Text(
                            "Log In",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/register',
                          );
                          Navigator.pushReplacementNamed(context, '/register');
                        },

                        child: const Text.rich(
                          TextSpan(
                            text:
                                "Don't have an account? ",

                            style: TextStyle(
                              color: Colors.white70,
                            ),

                            children: [
                              TextSpan(
                                text:
                                    "Create an account",

                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Colors.blueAccent,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool isRequired = false,
    bool isEmail = false,
    bool isPasswordValidation = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText:
          isPassword ? obscureText : false,

      maxLength: isPassword ? 64 : 100,

      style: const TextStyle(
        color: Colors.white,
      ),

      decoration: InputDecoration(
        counterText: "",
        labelText: label,

        labelStyle: const TextStyle(
          color: Colors.white70,
        ),

        filled: true,
        fillColor: Colors.black.withOpacity(0.3),

        enabledBorder: OutlineInputBorder(
          borderSide:
              const BorderSide(color: Colors.white54),

          borderRadius:
              BorderRadius.circular(14),
        ),

        focusedBorder: OutlineInputBorder(
          borderSide:
              const BorderSide(color: Colors.white),

          borderRadius:
              BorderRadius.circular(14),
        ),

        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off
                      : Icons.visibility,

                  color: Colors.white70,
                ),

                onPressed: toggleObscure,
              )
            : null,
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: toggleObscure,
                )
                : null,
      ),

      validator: (value) {
        if (isRequired &&
            (value == null ||
                value.trim().isEmpty)) {
          return '$label is required';
        }

        if (isEmail &&
            value != null &&
            value.isNotEmpty) {
          final emailRegExp = RegExp(
            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          );

          if (!emailRegExp.hasMatch(
            value.trim(),
          )) {
            return 'Please enter a valid email address';
        if (isEmail && value != null && value.isNotEmpty) {
          final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegExp.hasMatch(value)) {
            return 'Please enter a valid email address (example@domain.com)';
          }
        }

        if (isPasswordValidation &&
            value != null) {
          if (value.length < 8) {
            return 'Password must be at least 8 characters';
          }

          if (value.length > 64) {
            return 'Password is too long';
          }
        }

        return null;
      },
    );
  }
}