import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Add user to profiles table
  Future<void> addUser(
    String uid,
    String name,
    String email,
    String mobile,
    String role,
  ) async {
    try {
      print("Adding user to profiles table...");

      await supabase.from('profiles').upsert({
        'id': uid,
        'full_name': name,
        'email': email,
        'phone': mobile,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      print("User added to profiles successfully");
    } on PostgrestException catch (e) {
      print("Database Error: ${e.message}");
      print("Details: ${e.details}");
      print("Hint: ${e.hint}");
      rethrow;
    } catch (e) {
      print("Unexpected UserService Error: $e");
      rethrow;
    }
  }

  // Get user name
  Future<String?> getUserName(String uid) async {
    final response =
        await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', uid)
            .maybeSingle();

    return response?['full_name'];
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    final response =
        await supabase
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .maybeSingle();

    return response?['role'];
  }

  // Get full profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final response =
        await supabase.from('profiles').select().eq('id', uid).maybeSingle();

    return response;
  }

  // Get all managers
  Future<List<Map<String, dynamic>>> getManagers() async {
    final response = await supabase
        .from('profiles')
        .select()
        .or('role.eq.manager,role.eq.project manager');

    return List<Map<String, dynamic>>.from(response);
  }

  // Get all site engineers
  Future<List<Map<String, dynamic>>> getSiteEngineers() async {
    final response = await supabase
        .from('profiles')
        .select()
        .or('role.eq.site engineer,role.eq.site_engineer');

    return List<Map<String, dynamic>>.from(response);
  }
}
