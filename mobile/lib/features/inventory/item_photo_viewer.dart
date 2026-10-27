import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/private_image.dart';

/// Uses the same authenticated photo source as the item gallery, at full size.
class ItemPhotoViewer extends StatefulWidget {
  const ItemPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<ItemPhoto> photos;
  final int initialIndex;

  @override
  State<ItemPhotoViewer> createState() => _ItemPhotoViewerState();
}

class _ItemPhotoViewerState extends State<ItemPhotoViewer> {
  final _transform = TransformationController();
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _select(int index) {
    _transform.value = Matrix4.identity();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text('Photo ${_index + 1} of ${widget.photos.length}'),
      actions: [
        IconButton(
          tooltip: 'Close photo',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              key: const ValueKey('full-item-photo'),
              transformationController: _transform,
              minScale: 1,
              maxScale: 8,
              child: SizedBox.expand(
                child: PrivateImage(
                  widget.photos[_index].imageUrl,
                  key: ValueKey(widget.photos[_index].photoId),
                  fit: BoxFit.contain,
                  semanticLabel: 'Item photo ${_index + 1}',
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Photo unavailable. Close and try again.'),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.photos.length > 1)
                  IconButton(
                    tooltip: 'Previous photo',
                    onPressed: _index > 0 ? () => _select(_index - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                TextButton(
                  onPressed: () => _transform.value = Matrix4.identity(),
                  child: const Text('Reset zoom'),
                ),
                if (widget.photos.length > 1)
                  IconButton(
                    tooltip: 'Next photo',
                    onPressed: _index < widget.photos.length - 1
                        ? () => _select(_index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
