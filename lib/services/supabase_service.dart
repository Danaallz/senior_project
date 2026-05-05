import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  Future<void> addProfile({
    required String firebaseUid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    await supabase.from('profiles').insert({
      'firebase_uid': firebaseUid,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
    });
  }

  Future<Map<String, dynamic>?> getProfileByFirebaseUid(String firebaseUid) async {
    return await supabase
        .from('profiles')
        .select()
        .eq('firebase_uid', firebaseUid)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getOwnerProjects(String ownerId) async {
    final response = await supabase
        .from('projects')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateProfile({
    required String profileId,
    required Map<String, dynamic> data,
  }) async {
    await supabase.from('profiles').update(data).eq('id', profileId);
  }

  Future<void> createSupportTicket({
    required String userId,
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await supabase.from('support_tickets').insert({
      'user_id': userId,
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'status': 'open',
    });
  }

  Future<void> createProject({
    required Map<String, dynamic> data,
  }) async {
    await supabase.from('projects').insert(data);
  }
  Future<List<Map<String, dynamic>>> getAllProjects() async {
    final response = await supabase
        .from('projects')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}