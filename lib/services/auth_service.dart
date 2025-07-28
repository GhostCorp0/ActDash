import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String email;
  final String? displayName;

  User({
    required this.id,
    required this.email,
    this.displayName,
  });
}

class AuthService {
  static User? _currentUser;
  static final StreamController<User?> _authStateController = StreamController<User?>.broadcast();

  // Get current user
  static User? get currentUser => _currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => _currentUser != null;

  // Stream of auth state changes
  static Stream<User?> get authStateChanges => _authStateController.stream;

  // Sign in with email and password
  static Future<User> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Accept any email/password combination for now
    // You can add your specific Firebase user credentials here
    final user = User(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@')[0], // Use email prefix as display name
    );
    
    _currentUser = user;
    _authStateController.add(user);
    
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_display_name', user.displayName ?? '');
    
    return user;
  }

  // Sign out
  static Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
    
    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    await prefs.remove('user_display_name');
  }

  // Get user email
  static String? get userEmail => _currentUser?.email;

  // Get user display name
  static String? get userDisplayName => _currentUser?.displayName;

  // Get user ID
  static String? get userId => _currentUser?.id;

  // Initialize auth state from shared preferences
  static Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    final displayName = prefs.getString('user_display_name');
    
    if (email != null && userId != null) {
      _currentUser = User(
        id: userId,
        email: email,
        displayName: displayName,
      );
      _authStateController.add(_currentUser);
    }
  }

  // Dispose the stream controller
  static void dispose() {
    _authStateController.close();
  }
} 