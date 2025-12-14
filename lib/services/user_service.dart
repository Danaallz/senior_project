import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  Future<void> addUser(String uid, String name, String email, String mobile, String role) {
  return users.doc(uid).set({
    'name': name,
    'email': email,
    'mobile': mobile,
    'role': role,
    'createdAt': Timestamp.now(),
  });
}


  // get user name from Firestore
  Future<String?> getUserName(String uid) async {
    final doc = await users.doc(uid).get();
    if (doc.exists) {
      return doc.get('name') as String?;
    }
    return null;
  }
}
