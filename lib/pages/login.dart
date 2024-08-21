import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'webview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> get _cookieFile async {
  final path = await _localPath;
  return File('$path/cookies.json');
}

Future<void> writeCookies(Map<String, String> cookies, String url) async {
  final file = await _cookieFile;
  final data = {
    'url': url,
    'cookies': cookies,
  };
  await file.writeAsString(jsonEncode(data));
  // print('Cookies written: $data');
}

Future<Map<String, dynamic>?> readCookies() async {
  try {
    final file = await _cookieFile;
    final contents = await file.readAsString();
    final data = jsonDecode(contents);
    // print('Cookies read: ${data['cookies']}');
    return data;
  } catch (e) {
    // print('Error reading cookies: $e');
    return null;
  }
}

Future<void> _signInWithGoogle(BuildContext context) async {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );

  try {
    // Initiating the sign-in process
    final GoogleSignInAccount? googleSignInAccount = await _googleSignIn.signIn();
    print('Google user: $googleSignInAccount');

    if (googleSignInAccount == null) {
      Fluttertoast.showToast(msg: 'Sign-in canceled.');
      return;
    }

    // Getting the authentication tokens from the signed-in Google user
    final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              SizedBox(width: 20),
              Text('Signing In...'),
            ],
          ),
        );
      },
    );

    // Print the authentication details
    // print('Google ID Token: ${googleSignInAuthentication.idToken}');
    // print('Google Access Token: ${googleSignInAuthentication.accessToken}');

    // Creating Firebase credential with the obtained Google authentication tokens
    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleSignInAuthentication.idToken,
      accessToken: googleSignInAuthentication.accessToken,
    );

    // Signing in to Firebase with the Google credential
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    final User? user = userCredential.user;
    // print('Firebase user: ${user?.displayName}');

    if (googleSignInAuthentication.idToken != null) {
      String idToken = googleSignInAuthentication.idToken!;
      // print('ID Token: $idToken');

      // Decode the ID token
      Map<String, dynamic> decodedToken = JwtDecoder.decode(idToken);
      // print('Decoded Token: $decodedToken');

      // Send the encoded token and Moodle URL to your API and get the cookies
      Map<String, String> cookieMap = await _sendEncodedTokenAndUrl(idToken);

      if (cookieMap.isNotEmpty) {
        // Prepare your target URL
        String targetUrl = "https://lms.elprof.cloud/";

        // Save the cookies for the WebView
        await writeCookies(cookieMap, targetUrl);

        // Navigate to the WebView with the target URL and cookies
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WebViewExample(
              targetUrl: targetUrl,
              cookies: cookieMap,
            ),
          ),
        );
      } else {
        _retrySignIn(context);
      }
    } else {
      _retrySignIn(context);
    }
  } catch (error) {
    if (error.toString().contains('404')) {
      _retrySignIn(context); // Retry if the error is 404
    } else {
      Fluttertoast.showToast(msg: 'Sign-in error: ${error.toString()}');
    }
  }
}

Future<void> _retrySignIn(BuildContext context) async {
  _signInWithGoogle(context);
}
final GoogleSignIn _googleSignIn = GoogleSignIn();

