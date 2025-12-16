import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerService {
  final CollectionReference workers =
      FirebaseFirestore.instance.collection('workers');

  Future<void> addWorker({
    required String name,
    required String role,
    required String phone,
    required String email,
    required String salary,
    required String salaryType,
    required String shiftType,
    required String joiningDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    await workers.add({
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'salary': salary,
      'salaryType': salaryType,
      'shiftType': shiftType,
      'joiningDate': joiningDate,
      'createdBy': user?.uid, // Track who created the worker entry
      'createdAt': Timestamp.now(),
    });
  }
}
