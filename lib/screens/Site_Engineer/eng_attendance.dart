import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EngAttendanceTab extends StatefulWidget {
  final String? projectId;

  const EngAttendanceTab({super.key, this.projectId});

  @override
  State<EngAttendanceTab> createState() => _EngAttendanceTabState();
}

class _EngAttendanceTabState extends State<EngAttendanceTab>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController tabController;

  bool isLoading = true;
  List<Map<String, dynamic>> workers = [];
  Map<String, String> attendanceStatus = {};
  DateTime selectedDate = DateTime.now();

  String get dateText {
    return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (widget.projectId == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      final workerResponse = await supabase
          .from('project_workers')
          .select('workers(*)')
          .eq('project_id', widget.projectId!);

      final attendanceResponse = await supabase
          .from('attendance')
          .select()
          .eq('project_id', widget.projectId!)
          .eq('attendance_date', dateText);

      final loadedWorkers = <Map<String, dynamic>>[];

      for (final item in workerResponse) {
        if (item['workers'] != null) {
          loadedWorkers.add(Map<String, dynamic>.from(item['workers']));
        }
      }

      final loadedAttendance = <String, String>{};

      for (final item in attendanceResponse) {
        final workerId = item['worker_id']?.toString();

        if (workerId != null && workerId.isNotEmpty) {
          loadedAttendance[workerId] = item['status']?.toString() ?? '';
        }
      }

      if (!mounted) return;

      setState(() {
        workers = loadedWorkers;
        attendanceStatus = loadedAttendance;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading attendance: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> markAttendance(
    Map<String, dynamic> worker,
    String status,
  ) async {
    if (widget.projectId == null) return;

    final workerId = worker['id']?.toString();

    if (workerId == null || workerId.isEmpty) return;

    try {
      await supabase.from('attendance').upsert({
        'project_id': widget.projectId,
        'worker_name': worker['name']?.toString() ?? 'Worker',
        'role': worker['role']?.toString() ?? 'Worker',
        'status': status,
        'attendance_date': dateText,
        'check_in':
            status == 'Present' ? DateTime.now().toIso8601String() : null,
        'created_at': DateTime.now().toIso8601String(),
        'worker_id': workerId,
      }, onConflict: 'project_id,worker_id,attendance_date');

      setState(() {
        attendanceStatus[workerId] = status;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving attendance: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int get presentCount =>
      attendanceStatus.values.where((status) => status == "Present").length;

  int get absentCount =>
      attendanceStatus.values.where((status) => status == "Absent").length;

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return const Center(child: Text("No project selected"));
    }

    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF1C2A44),
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade700,
            tabs: const [
              Tab(text: "Attendance"),
              Tab(text: "Attendance Sheet"),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                    controller: tabController,
                    children: [buildAttendanceView(), buildAttendanceSheet()],
                  ),
        ),
      ],
    );
  }

  Widget buildAttendanceView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        buildDateCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: summaryCard(
                title: "Present",
                value: "$presentCount",
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: summaryCard(
                title: "Absent",
                value: "$absentCount",
                icon: Icons.cancel,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          "Daily Attendance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...workers.map((worker) {
          final id = worker['id'].toString();
          final status = attendanceStatus[id] ?? "Not marked";

          return workerAttendanceCard(worker, status);
        }),
      ],
    );
  }

  Widget buildAttendanceSheet() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        buildDateCard(),
        const SizedBox(height: 14),
        const Text(
          "Mark Workers Attendance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...workers.map((worker) {
          final id = worker['id'].toString();
          final status = attendanceStatus[id];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      worker['image_url'] != null
                          ? NetworkImage(worker['image_url'])
                          : null,
                  child:
                      worker['image_url'] == null
                          ? const Icon(Icons.person)
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker['name'] ?? "Unnamed Worker",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        worker['role'] ?? "Worker",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                attendanceButton(
                  label: "Present",
                  selected: status == "Present",
                  color: Colors.green,
                  onTap: () => markAttendance(worker, "Present"),
                ),
                const SizedBox(width: 6),
                attendanceButton(
                  label: "Absent",
                  selected: status == "Absent",
                  color: Colors.red,
                  onTap: () => markAttendance(worker, "Absent"),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dateText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
              loadData();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
              loadData();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }

  Widget workerAttendanceCard(Map<String, dynamic> worker, String status) {
    final isPresent = status == "Present";
    final isAbsent = status == "Absent";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage:
                worker['image_url'] != null
                    ? NetworkImage(worker['image_url'])
                    : null,
            child:
                worker['image_url'] == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              worker['name'] ?? "Unnamed Worker",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isPresent
                      ? Colors.green.shade100
                      : isAbsent
                      ? Colors.red.shade100
                      : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color:
                    isPresent
                        ? Colors.green
                        : isAbsent
                        ? Colors.red
                        : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget attendanceButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
