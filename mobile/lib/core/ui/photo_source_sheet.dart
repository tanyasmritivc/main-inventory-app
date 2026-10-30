import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'liquid_surface.dart';

Future<bool?> showPhotoSourceSheet(
  BuildContext context,
) => showModalBottomSheet<bool>(
  context: context,
  backgroundColor: Colors.transparent,
  showDragHandle: false,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: LiquidSurface(
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(CupertinoIcons.camera),
                title: const Text('Take photo'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onTap: () => Navigator.pop(context, true),
              ),
              const Divider(height: 1, indent: 54, endIndent: 16),
              ListTile(
                leading: const Icon(CupertinoIcons.photo_on_rectangle),
                title: const Text('Choose photo'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onTap: () => Navigator.pop(context, false),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
