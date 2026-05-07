import 'package:flutter/material.dart';

class TaskScreen extends StatelessWidget {
  final List<Map<String, dynamic>> tasks = [
    {
      "title": "Electrician",
      "count": 3,
      "description":
          "Supplying and managing electrical power to safely operate tools.",
      "assignedBy": "Alesha",
      "assignedTo": "Aziz",
      "date": "17 Oct '24",
    },
    {
      "title": "Plumbing",
      "count": 2,
      "description": "Installing and maintaining water systems.",
      "assignedBy": "John",
      "assignedTo": "Ali",
      "date": "15 Oct '24",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Monte Carlo Tower Project"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Cards Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  statusCard("Not Started", "12", Colors.red),
                  statusCard("Ongoing", "30", Colors.orange),
                  statusCard("Completed", "20", Colors.green),
                  statusCard("At Risk", "4", Colors.red),
                ],
              ),

              SizedBox(height: 20),

              // Tasks Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tasks",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(onPressed: () {}, child: Text("Upload")),
                ],
              ),

              SizedBox(height: 10),

              // Task List (Scrollable inside page)
              ListView.builder(
                itemCount: tasks.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return TaskCard(task: tasks[index]);
                },
              ),

              SizedBox(height: 20),

              // Add Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue[900],
                ),
                onPressed: () {},
                child: Text("Add New Task"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statusCard(String title, String number, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title),
              SizedBox(height: 8),
              Text(
                number,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
