import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream of Auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Sign Up
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Login
  Future<AuthResponse> login(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
