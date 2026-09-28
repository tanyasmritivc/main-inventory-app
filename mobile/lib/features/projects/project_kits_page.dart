import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/world_views.dart';

class ProjectKitsPage extends StatefulWidget {
  const ProjectKitsPage({
    super.key,
    required this.api,
    this.location,
    this.shareId,
  });
  final ApiClient api;
  final String? location;
  final String? shareId;

  @override
  State<ProjectKitsPage> createState() => _ProjectKitsPageState();
}

class _ProjectKitsPageState extends State<ProjectKitsPage> {
  bool _loading = true;
  String? _error;
  List<ProjectKitSummary> _kits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kits = await widget.api.getProjectKits(
        location: widget.location,
        shareId: widget.shareId,
      );
      if (mounted) setState(() => _kits = kits);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Project Kit'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'Project name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('Choose BOM'),
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    var location = widget.location;
    if (location == null) {
      try {
        final spaces = await widget.api.listSpaces();
        if (!mounted) return;
        final choices = <String>[
          'Unsorted',
          for (final space in spaces)
            if ((space['name'] ?? '').toString().trim().isNotEmpty)
              space['name'].toString().trim(),
        ];
        location = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Where is this project?')),
                for (final choice in choices)
                  ListTile(
                    title: Text(choice),
                    onTap: () => Navigator.pop(context, choice),
                  ),
              ],
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
        return;
      }
    }
    if (location == null || !mounted) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final extension = (file.extension ?? file.name.split('.').last)
        .toLowerCase();
    if (!['xlsx', 'csv'].contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an Excel (.xlsx) or CSV file.')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final multipart = file.path != null
          ? await dio.MultipartFile.fromFile(file.path!, filename: file.name)
          : dio.MultipartFile.fromStream(
              () => file.readStream!,
              file.size,
              filename: file.name,
            );
      final kit = await widget.api.createProjectKit(
        file: multipart,
        name: name,
        location: location,
        shareId: widget.shareId,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectKitDetailPage(api: widget.api, initial: kit),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openKit(ProjectKitSummary kit) async {
    try {
      final detail = await widget.api.getProjectKit(kit.id);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProjectKitDetailPage(api: widget.api, initial: detail),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Projects',
              onBack: () => Navigator.pop(context),
              actions: [
                TextButton(
                  onPressed: _loading ? null : _create,
                  child: const Text('Add'),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load projects',
                        children: [
                          WorldRow(title: _error!, count: '', onTap: _load),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else if (_kits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No projects yet. Add a parts list to see what you have and what is missing.',
                          style: TextStyle(color: t.text2, fontSize: 15),
                        ),
                      )
                    else
                      WorldSection(
                        title: 'In this workspace',
                        children: [
                          for (final kit in _kits)
                            WorldRow(
                              title: kit.name,
                              subtitle: kit.location,
                              count: '',
                              onTap: () => _openKit(kit),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _loading ? null : _create,
                      child: const Text('Add a project'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectKitDetailPage extends StatefulWidget {
  const ProjectKitDetailPage({
    super.key,
    required this.api,
    required this.initial,
  });
  final ApiClient api;
  final ProjectKitDetail initial;
  @override
  State<ProjectKitDetailPage> createState() => _ProjectKitDetailPageState();
}

class _ProjectKitDetailPageState extends State<ProjectKitDetailPage> {
  late ProjectKitDetail _kit = widget.initial;
  bool _refreshing = false;
  bool _changingReservation = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final kit = await widget.api.getProjectKit(_kit.id);
      if (mounted) setState(() => _kit = kit);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _copyMissing() async {
    final text = _kit.items
        .where((i) => i.missingQuantity > 0)
        .map(
          (i) =>
              '${i.missingQuantity}× ${i.name}${i.partNumber == null ? '' : ' (${i.partNumber})'}',
        )
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing-parts list copied.')),
      );
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project kit?'),
        content: Text('Delete ${_kit.name}? Inventory will not be changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.api.deleteProjectKit(_kit.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _reserve() async {
    setState(() => _changingReservation = true);
    try {
      final kit = await widget.api.reserveProjectKit(_kit.id);
      if (mounted) setState(() => _kit = kit);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _changingReservation = false);
    }
  }

  Future<void> _release() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release reservations?'),
        content: const Text(
          'These parts will become available to other projects. Inventory quantities will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _changingReservation = true);
    try {
      final kit = await widget.api.releaseProjectKitReservations(_kit.id);
      if (mounted) setState(() => _kit = kit);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _changingReservation = false);
    }
  }

  Future<void> _actions() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_kit.items.any((item) => item.missingQuantity > 0))
              ListTile(
                title: const Text('Copy missing parts'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (_kit.canReserve)
              ListTile(
                title: const Text('Reserve available parts'),
                onTap: () => Navigator.pop(context, 'reserve'),
              ),
            if (_kit.canReserve &&
                _kit.items.any((item) => item.reservedQuantity > 0))
              ListTile(
                title: const Text('Release reservations'),
                onTap: () => Navigator.pop(context, 'release'),
              ),
            ListTile(
              title: const Text('Delete project'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (selected) {
      case 'copy':
        await _copyMissing();
      case 'reserve':
        await _reserve();
      case 'release':
        await _release();
      case 'delete':
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: _kit.name,
              onBack: () => Navigator.pop(context),
              actions: [
                TextButton(
                  onPressed: _changingReservation ? null : _actions,
                  child: const Text('Actions'),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (_refreshing)
                      const LinearProgressIndicator(minHeight: 2),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(AppTokens.radius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_kit.summary.readinessPercent}%',
                            style: TextStyle(
                              color: t.accent,
                              fontSize: 42,
                              fontFamily: 'IBMPlexMono',
                            ),
                          ),
                          Text(
                            'ready in ${_kit.location}',
                            style: TextStyle(color: t.text2, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value:
                                _kit.summary.readinessPercent.clamp(0, 100) /
                                100,
                            backgroundColor: t.s2,
                            color: t.accent,
                            minHeight: 4,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_kit.summary.readyLines} ready  ·  ${_kit.summary.partialLines} partial  ·  ${_kit.summary.missingLines} missing',
                            style: TextStyle(color: t.text2, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (!_kit.canReserve)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'An editor can change reservations.',
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_kit.items.isEmpty)
                      Text(
                        'This project has no parts yet.',
                        style: TextStyle(color: t.text2, fontSize: 15),
                      )
                    else
                      WorldSection(
                        title: 'Parts needed',
                        children: [
                          for (final item in _kit.items)
                            WorldRow(
                              title: item.partNumber ?? item.name,
                              subtitle:
                                  '${item.name}  ·  ${item.reservedQuantity} reserved  ·  ${item.unreservedAvailableQuantity} free',
                              count:
                                  '${item.availableQuantity}/${item.requiredQuantity}',
                              warning: item.missingQuantity > 0,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
