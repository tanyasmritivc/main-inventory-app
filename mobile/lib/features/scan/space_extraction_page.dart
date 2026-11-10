import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ask_answer.dart';
import '../chat/native_scan_progress.dart';
import '../chat/chat_capture_card.dart';
import '../chat/extraction_progress_panel.dart';
import '../chat/scan_region.dart';

/// The main FIND preview service and components, bound to the invoking Space.
class SpaceExtractionPage extends StatefulWidget {
  const SpaceExtractionPage({
    super.key,
    required this.api,
    required this.bytes,
    required this.spaceId,
    required this.spaceName,
  });
  final ApiClient api;
  final Uint8List bytes;
  final String spaceId, spaceName;
  @override
  State<SpaceExtractionPage> createState() => _SpaceExtractionPageState();
}

class _SpaceExtractionPageState extends State<SpaceExtractionPage> {
  late final ApiClient world;
  StreamIterator<AiStreamEvent>? stream;
  Map<String, dynamic>? draft;
  String? conversation, error;
  String progress = 'Reading your photo...';
  List<ScanRegion> regions = [];
  bool busy = true, saved = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    world = ApiClient.forWorld(
      widget.api,
      widget.api.inventoryContext!.organizationId ?? 'personal',
      isCurrent: () {
        widget.api.assertCurrentContext();
        return mounted;
      },
    );
    unawaited(scan());
  }

  @override
  void dispose() {
    generation++;
    unawaited(stream?.cancel());
    super.dispose();
  }

  Future<void> scan() async {
    final run = ++generation;
    setState(() {
      busy = true;
      error = null;
      regions = [];
    });
    final iterator = StreamIterator(
      world.aiPhotoQuestionStream(
        message: '',
        photo: AskPhoto(bytes: widget.bytes, autoExtract: true),
        previewOnly: true,
      ),
    );
    stream = iterator;
    try {
      Map<String, dynamic>? captured;
      var completed = false;
      while (await iterator.moveNext()) {
        if (!mounted || run != generation) return;
        final event = iterator.current;
        conversation = event.conversationId ?? conversation;
        if (event.type == 'status') {
          setState(() => progress = event.message ?? progress);
        }
        if (event.type == 'scan_regions') {
          setState(() => regions = applyScanRegions(regions, event.result));
        }
        captured = event.answerContext?.chatCapture ?? captured;
        if (event.type == 'done') {
          completed = true;
          break;
        }
      }
      if (!completed || captured == null || conversation == null) {
        throw const FormatException(
          'Could not finish scanning. Your photo is ready to retry.',
        );
      }
      final response = await world.collaboration(
        '/worlds/${world.worldKey}/conversations/$conversation/captures/${captured['id']}',
        method: 'PATCH',
        data: {
          'revision': captured['revision'],
          'changes': {
            'inventory_id': widget.api.inventoryContext!.inventoryId,
            'space_id': widget.spaceId,
          },
        },
      );
      final bound = Map<String, dynamic>.from(response['capture'] as Map);
      if (bound['inventory_id'] != widget.api.inventoryContext!.inventoryId ||
          bound['space_id'] != widget.spaceId) {
        throw const FormatException(
          'The Space destination could not be confirmed. Nothing was saved.',
        );
      }
      if (mounted && run == generation) setState(() => draft = bound);
    } catch (e) {
      if (mounted && run == generation) {
        setState(() => error = friendlyApiError(e));
      }
    } finally {
      unawaited(iterator.cancel());
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(saved);
    },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.spaceName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (draft != null && conversation != null)
              ChatCaptureCard(
                api: world,
                conversationId: conversation!,
                draft: draft!,
                photo: MemoryImage(widget.bytes),
                reviewHeader: ScanPhotoFrame(
                  image: MemoryImage(widget.bytes),
                  height: 180,
                  scanning: false,
                ),
                fixedInventoryId: widget.api.inventoryContext!.inventoryId,
                fixedSpaceId: widget.spaceId,
                onChanged: (value) => setState(() {
                  draft = value;
                  saved =
                      saved ||
                      ((value['receipt'] as Map?)?['saved_count'] as num? ??
                              0) >
                          0;
                }),
                onSaved: () {
                  saved = true;
                },
              )
            else if (busy && usesNativeScanProgress)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: NativeScanProgress(
                  image: MemoryImage(widget.bytes),
                  message: progress,
                  regions: regions,
                  onStop: () => Navigator.of(context).pop(saved),
                ),
              )
            else ...[
              ScanPhotoFrame(
                image: MemoryImage(widget.bytes),
                height: MediaQuery.sizeOf(context).height * .35,
                scanning: busy,
              ),
              if (busy)
                ExtractionProgressPanel(message: progress, regions: regions),
              if (error != null) ...[
                Text(error!, semanticsLabel: error),
                TextButton(onPressed: scan, child: const Text('Retry photo')),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pop(saved),
                child: Text(busy ? 'Stop extraction' : 'Close'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
