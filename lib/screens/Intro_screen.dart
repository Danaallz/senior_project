import 'package:flutter/material.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required String title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 🔹 Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/DigitalTwins.png',
                fit: BoxFit.contain,
              ),
            ),

            // 🔹 Foreground Content
            Column(
              children: [
                // Top Image
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Image.asset(
                        "assets/DTPCM.jpeg",
                        width: 230,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Bottom Card
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(173, 134, 134, 134),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 25,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Optimize Projects with DTPCM",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Optimize projects with digital twin visualization and AI predictive models, empowering managers to achieve unparalleled efficiency and success.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(137, 0, 0, 0),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Dots Indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDot(true),
                              _buildDot(false),
                              _buildDot(false),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF0D1A3A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Log In",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Social Buttons
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _socialButton(
                                  "assets/google-Icon.png"),
                              _socialButton(
                                  "assets/apple-Icon.png"),
                              _socialButton(
                                  "assets/facebook-alt-Icon.png"),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Create Account Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don’t have an account?",
                                style:
                                    TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                      context, '/register');
                                },
                                child: const Text(
                                  "Create an account",
                                  style: TextStyle(
                                    color: Color.fromARGB(
                                        255, 5, 96, 170),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Dot indicator
  static Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.black87 : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  // Social Button
  static Widget _socialButton(String assetPath) {
    return Container(
      width: 60,
      height: 50,
      decoration: BoxDecoration(
        color: const Color.fromARGB(164, 114, 114, 114),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ],
      ),
      child: Center(
        child: Image.asset(assetPath, width: 28, height: 28),
      ),
    );
  }
}
