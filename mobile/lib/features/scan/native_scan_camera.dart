import 'dart:async';
import 'package:flutter/services.dart';

class ScanCameraResult {
  const ScanCameraResult({this.photo, this.barcode});
  final Uint8List? photo;
  final String? barcode;
}

class NativeScanCamera {
  static const channel = MethodChannel('com.findez.app/scan-camera');
  static int _next = 0;
  String? _token;
  Future<Uint8List?> pick({required bool dark}) async {
    if (_token != null) return null;
    final token = _token = 'scan-camera-${++_next}';
    try {
      final bytes = await channel.invokeMethod<Uint8List>('present', {
        'token': token,
        'dark': dark,
      });
      return _token == token ? bytes : null;
    } finally {
      if (_token == token) _token = null;
    }
  }

  Future<ScanCameraResult?> capture({required bool dark}) async {
    if (_token != null) return null;
    final token = _token = 'scan-camera-${++_next}';
    try {
      final value = await channel.invokeMapMethod<String, dynamic>('present', {
        'token': token,
        'dark': dark,
        'barcodes': true,
      });
      if (_token != token || value == null) return null;
      return ScanCameraResult(
        photo: value['photo'] as Uint8List?,
        barcode: value['barcode'] as String?,
      );
    } finally {
      if (_token == token) _token = null;
    }
  }

  void cancel() {
    final token = _token;
    _token = null;
    if (token != null) {
      unawaited(channel.invokeMethod<void>('dismiss', {'token': token}));
    }
  }
}
