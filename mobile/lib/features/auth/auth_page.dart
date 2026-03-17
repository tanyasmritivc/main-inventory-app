import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
import '../onboarding/onboarding_prefs.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  bool _needsEmailVerification = false;
  String? _verificationEmail;

  String _friendlyAuthError(String message) {
    final m = message.trim();
    final lower = m.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email') &&
        lower.contains('password') &&
        lower.contains('required')) {
      return 'Email and password are required.';
    }
    if (m.isEmpty) return 'That didn’t work. Try again.';
    return 'That didn’t work. Try again.';
  }

  void _showEmailVerificationPrompt({required String email}) {
    setState(() {
      _needsEmailVerification = true;
      _verificationEmail = email;
      _error = null;
    });
  }

  Future<void> _resendVerificationEmail() async {
    final email = (_verificationEmail ?? _email.text).trim();
    if (email.isEmpty) return;

    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  Future<void> _ensureProfile({required String userId}) async {
    try {
      final md =
          Supabase.instance.client.auth.currentUser?.userMetadata ??
          const <String, dynamic>{};
      final given = (md['given_name'] is String)
          ? (md['given_name'] as String).trim()
          : '';
      final family = (md['family_name'] is String)
          ? (md['family_name'] as String).trim()
          : '';

      final first = _firstName.text.trim();
      final last = _lastName.text.trim();

      final firstName = first.isNotEmpty ? first : given;
      final lastName = last.isNotEmpty ? last : family;

      if (firstName.isEmpty && lastName.isEmpty) return;

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsEmailVerification = false;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = _email.text.trim();
      final password = _password.text;

      if (email.isEmpty || password.isEmpty) {
        throw const AuthException('Email and password are required');
      }

      if (_isLogin) {
        await auth.signInWithPassword(email: email, password: password);
        await auth.refreshSession();

        final confirmedAt =
            Supabase.instance.client.auth.currentSession?.user.emailConfirmedAt;
        if (confirmedAt == null) {
          await auth.signOut();
          _showEmailVerificationPrompt(email: email);
          return;
        }

        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        }
      } else {
        final res = await auth.signUp(email: email, password: password);
        final userId = res.user?.id;
        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        }
        await OnboardingPrefs.setPostSignupPending(true);

        final confirmedAt = res.session?.user?.emailConfirmedAt;
        if (confirmedAt == null) {
          if (res.session != null) {
            await auth.signOut();
          }
          _showEmailVerificationPrompt(email: email);
          return;
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign in' : 'Create account'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'Welcome back' : 'Welcome',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Sign in to upload documents and view activity.'
                        : 'Sign up to start uploading documents.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_isLogin) ...[
                    TextField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastName,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@company.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  PrimaryGradientButton(
                    onPressed: _loading ? null : _submit,
                    borderRadius: 999,
                    height: 50,
                    child: Text(
                      _loading
                          ? 'Please wait…'
                          : (_isLogin ? 'Sign in' : 'Create account'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_needsEmailVerification) ...[
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mark_email_unread_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Please verify your email before signing in. Check your inbox.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: (_resending || _loading)
                                ? null
                                : _resendVerificationEmail,
                            child: Text(
                              _resending
                                  ? 'Resending…'
                                  : 'Resend verification email',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _needsEmailVerification = false;
                              _verificationEmail = null;
                              _error = null;
                            });
                          },
                    child: Text(
                      _isLogin
                          ? 'Need an account? Sign up'
                          : 'Have an account? Login',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
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
