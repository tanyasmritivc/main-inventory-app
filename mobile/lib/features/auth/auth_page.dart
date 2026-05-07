import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/onboarding_prefs.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onAuthChanged});

  final VoidCallback? onAuthChanged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _isLogin = true;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  bool _needsEmailVerification = false;
  String? _verificationEmail;

  static const _oauthRedirectTo = 'io.supabase.flutter://login-callback';

  OAuthProvider? _oauthProviderLoading;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    assert(() {
      final keepAlive = <Object?>[
        _oauthSignIn,
      ];
      return keepAlive.isNotEmpty;
    }());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        )
      );
  }

  Future<void> _oauthSignIn(OAuthProvider provider) async {
    if (_loading) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = provider;
      _error = null;
      _needsEmailVerification = false;
      _verificationEmail = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectTo,
      );
    } on AuthException catch (e) {
      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Try again.');
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _oauthProviderLoading = null;
        });
      }
    }
  }

  bool _isDuplicateEmailMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('already exists') ||
        lower.contains('duplicate');
  }

  String _friendlyAuthError(String message) {
    final m = message.trim();
    final lower = m.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('invalid email') ||
        (lower.contains('email') && lower.contains('invalid'))) {
      return 'Enter a valid email address.';
    }
    if (lower.contains('password') &&
        (lower.contains('too short') ||
            lower.contains('at least') ||
            lower.contains('weak'))) {
      return 'Choose a stronger password.';
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

    if (!mounted) return;
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _oauthProviderLoading = null;
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

        final userId = Supabase.instance.client.auth.currentUser?.id;
        final confirmedAt = Supabase
            .instance
            .client
            .auth
            .currentSession
            ?.user
            .emailConfirmedAt;
        if (confirmedAt == null) {
          _showMessage(
            'Please verify your email. Some features may be limited.',
          );
        }

        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        }
      } else {
        final res = await auth.signUp(email: email, password: password);
        if (res.user != null) {
          try {
            await auth.refreshSession();
          } catch (_) {
          }

          if (auth.currentSession == null) {
            try {
              await auth.signInWithPassword(
                email: email,
                password: password,
              );
              await auth.refreshSession();
            } on AuthException catch (_) {
            } catch (_) {
            }
          }
        }

        widget.onAuthChanged?.call();

        if (res.user == null && res.session == null) {
          const msg =
              'An account with this email already exists. Please sign in.';
          if (!mounted) return;
          setState(() {
            _error = msg;
            _isLogin = true;
            _needsEmailVerification = false;
            _verificationEmail = null;
          });
          _showMessage(msg);
          return;
        }

        final userId = res.user?.id;
        if (userId != null && userId.isNotEmpty) {
          await _ensureProfile(userId: userId);
        } else {
          debugPrint(
            '[Auth] signUp did not return a user (email=$email). session=${res.session != null}',
          );
          if (!mounted) return;
          setState(() {
            _error = 'That didn’t work. Try again.';
          });
          _showMessage(_error!);
          return;
        }

        await OnboardingPrefs.setPostSignupPending(true);

        final confirmedAt = res.session?.user.emailConfirmedAt;
        if (confirmedAt == null) {
          _showMessage(
            'Please verify your email. Some features may be limited.',
          );

          if (res.session == null) {
            _showEmailVerificationPrompt(email: email);
          }
          return;
        }
      }
    } on AuthException catch (e) {
      debugPrint('[Auth] AuthException: ${e.message}');

      if (!_isLogin && _isDuplicateEmailMessage(e.message)) {
        const msg =
            'An account with this email already exists. Please sign in.';
        if (!mounted) return;
        setState(() {
          _error = msg;
          _isLogin = true;
          _needsEmailVerification = false;
          _verificationEmail = null;
        });
        _showMessage(msg);
        return;
      }

      final friendly = _friendlyAuthError(e.message);
      if (!mounted) return;
      setState(() => _error = friendly);
      _showMessage(friendly);
    } catch (e) {
      debugPrint('[Auth] Unknown error: $e');
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Try again.');
      _showMessage(_error!);
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
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
    );
    const focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
    );

    InputDecoration fieldDeco(String hint, {Widget? suffixIcon}) =>
        InputDecoration(
          filled: true,
          fillColor: const Color(0x0AFFFFFF),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0x33FFFFFF),
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: focusedBorder,
          suffixIcon: suffixIcon,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenH - safeTop - safeBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo area ────────────────────────────────────────
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0x14FFFFFF),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FindEZ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome back.' : 'Create your account.',
                        style: const TextStyle(
                          color: Color(0x73FFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form ─────────────────────────────────────────────
                const SizedBox(height: 48),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  height: _isLogin ? 0 : 66.0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: Column(
                    children: [
                      TextField(
                        controller: _firstName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: fieldDeco('Your name'),
                        autofillHints: const [AutofillHints.givenName],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: fieldDeco('Email'),
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: fieldDeco(
                    'Password',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0x4DFFFFFF),
                        size: 18,
                      ),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 54,
                  child: TextButton(
                    onPressed: _loading ? null : _submit,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: (_loading && _oauthProviderLoading == null)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Please wait…',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isLogin ? 'Sign in' : 'Create account',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_needsEmailVerification) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Check your inbox to verify your email.',
                    style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: (_resending || _loading)
                        ? null
                        : _resendVerificationEmail,
                    child: Text(
                      _resending ? 'Resending…' : 'Resend verification email',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // ── Bottom spacer + toggle ────────────────────────────
                const Spacer(),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                        style: const TextStyle(
                          color: Color(0x4DFFFFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      GestureDetector(
                        onTap: _loading
                            ? null
                            : () => setState(() {
                                  _isLogin = !_isLogin;
                                  _needsEmailVerification = false;
                                  _verificationEmail = null;
                                  _error = null;
                                }),
                        child: Text(
                          _isLogin ? 'Sign up' : 'Sign in',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
