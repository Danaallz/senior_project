import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'addWorker_page.dart';
import '../../services/worker_service.dart';

class WorkersTab extends StatefulWidget {
  final String? projectId;

  const WorkersTab({super.key, this.projectId});

  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  final WorkerService workerService = WorkerService();

  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> filteredWorkers = [];

  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  final List<String> roles = [
    "Site engineer",
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
    "superintendents",
    "operators",
  ];

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadWorkers() async {
    try {
      setState(() {
        isLoading = true;
      });

      final data = await workerService.getWorkers(projectId: widget.projectId);

      if (!mounted) return;

      setState(() {
        workers = data;
        filteredWorkers = _applySearch(data, searchController.text);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading workers: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _applySearch(
    List<Map<String, dynamic>> source,
    String query,
  ) {
    final lowerQuery = query.toLowerCase().trim();

    if (lowerQuery.isEmpty) {
      return List<Map<String, dynamic>>.from(source);
    }

    return source.where((worker) {
      final name = worker['name']?.toString().toLowerCase() ?? '';
      final role = worker['role']?.toString().toLowerCase() ?? '';
      final email = worker['email']?.toString().toLowerCase() ?? '';
      final phone = worker['phone']?.toString().toLowerCase() ?? '';

      return name.contains(lowerQuery) ||
          role.contains(lowerQuery) ||
          email.contains(lowerQuery) ||
          phone.contains(lowerQuery);
    }).toList();
  }

  void searchWorkers(String query) {
    setState(() {
      filteredWorkers = _applySearch(workers, query);
    });
  }

  Future<void> printWorkersPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text(
                "Workers Report",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  "Name",
                  "Role",
                  "Phone",
                  "Email",
                  "Salary",
                  "Salary Type",
                  "Shift",
                  "Joining Date",
                ],
                data:
                    workers.map((worker) {
                      return [
                        worker['name'] ?? '',
                        worker['role'] ?? '',
                        worker['phone'] ?? '',
                        worker['email'] ?? '',
                        worker['salary'] ?? '',
                        worker['salary_type'] ?? '',
                        worker['shift_type'] ?? '',
                        worker['joining_date'] ?? '',
                      ];
                    }).toList(),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> deleteWorker(Map<String, dynamic> worker) async {
    final workerId = worker['id']?.toString() ?? '';

    if (workerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot remove worker because worker ID is missing"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text("Remove Worker"),
          content: Text(
            "Are you sure you want to remove ${worker['name'] ?? 'this worker'}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await workerService.deleteWorker(workerId: workerId);

      if (!mounted) return;

      setState(() {
        workers.removeWhere((w) => w['id']?.toString() == workerId);
        filteredWorkers = _applySearch(workers, searchController.text);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Worker removed successfully"),
          backgroundColor: Colors.green,
        ),
      );

      await loadWorkers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error removing worker: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editWorker(Map<String, dynamic> worker) async {
    final workerId = worker['id']?.toString() ?? '';

    if (workerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot edit worker because worker ID is missing"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: worker['name'] ?? '');
    final phoneController = TextEditingController(text: worker['phone'] ?? '');
    final emailController = TextEditingController(text: worker['email'] ?? '');
    final salaryController = TextEditingController(
      text: worker['salary']?.toString() ?? '',
    );
    final salaryTypeController = TextEditingController(
      text: worker['salary_type'] ?? '',
    );
    final shiftController = TextEditingController(
      text: worker['shift_type'] ?? '',
    );

    String? selectedRole = worker['role']?.toString();

    if (selectedRole != null && !roles.contains(selectedRole)) {
      selectedRole = null;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2A44).withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF1C2A44),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Edit Worker",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Update worker information",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      editField("Name", nameController, Icons.person),
                      editRoleDropdown(
                        selectedRole: selectedRole,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      editField("Phone", phoneController, Icons.phone),
                      editField("Email", emailController, Icons.email),
                      editField("Salary", salaryController, Icons.payments),
                      editField(
                        "Salary Type",
                        salaryTypeController,
                        Icons.credit_card,
                      ),
                      editField("Shift Type", shiftController, Icons.schedule),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFF1C2A44),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Save"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    final updatedWorker = {
      'name': nameController.text.trim(),
      'role': selectedRole ?? '',
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'salary': salaryController.text.trim(),
      'salary_type': salaryTypeController.text.trim(),
      'shift_type': shiftController.text.trim(),
    };

    try {
      await workerService.updateWorker(
        workerId: workerId,
        name: updatedWorker['name']!,
        role: updatedWorker['role']!,
        phone: updatedWorker['phone']!,
        email: updatedWorker['email']!,
        salary: updatedWorker['salary']!,
        salaryType: updatedWorker['salary_type']!,
        shiftType: updatedWorker['shift_type']!,
      );

      if (!mounted) return;

      setState(() {
        final index = workers.indexWhere(
          (w) => w['id']?.toString() == workerId,
        );

        if (index != -1) {
          workers[index] = {...workers[index], ...updatedWorker};
        }

        filteredWorkers = _applySearch(workers, searchController.text);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Worker updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      await loadWorkers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating worker: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget editField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF1C2A44)),
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget editRoleDropdown({
    required String? selectedRole,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.work, color: Color(0xFF1C2A44)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  hint: const Text("Select role"),
                  value: selectedRole,
                  isExpanded: true,
                  items:
                      roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget workerCard(Map<String, dynamic> worker) {
    final imageUrl = worker['image_url'];

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.grey.shade300,
            backgroundImage:
                imageUrl != null && imageUrl.toString().isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
            child:
                imageUrl == null || imageUrl.toString().isEmpty
                    ? const Icon(Icons.person, size: 34)
                    : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        worker['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          editWorker(worker);
                        } else if (value == 'remove') {
                          deleteWorker(worker);
                        }
                      },
                      itemBuilder:
                          (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Remove",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Worker | ${worker['role'] ?? ''}",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  "${worker['shift_type'] ?? ''} shift - ﷼ ${worker['salary'] ?? ''}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        worker['phone'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        worker['email'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: workers.isEmpty ? null : printWorkersPdf,
              child: Text(
                "Upload",
                style: TextStyle(
                  color: workers.isEmpty ? Colors.grey : Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onChanged: searchWorkers,
          decoration: InputDecoration(
            hintText: "Search employee...",
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
        ),
        const SizedBox(height: 12),
        Expanded(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredWorkers.isEmpty
                  ? const Center(child: Text("No workers found"))
                  : ListView.builder(
                    itemCount: filteredWorkers.length,
                    itemBuilder: (context, index) {
                      return workerCard(filteredWorkers[index]);
                    },
                  ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: const Color(0xFF1C2A44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AddWorkerPage(projectId: widget.projectId),
                ),
              );

              if (result == true) {
                await loadWorkers();
              }
            },
            child: const Text(
              "Add New Worker",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