// Function to send the encoded token and Moodle URL to the API
Future<Map<String, String>> _sendEncodedTokenAndUrl(String idToken) async {
  final String apiUrl = "https://moodle-login.vercel.app/api/moodle-login-google"; // Replace with your API endpoint

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
        'moodleUrl': "https://lms.elprof.cloud/",
      }),
    );

    if (response.statusCode == 200) {
      // print('Successfully sent encoded token and Moodle URL to API. ${response.body}');
      // Sign out the current user to ensure the account picker is shown
      await _googleSignIn.signOut();

      // Decode the response body
      final responseBody = jsonDecode(response.body);

      // Extract the list of cookies
      List<dynamic> cookiesList = responseBody['cookies'];

      // Convert the list of cookies to a Map<String, String>
      Map<String, String> cookiesMap = {};
      for (var cookie in cookiesList) {
        cookiesMap[cookie['key']] = cookie['value'];
      }

      // print('Received cookies from API: $cookiesMap');
      return cookiesMap;
    } else {
      // print('Failed to send encoded token and Moodle URL to API: ${response.statusCode} - ${response.body}');
      // Fluttertoast.showToast(msg: 'Failed to send encoded token and Moodle URL to API.');
    }
  } catch (error) {
    // print('Error sending encoded token and Moodle URL to API: $error');
    // Fluttertoast.showToast(msg: 'Error sending encoded token and Moodle URL to API.');
  }

  return {};
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Prof',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<Map<String, dynamic>?>(
        future: readCookies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData && snapshot.data!['cookies'].isNotEmpty) {
            return WebViewExample(
              targetUrl: 'https://lms.elprof.cloud/',
              cookies: Map<String, String>.from(snapshot.data!['cookies']),
            );
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  void _showNoNetworkDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Network'),
          content: const Text('Please check your connection and try again.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _login() async {
    bool hasNetwork = await _checkNetwork();
    if (!hasNetwork) {
      _showNoNetworkDialog(context);
      return;
    }

    if (_formKey.currentState!.validate()) {
      String email = _emailController.text;
      String password = _passwordController.text;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
                SizedBox(width: 20),
                Text('Loading...'),
              ],
            ),
          );
        },
      );

      final loginUrl = Uri.parse('http://moodle-login.vercel.app/api/moodle-login');
      const targetUrl = 'https://lms.elprof.cloud/';

      try {
        final loginFormValues = <String, String>{
          'username': email,
          'password': password,
          'url': "https://lms.elprof.cloud/"
        };

        var response = await http.post(
          loginUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(loginFormValues),
        );

        // Handle redirects if necessary
        while (response.statusCode == 308 || response.statusCode == 302) {
          final redirectUrl = response.headers['location'];
          if (redirectUrl == null) break;

          response = await http.post(
            Uri.parse(redirectUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(loginFormValues),
          );
        }

        Navigator.of(context).pop();
        _handleResponse(response, targetUrl);
      } catch (e) {
        Navigator.of(context).pop();
        Fluttertoast.showToast(msg: 'An error occurred: $e');
      }
    }
  }

  void _handleResponse(http.Response response, String targetUrl) async {
    if (response.statusCode == 200) {
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      if (responseJson['message'] == 'Login successful') {
        final cookies = responseJson['cookies'] as List<dynamic>;
        Map<String, String> cookieMap = {};
        for (var cookie in cookies) {
          cookieMap[cookie['key']] = cookie['value'];
        }

        if (cookieMap.isNotEmpty) {
          await writeCookies(cookieMap, targetUrl);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WebViewExample(
                targetUrl: targetUrl,
                cookies: cookieMap,
              ),
            ),
          );
        } else {
          // Fluttertoast.showToast(msg: 'No cookies found in the response.');
        }
      } else {
        // Fluttertoast.showToast(msg: 'Login failed: ${responseJson['message']}');
      }
    } else {
      Fluttertoast.showToast(msg: 'Login failed with status code: ${response.statusCode}');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/logback.jpg'),
              fit: BoxFit.cover, // Adjust the fit as needed
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/login.png',
                    height: 210,
                    width: 300.0,
                  ),
                  SizedBox(height: 7),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Username',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12.0,
                            ), // Adjust height here
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 50),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _login,
                            label: Text(
                              'Login',
                              style: TextStyle(color: Colors.purple,fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: TextStyle(
                                fontSize: 18.0,
                                color: Color(0xFF672c7b),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _signInWithGoogle(context);
                            },
                            icon: SvgPicture.asset(
                              'assets/google_logo.svg',
                              height: 20,
                            ),
                            label: Text(
                              'Login with Google',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: TextStyle(
                                fontSize: 18.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 200.0),
                  Text(
                    'El Prof © 2024 Designed by Learnock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}