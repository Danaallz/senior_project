import 'package:flutter/material.dart';
import '../services/worker_service.dart';

class AddWorkerPage extends StatefulWidget {
  const AddWorkerPage({super.key});

  @override
  _AddWorkerPageState createState() => _AddWorkerPageState();
}

class _AddWorkerPageState extends State<AddWorkerPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedRole;
  String salaryType = "month";
  String shiftType = "day";

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final salaryController = TextEditingController();
  final dateController = TextEditingController(text: "25-10-2024");

  final WorkerService workerService = WorkerService();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    salaryController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              fieldTitle("Name"),
              inputField(
                controller: nameController,
                hint: "Enter name",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Name is required";
                  }
                  List<String> parts = value.trim().split(" ");
                  if (parts.length < 2) {
                    return "Please enter first and last name";
                  }
                  return null;
                },
              ),

              fieldTitle("Role"),
              roleDropdown(),

              fieldTitle("Contact Number"),
              inputField(
                controller: phoneController,
                hint: "Enter contact number",
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Email is required";
                  }
                  final regex = RegExp(
                      r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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
              inputField(
                controller: salaryController,
                hint: "e.g 15,000",
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Salary is required";
                  }
                  int? salary =
                      int.tryParse(value.replaceAll(',', ''));
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
                readOnly: true,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Joining date is required";
                  }
                  return null;
                },
              ),

              fieldTitle("Identification Proof"),
              Row(
                children: [
                  actionButton(Icons.camera_alt, "Take Photo"),
                  const SizedBox(width: 10),
                  actionButton(Icons.cloud_upload_outlined, "Add Photo"),
                ],
              ),

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
                  onPressed: saveWorker,
                  child: const Text(
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

  // ================= LOGIC =================

  Future<void> saveWorker() async {
    try {
      if (!_formKey.currentState!.validate()) return;
      if (selectedRole == null) {
        throw Exception("Please select worker role");
      }

      await workerService.addWorker(
        name: nameController.text.trim(),
        role: selectedRole!,
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        salary: salaryController.text.trim(),
        salaryType: salaryType,
        shiftType: shiftType,
        joiningDate: dateController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Worker added successfully ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ================= UI HELPERS =================

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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
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
          items: [
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
          ].map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role),
            ),
          ).toList(),
          onChanged: (value) {
            setState(() => selectedRole = value);
          },
        ),
      ),
    );
  }

  Widget radioOption(String title, String value) {
    return Row(
      children: [
        Radio(
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
        Radio(
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

  Widget actionButton(IconData icon, String text) {
    return Expanded(
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
    );
  }
}
