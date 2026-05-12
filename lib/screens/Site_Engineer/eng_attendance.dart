import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/worker_service.dart';

class EngAttendanceTab extends StatefulWidget {
  final String? projectId;

  const EngAttendanceTab({super.key, this.projectId});

  @override
  State<EngAttendanceTab> createState() => _EngAttendanceTabState();
}

class _EngAttendanceTabState extends State<EngAttendanceTab> {
  final supabase = Supabase.instance.client;
  final WorkerService workerService = WorkerService();

  bool isLoading = true;
  bool showSheet = false;

  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> filteredWorkers = [];
  Map<String, String> attendanceStatus = {};

  final TextEditingController searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  static const Color primaryBlue = Color(0xFF152B7F);
  static const Color orange = Color(0xFFFFB21A);
  static const Color green = Color(0xFF2E9461);
  static const Color red = Color(0xFFE6313A);

  String get dateText {
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return "${selectedDate.day.toString().padLeft(2, '0')} "
        "${months[selectedDate.month - 1]} "
        "${selectedDate.year}, "
        "${days[selectedDate.weekday - 1]}";
  }

  String get dbDate {
    return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    loadData();
    searchController.addListener(() {
      applySearch(searchController.text);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return "";
  }

  void applySearch(String query) {
    final q = query.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        filteredWorkers = List<Map<String, dynamic>>.from(workers);
      } else {
        filteredWorkers =
            workers.where((worker) {
              final name =
                  value(worker, [
                    'name',
                    'full_name',
                    'worker_name',
                  ]).toLowerCase();
              final role =
                  value(worker, ['role', 'job', 'job_title']).toLowerCase();
              final email =
                  value(worker, ['email', 'worker_email']).toLowerCase();

              return name.contains(q) || role.contains(q) || email.contains(q);
            }).toList();
      }
    });
  }

  Future<void> loadData() async {
    if (widget.projectId == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      final currentEmail =
          supabase.auth.currentUser?.email?.trim().toLowerCase() ?? "";

      final allWorkers = await workerService.getWorkers(
        projectId: widget.projectId,
      );

      final visibleWorkers =
          allWorkers.where((worker) {
            final email =
                value(worker, ['email', 'worker_email']).toLowerCase();
            return email != currentEmail;
          }).toList();

      final attendanceResponse = await supabase
          .from('attendance')
          .select()
          .eq('project_id', widget.projectId!)
          .eq('attendance_date', dbDate);

      final loadedAttendance = <String, String>{};

      for (final item in attendanceResponse) {
        final workerId = item['worker_id']?.toString();

        if (workerId != null && workerId.isNotEmpty) {
          loadedAttendance[workerId] = item['status']?.toString() ?? '';
        }
      }

      if (!mounted) return;

      setState(() {
        workers = visibleWorkers;
        attendanceStatus = loadedAttendance;
        filteredWorkers = List<Map<String, dynamic>>.from(visibleWorkers);
        isLoading = false;
      });

      applySearch(searchController.text);
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
        'worker_id': workerId,
        'worker_name': value(worker, ['name', 'full_name', 'worker_name']),
        'role':
            value(worker, ['role', 'job', 'job_title']).isEmpty
                ? 'Worker'
                : value(worker, ['role', 'job', 'job_title']),
        'status': status,
        'attendance_date': dbDate,
        'check_in':
            status == 'Present' ? DateTime.now().toIso8601String() : null,
        'created_at': DateTime.now().toIso8601String(),
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
      attendanceStatus.values.where((s) => s == "Present").length;

  int get absentCount =>
      attendanceStatus.values.where((s) => s == "Absent").length;

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return const Center(child: Text("No project selected"));
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 125),
      children: [
        buildDateRow(),
        const SizedBox(height: 12),
        buildSummaryRow(),
        const SizedBox(height: 18),
        buildSegmentedTabs(),
        const SizedBox(height: 14),
        buildSearchField(),
        const SizedBox(height: 14),
        buildWorkerHeader(),
        const SizedBox(height: 10),

        if (filteredWorkers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 45),
            child: Center(child: Text("No workers found")),
          )
        else
          ...filteredWorkers.map((worker) {
            return showSheet
                ? buildSheetWorkerCard(worker)
                : buildAttendanceStatusCard(worker);
          }),
      ],
    );
  }

  Widget buildDateRow() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 32),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
              loadData();
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                dateText,
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 32),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
              loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget buildSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: buildSmallSummaryCard(
            title: "Present",
            count: presentCount,
            color: green,
          ),
        ),
        const SizedBox(width: 34),
        Expanded(
          child: buildSmallSummaryCard(
            title: "Absent",
            count: absentCount,
            color: red,
          ),
        ),
      ],
    );
  }

  Widget buildSmallSummaryCard({
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(
            "$count",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSegmentedTabs() {
    return Container(
      height: 43,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: buildSegmentButton(
              title: "Attendance",
              selected: !showSheet,
              onTap: () => setState(() => showSheet = false),
            ),
          ),
          Expanded(
            child: buildSegmentButton(
              title: "Attendance sheet",
              selected: showSheet,
              onTap: () => setState(() => showSheet = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSegmentButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? orange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: "Search worker...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildWorkerHeader() {
    return Row(
      children: const [
        Text(
          "Workers",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        Spacer(),
        Icon(Icons.upload_file, color: primaryBlue, size: 18),
        SizedBox(width: 4),
        Text(
          "Upload",
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget buildWorkerImage(Map<String, dynamic> worker) {
    final imageUrl = value(worker, [
      'image_url',
      'photo_url',
      'profile_image',
      'profile_image_url',
    ]);

    return CircleAvatar(
      radius: 23,
      backgroundColor: Colors.grey.shade100,
      backgroundImage:
          imageUrl.startsWith('http') ? NetworkImage(imageUrl) : null,
      child:
          imageUrl.startsWith('http')
              ? null
              : const Icon(Icons.person_outline, color: primaryBlue, size: 28),
    );
  }

  Widget buildWorkerTopRow(Map<String, dynamic> worker) {
    final name = value(worker, ['name', 'full_name', 'worker_name']);
    final role = value(worker, ['role', 'job', 'job_title']);
    final shift = value(worker, ['shift_type', 'shift']);

    return Column(
      children: [
        Row(
          children: [
            buildWorkerImage(worker),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name.isEmpty ? "Unnamed Worker" : name,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              role.isEmpty ? "Worker" : role,
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(
              shift.isEmpty ? "1 Shift" : "$shift Shift",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSheetWorkerCard(Map<String, dynamic> worker) {
    final workerId = worker['id'].toString();
    final selectedStatus = attendanceStatus[workerId];

    return baseWorkerCard(
      child: Column(
        children: [
          buildWorkerTopRow(worker),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: attendanceActionButton(
                  title: "Present",
                  selected: selectedStatus == "Present",
                  selectedColor: green,
                  onTap: () => markAttendance(worker, "Present"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: attendanceActionButton(
                  title: "Absent",
                  selected: selectedStatus == "Absent",
                  selectedColor: red,
                  onTap: () => markAttendance(worker, "Absent"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildAttendanceStatusCard(Map<String, dynamic> worker) {
    final workerId = worker['id'].toString();
    final status = attendanceStatus[workerId] ?? "Not marked";

    Color color = Colors.grey;
    if (status == "Present") color = green;
    if (status == "Absent") color = red;

    return baseWorkerCard(
      child: Row(
        children: [
          buildWorkerImage(worker),
          const SizedBox(width: 10),
          Expanded(child: buildStatusWorkerInfo(worker)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusWorkerInfo(Map<String, dynamic> worker) {
    final name = value(worker, ['name', 'full_name', 'worker_name']);
    final role = value(worker, ['role', 'job', 'job_title']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? "Unnamed Worker" : name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role.isEmpty ? "Worker" : role,
          style: const TextStyle(
            color: primaryBlue,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget baseWorkerCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget attendanceActionButton({
    required String title,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
