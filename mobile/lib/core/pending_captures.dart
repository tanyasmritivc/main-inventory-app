import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingCapture {
  const PendingCapture({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.place,
    required this.createdAt,
    required this.photoPath,
    this.extractedItems,
  });

  final String id;
  final String userId;
  final String workspaceId;
  final String place;
  final DateTime createdAt;
  final String photoPath;
  final List<Map<String, dynamic>>? extractedItems;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'workspace_id': workspaceId,
    'place': place,
    'created_at': createdAt.toIso8601String(),
    'photo_path': photoPath,
    if (extractedItems != null) 'extracted_items': extractedItems,
  };

  factory PendingCapture.fromJson(Map<String, dynamic> value) => PendingCapture(
    id: value['id'].toString(),
    userId: value['user_id'].toString(),
    workspaceId: value['workspace_id'].toString(),
    place: value['place'].toString(),
    createdAt: DateTime.parse(value['created_at'].toString()),
    photoPath: value['photo_path'].toString(),
    extractedItems: value['extracted_items'] is List
        ? List<Map<String, dynamic>>.from(value['extracted_items'] as List)
        : null,
  );
}

class PendingCaptures {
  PendingCaptures._();

  static Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/pending_captures');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<PendingCapture> add({
    required List<int> photo,
    required String workspaceId,
    required String place,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || workspaceId.isEmpty) {
      throw StateError('Sign in and choose a workspace before capturing.');
    }
    final directory = await _directory();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final photoPath = '${directory.path}/$id.jpg';
    final photoFile = File(photoPath);
    await photoFile.writeAsBytes(photo, flush: true);
    final capture = PendingCapture(
      id: id,
      userId: userId,
      workspaceId: workspaceId,
      place: place,
      createdAt: DateTime.now(),
      photoPath: photoPath,
    );
    try {
      await File(
        '${directory.path}/$id.json',
      ).writeAsString(jsonEncode(capture.toJson()), flush: true);
    } catch (_) {
      await photoFile.delete();
      rethrow;
    }
    return capture;
  }

  static Future<List<PendingCapture>> list(String? workspaceId) async {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } on AssertionError {
      return const [];
    }
    if (userId == null || workspaceId == null) return const [];
    final directory = await _directory();
    final captures = <PendingCapture>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final data =
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
      final capture = PendingCapture.fromJson(data);
      if (capture.userId != userId || capture.workspaceId != workspaceId) {
        continue;
      }
      if (!await File(capture.photoPath).exists()) {
        throw StateError('A waiting capture photo is missing.');
      }
      captures.add(capture);
    }
    captures.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return captures;
  }

  static Future<void> remove(PendingCapture capture) async {
    final directory = await _directory();
    final metadata = File('${directory.path}/${capture.id}.json');
    if (await metadata.exists()) {
      await metadata.delete();
    }
    final photo = File(capture.photoPath);
    if (await photo.exists()) await photo.delete();
  }

  static Future<PendingCapture> saveExtraction(
    PendingCapture capture,
    List<Map<String, dynamic>> items,
  ) async {
    final updated = PendingCapture(
      id: capture.id,
      userId: capture.userId,
      workspaceId: capture.workspaceId,
      place: capture.place,
      createdAt: capture.createdAt,
      photoPath: capture.photoPath,
      extractedItems: items,
    );
    final directory = await _directory();
    final temporary = File('${directory.path}/${capture.id}.json.tmp');
    await temporary.writeAsString(jsonEncode(updated.toJson()), flush: true);
    await temporary.rename('${directory.path}/${capture.id}.json');
    return updated;
  }
}
