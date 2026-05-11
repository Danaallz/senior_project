import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTaskScreen extends StatefulWidget {
  final String? projectId;

  const AddTaskScreen({super.key, required this.projectId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController descriptionController = TextEditingController();

  final TextEditingController quantityController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  bool isSaving = false;

  String selectedUnit = "unit";

  Map<String, dynamic>? selectedWorker;

  List<Map<String, dynamic>> workers = [];

  final List<String> units = ["unit", "m", "m²", "kg", "pcs", "hrs", "%", "ft"];

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  Future<void> loadWorkers() async {
    if (widget.projectId == null) return;

    try {
      final response = await supabase
          .from('project_workers')
          .select('workers(*)')
          .eq('project_id', widget.projectId!);

      final loadedWorkers = <Map<String, dynamic>>[];

      for (final item in response) {
        if (item['workers'] != null) {
          loadedWorkers.add(Map<String, dynamic>.from(item['workers']));
        }
      }

      if (!mounted) return;

      setState(() {
        workers = loadedWorkers;
      });
    } catch (e) {
      showError("Error loading workers: $e");
    }
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

    if (selectedWorker == null) {
      showError("Please assign a worker");
      return;
    }

    if (startDate == null || endDate == null) {
      showError("Start date and end date are required");
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      showError("End date cannot be before start date");
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showError("Estimated quantity must be valid");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await supabase.from('tasks').insert({
        'project_id': widget.projectId,
        'description': description,
        'assigned_worker_id': selectedWorker!['id'],
        'start_date': startDate!.toIso8601String(),
        'end_date': endDate!.toIso8601String(),
        'progress_unit': selectedUnit,
        'est_quantity': quantity,
        'completed_quantity': 0,
        'progress_percent': 0,
        'status': 'Not Started',
        'created_by': supabase.auth.currentUser?.id,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      showError("Error adding task: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
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
      initialDate: DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Add Task"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Task Description",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: inputDecoration("Enter task description"),
          ),

          const SizedBox(height: 20),

          const Text(
            "Assign Worker",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<Map<String, dynamic>>(
            value: selectedWorker,

            decoration: inputDecoration("Select worker"),

            items:
                workers.map((worker) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: worker,

                    child: Text(worker['name']?.toString() ?? "Worker"),
                  );
                }).toList(),

            onChanged: (value) {
              setState(() {
                selectedWorker = value;
              });
            },
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

                    setState(() {
                      selectedUnit = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: quantityController,

                  keyboardType: TextInputType.number,

                  decoration: inputDecoration("Estimated Quantity"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          Container(
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: Colors.blue.withOpacity(0.15)),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    "Task progress is automatically calculated based on completed quantity updates entered by the site engineer.",
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
            backgroundColor: const Color(0xFF1C2A44),

            minimumSize: const Size(double.infinity, 56),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),

          onPressed: isSaving ? null : saveTask,

          child:
              isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                    "Create Task",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget buildDateCard({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),

        InkWell(
          onTap: onTap,

          child: Container(
            padding: const EdgeInsets.all(15),

            decoration: BoxDecoration(
              color: const Color(0xfff8f9fb),

              borderRadius: BorderRadius.circular(14),
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
