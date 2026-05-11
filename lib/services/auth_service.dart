import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add new user
  Future<User?> register(String email, String password, String name) async {
    try {
      print("Starting registration...");

      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password.trim(),
        data: {'full_name': name.trim()},
      );

      print("Auth signup successful");
      print("User ID: ${response.user?.id}");
      print("User Email: ${response.user?.email}");

      return response.user;
    } on AuthException catch (e) {
      print("Auth Error: ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected Error: $e");
      rethrow;
    }
  }

  // Login existing user
  Future<User?> login(String email, String password) async {
    try {
      print("Attempting login...");

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      print("Login successful");
      print("Logged in user: ${response.user?.email}");

      return response.user;
    } on AuthException catch (e) {
      print("Login Error: ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected Login Error: $e");
      rethrow;
    }
  }

  // Logout user
  Future<void> logout() async {
    await _supabase.auth.signOut();
    print("User logged out");
  }

  // Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Get current user id
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }
}
