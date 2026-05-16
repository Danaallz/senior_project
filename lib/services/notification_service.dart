import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> getUnreadCount() async {
    final notifications = await getMyNotifications();
    return notifications.where((item) => item['is_read'] != true).length;
  }

  Future<void> markAsRead(String notificationId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id);
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'info',
    String? projectId,
  }) async {
    await supabase.from('notifications').insert({
      'user_id': userId,
      'project_id': projectId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
