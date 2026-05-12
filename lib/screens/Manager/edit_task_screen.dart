import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color borderColor = Color(0xffeeeeee);

  late TextEditingController descriptionController;
  late TextEditingController quantityController;

  DateTime? startDate;
  DateTime? endDate;

  String selectedUnit = "unit";
  bool isSaving = false;

  final List<String> units = [
    "unit",
    "meters",
    "m",
    "m²",
    "kg",
    "pcs",
    "hrs",
    "%",
    "ft",
    "m3",
  ];

  @override
  void initState() {
    super.initState();

    descriptionController = TextEditingController(
      text: widget.task['description']?.toString() ?? '',
    );

    quantityController = TextEditingController(
      text: widget.task['est_quantity']?.toString() ?? '',
    );

    final savedUnit = widget.task['progress_unit']?.toString() ?? "unit";

    selectedUnit = units.contains(savedUnit) ? savedUnit : "unit";

    startDate = DateTime.tryParse(widget.task['start_date']?.toString() ?? '');
    endDate = DateTime.tryParse(widget.task['end_date']?.toString() ?? '');
  }

  @override
  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> saveTask() async {
    final description = descriptionController.text.trim();

    if (description.isEmpty) {
      showError("Task description is required");
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showError("Estimated quantity must be valid");
      return;
    }

    if (startDate == null || endDate == null) {
      showError("Start and end dates are required");
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      showError("End date cannot be before start date");
      return;
    }

    setState(() => isSaving = true);

    try {
      await supabase
          .from('tasks')
          .update({
            'description': description,
            'start_date': startDate!.toIso8601String().split('T').first,
            'end_date': endDate!.toIso8601String().split('T').first,
            'progress_unit': selectedUnit,
            'est_quantity': quantity,
          })
          .eq('id', widget.task['id']);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      showError("Error updating task: $e");
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate ? startDate ?? DateTime.now() : endDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      if (isStartDate) {
        startDate = picked;
      } else {
        endDate = picked;
      }
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select";
    return "${date.day}/${date.month}/${date.year}";
  }

  String get resourceType {
    if (widget.task['material_id'] != null) return "Material";
    if (widget.task['equipment_id'] != null) return "Equipment";
    return "General";
  }

  String get quantityLabel {
    if (resourceType == "Material") return "Required Material Quantity";
    if (resourceType == "Equipment") return "Required Equipment Quantity";
    return "Estimated Task Quantity";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Edit Task"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          sectionTitle("Task Description"),
          const SizedBox(height: 8),

          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: inputDecoration("Enter task description"),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: buildDateCard(
                  title: "Start Date",
                  date: startDate,
                  onTap: () => pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildDateCard(
                  title: "End Date",
                  date: endDate,
                  onTap: () => pickDate(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          sectionTitle("Task Resource"),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9fb),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  resourceType == "Material"
                      ? Icons.inventory_2_outlined
                      : resourceType == "Equipment"
                      ? Icons.precision_manufacturing_outlined
                      : Icons.task_alt_rounded,
                  color: primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  resourceType,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          sectionTitle(quantityLabel),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: inputDecoration("Unit"),
                  items:
                      units.map((unit) {
                        return DropdownMenuItem(value: unit, child: Text(unit));
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedUnit = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: inputDecoration("Quantity"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withOpacity(0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tasks can only be edited before work starts. If this task uses material or equipment, only update the quantity/unit carefully.",
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isSaving ? null : saveTask,
          child:
              isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                    "Save Changes",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
  }

  Widget buildDateCard({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(title),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9fb),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(child: Text(formatDate(date))),
                const Icon(Icons.calendar_month_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xfff8f9fb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade300),
      ),
    );
  }
}
