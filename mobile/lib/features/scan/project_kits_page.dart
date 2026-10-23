import '../../core/app_theme.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/ui/glass_fab.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';
import 'package:mobile/core/ui/app_text.dart';

class ProjectKitsPage extends StatefulWidget {
  const ProjectKitsPage({
    super.key,
    required this.api,
    required this.location,
    this.shareId,
  });
  final ApiClient api;
  final String location;
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
          title: const AppText('New Project Kit'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'Competition Robot',
            ),
            style: AppTypography.bodyStyleOf(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const AppText('Choose BOM'),
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
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
          const SnackBar(
            content: AppText('Choose an Excel (.xlsx) or CSV file.'),
          ),
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
        location: widget.location,
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
        ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.adaptive(context, Colors.black),
    appBar: AppBar(
      title: const AppText('Project Kits'),
      centerTitle: true,
      backgroundColor: AppTheme.adaptive(context, Colors.black),
    ),
    floatingActionButton: GlassFab(
      onPressed: _loading ? null : _create,
      icon: Icons.add_rounded,
      label: 'New Project',
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                const SizedBox(height: 180),
                Center(
                  child: AppText(
                    _error!,
                    style: TextStyle(
                      color: AppTheme.foreground(context, AppColors.danger),
                    ),
                  ),
                ),
              ],
            )
          : _kits.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 160),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppTheme.foreground(context, Colors.white38),
                ),
                SizedBox(height: 18),
                Center(
                  child: AppText(
                    'No project kits yet',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: AppText(
                    'Create one from a BOM to track readiness over time.',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white54),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _kits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final kit = _kits[index];
                return Card(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.adaptive(
                        context,
                        Color(0xFF123B63),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: AppTheme.foreground(context, Color(0xFF6997DD)),
                      ),
                    ),
                    title: AppText(
                      kit.name,
                      style: TextStyle(
                        color: AppTheme.foreground(context, Colors.white),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      kit.location,
                      style: TextStyle(
                        color: AppTheme.foreground(context, Colors.white54),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.foreground(context, Colors.white38),
                    ),
                    onTap: () async {
                      try {
                        final detail = await widget.api.getProjectKit(kit.id);
                        if (!mounted) return;
                        await Navigator.push<void>(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) => ProjectKitDetailPage(
                              api: widget.api,
                              initial: detail,
                            ),
                          ),
                        );
                        await _load();
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: AppText(describeError(error).$1)),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
    ),
  );
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
        const SnackBar(content: AppText('Missing-parts list copied.')),
      );
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete project kit?'),
        content: AppText('Delete ${_kit.name}? Inventory will not be changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await widget.api.deleteProjectKit(_kit.id);
    if (mounted) Navigator.pop(context);
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
        ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _changingReservation = false);
    }
  }

  Future<void> _release() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Release reservations?'),
        content: const AppText(
          'These parts will become available to other projects. Inventory quantities will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Release'),
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
        ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _changingReservation = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.adaptive(context, Colors.black),
    appBar: AppBar(
      title: AppText(_kit.name),
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      actions: [
        IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppTheme.adaptive(context, const Color(0xFF171717)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AppText(
                    '${_kit.summary.readinessPercent}%',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  AppText(
                    'ready in ${_kit.location}',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: _kit.summary.readinessPercent / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: AppTheme.adaptive(context, Colors.white12),
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    '${_kit.summary.readyLines} ready · ${_kit.summary.partialLines} partial · ${_kit.summary.missingLines} missing',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: AppText(_refreshing ? 'Refreshing…' : 'Refresh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _kit.items.any((i) => i.missingQuantity > 0)
                      ? _copyMissing
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const AppText('Copy Missing'),
                ),
              ),
            ],
          ),
          if (_kit.canReserve) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _changingReservation ? null : _reserve,
                    icon: const Icon(Icons.lock_outline),
                    label: AppText(
                      _changingReservation ? 'Updating…' : 'Reserve Available',
                    ),
                  ),
                ),
                if (_kit.items.any((item) => item.reservedQuantity > 0)) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _changingReservation ? null : _release,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const AppText('Release'),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            AppText(
              'View only · An editor can change reservations',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white54),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ..._kit.items.map((item) {
            final ready = item.status == 'ready';
            final color = ready
                ? AppTheme.adaptive(context, AppColors.success)
                : item.status == 'partial'
                ? AppTheme.adaptive(context, AppColors.warning)
                : AppTheme.adaptive(context, AppColors.danger);
            final identity = item.partNumber != null
                ? item.name
                : (item.brand ?? '');
            final reservation =
                '${item.reservedQuantity} reserved · ${item.unreservedAvailableQuantity} free';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.reservedQuantity >= item.requiredQuantity
                    ? Icons.lock
                    : (ready ? Icons.check_circle : Icons.cancel),
                color: color,
              ),
              title: AppText(
                item.partNumber ?? item.name,
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                ),
              ),
              subtitle: AppText(
                '$identity${identity.isEmpty ? '' : '\n'}$reservation',
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white54),
                ),
              ),
              isThreeLine: identity.isNotEmpty,
              trailing: AppText(
                '${item.availableQuantity}/${item.requiredQuantity}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            );
          }),
        ],
      ),
    ),
  );
}
