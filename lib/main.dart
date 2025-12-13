import 'package:flutter/material.dart';

// 1. IMPORT NECESSARY SCREENS
import 'intro_screen.dart';
// Import your Registration/Sign-up Screen file (MUST be imported to use RegisterScreen)
import 'signup_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Senior Project', // Changed title
      debugShowCheckedModeBanner: false, // Recommended to remove debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ), // Updated seed color
        useMaterial3: true,
      ),

      // 2. ENTRY POINT CHANGE
      // Application now starts with the RegisterScreen:
      home: const RegisterScreen(),

      // Original IntroScreen/MyHomePage kept here as a comment for future use:
      //home: const IntroScreen(title: 'Flutter Demo Home Page'),
    );
  }
}


// 3. REMOVAL OF UNUSED DEFAULT WIDGETS
// NOTE: I am removing the entire 'MyHomePage' and '_MyHomePageState' classes from this file 
// because they are the default Flutter template and are not being used in your current setup. 
// If you want to keep them for reference, you must comment them out entirely (from class MyHomePage to the end).

/*
// --- START OF COMMENTED OUT DEFAULT WIDGETS ---
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
// --- END OF COMMENTED OUT DEFAULT WIDGETS ---
*/