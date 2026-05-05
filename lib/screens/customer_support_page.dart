import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class CustomerSupportPage extends StatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  State<CustomerSupportPage> createState() =>
      _CustomerSupportPageState();
}

class _CustomerSupportPageState
    extends State<CustomerSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final supabaseService = SupabaseService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String? profileId;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  String cleanInput(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[<>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final profile =
        await supabaseService.getProfileByFirebaseUid(
      user.uid,
    );

    if (profile != null) {
      profileId = profile['id'];

      _nameController.text =
          profile['full_name'] ?? '';

      _emailController.text =
          profile['email'] ?? user.email ?? '';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    if (profileId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await supabaseService.createSupportTicket(
        userId: profileId!,
        name: cleanInput(_nameController.text),
        email: _emailController.text.trim(),
        subject: cleanInput(
          _subjectController.text,
        ),
        message: cleanInput(
          _messageController.text,
        ),
      );

      _subjectController.clear();
      _messageController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Support ticket submitted successfully ✅",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to submit ticket. Please try again.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType =
        TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,

          maxLength: maxLines > 1 ? 1000 : 100,

          validator: (v) {
            if (v == null ||
                v.trim().isEmpty) {
              return "$label is required";
            }

            if (label == "Message" &&
                v.trim().length < 10) {
              return "Message is too short";
            }

            return null;
          },

          decoration: InputDecoration(
            counterText: "",
            hintText: hint,

            hintStyle: TextStyle(
              color: Colors.grey[400],
            ),

            filled: true,

            fillColor: readOnly
                ? Colors.grey[100]
                : Colors.grey[50],

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),

              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),

            focusedBorder:
                const OutlineInputBorder(
              borderSide: BorderSide(
                color: Color(0xFF0D1A3A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.grey[50],

          borderRadius:
              BorderRadius.circular(12),

          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),

        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFF0D1A3A),
              size: 28,
            ),

            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          "Customer Support",

          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),

          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(20),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF0D1A3A),

                        borderRadius:
                            BorderRadius.circular(
                                16),
                      ),

                      child: const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.headset_mic,
                                color:
                                    Colors.white,
                                size: 28,
                              ),

                              SizedBox(width: 12),

                              Text(
                                "How can we help?",

                                style: TextStyle(
                                  color:
                                      Colors.white,

                                  fontSize: 18,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8),

                          Text(
                            "Our support team is available to assist you with any issues or questions.",

                            style: TextStyle(
                              color:
                                  Colors.white70,

                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        _contactOption(
                          icon:
                              Icons.chat_bubble_outline,
                          title: "Live Chat",
                          subtitle: "Coming soon",
                        ),

                        const SizedBox(width: 12),

                        _contactOption(
                          icon:
                              Icons.email_outlined,
                          title: "Email",
                          subtitle:
                              "support@dtpcm.com",
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Submit a Ticket",

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      label: "Full Name",
                      hint: "Enter your name",
                      controller:
                          _nameController,
                      readOnly: true,
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      label: "Email Address",
                      hint: "Enter your email",
                      controller:
                          _emailController,

                      keyboardType:
                          TextInputType
                              .emailAddress,

                      readOnly: true,
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      label: "Subject",
                      hint: "Enter subject",
                      controller:
                          _subjectController,
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      label: "Message",

                      hint:
                          "Describe your issue in detail...",

                      controller:
                          _messageController,

                      maxLines: 5,
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : _submitTicket,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                                  0xFF0D1A3A),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                                        12),
                          ),
                        ),

                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color:
                                    Colors.white,
                              )
                            : const Text(
                                "Submit Ticket",

                                style: TextStyle(
                                  color:
                                      Colors.white,

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