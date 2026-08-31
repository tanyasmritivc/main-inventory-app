import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please sign in again.';
}

class ApiClient {
  ApiClient({required String baseUrl})
    : _dio = dio.Dio(
        dio.BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      _teamId = null,
      _teamSpaceId = null {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  ApiClient.forTeamSpace(
    ApiClient source, {
    required String teamId,
    required String spaceId,
  }) : _dio = source._dio,
       _teamId = teamId,
       _teamSpaceId = spaceId;

  final dio.Dio _dio;
  final String? _teamId;
  final String? _teamSpaceId;

  String _requireToken() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) throw SessionExpiredException();
    return token;
  }

  dio.Options _authOptions({Map<String, dynamic>? extra}) {
    final token = _requireToken();
    return dio.Options(
      headers: <String, dynamic>{'Authorization': 'Bearer $token', ...?extra},
    );
  }

  dio.Options _longRunningOptions() {
    return dio.Options(
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(minutes: 2),
    );
  }

  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {
    await _dio.post<void>(
      '/push/devices',
      data: {'device_token': token, 'environment': environment},
    );
  }

  Future<void> sendTestPush() async => _dio.post<void>('/push/test');

  Future<List<ActivityEntry>> getRecentActivity({int limit = 10}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/activity/recent',
      queryParameters: {'limit': limit},
    );

