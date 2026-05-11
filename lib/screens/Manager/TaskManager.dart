import 'package:flutter/material.dart';

class TaskScreen extends StatelessWidget {
  TaskScreen({super.key});

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
        title: const Text("Monte Carlo Tower Project"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            children: [
              // Status Cards
              Row(
                children: [
                  Expanded(child: statusCard("Not Started", "12", Colors.red)),

                  const SizedBox(width: 8),

                  Expanded(child: statusCard("Ongoing", "30", Colors.orange)),

                  const SizedBox(width: 8),

                  Expanded(child: statusCard("Completed", "20", Colors.green)),

                  const SizedBox(width: 8),

                  Expanded(child: statusCard("At Risk", "4", Colors.red)),
                ],
              ),

              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    "Tasks",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  TextButton(onPressed: () {}, child: const Text("Upload")),
                ],
              ),

              const SizedBox(height: 10),

              // Tasks
              ListView.builder(
                itemCount: tasks.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),

                itemBuilder: (context, index) {
                  return TaskCard(task: tasks[index]);
                },
              ),

              const SizedBox(height: 20),

              // Add button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),

                  backgroundColor: Colors.blue[900],
                ),

                onPressed: () {},

                child: const Text(
                  "Add New Task",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statusCard(String title, String number, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),

        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 8),

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
    );
  }
}

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  task["title"],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[100],

                  child: Text(
                    task["count"].toString(),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              task["description"],
              style: TextStyle(color: Colors.grey[700]),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.person, size: 18),

                const SizedBox(width: 5),

                Text("Assigned by: ${task["assignedBy"]}"),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.engineering, size: 18),

                const SizedBox(width: 5),

                Text("Assigned to: ${task["assignedTo"]}"),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),

                const SizedBox(width: 5),

                Text(task["date"]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
