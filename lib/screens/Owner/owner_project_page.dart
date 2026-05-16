// lib/screens/owner_project_screen.dart

import 'package:flutter/material.dart';
import '../notification_bell.dart';

class OwnerProjectScreen extends StatelessWidget {
  final Widget body;
  final String ownerName;
  final String? profileImageUrl;
  final VoidCallback onLogout;
  final VoidCallback? onProfileUpdated;
  final bool showBackButton;
  final Widget? bottomNavigationBar;
  final Future<void> Function()? onRefresh;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color orangeColor = Color(0xffff8a00);
  static const Color greenColor = Color(0xff35c76b);

  const OwnerProjectScreen({
    super.key,
    required this.body,
    required this.ownerName,
    required this.profileImageUrl,
    required this.onLogout,
    this.onProfileUpdated,
    this.showBackButton = false,
    this.bottomNavigationBar,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        onRefresh == null
            ? body
            : RefreshIndicator(onRefresh: onRefresh!, child: body);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: OwnerSidebar(
        ownerName: ownerName,
        profileImageUrl: profileImageUrl,
        onLogout: onLogout,
        onProfileUpdated: onProfileUpdated,
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading:
            showBackButton
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(
              color: OwnerProjectScreen.primaryColor,
              onClosed: onProfileUpdated,
            ),
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
  });

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = isValidImageUrl(imageUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child:
          hasImage
              ? null
              : Icon(Icons.person, color: Colors.grey, size: radius),
    );
  }
}

class OwnerSidebar extends StatelessWidget {
  final String ownerName;
  final String? profileImageUrl;
  final VoidCallback onLogout;
  final VoidCallback? onProfileUpdated;

  const OwnerSidebar({
    super.key,
    required this.ownerName,
    required this.profileImageUrl,
    required this.onLogout,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(imageUrl: profileImageUrl, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "Owner",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              const Text(
                "MENUS",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text("Home"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/ownerHome');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("Account Settings"),
                onTap: () async {
                  Navigator.pop(context);

                  final result = await Navigator.pushNamed(
                    context,
                    '/settings',
                  );

                  if (result == true) {
                    onProfileUpdated?.call();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text("Customer Support"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/customerSupport');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("About us"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/aboutUs');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Log out",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerProjectHeader extends StatelessWidget {
  final String projectName;
  final String location;
  final String imageUrl;
  final String status;

  const OwnerProjectHeader({
    super.key,
    required this.projectName,
    required this.location,
    required this.imageUrl,
    required this.status,
  });

  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child:
              isValidImageUrl(imageUrl)
                  ? Image.network(
                    imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => imagePlaceholder(),
                  )
                  : imagePlaceholder(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: OwnerProjectScreen.orangeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: OwnerProjectScreen.orangeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade200,
      child: const Icon(Icons.apartment, color: Colors.grey),
    );
  }
}

class OwnerProjectTabBar extends StatelessWidget {
  final String selectedTab;
  final Function(String value) onTabSelected;

  const OwnerProjectTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tab("home", "Home"),
          tab("digital_twin", "Digital Twin"),
          tab("material", "Material"),
          tab("equipment", "Equipment"),
        ],
      ),
    );
  }

  Widget tab(String value, String title) {
    final isSelected = selectedTab == value;

    return GestureDetector(
      onTap: () => onTabSelected(value),
      child: Container(
        margin: const EdgeInsets.only(right: 22),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color:
                  isSelected
                      ? OwnerProjectScreen.primaryColor
                      : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? OwnerProjectScreen.primaryColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
