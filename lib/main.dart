import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

// Screens
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';

import 'package:senior_project/screens/Manager/addWorker_page.dart';
import 'package:senior_project/screens/Manager/Workers.dart';
import 'package:senior_project/screens/Manager/project_screen.dart';

// Site Engineer Screen
import 'package:senior_project/screens/Site_Engineer/eng_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(
    url: 'https://obiwgenpodvxcdgfjkyc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iaXdnZW5wb2R2eGNkZ2Zqa3ljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjIwMzksImV4cCI6MjA5MTYzODAzOX0.EAEuUgG-W0p5o3-114jxWk5Ge3phxJjMJvOeUcHxaaY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Senior Project',
      debugShowCheckedModeBanner: false,

      // Start Screen
      home: const ProjectScreen(),

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => ProjectScreen(),

        // Manager Pages
        '/addWorker': (context) => const AddWorkerPage(),
        '/workers': (context) => const WorkersTab(),
        '/project': (context) => const ProjectScreen(),

        // Site Engineer Page
        '/engineerHome': (context) => const EngHomePage(),
      },
    );
  }
}
