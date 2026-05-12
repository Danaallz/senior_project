import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EngWorkersTab extends StatefulWidget {
  final String? projectId;

  const EngWorkersTab({super.key, this.projectId});

  @override
  State<EngWorkersTab> createState() => _EngWorkersTabState();
}

class _EngWorkersTabState extends State<EngWorkersTab> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchWorkers() async {
    if (widget.projectId == null) return [];

    final currentUserEmail =
        supabase.auth.currentUser?.email?.trim().toLowerCase() ?? '';

    final projectWorkers = await supabase
        .from('project_workers')
        .select('worker_id')
        .eq('project_id', widget.projectId!);

    if (projectWorkers.isEmpty) return [];

    final workerIds =
        projectWorkers
            .map((item) => item['worker_id'])
            .where((id) => id != null)
            .toList();

    if (workerIds.isEmpty) return [];

    final workersResponse = await supabase
        .from('workers')
        .select()
        .inFilter('id', workerIds);

    final workers = <Map<String, dynamic>>[];

    for (final item in workersResponse) {
      final worker = Map<String, dynamic>.from(item);

      final email = worker['email']?.toString().trim().toLowerCase() ?? '';

      // Hide only the logged-in Site Engineer
      if (email == currentUserEmail) continue;

      workers.add(worker);
    }

    return workers;
  }

  String getValue(Map<String, dynamic> worker, List<String> keys) {
    for (final key in keys) {
      if (worker[key] != null && worker[key].toString().trim().isNotEmpty) {
        return worker[key].toString();
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return const Center(child: Text("No project selected"));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchWorkers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading workers:\n${snapshot.error}",
              textAlign: TextAlign.center,
            ),
          );
        }

        final workers = snapshot.data ?? [];

        if (workers.isEmpty) {
          return const Center(
            child: Text("No workers assigned to this project"),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            const Text(
              "Project Workers",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...workers.map((worker) {
              final name = getValue(worker, [
                'name',
                'worker_name',
                'full_name',
              ]);

              final role = getValue(worker, [
                'role',
                'job',
                'job_title',
                'specialization',
              ]);

              final shift = getValue(worker, [
                'shift_type',
                'shift',
                'work_shift',
              ]);

              final salary = getValue(worker, ['salary', 'payment', 'wage']);

              final phone = getValue(worker, [
                'phone',
                'phone_number',
                'mobile',
              ]);

              final email = getValue(worker, ['email', 'worker_email']);

              final imageUrl = getValue(worker, [
                'image_url',
                'photo_url',
                'profile_image',
              ]);

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
                          imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                      child:
                          imageUrl.isEmpty
                              ? const Icon(Icons.person, size: 34)
                              : null,
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? "Unnamed Worker" : name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            role.isEmpty ? "Worker" : "Worker | $role",
                            style: const TextStyle(fontSize: 13),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "${shift.isEmpty ? "Day shift" : shift} - ﷼ ${salary.isEmpty ? "0" : salary}",
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
                                  phone.isEmpty ? "No phone" : phone,
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
                                  email.isEmpty ? "No email" : email,
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
            }),
          ],
        );
      },
    );
  }
}
