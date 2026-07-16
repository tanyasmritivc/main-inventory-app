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

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottom + 24,
      ),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Name',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Category',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
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
            children: ['Electronics', 'Clothing', 'Hardware', 'Food', 'Tools', 'Other'].map((cat) =>
              GestureDetector(
                onTap: () => setState(() => _category.text = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Text(cat, style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12)),
                ),
              )
            ).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Location',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
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
                            ? AppTheme.textPrimary(context)
                            : AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _location.text == loc
                              ? AppTheme.textPrimary(context)
                              : AppTheme.cardBorder(context),
                        ),
                      ),
                      child: Text(
                        loc,
                        style: TextStyle(
                          color: _location.text == loc ? AppTheme.bg(context) : AppTheme.textSecondary(context),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Quantity',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
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
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_quantity.text.trim()) ?? 0;
                final rawThreshold = int.tryParse(_threshold.text.trim());
                final threshold = (rawThreshold != null && rawThreshold > 0)
                    ? rawThreshold
                    : null;
                final location = _location.text.trim().isEmpty
                    ? 'Unsorted'
                    : _location.text.trim();
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
    );
  }
}
