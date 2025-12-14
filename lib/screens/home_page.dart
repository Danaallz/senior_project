import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService auth = AuthService();
  final UserService userService = UserService();
  String userName = "User";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = auth.getCurrentUser();
    if (user != null) {
      // get user name from Firestore
      final name = await userService.getUserName(user.uid);
      setState(() {
        userName = name ?? user.email ?? "User";
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await auth.logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Logged out successfully"),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Welcome, $userName",
          style: const TextStyle(color: Colors.grey),
        ),
        backgroundColor: const Color(0xff0d1b46),
        iconTheme: const IconThemeData(color: Colors.grey),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
        ],
      ),
      body: const Center(),
    );
  }
}
