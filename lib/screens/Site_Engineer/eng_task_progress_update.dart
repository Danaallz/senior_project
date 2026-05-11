import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EngTaskProgressUpdate extends StatefulWidget {
  final Map<String, dynamic> task;

  const EngTaskProgressUpdate({super.key, required this.task});

  @override
  State<EngTaskProgressUpdate> createState() => _EngTaskProgressUpdateState();
}

class _EngTaskProgressUpdateState extends State<EngTaskProgressUpdate> {
  final supabase = Supabase.instance.client;

  final TextEditingController quantityController = TextEditingController();

  final TextEditingController noteController = TextEditingController();

  bool isSaving = false;

  double get estimatedQuantity {
    return double.tryParse(widget.task['est_quantity']?.toString() ?? '0') ?? 0;
  }

  double get completedQuantity {
    return double.tryParse(
          widget.task['completed_quantity']?.toString() ?? '0',
        ) ??
        0;
  }

  int get progressPercent {
    return int.tryParse(widget.task['progress_percent']?.toString() ?? '0') ??
        0;
  }

  String get unit {
    return widget.task['progress_unit']?.toString() ?? "unit";
  }

  String get status {
    return widget.task['status']?.toString() ?? "Not Started";
  }

  Color get statusColor {
    if (status == "Completed") {
      return Colors.green;
    }

    if (status == "Ongoing") {
      return Colors.orange;
    }

    return Colors.red;
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> saveProgress() async {
    final addedQuantity = double.tryParse(quantityController.text.trim());

    if (addedQuantity == null || addedQuantity <= 0) {
      showError("Enter a valid completed quantity");
      return;
    }

    if (estimatedQuantity <= 0) {
      showError("Estimated quantity is missing for this task");
      return;
    }

    final newCompletedQuantity = completedQuantity + addedQuantity;

    if (newCompletedQuantity > estimatedQuantity) {
      showError("Completed quantity cannot exceed estimated quantity");
      return;
    }

    final newProgressPercent =
        ((newCompletedQuantity / estimatedQuantity) * 100).round();

    String newStatus = "Not Started";

    if (newProgressPercent >= 100) {
      newStatus = "Completed";
    } else if (newProgressPercent > 0) {
      newStatus = "Ongoing";
    }

    setState(() {
      isSaving = true;
    });

    try {
      await supabase.from('task_progress_logs').insert({
        'task_id': widget.task['id'],
        'completed_quantity_added': addedQuantity,
        'note': noteController.text.trim(),
        'updated_by': supabase.auth.currentUser?.id,
      });

      await supabase
          .from('tasks')
          .update({
            'completed_quantity': newCompletedQuantity,
            'progress_percent': newProgressPercent,
            'status': newStatus,
          })
          .eq('id', widget.task['id']);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      showError("Error saving progress: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingQuantity = estimatedQuantity - completedQuantity;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Update Progress"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: progressPercent / 100,
                      strokeWidth: 14,
                      color: statusColor,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$progressPercent%",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text("Completed", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              widget.task['description']?.toString() ?? "Task",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 24),

          buildInfoCard(
            title: "Estimated Quantity",
            value: "$estimatedQuantity $unit",
          ),

          buildInfoCard(
            title: "Completed Quantity",
            value: "$completedQuantity $unit",
          ),

          buildInfoCard(
            title: "Remaining Quantity",
            value: "$remainingQuantity $unit",
          ),

          buildInfoCard(
            title: "Status",
            value: status,
            valueColor: statusColor,
          ),

          const SizedBox(height: 24),

          const Text(
            "Add Completed Quantity",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration("Example: 50"),
          ),

          const SizedBox(height: 20),

          const Text(
            "Progress Note",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: noteController,
            maxLines: 4,
            decoration: inputDecoration("Write progress update note..."),
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
                    "The system automatically calculates task progress based on completed quantity updates entered by the site engineer.",
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

          onPressed: isSaving ? null : saveProgress,

          child:
              isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                    "Save Progress Update",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget buildInfoCard({
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade700)),

          const Spacer(),

          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
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
