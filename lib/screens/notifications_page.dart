import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService notificationService = NotificationService();

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color orangeColor = Color(0xffff9800);
  static const Color greenColor = Color(0xff22c55e);
  static const Color redColor = Color(0xffef4444);

  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadNotifications() async {
    setState(() => isLoading = true);

    try {
      final data = await notificationService.getMyNotifications();
      if (!mounted) return;
      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color colorFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('success') ||
        value.contains('approved') ||
        value.contains('good'))
      return greenColor;
    if (value.contains('critical') || value.contains('rejected'))
      return redColor;
    if (value.contains('warning') ||
        value.contains('delay') ||
        value.contains('risk'))
      return orangeColor;
    return primaryColor;
  }

  IconData iconFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('success') ||
        value.contains('approved') ||
        value.contains('good'))
      return Icons.check_circle_outline;
    if (value.contains('critical') || value.contains('rejected'))
      return Icons.error_outline;
    if (value.contains('delay')) return Icons.schedule;
    if (value.contains('warning') || value.contains('risk'))
      return Icons.warning_amber_rounded;
    return Icons.notifications_none;
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse(cleanText(value));
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> openNotification(Map<String, dynamic> item) async {
    final id = cleanText(item['id']);
    if (id.isNotEmpty && item['is_read'] != true) {
      await notificationService.markAsRead(id);
      await loadNotifications();
    }
  }

  Widget notificationCard(Map<String, dynamic> item) {
    final title =
        cleanText(item['title']).isEmpty
            ? 'Notification'
            : cleanText(item['title']);
    final message = cleanText(item['message']);
    final type =
        cleanText(item['type']).isEmpty ? 'info' : cleanText(item['type']);
    final isRead = item['is_read'] == true;
    final color = colorFor(type);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => openNotification(item),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isRead ? Colors.grey.shade100 : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : color.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(iconFor(type), color: color, size: 24),
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
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatDate(item['created_at']),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 70,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            const Text(
              'No notifications yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Project approvals, AI risks, delays, and site updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await notificationService.markAllAsRead();
                await loadNotifications();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? emptyState()
              : RefreshIndicator(
                onRefresh: loadNotifications,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                  children: [
                    Row(
                      children: [
                        Text(
                          '$unread unread',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'AI + Project Alerts',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...notifications.map(notificationCard),
                  ],
                ),
              ),
    );
  }
}
