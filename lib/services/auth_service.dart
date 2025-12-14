import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // add new user
  Future<User?> register(String email, String password, String name) async {
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;

    if (user != null) {
      // update display name
      await user.updateDisplayName(name);
      await user.reload(); // refresh user data
      user = _auth.currentUser;
    }

    return user;
  }

  // login existing user
  Future<User?> login(String email, String password) async {
    UserCredential userCredential =
        await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  // logout user
  Future<void> logout() async {
    await _auth.signOut();
  }

  // get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
