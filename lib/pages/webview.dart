import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'login.dart';

class WebViewExample extends StatefulWidget {
  final String targetUrl;
  final Map<String, String> cookies;

  WebViewExample({required this.targetUrl, required this.cookies});

  @override
  _WebViewExampleState createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  final CookieManager _cookieManager = CookieManager.instance();
  String _currentUrl = '';
  DateTime? lastPressed;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebView();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        _showNoNetworkDialog();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeWebView() async {
    // print('Initializing WebView with cookies: ${widget.cookies}');

    // Combine API cookies with Google cookies
    Map<String, String> combinedCookies = Map.from(widget.cookies);

    // Add Google cookies
    Map<String, String> googleCookies = await _getGoogleCookies();
    combinedCookies.addAll(googleCookies);

    // Set all cookies
    for (var entry in combinedCookies.entries) {
      await _cookieManager.setCookie(
        url: Uri.parse(widget.targetUrl),
        name: entry.key,
        value: entry.value,
      );
      // print('Cookie set: ${entry.key}=${entry.value}');
    }

    // Once cookies are set, load the URL
    _webViewController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(widget.targetUrl)));
    // print('Loaded URL: ${widget.targetUrl}');
  }

// Function to retrieve Google cookies
  Future<Map<String, String>> _getGoogleCookies() async {
    Map<String, String> googleCookies = {};

    try {
      // Retrieve cookies from Google's domain
      List<Cookie> cookies = await _cookieManager.getCookies(
        url: Uri.parse('https://accounts.google.com'),
      );

      // Convert the List<Cookie> to a Map<String, String>
      for (var cookie in cookies) {
        googleCookies[cookie.name] = cookie.value;
      }

      // print('Google cookies: $googleCookies');
    } catch (error) {
      // print('Failed to retrieve Google cookies: $error');
    }

    return googleCookies;
  }

  Future<bool> _onWillPop() async {
    if (await _webViewController?.canGoBack() ?? false) {
      _webViewController?.goBack();
      return Future.value(false);
    } else {
      DateTime now = DateTime.now();
      if (lastPressed == null || now.difference(lastPressed!) > Duration(seconds: 2)) {
        lastPressed = now;
        Fluttertoast.showToast(msg: 'Press again to exit');
        return Future.value(false);
      }
      return Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(url: Uri.parse(widget.targetUrl)),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                        },
                        onLoadStart: (controller, url) {
                          setState(() {
                            _isLoading = true;
                            _currentUrl = url.toString();
                          });
                        },
                        onLoadStop: (controller, url) {
                          setState(() {
                            _isLoading = false;
                            _currentUrl = url.toString();
                          });
                          _saveCurrentUrl(_currentUrl);
                        },
                        onProgressChanged: (controller, progress) {
                          setState(() {
                            _isLoading = progress < 100;
                          });
                        },
                      ),
                      if (_isLoading)
                        Positioned(
                          bottom: 34,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            color: Colors.amber,
                            child: LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                              backgroundColor: Colors.yellow,
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 7,
                            color: Color(0xFF672c7b),
                            width: MediaQuery.of(context).size.width,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: MediaQuery.of(context).size.width / 2,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width / 2,
                                    height: 10,
                                    color: Colors.amber,
                                  ),
                                ),
                                Align(
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    width: _isLoading ? MediaQuery.of(context).size.width : 0,
                                    height: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 17,
                            color: Colors.yellow,
                            child: Row(
                              children: [
                                _buildNavText('All Courses'),
                                _buildNavText('My Calendar'),
                                _buildNavText('My Dashboard'),
                                _buildNavText('My Profile'),
                                _buildNavText('Logout'),
                              ],
                            ),
                          ),
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/bar.jpg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildIcon('assets/courses.svg', 'https://lms.elprof.cloud/course/'),
                                _buildIcon('assets/calendar.svg', 'https://lms.elprof.cloud/calendar/view.php?view=month'),
                                _buildIcon('assets/dashboard.svg', 'https://lms.elprof.cloud/my/'),
                                _buildIcon('assets/profile.svg', 'https://lms.elprof.cloud/user/profile.php'),
                                _buildIcon('assets/logout.svg', '', isLogout: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentUrl(String url) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedUrl', url);
  }

  Widget _buildNavText(String text) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.yaldevi(
            textStyle: TextStyle(
              color: Color(0xFF672c7b),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String assetPath, String url, {bool isLogout = false}) {
    bool isSelected = _currentUrl == url && !isLogout;
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (isLogout) {
            await _logout();
          } else {
            _webViewController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
            setState(() {
              _currentUrl = url;
            });
            _saveCurrentUrl(url);
          }
        },
        child: Center(
          child: SvgPicture.asset(
            assetPath,
            height: isLogout ? 35 : 40,
            color: isSelected ? Colors.yellow : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await _cookieManager.deleteAllCookies();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showNoNetworkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('No Network'),
          content: Text('No network connection detected. Please check your network settings and refresh.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeWebView();
              },
              child: Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}