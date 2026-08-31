import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class ItemEditorResult {
  const ItemEditorResult({
    required this.add,
    required this.update,
    required this.threshold,
  });

  final AddItemRequest add;
  final UpdateItemRequest update;
  final int? threshold;
}

class ItemEditorSheet extends StatefulWidget {
  const ItemEditorSheet({
    this.item,
    this.initialThreshold,
    this.initialLocation,
    this.availableLocations,
    super.key,
  });

  final InventoryItem? item;
  final int? initialThreshold;
  final String? initialLocation;
  final List<String>? availableLocations;

  @override
  State<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _category = TextEditingController(text: widget.item?.category ?? '');
    _location = TextEditingController(text: widget.item?.location ?? widget.initialLocation ?? '');
    _quantity = TextEditingController(
      text: (widget.item?.quantity ?? 1).toString(),
    );
    _threshold = TextEditingController(
      text: (widget.initialThreshold ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.20), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom + 24),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item == null ? 'Add item' : 'Edit item',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Name',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0xFF171717),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Category',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0xFF171717),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ['Electronics', 'Clothing', 'Hardware', 'Food', 'Tools', 'Other'].map((cat) {
              final isActive = _category.text == cat;
              return GestureDetector(
                onTap: () => setState(() => _category.text = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isActive ? Colors.white.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: const Color(0xFF7CA2E4).withValues(alpha: 0.30), blurRadius: 10)]
                        : [],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0x73FFFFFF),
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: (_) {
              if (_locationError != null) setState(() => _locationError = null);
            },
            decoration: InputDecoration(
              hintText: 'Location',
              hintStyle: const TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              errorText: _locationError,
              filled: true,
              fillColor: const Color(0xFF171717),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          if (widget.availableLocations != null && widget.availableLocations!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.availableLocations!.map((loc) => GestureDetector(
                    onTap: () => setState(() => _location.text = loc),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _location.text == loc
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _location.text == loc
                              ? Colors.white.withValues(alpha: 0.30)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: _location.text == loc
                            ? [BoxShadow(color: const Color(0xFF7CA2E4).withValues(alpha: 0.30), blurRadius: 10)]
                            : [],
                      ),
                      child: Text(
                        loc,
                        style: TextStyle(
                          color: _location.text == loc ? Colors.white : const Color(0x73FFFFFF),
                          fontSize: 12,
                          fontWeight: _location.text == loc ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Quantity',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0xFF171717),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7CA2E4).withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                // Resolve location
                String location = _location.text.trim();
                if (location.isEmpty) {
                  final def = (widget.initialLocation ?? '').trim();
                  if (def.isNotEmpty) {
                    location = def;
                  } else {
                    setState(() => _locationError = 'Please enter a location');
                    return;
                  }
                }

                final qty = int.tryParse(_quantity.text.trim()) ?? 0;
                final rawThreshold = int.tryParse(_threshold.text.trim());
                final threshold = (rawThreshold != null && rawThreshold > 0)
                    ? rawThreshold
                    : null;

                // For Add mode only: confirm if location is a new space
                if (widget.item == null) {
                  final existingLocations = widget.availableLocations ?? const [];
                  final matchesInitial = (widget.initialLocation ?? '').trim().toLowerCase() == location.toLowerCase();
                  final isNewSpace = !matchesInitial && !existingLocations.any(
                    (l) => l.toLowerCase() == location.toLowerCase(),
                  );
                  if (isNewSpace) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Create new space?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          '"$location" doesn\'t exist yet. Create it and add this item?',
                          style: const TextStyle(color: Color(0x99FFFFFF)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0x73FFFFFF)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Create Space',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                  }
                }

                if (!context.mounted) return;
                if (widget.item == null) {
                  Navigator.of(context).pop(
                    ItemEditorResult(
                      threshold: threshold,
                      add: AddItemRequest(
                        name: _name.text.trim(),
                        category: _category.text.trim().isEmpty ? 'Other' : _category.text.trim(),
                        quantity: qty,
                        location: location,
                      ),
                      update: UpdateItemRequest(itemId: ''),
                    ),
                  );
                } else {
                  Navigator.of(context).pop(
                    ItemEditorResult(
                      threshold: threshold,
                      add: AddItemRequest(
                        name: '',
                        category: '',
                        quantity: 0,
                        location: '',
                      ),
                      update: UpdateItemRequest(
                        itemId: widget.item!.itemId,
                        name: _name.text.trim(),
                        category: _category.text.trim().isEmpty ? 'Other' : _category.text.trim(),
                        quantity: qty,
                        location: location,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: const Color(0xFF7CA2E4).withValues(alpha: 0.60),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0x73FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
        ),
      ),
    );
  }
}
