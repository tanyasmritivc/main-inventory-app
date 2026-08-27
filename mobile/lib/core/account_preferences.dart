import 'package:supabase_flutter/supabase_flutter.dart';

String accountPreferenceKey(String baseKey) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) return '$baseKey:signed-out';
  return '$baseKey:$userId';
}
