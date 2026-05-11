import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_task_screen.dart';

class ManagerTasksTab extends StatefulWidget {
  final String? projectId;

  const ManagerTasksTab({super.key, this.projectId});

  @override
  State<ManagerTasksTab> createState() => _ManagerTasksTabState();
}

class _ManagerTasksTabState extends State<ManagerTasksTab> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  @override
  void didUpdateWidget(covariant ManagerTasksTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      loadTasks();
    }
  }

  Future<void> loadTasks() async {
    if (widget.projectId == null) {
      setState(() {
        tasks = [];
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('tasks')
          .select()
          .eq('project_id', widget.projectId!)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        tasks = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading tasks: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int countByStatus(String status) {
    return tasks.where((task) {
      return (task['status'] ?? 'Not Started').toString() == status;
    }).length;
  }

  Future<void> openAddTask() async {
    if (widget.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a project first"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(projectId: widget.projectId),
      ),
    );

    if (result == true) {
      loadTasks();
    }
  }

  void showCannotEditDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Can’t Edit Task",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "This task cannot be edited because it is already in progress. You can only edit tasks that have not started yet.",
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1C2A44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void openEditTask(Map<String, dynamic> task) {
    final status = (task['status'] ?? 'Not Started').toString();

    if (status != "Not Started") {
      showCannotEditDialog();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Edit task page will be connected next")),
    );
  }

  void openProgressView(Map<String, dynamic> task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManagerTaskProgressView(task: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return const Center(child: Text("No project selected"));
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Row(
          children: [
            buildSummaryCard(
              title: "Not Started",
              value: countByStatus("Not Started").toString(),
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            buildSummaryCard(
              title: "Ongoing",
              value: countByStatus("Ongoing").toString(),
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            buildSummaryCard(
              title: "Completed",
              value: countByStatus("Completed").toString(),
              color: Colors.green,
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            const Text(
              "Tasks",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: openAddTask,
              icon: const Icon(Icons.add),
              label: const Text("Add Task"),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Expanded(
          child:
              tasks.isEmpty
                  ? const Center(child: Text("No tasks added yet"))
                  : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return buildTaskCard(tasks[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTaskCard(Map<String, dynamic> task) {
    final description = task['description']?.toString() ?? "Task";
    final status = task['status']?.toString() ?? "Not Started";

    final estQuantity =
        double.tryParse(task['est_quantity']?.toString() ?? '0') ?? 0;

    final completedQuantity =
        double.tryParse(task['completed_quantity']?.toString() ?? '0') ?? 0;

    final progressPercent =
        int.tryParse(task['progress_percent']?.toString() ?? '0') ?? 0;

    final unit = task['progress_unit']?.toString() ?? "unit";

    Color statusColor = Colors.red;

    if (status == "Ongoing") {
      statusColor = Colors.orange;
    } else if (status == "Completed") {
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: progressPercent / 100,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.grey.shade300,
            color: statusColor,
          ),

          const SizedBox(height: 8),

          Text(
            "$progressPercent% completed",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 4),

          Text(
            "$completedQuantity / $estQuantity $unit",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openProgressView(task),
                  icon: const Icon(Icons.timeline_rounded, size: 18),
                  label: const Text("Progress"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openEditTask(task),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text("Edit"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ManagerTaskProgressView extends StatelessWidget {
  final Map<String, dynamic> task;

  const ManagerTaskProgressView({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final description = task['description']?.toString() ?? "Task";

    final estQuantity =
        double.tryParse(task['est_quantity']?.toString() ?? '0') ?? 0;

    final completedQuantity =
        double.tryParse(task['completed_quantity']?.toString() ?? '0') ?? 0;

    final progressPercent =
        int.tryParse(task['progress_percent']?.toString() ?? '0') ?? 0;

    final unit = task['progress_unit']?.toString() ?? "unit";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Task Progress"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: SizedBox(
              width: 135,
              height: 135,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent / 100,
                    strokeWidth: 14,
                    color: Colors.green,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  Text(
                    "$progressPercent%\nDone",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          infoRow("Estimated Quantity", "$estQuantity $unit"),
          infoRow("Completed Quantity", "$completedQuantity $unit"),
          infoRow(
            "Remaining Quantity",
            "${estQuantity - completedQuantity} $unit",
          ),
          infoRow("Status", task['status']?.toString() ?? "Not Started"),
        ],
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(title),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
