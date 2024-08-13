// google.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

   signInWithGoogle() async {
    print(4);
  }
  //   try {
  //     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  //     if (googleUser == null) {
  //       print('Google sign-in cancelled');
  //       return false;
  //     }
  //
  //     final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  //
  //     final AuthCredential credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );
  //
  //     final UserCredential userCredential = await _auth.signInWithCredential(credential);
  //     final User? user = userCredential.user;
  //
  //     if (user != null) {
  //       final idToken = await user.getIdToken();
  //       await _authenticateWithBackend(idToken!);
  //
  //       print('Google sign-in successful');
  //       return true;
  //     }
  //   } catch (e) {
  //     print('Error signing in with Google: $e');
  //   }
  //   return false;
  // }

  Future<void> _authenticateWithBackend(String idToken) async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/api/authenticate'), // Change to your actual backend endpoint
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      // Handle cookies or any other relevant data here
      print('Backend authentication successful: $responseBody');
    } else {
      print('Failed to authenticate with backend. Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }
  }
}
