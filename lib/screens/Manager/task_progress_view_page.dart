import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskProgressViewPage extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskProgressViewPage({super.key, required this.task});

  @override
  State<TaskProgressViewPage> createState() => _TaskProgressViewPageState();
}

class _TaskProgressViewPageState extends State<TaskProgressViewPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  List<Map<String, dynamic>> progressLogs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      final response = await supabase
          .from('task_progress_logs')
          .select()
          .eq('task_id', widget.task['id'])
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        progressLogs = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading progress: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double get estQuantity {
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
    if (progressPercent >= 88) {
      return Colors.green;
    }

    if (progressPercent >= 50) {
      return const Color.fromARGB(255, 139, 209, 47);
    }

    if (progressPercent >= 30) {
      return Colors.orange;
    }

    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (estQuantity - completedQuantity).clamp(0, estQuantity);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Task Progress"),
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

                              const Text(
                                "Completed",
                                style: TextStyle(fontSize: 13),
                              ),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        buildInfoRow("Status", status, valueColor: statusColor),

                        const SizedBox(height: 14),

                        buildInfoRow(
                          "Estimated Quantity",
                          "$estQuantity $unit",
                        ),

                        const SizedBox(height: 14),

                        buildInfoRow(
                          "Completed Quantity",
                          "$completedQuantity $unit",
                        ),

                        const SizedBox(height: 14),

                        buildInfoRow("Remaining Quantity", "$remaining $unit"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    "Progress Updates",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 14),

                  if (progressLogs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text("No progress updates yet"),
                      ),
                    ),

                  ...progressLogs.map((log) {
                    final quantity =
                        log['completed_quantity_added']?.toString() ?? '0';

                    final note = log['note']?.toString() ?? '';

                    final createdAt = log['created_at']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "+ $quantity $unit completed",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      createdAt
                                          .replaceAll("T", "  ")
                                          .split(".")
                                          .first,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 14),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                note,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
    );
  }

  Widget buildInfoRow(String title, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade700)),

        const Spacer(),

        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
