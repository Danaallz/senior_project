import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerService {
  final supabase = Supabase.instance.client;

  Future<void> addWorker({
    required String name,
    required String role,
    required String phone,
    required String email,
    required String salary,
    required String salaryType,
    required String shiftType,
    required String joiningDate,
    String? projectId,
    File? imageFile,
  }) async {
    try {
      String? imageUrl;

      if (imageFile != null) {
        final fileName = 'worker_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('worker-imges').upload(fileName, imageFile);

        imageUrl = supabase.storage.from('worker-imges').getPublicUrl(fileName);
      }

      final insertedWorker =
          await supabase
              .from('workers')
              .insert({
                'name': name,
                'role': role,
                'phone': phone,
                'email': email,
                'salary': salary,
                'salary_type': salaryType,
                'shift_type': shiftType,
                'joining_date': joiningDate,
                'image_url': imageUrl,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      if (projectId != null && projectId.isNotEmpty) {
        await supabase.from('project_workers').insert({
          'project_id': projectId,
          'worker_id': insertedWorker['id'],
          'assigned_by': supabase.auth.currentUser?.id,
        });
      }
    } catch (e) {
      throw Exception("Failed to add worker: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getWorkers({String? projectId}) async {
    try {
      if (projectId != null && projectId.isNotEmpty) {
        final response = await supabase
            .from('project_workers')
            .select('workers(*)')
            .eq('project_id', projectId)
            .order('assigned_at', ascending: false);

        return response
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item['workers']),
            )
            .toList();
      }

      final response = await supabase
          .from('workers')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Failed to fetch workers: $e");
    }
  }

  Future<void> updateWorker({
    required String workerId,
    required String name,
    required String role,
    required String phone,
    required String email,
    required String salary,
    required String salaryType,
    required String shiftType,
  }) async {
    try {
      await supabase
          .from('workers')
          .update({
            'name': name,
            'role': role,
            'phone': phone,
            'email': email,
            'salary': salary,
            'salary_type': salaryType,
            'shift_type': shiftType,
          })
          .eq('id', workerId);
    } catch (e) {
      throw Exception("Failed to update worker: $e");
    }
  }

  Future<void> deleteWorker({required String workerId}) async {
    try {
      await supabase.from('project_workers').delete().eq('worker_id', workerId);

      await supabase.from('workers').delete().eq('id', workerId);
    } catch (e) {
      throw Exception("Failed to delete worker: $e");
    }
  }

  Future<void> assignWorkerToProject({
    required String workerId,
    required String projectId,
  }) async {
    try {
      await supabase.from('project_workers').upsert({
        'project_id': projectId,
        'worker_id': workerId,
        'assigned_by': supabase.auth.currentUser?.id,
      });
    } catch (e) {
      throw Exception("Failed to assign worker to project: $e");
    }
  }
}
