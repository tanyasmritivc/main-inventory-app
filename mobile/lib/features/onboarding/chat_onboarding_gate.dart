import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/chat_source.dart';
import '../../core/last_place.dart';
import '../workspaces/inventory_context_host.dart';
import 'chat_onboarding_draft.dart';
import 'chat_onboarding_page.dart';
import 'chat_onboarding_save.dart';
import 'world_setup_gate.dart';

/// Permanent sessions bypass the introduction. Only an explicitly retained
/// trial can hold the authenticated handoff while its save is retried.
class ChatOnboardingGate extends StatefulWidget {
  const ChatOnboardingGate({super.key, required this.api});
  final ApiClient api;
  @override
  State<ChatOnboardingGate> createState() => _ChatOnboardingGateState();
}

class _ChatOnboardingGateState extends State<ChatOnboardingGate> {
  ChatOnboardingDraft? _draft;
  bool _loading = true;
  String? _error;
  bool _notified = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final draft = await ChatOnboardingStore.read();
      if (!mounted) return;
      final owner = widget.api.accountId;
      if (draft == null ||
          draft.option == 'snap' ||
          draft.method.isEmpty ||
          (draft.owner != null && draft.owner != owner)) {
        setState(() {
          _loading = false;
          _draft = null;
        });
        return;
      }
      _draft = draft;
      if ((draft.keep || draft.saving) && !draft.complete) {
        await ChatOnboardingSaver(widget.api).save(draft);
      }
      if (!mounted || widget.api.accountId != owner) return;
      if (draft.complete) {
        await LastPlaceStore(owner!).save(
          const LastPlace.personal(),
          isCurrent: () => widget.api.accountId == owner,
        );
        trialEvent('onboarding_completed', {
          'method': draft.method,
          'path': draft.option,
        });
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Your items are safe on this device. We could not finish saving them. Check your connection and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Retry save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final draft = _draft;
    if (draft == null) return WorldSetupGate(api: widget.api);
    if (!draft.complete) {
      return ChatOnboardingPage(
        api: widget.api,
        initialDraft: draft,
        onAuthenticatedKeep: _load,
      );
    }
    void acknowledge() {
      if (_notified || !mounted) return;
      _notified = true;
      unawaited(() async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draft.isSample
                  ? 'Snap a shelf to add your first items'
                  : 'Saved ${draft.items.length} items to ${draft.space}',
            ),
          ),
        );
        try {
          await ChatOnboardingStore.clear(draft.id);
        } catch (_) {
          /* A receipt reopens the destination; it never writes again. */
        }
      }());
    }

    return InventoryContextHost(
      api: widget.api,
      onInitialChatReady: acknowledge,
      initialChatSource: draft.isSample
          ? null
          : ChatSource(
              kind: 'space',
              name: draft.space,
              inventoryId: draft.inventoryId,
              resourceId: draft.spaceId,
            ),
    );
  }
}
