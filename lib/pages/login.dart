import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'webview.dart';
import 'google.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
  print('Cookies written: $cookies');
}

Future<Map<String, dynamic>?> readCookies() async {
  try {
    final file = await _cookieFile;
    final contents = await file.readAsString();
    final data = jsonDecode(contents);
    print('Cookies read: ${data['cookies']}');
    return data;
  } catch (e) {
    print('Error reading cookies: $e');
    return null;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITalent',
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
  final AuthService _authService = AuthService();

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

  void _showNoNetworkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No Network'),
          content: Text('Please check your connection and try again.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
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
      _showNoNetworkDialog();
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF672c7b),),
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
          'url': 'https://lms.elprof.cloud/',
        };

        var response = await http.post(
          loginUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(loginFormValues),
        );

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
      final responseJson = jsonDecode(response.body);
      if (responseJson['message'] == 'Login successful') {
        final cookies = responseJson['cookies'] as List<dynamic>;
        Map<String, String> cookieMap = {};
        cookies.forEach((cookie) {
          cookieMap[cookie['key']] = cookie['value'];
        });

        if (cookieMap.isNotEmpty) {
          await writeCookies(cookieMap, targetUrl);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  WebViewExample(
                    targetUrl: targetUrl,
                    cookies: cookieMap,
                  ),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: 'No cookies found in the response.');
        }
      } else if (responseJson['error'] == 'Invalid login credentials') {
        Fluttertoast.showToast(msg: 'Invalid credentials. Please try again.');
      } else {
        Fluttertoast.showToast(msg: 'Internal server error. Please try again later.');
      }
    } else {
      Fluttertoast.showToast(msg: 'Invalid credentials.');
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
                            onPressed: _authService.signInWithGoogle,
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