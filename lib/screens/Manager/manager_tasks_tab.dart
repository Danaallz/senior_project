import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'add_task_screen.dart';
import 'task_progress_view_page.dart';
import 'edit_task_screen.dart';

class ManagerTasksTab extends StatefulWidget {
  final String? projectId;

  const ManagerTasksTab({super.key, this.projectId});

  @override
  State<ManagerTasksTab> createState() => _ManagerTasksTabState();
}

class _ManagerTasksTabState extends State<ManagerTasksTab> {
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color borderColor = Color(0xffeeeeee);
  static const Color lightTextColor = Color(0xff8f8f8f);

  bool isLoading = true;
  String search = '';

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

    setState(() => isLoading = true);

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

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading tasks: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filteredTasks {
    return tasks.where((task) {
      final description = task['description']?.toString().toLowerCase() ?? '';
      final status = task['status']?.toString().toLowerCase() ?? '';
      final query = search.toLowerCase();

      return description.contains(query) || status.contains(query);
    }).toList();
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

  Future<void> exportTasksPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text(
                'Tasks Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Project ID: ${widget.projectId ?? '-'}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Task',
                  'Status',
                  'Estimated',
                  'Completed',
                  'Progress',
                  'Start',
                  'End',
                ],
                data:
                    filteredTasks.map((task) {
                      final unit = task['progress_unit']?.toString() ?? 'unit';

                      return [
                        task['description']?.toString() ?? 'Task',
                        task['status']?.toString() ?? 'Not Started',
                        '${task['est_quantity'] ?? 0} $unit',
                        '${task['completed_quantity'] ?? 0} $unit',
                        '${task['progress_percent'] ?? 0}%',
                        task['start_date']?.toString() ?? '-',
                        task['end_date']?.toString() ?? '-',
                      ];
                    }).toList(),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
                  backgroundColor: primaryColor,
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

  Future<void> openEditTask(Map<String, dynamic> task) async {
    final status = (task['status'] ?? 'Not Started').toString();

    if (status != "Not Started") {
      showCannotEditDialog();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );

    if (result == true) {
      loadTasks();
    }
  }

  void openProgressView(Map<String, dynamic> task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskProgressViewPage(task: task)),
    );
  }

  Color getStatusColor(String status) {
    if (status == "Ongoing") return Colors.orange;
    if (status == "Completed") return Colors.green;
    return Colors.red;
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
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
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
        ),

        const SizedBox(height: 16),

        topRow(),

        const SizedBox(height: 12),

        searchBox(),

        const SizedBox(height: 12),

        Expanded(
          child:
              filteredTasks.isEmpty
                  ? const Center(
                    child: Text(
                      "No tasks found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: loadTasks,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        return buildTaskCard(filteredTasks[index]);
                      },
                    ),
                  ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: openAddTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                "Add New Task",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget topRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const Text(
            "Tasks",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          GestureDetector(
            onTap: filteredTasks.isEmpty ? null : exportTasksPdf,
            child: Text(
              "Upload PDF",
              style: TextStyle(
                color: filteredTasks.isEmpty ? Colors.grey : primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget searchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          maxLength: 50,
          onChanged: (value) {
            setState(() => search = value);
          },
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Search tasks',
            hintStyle: TextStyle(fontSize: 12),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, size: 20),
            suffixIcon: Icon(Icons.tune, size: 18, color: primaryColor),
          ),
        ),
      ),
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

    final statusColor = getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Icon(Icons.task_alt_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: (progressPercent / 100).clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.grey.shade200,
            color: statusColor,
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                "$progressPercent% completed",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                "$completedQuantity / $estQuantity $unit",
                style: const TextStyle(color: lightTextColor, fontSize: 12),
              ),
            ],
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
