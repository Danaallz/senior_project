import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/services/supabase_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String? projectId;

  const AddTaskScreen({super.key, required this.projectId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final supabase = Supabase.instance.client;
  final SupabaseService supabaseService = SupabaseService();

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color borderColor = Color(0xffeeeeee);

  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = true;
  bool isSaving = false;

  String selectedResourceType = "Material";
  String selectedUnit = "unit";

  Map<String, dynamic>? selectedWorker;
  Map<String, dynamic>? selectedMaterial;
  Map<String, dynamic>? selectedEquipment;

  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> equipment = [];

  final List<String> resourceTypes = ["Material", "Equipment", "General"];
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
    loadInitialData();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadInitialData() async {
    if (widget.projectId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      await Future.wait([loadWorkers(), loadMaterials(), loadEquipment()]);

      if (!mounted) return;

      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      showError("Error loading task data: $e");
    }
  }

  Future<void> loadWorkers() async {
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

    workers = loadedWorkers;
  }

  Future<void> loadMaterials() async {
    materials = await supabaseService.getProjectMaterials(widget.projectId!);
  }

  Future<void> loadEquipment() async {
    equipment = await supabaseService.getProjectEquipment(widget.projectId!);
  }

  double get selectedAvailableQuantity {
    if (selectedResourceType == "Material" && selectedMaterial != null) {
      return double.tryParse(
            selectedMaterial!['available_quantity']?.toString() ?? '0',
          ) ??
          0;
    }

    if (selectedResourceType == "Equipment" && selectedEquipment != null) {
      return double.tryParse(
            selectedEquipment!['available_quantity']?.toString() ?? '0',
          ) ??
          0;
    }

    return double.infinity;
  }

  String get quantityLabel {
    if (selectedResourceType == "Material") {
      return "Required Material Quantity";
    }

    if (selectedResourceType == "Equipment") {
      return "Required Equipment Quantity";
    }

    return "Estimated Task Quantity";
  }

  String get selectedResourceName {
    if (selectedResourceType == "Material" && selectedMaterial != null) {
      return cleanText(selectedMaterial!['material_catalog']?['name']);
    }

    if (selectedResourceType == "Equipment" && selectedEquipment != null) {
      return cleanText(selectedEquipment!['equipment_catalog']?['name']);
    }

    return "General task";
  }

  void updateUnitFromSelectedResource() {
    if (selectedResourceType == "Material" && selectedMaterial != null) {
      final unit = cleanText(selectedMaterial!['material_catalog']?['unit']);

      selectedUnit = unit.isEmpty ? "unit" : unit;
      return;
    }

    if (selectedResourceType == "Equipment") {
      selectedUnit = "unit";
      return;
    }

    selectedUnit = "unit";
  }

// ================================
  // MANAGER TASK NOTIFICATION
  // Notifies the manager when a new task is created and assigned.
  // This helps the manager track newly planned work from the notification center.
  // ================================
  Future<void> createTaskNotification({
    required String taskDescription,
    required String workerName,
  }) async {
    try {
      final managerId = supabase.auth.currentUser?.id;
      if (managerId == null || managerId.isEmpty || widget.projectId == null) {
        return;
      }

      final existing = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', managerId)
          .eq('project_id', widget.projectId!)
          .eq('type', 'task_created')
          .eq('message', '$taskDescription - $workerName')
          .limit(1);

      if (existing.isNotEmpty) return;

      await supabase.from('notifications').insert({
        'user_id': managerId,
        'project_id': widget.projectId!,
        'type': 'task_created',
        'title': 'New Task Created',
        'message': 'Task "$taskDescription" has been assigned to $workerName.',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Task notification error: $e');
    }
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

    if (selectedResourceType == "Material" && selectedMaterial == null) {
      showError("Please select a material");
      return;
    }

    if (selectedResourceType == "Equipment" && selectedEquipment == null) {
      showError("Please select equipment");
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showError("$quantityLabel must be valid");
      return;
    }

    if (selectedResourceType != "General" &&
        quantity > selectedAvailableQuantity) {
      showError(
        "Required quantity cannot be more than available stock: $selectedAvailableQuantity $selectedUnit",
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final Map<String, dynamic> data = {
        'project_id': widget.projectId,
        'description': description,
        'assigned_worker_id': selectedWorker!['id'],
        'start_date': startDate!.toIso8601String().split('T').first,
        'end_date': endDate!.toIso8601String().split('T').first,
        'progress_unit': selectedUnit,
        'est_quantity': quantity,
        'completed_quantity': 0,
        'progress_percent': 0,
        'progress': 0,
        'status': 'Not Started',
        'created_by': supabase.auth.currentUser?.id,
      };

      if (selectedResourceType == "Material") {
        data['material_id'] = selectedMaterial!['material_id'];
        data['equipment_id'] = null;
      } else if (selectedResourceType == "Equipment") {
        data['equipment_id'] = selectedEquipment!['equipment_id'];
        data['material_id'] = null;
      } else {
        data['material_id'] = null;
        data['equipment_id'] = null;
      }

      await supabase.from('tasks').insert(data);

      // ================================
      // CREATE MANAGER TASK NOTIFICATION
      // Sent after the task is saved successfully.
      // ================================
      await createTaskNotification(
        taskDescription: description,
        workerName: selectedWorker!['name']?.toString() ?? 'Worker',
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      showError("Error adding task: $e");
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

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
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

                  sectionTitle("Assign Worker"),
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
                      setState(() => selectedWorker = value);
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

                  sectionTitle("Task Resource"),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedResourceType,
                    decoration: inputDecoration("Select resource type"),
                    items:
                        resourceTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        selectedResourceType = value;
                        selectedMaterial = null;
                        selectedEquipment = null;
                        quantityController.clear();
                        updateUnitFromSelectedResource();
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  if (selectedResourceType == "Material")
                    buildMaterialSelector(),

                  if (selectedResourceType == "Equipment")
                    buildEquipmentSelector(),

                  if (selectedResourceType == "General")
                    buildGeneralUnitSelector(),

                  const SizedBox(height: 14),

                  sectionTitle(quantityLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: inputDecoration("Enter required quantity"),
                  ),

                  const SizedBox(height: 12),

                  if (selectedResourceType != "General") stockInfoBox(),

                  const SizedBox(height: 26),

                  infoBox(),
                ],
              ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
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

  Widget buildMaterialSelector() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: selectedMaterial,
      decoration: inputDecoration("Select material from stock"),
      items:
          materials.map((item) {
            final catalog = item['material_catalog'] ?? {};
            final name =
                cleanText(catalog['name']).isEmpty
                    ? "Material"
                    : cleanText(catalog['name']);
            final unit =
                cleanText(catalog['unit']).isEmpty
                    ? "unit"
                    : cleanText(catalog['unit']);
            final available = item['available_quantity']?.toString() ?? '0';

            return DropdownMenuItem<Map<String, dynamic>>(
              value: item,
              child: Text("$name • Available: $available $unit"),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          selectedMaterial = value;
          quantityController.clear();
          updateUnitFromSelectedResource();
        });
      },
    );
  }

  Widget buildEquipmentSelector() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: selectedEquipment,
      decoration: inputDecoration("Select equipment from stock"),
      items:
          equipment.map((item) {
            final catalog = item['equipment_catalog'] ?? {};
            final name =
                cleanText(catalog['name']).isEmpty
                    ? "Equipment"
                    : cleanText(catalog['name']);
            final type = cleanText(catalog['type']);
            final available = item['available_quantity']?.toString() ?? '0';

            return DropdownMenuItem<Map<String, dynamic>>(
              value: item,
              child: Text(
                type.isEmpty
                    ? "$name • Available: $available"
                    : "$name • $type • Available: $available",
              ),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          selectedEquipment = value;
          quantityController.clear();
          updateUnitFromSelectedResource();
        });
      },
    );
  }

  Widget buildGeneralUnitSelector() {
    return DropdownButtonFormField<String>(
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
    );
  }

  Widget stockInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$selectedResourceName available stock: $selectedAvailableQuantity $selectedUnit",
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoBox() {
    return Container(
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
              "Task progress is calculated from completed quantity updates entered by the site engineer.",
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
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
