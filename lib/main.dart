import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


// Screens
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';
import 'screens/addWorker_page.dart';
import 'screens/owner_home_page.dart';
import 'screens/settings_page.dart';
import 'screens/customer_support_page.dart';
import 'screens/about_us_page.dart';
import 'screens/add_project_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Senior Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // Entry point
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroScreen(title: 'Intro'),
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(),
        '/addWorker': (context) => const AddWorkerPage(),


        '/ownerHome': (context) => const OwnerHomePage(),
        '/adminHome': (context) => const HomePage(),
        '/managerHome': (context) => const HomePage(),
        '/engineerHome': (context) => const HomePage(),

        '/settings': (context) => const SettingsPage(),
        '/customerSupport': (context) => const CustomerSupportPage(),
        '/aboutUs': (context) => const AboutUsPage(),

        '/addProject': (context) => const AddProjectPage(),
      },
    );
  }
}
