import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications_page.dart';

class NotificationBell extends StatefulWidget {
  final Color color;
  final VoidCallback? onClosed;

  const NotificationBell({super.key, required this.color, this.onClosed});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final supabase = Supabase.instance.client;

  int unreadCount = 0;
  RealtimeChannel? notificationChannel;

  @override
  void initState() {
    super.initState();

    loadUnreadCount();
    subscribeToNotifications();
  }

  // ================================
  // REALTIME NOTIFICATION LISTENER
  // This updates the badge number immediately when a new notification
  // is inserted/updated/deleted in Supabase.
  // ================================
  void subscribeToNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    notificationChannel =
        supabase
            .channel('notifications_badge_${user.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                final newRecord = payload.newRecord;
                final oldRecord = payload.oldRecord;

                final newUserId = newRecord['user_id']?.toString();
                final oldUserId = oldRecord['user_id']?.toString();

                // Only refresh this user's badge.
                if (newUserId == user.id || oldUserId == user.id) {
                  loadUnreadCount();
                }
              },
            )
            .subscribe();
  }

  Future<void> loadUnreadCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (!mounted) return;
      setState(() => unreadCount = response.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => unreadCount = 0);
    }
  }

  @override
  void dispose() {
    if (notificationChannel != null) {
      supabase.removeChannel(notificationChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none, color: widget.color, size: 29),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );

            await loadUnreadCount();
            widget.onClosed?.call();
          },
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
