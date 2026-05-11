import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/Manager/manager_home_page.dart';

import 'firebase_options.dart';

// General Screens
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_page.dart';

//Admin Screens
import 'package:senior_project/screens/Admin/admin_home_page.dart';

// Owner Screens
import 'screens/Owner/owner_home_page.dart';
import 'screens/Owner/add_project_page.dart';
import 'screens/Owner/project_details_page.dart';

// Site engineer
import 'screens/Site_Engineer/eng_welcome_page.dart';

// Sidebar Pages
import 'screens/sidebar_pages/settings_page.dart';
import 'screens/sidebar_pages/customer_support_page.dart';
import 'screens/sidebar_pages/about_us_page.dart';

// Digital Twin
import 'package:senior_project/screens/digital_twin_page.dart';

// Manager Screens
import 'package:senior_project/screens/Manager/addWorker_page.dart';
import 'package:senior_project/screens/Manager/Workers.dart';
import 'package:senior_project/screens/Manager/project_screen.dart';

// Site Engineer Screens
import 'package:senior_project/screens/Site_Engineer/eng_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  await dotenv.load(fileName: ".env");

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(
    url:
        dotenv
            .env['postgresql://postgres:52KGVh?mAF87txG@db.obiwgenpodvxcdgfjkyc.supabase.co:5432/postgres'] ??
        'https://obiwgenpodvxcdgfjkyc.supabase.co',
    anonKey:
        dotenv
            .env['eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iaXdnZW5wb2R2eGNkZ2Zqa3ljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjIwMzksImV4cCI6MjA5MTYzODAzOX0.EAEuUgG-W0p5o3-114jxWk5Ge3phxJjMJvOeUcHxaaY'] ??
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

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // First page
      home: const IntroScreen(title: 'Intro'),
      //home: const ProjectScreen(),

      // Normal routes
      routes: {
        // Auth
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        //Admin Pages
        '/adminHome': (context) => const AdminHomePage(),

        // Home Pages
        '/ownerHome': (context) => const OwnerHomePage(),

        // '/adminHome': (context) => const OwnerHomePage(),
        '/engineerHome': (context) => const EngWelcomePage(),

        // Sidebar Pages
        '/settings': (context) => const SettingsPage(),
        '/customerSupport': (context) => const CustomerSupportPage(),
        '/aboutUs': (context) => const AboutUsPage(),

        // Owner Pages
        '/addProject': (context) => const AddProjectPage(),

        // Manager Pages
        '/addWorker': (context) => const AddWorkerPage(),
        '/workers': (context) => const WorkersTab(),
        '/managerHome': (context) => const ManagerHomePage(),

        // Site engineer
        '/engineerHome': (context) => const EngWelcomePage(),
      },

      // Routes with arguments
      onGenerateRoute: (settings) {
        // Digital Twin Page
        if (settings.name == '/digitalTwin') {
          final project = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (context) => DigitalTwinPage(project: project),
          );
        }

        // Project Details Page
        if (settings.name == '/projectDetails') {
          final projectId = settings.arguments as String;

          return MaterialPageRoute(
            builder: (context) => ProjectDetailsPage(projectId: projectId),
          );
        }

        return null;
      },
    );
  }
}
