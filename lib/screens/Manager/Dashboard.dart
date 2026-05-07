import 'package:flutter/material.dart';

void main() {
  runApp(const ConstructionDashboardApp());
}

class ConstructionDashboardApp extends StatelessWidget {
  const ConstructionDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        fontFamily: 'sans-serif',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            _buildInsightsSection(),
            _buildSitePhotosSection(),
          ],
        ),
      ),
    );
  }

  // MARK: - Header Section
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.person, size: 40, color: Colors.blue),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Hello!",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
                "Sara Algamdi",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: const [
                  Icon(Icons.business, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Monte Carlo Tower Project",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const Text(
                "As Salamah, Jeddah, Saudi Arabia",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "⏳ In Progress",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MARK: - Tab Bar
  Widget _buildTabBar() {
    final tabs = [
      "Digital Twin",
      "Task",
      "Attendance",
      "Material",
      "Worker",
      "Equipment",
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children:
            tabs.map((tab) {
              bool isSelected = tab == "Task";
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border:
                      isSelected
                          ? const Border(
                            bottom: BorderSide(
                              color: Color(0xFF214192),
                              width: 3,
                            ),
                          )
                          : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF214192) : Colors.grey,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // MARK: - Insights Section
  Widget _buildInsightsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSectionHeader("Insights"),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInsightCard(
                  "Materials",
                  "124",
                  "Received",
                  Colors.green,
                  Icons.fact_check_outlined,
                ),
                _buildInsightCard(
                  "Materials",
                  "23",
                  "Used",
                  Colors.red,
                  Icons.delete_outline,
                ),
                _buildInsightCard(
                  "Labour",
                  "23",
                  "All",
                  Colors.brown,
                  Icons.people_outline,
                ),
                _buildInsightCard(
                  "Tasks",
                  "30",
                  "All",
                  Colors.amber,
                  Icons.sync,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    String title,
    String count,
    String sub,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  // MARK: - Site Photos Section
  Widget _buildSitePhotosSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionHeader("Site Photos"),
          const SizedBox(height: 15),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildAddPhotoButton(),
                _buildPhotoItem(
                  "https://images.unsplash.com/photo-1541888946425-d81bb19240f5?q=80&w=500",
                ),
                _buildPhotoItem(
                  "https://images.unsplash.com/photo-1504307651254-35680f356dfd?q=80&w=500",
                ),
                _buildPhotoItem(
                  "https://images.unsplash.com/photo-1531834685032-c744644a3075?q=80&w=500",
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_a_photo_outlined, color: Colors.blue, size: 30),
          SizedBox(height: 8),
          Text("Add Photo", style: TextStyle(color: Colors.blue, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(String url) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () {},
          child: const Text("view all ›", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}
