import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = dio.Dio(
          dio.BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ) {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final dio.Dio _dio;

  Future<List<ActivityEntry>> getRecentActivity({int limit = 10}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/activity/recent',
      queryParameters: {'limit': limit},
    );

    final data = res.data ?? {};
    final activities = (data['activities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return activities.map(ActivityEntry.fromJson).toList();
  }

  Future<UploadDocumentResult> uploadDocument({required dio.MultipartFile file}) async {
    final form = dio.FormData.fromMap({'file': file});
    final res = await _dio.post<Map<String, dynamic>>('/documents/upload', data: form);
    final data = res.data ?? {};
    return UploadDocumentResult.fromJson(data);
  }

  Future<List<DocumentEntry>> getDocuments() async {
    final res = await _dio.get<Map<String, dynamic>>('/documents');
    final data = res.data ?? {};
    final docs = (data['documents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return docs.map(DocumentEntry.fromJson).toList();
  }

  Future<SearchItemsResult> searchItems({required String query}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/search_items',
      data: <String, dynamic>{'query': query},
    );

    final data = res.data ?? {};
    final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final parsed = (data['parsed'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return SearchItemsResult(
      items: items.map(InventoryItem.fromJson).toList(),
      parsed: parsed,
    );
  }

  Future<InventoryItem> addItem({required AddItemRequest item}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/add_item',
      data: item.toJson(),
    );
    final data = res.data ?? {};
    final out = (data['item'] as Map<String, dynamic>? ?? {});
    return InventoryItem.fromJson(out);
  }

  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/update_item',
      data: request.toJson(),
    );
    final data = res.data ?? {};
    final out = (data['item'] as Map<String, dynamic>? ?? {});
    return InventoryItem.fromJson(out);
  }

  Future<bool> deleteItem({required String itemId}) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/delete_item',
      queryParameters: <String, dynamic>{'item_id': itemId},
    );
    final data = res.data ?? {};
    return (data['deleted'] == true);
  }

  Future<MultiExtractResult> extractInventoryFromImage({required dio.MultipartFile file}) async {
    final form = dio.FormData.fromMap({'file': file});
    final res = await _dio.post<Map<String, dynamic>>('/inventory/extract_from_image', data: form);
    final data = res.data ?? {};
    return MultiExtractResult.fromJson(data);
  }

  Future<BulkCreateResult> bulkCreateInventory({required List<ExtractedInventoryItem> items}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/inventory/bulk_create',
      data: <String, dynamic>{
        'items': items.map((i) => i.toJson()).toList(),
      },
    );
    final data = res.data ?? {};
    return BulkCreateResult.fromJson(data);
  }

  Future<AiCommandResult> aiCommand({required String message}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ai_command',
      data: <String, dynamic>{'message': message},
    );
    final data = res.data ?? {};
    return AiCommandResult.fromJson(data);
  }
}

class ActivityEntry {
  ActivityEntry({required this.activityId, required this.summary, required this.createdAt});

  final String activityId;
  final String summary;
  final DateTime createdAt;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      activityId: (json['activity_id'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class DocumentEntry {
  DocumentEntry({required this.documentId, required this.filename, required this.mimeType, required this.url, required this.createdAt});

  final String documentId;
  final String filename;
  final String? mimeType;
  final String? url;
  final DateTime createdAt;

  factory DocumentEntry.fromJson(Map<String, dynamic> json) {
    final storagePath = (json['storage_path'] ?? '').toString();
    final docId = (json['document_id'] ?? '').toString();
    return DocumentEntry(
      documentId: storagePath.isNotEmpty ? storagePath : docId,
      filename: (json['filename'] ?? '').toString(),
      mimeType: json['mime_type']?.toString(),
      url: json['url']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
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

class InventoryItem {
  InventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.createdAt,
    this.imageUrl,
    this.barcode,
    this.purchaseSource,
    this.notes,
    this.subcategory,
    this.brand,
    this.partNumber,
    this.tags,
    this.confidence,
  });

  final String itemId;
  final String name;
  final String category;
  final int quantity;
  final String location;
  final String? imageUrl;
  final String? barcode;
  final String? purchaseSource;
  final String? notes;
  final String? subcategory;
  final String? brand;
  final String? partNumber;
  final List<String>? tags;
  final double? confidence;
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
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
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
    };
  }
}

class MultiExtractSummary {
  MultiExtractSummary({required this.totalDetected, required this.categories});

  final int totalDetected;
  final Map<String, int> categories;

  factory MultiExtractSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['categories'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return MultiExtractSummary(
      totalDetected: (json['total_detected'] is num)
          ? (json['total_detected'] as num).toInt()
          : int.tryParse((json['total_detected'] ?? '0').toString()) ?? 0,
      categories: raw.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0)),
    );
  }
}

class MultiExtractResult {
  MultiExtractResult({required this.items, required this.summary});

  final List<ExtractedInventoryItem> items;
  final MultiExtractSummary summary;

  factory MultiExtractResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final summary = (json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{});
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
    final inserted = (json['inserted'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final failures = (json['failures'] as List<dynamic>? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    return BulkCreateResult(
      inserted: inserted.map(InventoryItem.fromJson).toList(),
      failures: failures,
    );
  }
}

class AiCommandResult {
  AiCommandResult({required this.tool, required this.result, required this.assistantMessage});

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
