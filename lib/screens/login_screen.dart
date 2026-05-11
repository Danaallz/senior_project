import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  String normalizeRole(String? role) {
    return (role ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;

      if (!mounted) return;

      if (user == null) {
        showError("Invalid email or password.");
        return;
      }

      // Get profile from Supabase
      final profile =
          await supabase.from('profiles').select().eq('id', user.id).single();

      final rawRole = profile['role'];
      final role = normalizeRole(rawRole);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login successful 🎉"),
          backgroundColor: Colors.green,
        ),
      );

      print("Logged in user ID: ${user.id}");
      print("User role: $role");

      // Navigate based on role
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/adminHome');
      } else if (role == 'owner') {
        Navigator.pushReplacementNamed(context, '/ownerHome');
      } else if (role == 'manager' || role == 'project manager') {
        Navigator.pushReplacementNamed(context, '/managerHome');
      } else if (role == 'site engineer' || role == 'site_engineer') {
        Navigator.pushReplacementNamed(context, '/engineerHome');
      } else {
        showError("Unknown role: $rawRole");
      }
    } on AuthException catch (e) {
      showError(e.message);
    } catch (e) {
      showError("Something went wrong: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
          Image.asset("assets/Background_building.png", fit: BoxFit.cover),

          Container(color: Colors.black.withOpacity(0.5)),

          Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(182, 145, 144, 144),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white30),
                ),

                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Image.asset("assets/Logo_DTPCM.png", height: 60),

                      const SizedBox(height: 20),

                      _buildTextField(
                        label: "Email Address",
                        controller: _emailController,
                        isRequired: true,
                        isEmail: true,
                      ),

                      const SizedBox(height: 15),

                      _buildTextField(
                        label: "Password",
                        controller: _passwordController,
                        isRequired: true,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        toggleObscure: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,

                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginUser,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0d1b46),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          child:
                              _isLoading
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
                        ),
                      ),

                      const SizedBox(height: 15),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/register');
                        },

                        child: const Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",

                            style: TextStyle(color: Colors.white70),

                            children: [
                              TextSpan(
                                text: "Create an account",

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
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,

      style: const TextStyle(color: Colors.white),

      decoration: InputDecoration(
        labelText: label,

        labelStyle: const TextStyle(color: Colors.white70),

        filled: true,

        fillColor: Colors.black.withOpacity(0.3),

        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),

          borderRadius: BorderRadius.circular(14),
        ),

        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),

          borderRadius: BorderRadius.circular(14),
        ),

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
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }

        if (isEmail && value != null && value.isNotEmpty) {
          final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

          if (!emailRegExp.hasMatch(value.trim())) {
            return 'Enter a valid email';
          }
        }

        return null;
      },
    );
  }
}
