import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// First-party item images always travel through the authenticated API.
String? privateItemImagePath(String source, {String? storageOrigin}) {
  final uri = Uri.tryParse(source);
  if (uri == null) return null;
  final trusted = Uri.tryParse(storageOrigin ?? AppConfig.supabaseUrl);
  if (trusted == null ||
      !['http', 'https'].contains(uri.scheme) ||
      !['http', 'https'].contains(trusted.scheme) ||
      !trusted.hasAuthority ||
      !uri.hasAuthority ||
      trusted.origin != uri.origin) {
    return null;
  }
  final match = RegExp(
    r'^/storage/v1/object/(?:public/|sign/|authenticated/)?item-images/(.+)$',
  ).firstMatch(uri.path);
  if (match == null) return null;
  String path;
  try {
    path = Uri.decodeComponent(match.group(1)!);
  } catch (_) {
    return null;
  }
  if (!RegExp(r'^[0-9a-fA-F-]{36}/').hasMatch(path) ||
      path.contains('\\') ||
      RegExp(r'%[0-9a-fA-F]{2}').hasMatch(path) ||
      path.split('/').any((p) => p.isEmpty || p == '.' || p == '..')) {
    return null;
  }
  return path;
}

String privateItemImageUrl(String source, {String? storageOrigin}) {
  final path = privateItemImagePath(source, storageOrigin: storageOrigin);
  if (path == null) return source;
  final owner = Supabase.instance.client.auth.currentUser?.id ?? '';
  final session =
      Supabase.instance.client.auth.currentSession?.accessToken.hashCode
          .toRadixString(16) ??
      '';
  return Uri.parse(AppConfig.apiBaseUrl)
      .resolve('/media/item-image')
      .replace(
        queryParameters: {'path': path, 'account': owner, 'session': session},
      )
      .toString();
}

Map<String, String>? privateItemImageHeaders(
  String source, {
  String? storageOrigin,
}) {
  if (privateItemImagePath(source, storageOrigin: storageOrigin) == null) {
    return null;
  }
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token == null ? const {} : {'Authorization': 'Bearer $token'};
}

class PrivateImage extends StatelessWidget {
  const PrivateImage(
    this.source, {
    super.key,
    this.storageOrigin,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
    this.cacheHeight,
    this.gaplessPlayback = false,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });
  final String source;
  final String? storageOrigin;
  final double? width, height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final FilterQuality filterQuality;
  final int? cacheWidth, cacheHeight;
  final bool gaplessPlayback, excludeFromSemantics;
  final String? semanticLabel;
  Widget _image() => Image.network(
    privateItemImageUrl(source, storageOrigin: storageOrigin),
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    frameBuilder: frameBuilder,
    filterQuality: filterQuality,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    gaplessPlayback: gaplessPlayback,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
    headers: privateItemImageHeaders(source, storageOrigin: storageOrigin),
  );
  @override
  Widget build(BuildContext context) {
    if (privateItemImagePath(source, storageOrigin: storageOrigin) == null) {
      return _image();
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (_, _) => _image(),
    );
  }
}