    final data = res.data ?? {};
    final activities = (data['activities'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return activities.map(ActivityEntry.fromJson).toList();
  }

  Future<UploadDocumentResult> uploadDocument({
    required dio.MultipartFile file,
    String? itemId,
  }) async {
    final form = dio.FormData.fromMap({
      'file': file,
      if (itemId != null) 'item_id': itemId,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/documents/upload',
      data: form,
      options: _longRunningOptions(),
    );
    final data = res.data ?? {};
    developer.log('UPLOAD RESPONSE: ${jsonEncode(data)}');
    return UploadDocumentResult.fromJson(data);
  }

  Future<SpreadsheetImportResult> importSpreadsheet({
    required dio.MultipartFile file,
    required String location,
    String? shareId,
  }) async {
    final form = dio.FormData.fromMap({
      'file': file,
      'location': location,
      if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/import/spreadsheet',
      data: form,
      options: _longRunningOptions(),
    );
    return SpreadsheetImportResult.fromJson(res.data ?? const {});
  }

  Future<BomAnalysisResult> analyzeBom({
    required dio.MultipartFile file,
    required String location,
    String? shareId,
  }) async {
    final form = dio.FormData.fromMap({
      'file': file,
      'location': location,
      if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/inventory/bom/analyze',
      data: form,
      options: _longRunningOptions(),
    );
    return BomAnalysisResult.fromJson(res.data ?? const {});
  }

  Future<List<ProjectKitSummary>> getProjectKits({
    required String location,
    String? shareId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/project-kits',
      queryParameters: {
        'location': location,
        if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
      },
    );
    return ((res.data?['kits'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProjectKitSummary.fromJson)
        .toList();
  }

  Future<ProjectKitDetail> createProjectKit({
    required dio.MultipartFile file,
    required String name,
    required String location,
    String? shareId,
  }) async {
    final form = dio.FormData.fromMap({
      'file': file,
      'name': name,
      'location': location,
      if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/project-kits',
      data: form,
      options: _longRunningOptions(),
    );
    return ProjectKitDetail.fromJson(res.data ?? const {});
  }

  Future<ProjectKitDetail> getProjectKit(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/project-kits/$id');
    return ProjectKitDetail.fromJson(res.data ?? const {});
  }

  Future<ProjectKitDetail> reserveProjectKit(String id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/project-kits/$id/reserve',
    );
    return ProjectKitDetail.fromJson(res.data ?? const {});
  }

  Future<ProjectKitDetail> releaseProjectKitReservations(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/project-kits/$id/reservations',
    );
    return ProjectKitDetail.fromJson(res.data ?? const {});
  }

  Future<void> deleteProjectKit(String id) async =>
      _dio.delete<void>('/project-kits/$id');

  Future<List<DocumentEntry>> getDocuments({String? itemId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/documents',
      queryParameters: itemId != null ? {'item_id': itemId} : null,
    );
    final data = res.data ?? {};
    final docs = (data['documents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return docs.map(DocumentEntry.fromJson).toList();
  }

  Future<String> openDocumentUrl({required String storagePath}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/documents/open',
      queryParameters: <String, dynamic>{'storage_path': storagePath},
      options: _authOptions(),
    );
    final url = (res.data?['url'] ?? '').toString();
    if (url.isEmpty) throw StateError('Document URL missing');
    return url;
  }

  Future<void> renameDocument({
    required String storagePath,
    required String displayName,
  }) async {
    await _dio.patch<void>(
      '/documents/rename',
      data: <String, dynamic>{
        'storage_path': storagePath,
        'display_name': displayName,
      },
      options: _authOptions(),
    );
  }

  Future<void> linkDocument({
    required String storagePath,
    String? itemId,
  }) async {
    await _dio.patch<void>(
      '/documents/link',
      data: <String, dynamic>{'storage_path': storagePath, 'item_id': itemId},
      options: _authOptions(),
    );
  }

  Future<void> deleteDocument({required String storagePath}) async {
    await _dio.delete<void>(
      '/documents',
      queryParameters: <String, dynamic>{'storage_path': storagePath},
      options: _authOptions(),
    );
  }

  Future<BarcodeLookupResult> barcodeLookup({required String barcode}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/barcode_lookup',
      data: <String, dynamic>{'barcode': barcode},
    );
    final data = res.data ?? {};
    return BarcodeLookupResult.fromJson(data);
  }

  Future<SearchItemsResult> searchItems({required String query}) async {
    if (_teamId != null && _teamSpaceId != null) {
      final data = await getTeamSpaceItems(_teamId, _teamSpaceId);
      var items = List<Map<String, dynamic>>.from(
        data['items'] ?? const [],
      ).map(InventoryItem.fromJson).toList();
      final normalized = query.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        items = items.where((item) {
          return item.name.toLowerCase().contains(normalized) ||
              item.category.toLowerCase().contains(normalized) ||
              (item.partNumber ?? '').toLowerCase().contains(normalized);
        }).toList();
      }
      return SearchItemsResult(items: items, parsed: const {});
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/search_items',
      data: <String, dynamic>{'query': query},
      options: _authOptions(),
    );

    final data = res.data ?? {};
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final parsed =
        (data['parsed'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return SearchItemsResult(
      items: items.map(InventoryItem.fromJson).toList(),
      parsed: parsed,
    );
  }

  Future<InventoryItem> addItem({required AddItemRequest item}) async {
    if (_teamId != null && _teamSpaceId != null) {
      return addTeamSpaceItem(_teamId, _teamSpaceId, item);
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/add_item',
      data: item.toJson(),
      options: _authOptions(),
    );
    final data = res.data ?? {};
    final out = (data['item'] as Map<String, dynamic>? ?? {});
    return InventoryItem.fromJson(out);
  }

  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    if (_teamId != null && _teamSpaceId != null) {
      return updateTeamSpaceItem(_teamId, _teamSpaceId, request);
    }
    final res = await _dio.patch<Map<String, dynamic>>(
      '/update_item',
      data: request.toJson(),
      options: _authOptions(),
    );
    final data = res.data ?? {};
    final out = (data['item'] as Map<String, dynamic>? ?? {});
    return InventoryItem.fromJson(out);
  }

  Future<bool> deleteItem({required String itemId}) async {
    if (_teamId != null && _teamSpaceId != null) {
      await deleteTeamSpaceItem(_teamId, _teamSpaceId, itemId);
      return true;
    }
    final res = await _dio.delete<Map<String, dynamic>>(
      '/delete_item',
      queryParameters: <String, dynamic>{'item_id': itemId},
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['deleted'] == true);
  }

  List<int> _resizeAndCompressJpeg(List<int> bytes) {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return bytes;

      final resized = decoded.width > 1280
          ? img.copyResize(decoded, width: 1280)
          : decoded;
      return img.encodeJpg(resized, quality: 80);
    } catch (_) {
      return bytes;
    }
  }

  Future<MultiExtractResult> extractInventoryFromImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final outBytes = _resizeAndCompressJpeg(bytes);
    final outName =
        filename.toLowerCase().endsWith('.jpg') ||
            filename.toLowerCase().endsWith('.jpeg')
        ? filename
        : '${filename.split('.').first}.jpg';
    final file = dio.MultipartFile.fromBytes(outBytes, filename: outName);
    final form = dio.FormData.fromMap({'file': file});
    debugPrint(
      'FINDEZ api: POST ${_dio.options.baseUrl}/inventory/extract_from_image',
    );
    final res = await _dio.post<Map<String, dynamic>>(
      '/inventory/extract_from_image',
      data: form,
      options: _longRunningOptions(),
    );
    final data = res.data ?? {};
    return MultiExtractResult.fromJson(data);
  }

  Future<BulkCreateResult> bulkCreateInventory({
    required List<ExtractedInventoryItem> items,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/inventory/bulk_create',
      data: <String, dynamic>{'items': items.map((i) => i.toJson()).toList()},
    );
    final data = res.data ?? {};
    return BulkCreateResult.fromJson(data);
  }

  Future<VerifiedCatalogPart> getVerifiedCatalogPart(String catalogId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/inventory/catalog/$catalogId',
      options: _authOptions(),
    );
    return VerifiedCatalogPart.fromJson(res.data ?? const {});
  }

  Future<CatalogCompatibilityResult> getCompatibleCatalogParts(
    String catalogId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/inventory/catalog/$catalogId/compatible',
      options: _authOptions(),
    );
    return CatalogCompatibilityResult.fromJson(res.data ?? const {});
  }

  Future<AiCommandResult> aiCommand({required String message}) async {
    // No artificial delay.
    final res = await _dio.post<Map<String, dynamic>>(
      '/ai_command',
      data: {'message': message},
      options: _longRunningOptions(),
    );

    final data = res.data ?? {};
    return AiCommandResult.fromJson(data);
  }

  Future<Map<String, dynamic>> createShare({
    required String shareName,
    required String permission,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/sharing/create',
      data: {'share_name': shareName, 'permission': permission},
      options: _authOptions(),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyShares() async {
    final resp = await _dio.get<List<dynamic>>(
      '/sharing/my-shares',
      options: _authOptions(),
    );
    return resp.data as List<dynamic>;
  }

  Future<void> deleteShare(String shareId) async {
    await _dio.delete<void>('/sharing/$shareId', options: _authOptions());
  }

  Future<void> leaveShare({required String shareId}) async {
    await _dio.delete<Map<String, dynamic>>(
      '/sharing/$shareId/leave',
      options: _authOptions(),
    );
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/profile/me',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<void> updateProfile({
    String? displayName,
    String? contactEmail,
    String? avatarColor,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (contactEmail != null) data['contact_email'] = contactEmail;
    if (avatarColor != null) data['avatar_color'] = avatarColor;
    await _dio.patch<Map<String, dynamic>>(
      '/profile/update',
      data: data,
      options: _authOptions(),
    );
  }

  Future<List<Map<String, dynamic>>> getShareMembers({
    required String shareId,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/sharing/$shareId/members',
      options: _authOptions(),
    );
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<dynamic>> getJoinedShares() async {
    final resp = await _dio.get<List<dynamic>>(
      '/sharing/joined',
      options: _authOptions(),
    );
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getShareInventory(String shareId) async {
    final resp = await _dio.get<List<dynamic>>(
      '/sharing/$shareId/inventory',
      options: _authOptions(),
    );
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> joinShare(String code) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/sharing/join',
      data: {'share_code': code.toUpperCase()},
      options: _authOptions(),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<List<ConversationSummary>> listConversations() async {
    final res = await _dio.get<List<dynamic>>(
      '/conversations',
      options: _authOptions(),
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  }

  Future<ConversationDetail> getConversation(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/conversations/$id',
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return ConversationDetail(
      conversation: ConversationSummary.fromJson(
        (data['conversation'] as Map<String, dynamic>? ?? {}),
      ),
      messages: ((data['messages'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(ConversationMessage.fromJson)
          .toList(),
    );
  }

  Future<void> deleteConversation(String id) async {
    await _dio.delete<void>('/conversations/$id', options: _authOptions());
  }

  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
  }) async* {
    final baseUrl = _dio.options.baseUrl.endsWith('/')
        ? _dio.options.baseUrl.substring(0, _dio.options.baseUrl.length - 1)
        : _dio.options.baseUrl;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Not authenticated');

    final uri = Uri.parse('$baseUrl/ai_command?stream=true');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Authorization'] = 'Bearer $token';
    request.body = json.encode(<String, dynamic>{
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });

    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }

      var partialLine = '';
      await for (final bytes in response.stream) {
        final chunk = utf8.decode(bytes);
        partialLine += chunk;
        final lines = partialLine.split('\n');
        partialLine = lines.removeLast();
        for (final line in lines) {
          final l = line.trimRight();
          if (l.isEmpty || !l.startsWith('data:')) continue;
          final jsonStr = l.substring(5).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final decoded = json.decode(jsonStr);
            if (decoded is! Map) continue;
            yield AiStreamEvent.fromJson(decoded.cast<String, dynamic>());
          } catch (_) {}
        }
      }
      // Flush any remaining partial line
      final l = partialLine.trimRight();
      if (l.startsWith('data:')) {
        final jsonStr = l.substring(5).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final decoded = json.decode(jsonStr);
            if (decoded is Map) {
              yield AiStreamEvent.fromJson(decoded.cast<String, dynamic>());
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> getMyLimits() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/limits',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> joinTeam(String code) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/join',
      data: {'code': code.toUpperCase()},
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> listTeams() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams',
      options: _authOptions(),
    );
    return List<Map<String, dynamic>>.from(res.data?['teams'] ?? const []);
  }

  Future<Map<String, dynamic>> createTeam({
    required String name,
    required String program,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams',
      data: {'name': name, 'program': program, 'rookie': false},
      options: _authOptions(),
    );
    return Map<String, dynamic>.from(res.data?['team'] ?? const {});
  }

  Future<Map<String, dynamic>> getTeamBoard(String teamId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/board',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> getTeamWorkspace(String teamId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/workspace',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> getTeamSpaces(String teamId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/spaces',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> createTeamSpace(
    String teamId,
    String name,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/$teamId/spaces',
      data: {'name': name},
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> attachTeamSpace(
    String teamId,
    String spaceId,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/$teamId/spaces/attach',
      data: {'space_id': spaceId},
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<void> detachTeamSpace(String teamId, String spaceId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/teams/$teamId/spaces/$spaceId',
      options: _authOptions(),
    );
  }

  Future<Map<String, dynamic>> getTeamSpaceItems(
    String teamId,
    String spaceId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/spaces/$spaceId/items',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<InventoryItem> addTeamSpaceItem(
    String teamId,
    String spaceId,
    AddItemRequest item,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/$teamId/spaces/$spaceId/items',
      data: item.toJson(),
      options: _authOptions(),
    );
    return InventoryItem.fromJson(res.data?['item'] ?? {});
  }

  Future<InventoryItem> updateTeamSpaceItem(
    String teamId,
    String spaceId,
    UpdateItemRequest request,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/teams/$teamId/spaces/$spaceId/items/${request.itemId}',
      data: request.toJson(),
      options: _authOptions(),
    );
    return InventoryItem.fromJson(res.data?['item'] ?? {});
  }

  Future<void> deleteTeamSpaceItem(
    String teamId,
    String spaceId,
    String itemId,
  ) async {
    await _dio.delete<Map<String, dynamic>>(
      '/teams/$teamId/spaces/$spaceId/items/$itemId',
      options: _authOptions(),
    );
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/members',
      options: _authOptions(),
    );
    return List<Map<String, dynamic>>.from(res.data?['members'] ?? const []);
  }

  Future<void> updateTeamMemberRole(
    String teamId,
    String userId,
    String role,
  ) async {
    await _dio.patch<Map<String, dynamic>>(
      '/teams/$teamId/members/$userId',
      data: {'role': role},
      options: _authOptions(),
    );
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/teams/$teamId/members/$userId',
      options: _authOptions(),
    );
  }

  Future<String> rotateTeamJoinCode(String teamId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/$teamId/join-code/rotate',
      options: _authOptions(),
    );
    return res.data?['join_code']?.toString() ?? '';
  }

  Future<void> deleteTeam(String teamId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/teams/$teamId',
      options: _authOptions(),
    );
  }

  Future<void> leaveTeam(String teamId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/teams/$teamId/leave',
      options: _authOptions(),
    );
  }

  Future<List<Map<String, dynamic>>> getTeamActivity(String teamId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/teams/$teamId/activity',
      options: _authOptions(),
    );
    return List<Map<String, dynamic>>.from(res.data?['activity'] ?? const []);
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<void> markNotificationsRead() async {
    await _dio.post<Map<String, dynamic>>(
      '/notifications/read',
      options: _authOptions(),
    );
  }

  Future<Map<String, dynamic>> createTeamBoardTask(
    String teamId, {
    required String title,
    String description = '',
    String taskType = 'task',
    String priority = 'normal',
    String? assignedTo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams/$teamId/board',
      data: {
        'title': title,
        'description': description,
        'task_type': taskType,
        'priority': priority,
        if (assignedTo != null) 'assigned_to': assignedTo,
      },
      options: _authOptions(),
    );
    return Map<String, dynamic>.from(res.data?['task'] ?? const {});
  }

  Future<Map<String, dynamic>> updateTeamBoardTask(
    String teamId,
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/teams/$teamId/board/$taskId',
      data: updates,
      options: _authOptions(),
    );
    return Map<String, dynamic>.from(res.data?['task'] ?? const {});
  }

  Future<void> deleteTeamBoardTask(String teamId, String taskId) async {
    await _dio.delete<void>(
      '/teams/$teamId/board/$taskId',
      options: _authOptions(),
    );
  }

  // POST /checkouts/checkout
  Future<Map<String, dynamic>> checkoutItem({
    required String itemId,
    required String checkedOutBy,
    String? spaceName,
    String? dueBackAt,
    String? notes,
    int? checkoutQuantity,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/checkouts/checkout',
      data: {
        'item_id': itemId,
        'checked_out_by': checkedOutBy,
        if (spaceName != null) 'space_name': spaceName,
        if (dueBackAt != null) 'due_back_at': dueBackAt,
        if (notes != null) 'notes': notes,
        if (checkoutQuantity != null) 'checkout_quantity': checkoutQuantity,
      },
      options: _authOptions(),
    );
    return res.data ?? {};
  }

  Future<void> returnItem({required String checkoutId}) async {
    await _dio.post<Map<String, dynamic>>(
      '/checkouts/return',
      data: {'checkout_id': checkoutId},
      options: _authOptions(),
    );
  }

  Future<List<Map<String, dynamic>>> getActiveCheckouts() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/checkouts/active',
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['checkouts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getItemCheckouts({
    required String itemId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/checkouts/item/$itemId',
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['checkouts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> removeMember({
    required String shareId,
    required String memberId,
  }) async {
    await _dio.delete<void>(
      '/sharing/$shareId/members/$memberId',
      options: _authOptions(),
    );
  }

  Future<List<Map<String, dynamic>>> getShareCheckouts({
    required String shareId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/checkouts/active',
      queryParameters: {'share_id': shareId},
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['checkouts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<SpaceCheckoutsResult> getSpaceCheckouts({
    required String shareId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/checkouts/space',
      queryParameters: {'share_id': shareId},
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return SpaceCheckoutsResult(
      active: (data['active'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      returned: (data['returned'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<List<ActivityEntry>> getShareActivity({
    required String location,
    int limit = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/activity/recent',
      queryParameters: {'location': location, 'limit': limit},
    );
    final data = res.data ?? {};
    final activities = (data['activities'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return activities.map(ActivityEntry.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> listSpaces() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/spaces',
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['spaces'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSpace({required String name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/spaces',
      data: <String, dynamic>{'name': name},
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['space'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> renameSpace({
    required String spaceId,
    required String name,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/spaces/$spaceId',
      data: <String, dynamic>{'name': name},
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return (data['space'] as Map<String, dynamic>? ?? {});
  }

  Future<bool> deleteSpace({required String spaceId}) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/spaces/$spaceId',
      options: _authOptions(),
    );
    final data = res.data ?? {};
    return data['deleted'] == true;
  }
}

class AiStreamEvent {
  AiStreamEvent({
    required this.type,
    this.message,
    this.delta,
    this.tool,
    this.result,
    this.assistantMessage,
    this.conversationId,
  });

  final String type;
  final String? message;
  final String? delta;
  final String? tool;
  final Object? result;
  final String? assistantMessage;
  final String? conversationId;

  factory AiStreamEvent.fromJson(Map<String, dynamic> json) {
    return AiStreamEvent(
      type: (json['type'] ?? '').toString(),
      message: json['message']?.toString(),
      delta: json['delta']?.toString(),
      tool: json['tool']?.toString(),
      result: json['result'],
      assistantMessage: json['assistant_message']?.toString(),
      conversationId: json['conversation_id']?.toString(),
    );
  }
}

class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final DateTime createdAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ConversationMessage {
  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: (json['id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ConversationDetail {
  ConversationDetail({required this.conversation, required this.messages});

  final ConversationSummary conversation;
  final List<ConversationMessage> messages;
}

class ActivityEntry {
  ActivityEntry({
    required this.activityId,
    required this.summary,
    required this.createdAt,
  });

  final String activityId;
  final String summary;
  final DateTime createdAt;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      activityId: (json['activity_id'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class DocumentEntry {
  DocumentEntry({
    required this.documentId,
    required this.filename,
    required this.displayName,
    required this.mimeType,
    required this.url,
    required this.createdAt,
  });

  final String documentId;
  final String filename;
  final String? displayName;
  final String? mimeType;
  final String? url;
  final DateTime createdAt;

  factory DocumentEntry.fromJson(Map<String, dynamic> json) {
    final storagePath = (json['storage_path'] ?? '').toString();
    final docId = (json['document_id'] ?? '').toString();
    return DocumentEntry(
      documentId: storagePath.isNotEmpty ? storagePath : docId,
      filename: (json['filename'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString().trim().isEmpty
          ? null
          : json['display_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      url: json['url']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class SpreadsheetImportResult {
  SpreadsheetImportResult({
    required this.inserted,
    required this.failures,
    required this.totalFound,
  });

  final int inserted;
  final int failures;
  final int totalFound;

  factory SpreadsheetImportResult.fromJson(Map<String, dynamic> json) {
    int count(String key) {
      final value = json[key];
      return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    }

    return SpreadsheetImportResult(
      inserted: count('inserted'),
      failures: count('failures'),
      totalFound: count('total_found'),
    );
  }
}

class BomAnalysisResult {
  BomAnalysisResult({
    required this.location,
    required this.summary,
    required this.items,
  });
  final String location;
  final BomAnalysisSummary summary;
  final List<BomAnalysisItem> items;

  factory BomAnalysisResult.fromJson(Map<String, dynamic> json) =>
      BomAnalysisResult(
        location: (json['location'] ?? '').toString(),
        summary: BomAnalysisSummary.fromJson(
          (json['summary'] as Map<String, dynamic>?) ?? const {},
        ),
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BomAnalysisItem.fromJson)
            .toList(),
      );
}

class BomAnalysisSummary {
  BomAnalysisSummary({
    required this.totalLines,
    required this.readyLines,
    required this.partialLines,
    required this.missingLines,
    required this.readinessPercent,
  });
  final int totalLines,
      readyLines,
      partialLines,
      missingLines,
      readinessPercent;

  factory BomAnalysisSummary.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return BomAnalysisSummary(
      totalLines: number('total_lines'),
      readyLines: number('ready_lines'),
      partialLines: number('partial_lines'),
      missingLines: number('missing_lines'),
      readinessPercent: number('readiness_percent'),
    );
  }
}

class BomAnalysisItem {
  BomAnalysisItem({
    required this.name,
    required this.partNumber,
    required this.brand,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.missingQuantity,
    required this.reservedQuantity,
    required this.unreservedAvailableQuantity,
    required this.status,
  });
  final String name, status;
  final String? partNumber, brand;
  final int requiredQuantity,
      availableQuantity,
      missingQuantity,
      reservedQuantity,
      unreservedAvailableQuantity;

  factory BomAnalysisItem.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    String? optional(String key) {
      final value = (json[key] ?? '').toString().trim();
      return value.isEmpty ? null : value;
    }

    return BomAnalysisItem(
      name: (json['name'] ?? 'Unnamed item').toString(),
      partNumber: optional('part_number'),
      brand: optional('brand'),
      requiredQuantity: number('required_quantity'),
      availableQuantity: number('available_quantity'),
      missingQuantity: number('missing_quantity'),
      reservedQuantity: number('reserved_quantity'),
      unreservedAvailableQuantity: number('unreserved_available_quantity'),
      status: (json['status'] ?? 'missing').toString(),
    );
  }
}

class ProjectKitSummary {
  ProjectKitSummary({
    required this.id,
    required this.name,
    required this.location,
    required this.updatedAt,
  });
  final String id, name, location;
  final DateTime updatedAt;
  factory ProjectKitSummary.fromJson(Map<String, dynamic> json) =>
      ProjectKitSummary(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Untitled Project').toString(),
        location: (json['location'] ?? '').toString(),
        updatedAt:
            DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class ProjectKitDetail extends ProjectKitSummary {
  ProjectKitDetail({
    required super.id,
    required super.name,
    required super.location,
    required super.updatedAt,
    required this.summary,
    required this.items,
    required this.canReserve,
  });
  final BomAnalysisSummary summary;
  final List<BomAnalysisItem> items;
  final bool canReserve;
  factory ProjectKitDetail.fromJson(Map<String, dynamic> json) {
    final base = ProjectKitSummary.fromJson(json);
    return ProjectKitDetail(
      id: base.id,
      name: base.name,
      location: base.location,
      updatedAt: base.updatedAt,
      summary: BomAnalysisSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      canReserve: json['can_reserve'] != false,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BomAnalysisItem.fromJson)
          .toList(),
    );
  }
}

class UploadDocumentResult {
  UploadDocumentResult({required this.filename, required this.activitySummary});

  final String filename;
  final String activitySummary;

  factory UploadDocumentResult.fromJson(Map<String, dynamic> json) {
    final doc = (json['document'] as Map<String, dynamic>? ?? {});
    return UploadDocumentResult(
      filename: (doc['filename'] ?? '').toString(),
      activitySummary: (json['activity_summary'] ?? '').toString(),
    );
  }
}

class BarcodeLookupResult {
  BarcodeLookupResult({
    this.name,
    this.brand,
    this.model,
    this.category,
    this.imageUrl,
    this.foundInInventory = false,
    this.existingItem,
  });

  final String? name;
  final String? brand;
  final String? model;
  final String? category;
  final String? imageUrl;
  final bool foundInInventory;
  final Map<String, dynamic>? existingItem;

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      name: json['name']?.toString(),
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      category: json['category']?.toString(),
      imageUrl: json['image_url']?.toString(),
      foundInInventory: json['found_in_inventory'] == true,
      existingItem: json['existing_item'] as Map<String, dynamic>?,
    );
  }
}

class InventoryItem {
  InventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.createdAt,
    this.spaceId,
    this.imageUrl,
    this.barcode,
    this.purchaseSource,
    this.notes,
    this.subcategory,
    this.brand,
    this.partNumber,
    this.tags,
    this.confidence,
    this.catalogId,
  });

  final String itemId;
  final String name;
  final String category;
  final int quantity;
  final String location;
  final String? spaceId;
  final String? imageUrl;
  final String? barcode;
  final String? purchaseSource;
  final String? notes;
  final String? subcategory;
  final String? brand;
  final String? partNumber;
  final List<String>? tags;
  final double? confidence;
  final String? catalogId;
  final DateTime createdAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: (json['item_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : int.tryParse((json['quantity'] ?? '0').toString()) ?? 0,
      location: (json['location'] ?? '').toString(),
      spaceId: json['space_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      barcode: json['barcode']?.toString(),
      purchaseSource: json['purchase_source']?.toString(),
      notes: json['notes']?.toString(),
      subcategory: json['subcategory']?.toString(),
      brand: json['brand']?.toString(),
      partNumber: json['part_number']?.toString(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : double.tryParse((json['confidence'] ?? '').toString()),
      catalogId: json['catalog_id']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class AddItemRequest {
  AddItemRequest({
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    this.imageUrl,
    this.barcode,
    this.purchaseSource,
    this.notes,
  });

  final String name;
  final String category;
  final int quantity;
  final String location;
  final String? imageUrl;
  final String? barcode;
  final String? purchaseSource;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'quantity': quantity,
      'location': location,
      if (imageUrl != null) 'image_url': imageUrl,
      if (barcode != null) 'barcode': barcode,
      if (purchaseSource != null) 'purchase_source': purchaseSource,
      if (notes != null) 'notes': notes,
    };
  }
}

class UpdateItemRequest {
  UpdateItemRequest({
    required this.itemId,
    this.name,
    this.category,
    this.quantity,
    this.location,
    this.imageUrl,
    this.barcode,
    this.purchaseSource,
    this.notes,
  });

  final String itemId;
  final String? name;
  final String? category;
  final int? quantity;
  final String? location;
  final String? imageUrl;
  final String? barcode;
  final String? purchaseSource;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item_id': itemId,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (quantity != null) 'quantity': quantity,
      if (location != null) 'location': location,
      if (imageUrl != null) 'image_url': imageUrl,
      if (barcode != null) 'barcode': barcode,
      if (purchaseSource != null) 'purchase_source': purchaseSource,
      if (notes != null) 'notes': notes,
    };
  }
}

class SearchItemsResult {
  SearchItemsResult({required this.items, required this.parsed});

  final List<InventoryItem> items;
  final Map<String, dynamic> parsed;
}

class ExtractedInventoryItem {
  ExtractedInventoryItem({
    required this.name,
    required this.category,
    required this.quantity,
    this.subcategory,
    this.brand,
    this.partNumber,
    this.barcode,
    this.tags,
    this.confidence,
    this.notes,
    this.location,
    this.catalogMatch,
  });

  String name;
  String category;
  int quantity;
  String? subcategory;
  String? brand;
  String? partNumber;
  String? barcode;
  List<String>? tags;
  double? confidence;
  String? notes;
  String? location;
  VerifiedCatalogMatch? catalogMatch;

  factory ExtractedInventoryItem.fromJson(Map<String, dynamic> json) {
    return ExtractedInventoryItem(
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      subcategory: json['subcategory']?.toString(),
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : int.tryParse((json['quantity'] ?? '1').toString()) ?? 1,
      brand: json['brand']?.toString(),
      partNumber: json['part_number']?.toString(),
      barcode: json['barcode']?.toString(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : double.tryParse((json['confidence'] ?? '').toString()),
      notes: json['notes']?.toString(),
      location: json['location']?.toString(),
      catalogMatch: json['catalog_match'] is Map<String, dynamic>
          ? VerifiedCatalogMatch.fromJson(
              json['catalog_match'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'quantity': quantity,
      if (subcategory != null) 'subcategory': subcategory,
      if (brand != null) 'brand': brand,
      if (partNumber != null) 'part_number': partNumber,
      if (barcode != null) 'barcode': barcode,
      if (tags != null) 'tags': tags,
      if (confidence != null) 'confidence': confidence,
      if (notes != null) 'notes': notes,
      if (location != null) 'location': location,
      if (catalogMatch != null)
        'catalog_match': {
          'catalog_id': catalogMatch!.catalogId,
          'verified': catalogMatch!.verified,
        },
    };
  }
}

class VerifiedCatalogMatch {
  const VerifiedCatalogMatch({
    required this.catalogId,
    required this.verified,
    required this.source,
    this.productUrl,
    this.specifications = const {},
    this.compatibility = const {},
  });

  final bool verified;
  final String catalogId;
  final String source;
  final String? productUrl;
  final Map<String, dynamic> specifications;
  final Map<String, dynamic> compatibility;

  factory VerifiedCatalogMatch.fromJson(Map<String, dynamic> json) {
    return VerifiedCatalogMatch(
      catalogId: (json['catalog_id'] ?? '').toString(),
      verified: json['verified'] == true,
      source: (json['source'] ?? '').toString(),
      productUrl: json['product_url']?.toString(),
      specifications: json['specifications'] is Map
          ? Map<String, dynamic>.from(json['specifications'] as Map)
          : const {},
      compatibility: json['compatibility'] is Map
          ? Map<String, dynamic>.from(json['compatibility'] as Map)
          : const {},
    );
  }
}

class VerifiedCatalogPart {
  const VerifiedCatalogPart({
    required this.catalogId,
    required this.name,
    required this.brand,
    required this.partNumber,
    required this.specifications,
    required this.compatibility,
    this.description,
    this.productUrl,
  });

  final String catalogId;
  final String name;
  final String brand;
  final String partNumber;
  final String? description;
  final String? productUrl;
  final Map<String, dynamic> specifications;
  final Map<String, dynamic> compatibility;

  factory VerifiedCatalogPart.fromJson(Map<String, dynamic> json) {
    return VerifiedCatalogPart(
      catalogId: (json['catalog_id'] ?? '').toString(),
      name: (json['canonical_name'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      partNumber: (json['part_number'] ?? '').toString(),
      description: json['description']?.toString(),
      productUrl: json['product_url']?.toString(),
      specifications: json['specifications'] is Map
          ? Map<String, dynamic>.from(json['specifications'] as Map)
          : const {},
      compatibility: json['compatibility'] is Map
          ? Map<String, dynamic>.from(json['compatibility'] as Map)
          : const {},
    );
  }
}

class CompatibleCatalogPart {
  const CompatibleCatalogPart({
    required this.catalogId,
    required this.name,
    required this.brand,
    required this.partNumber,
    required this.sharedInterfaces,
    this.productUrl,
  });

  final String catalogId;
  final String name;
  final String brand;
  final String partNumber;
  final String? productUrl;
  final List<String> sharedInterfaces;

  factory CompatibleCatalogPart.fromJson(Map<String, dynamic> json) {
    return CompatibleCatalogPart(
      catalogId: (json['catalog_id'] ?? '').toString(),
      name: (json['canonical_name'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      partNumber: (json['part_number'] ?? '').toString(),
      productUrl: json['product_url']?.toString(),
      sharedInterfaces:
          (json['shared_interfaces'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
    );
  }
}

class CatalogCompatibilityResult {
  const CatalogCompatibilityResult({
    required this.interfaces,
    required this.matches,
  });

  final List<String> interfaces;
  final List<CompatibleCatalogPart> matches;

  factory CatalogCompatibilityResult.fromJson(Map<String, dynamic> json) {
    return CatalogCompatibilityResult(
      interfaces: (json['interfaces'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      matches: (json['matches'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompatibleCatalogPart.fromJson)
          .toList(),
    );
  }
}

class MultiExtractSummary {
  MultiExtractSummary({required this.totalDetected, required this.categories});

  final int totalDetected;
  final Map<String, int> categories;

  factory MultiExtractSummary.fromJson(Map<String, dynamic> json) {
    final raw =
        (json['categories'] as Map<String, dynamic>? ??
        const <String, dynamic>{});
    return MultiExtractSummary(
      totalDetected: (json['total_detected'] is num)
          ? (json['total_detected'] as num).toInt()
          : int.tryParse((json['total_detected'] ?? '0').toString()) ?? 0,
      categories: raw.map(
        (k, v) => MapEntry(
          k,
          (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0,
        ),
      ),
    );
  }
}

class MultiExtractResult {
  MultiExtractResult({required this.items, required this.summary});

  final List<ExtractedInventoryItem> items;
  final MultiExtractSummary summary;

  factory MultiExtractResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final summary =
        (json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return MultiExtractResult(
      items: items.map(ExtractedInventoryItem.fromJson).toList(),
      summary: MultiExtractSummary.fromJson(summary),
    );
  }
}

class BulkCreateResult {
  BulkCreateResult({required this.inserted, required this.failures});

  final List<InventoryItem> inserted;
  final List<Map<String, dynamic>> failures;

  factory BulkCreateResult.fromJson(Map<String, dynamic> json) {
    final inserted = (json['inserted'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final failures = (json['failures'] as List<dynamic>? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return BulkCreateResult(
      inserted: inserted.map(InventoryItem.fromJson).toList(),
      failures: failures,
    );
  }
}

class SpaceCheckoutsResult {
  SpaceCheckoutsResult({required this.active, required this.returned});
  final List<Map<String, dynamic>> active;
  final List<Map<String, dynamic>> returned;
}

class AiCommandResult {
  AiCommandResult({
    required this.tool,
    required this.result,
    required this.assistantMessage,
  });

  final String? tool;
  final Map<String, dynamic>? result;
  final String assistantMessage;

  factory AiCommandResult.fromJson(Map<String, dynamic> json) {
    return AiCommandResult(
      tool: json['tool']?.toString(),
      result: (json['result'] as Map?)?.cast<String, dynamic>(),
      assistantMessage: (json['assistant_message'] ?? '').toString(),
    );
  }
}
