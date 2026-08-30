import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import 'import_sheet_page.dart';

class SharedSpreadsheetPage extends StatefulWidget {
  const SharedSpreadsheetPage({
    super.key,
    required this.api,
    required this.filePath,
  });

  final ApiClient api;
  final String filePath;

  @override
  State<SharedSpreadsheetPage> createState() => _SharedSpreadsheetPageState();
}

class _SharedSpreadsheetPageState extends State<SharedSpreadsheetPage> {
  late Future<List<String>> _spacesFuture;
  final _newSpaceController = TextEditingController();
  bool _creatingSpace = false;

  String get _filename => File(widget.filePath).uri.pathSegments.last;

  @override
  void initState() {
    super.initState();
    _spacesFuture = _loadSpaces();
  }

  @override
  void dispose() {
    _newSpaceController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadSpaces() async {
    final rows = await widget.api.listSpaces();
    final names =
        rows
            .map((row) => (row['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<void> _importInto(String location) async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImportSheetPage(
          api: widget.api,
          location: location,
          initialFilePath: widget.filePath,
          initialFilename: _filename,
        ),
      ),
    );
    if (!mounted || imported != true) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createSpace() async {
    final name = _newSpaceController.text.trim();
    if (name.isEmpty || _creatingSpace) return;
    setState(() => _creatingSpace = true);
    try {
      final created = await widget.api.createSpace(name: name);
      final location = (created['name'] ?? name).toString().trim();
      if (!mounted) return;
      Navigator.of(context).pop();
      await _importInto(location);
    } catch (error) {
      if (!mounted) return;
      final message = describeError(error).$1;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _creatingSpace = false);
    }
  }

  void _showCreateSpace() {
    _newSpaceController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create a Space',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newSpaceController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createSpace(),
              decoration: const InputDecoration(hintText: 'Space name'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _creatingSpace ? null : _createSpace,
              child: const Text('Create and Import'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F4F6),
      appBar: AppBar(title: const Text('Import to FindEZ')),
      body: SafeArea(
        child: FutureBuilder<List<String>>(
          future: _spacesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                message: describeError(snapshot.error!).$1,
                onRetry: () {
                  setState(() => _spacesFuture = _loadSpaces());
                },
              );
            }

            final spaces = snapshot.data ?? const <String>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Text(
                  _filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose where these items should be saved.',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 14),
                ),
                const SizedBox(height: 22),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  tileColor: const Color(0xFFFFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Create New Space'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showCreateSpace,
                ),
                if (spaces.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'EXISTING SPACES',
                    style: TextStyle(
                      color: Color(0xFF636366),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...spaces.map(
                    (space) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        tileColor: const Color(0xFF111111),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(space),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _importInto(space),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
