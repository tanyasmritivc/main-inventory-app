import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class ScanEvidencePanel extends StatelessWidget {
  const ScanEvidencePanel({
    super.key,
    required this.evidence,
    this.barcode,
    this.initiallyExpanded = false,
  });

  final ScanEvidence evidence;
  final String? barcode;
  final bool initiallyExpanded;

  String _percent(double? value) {
    if (value == null) return 'Not available';
    return '${(value.clamp(0, 1) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final hasMeasurements =
        evidence.lengthMm != null || evidence.widthMm != null;
    // ExpansionTile's ListTile paints its background and ink on Material.
    // Keep that surface inside the border instead of hiding it with a container.
    return Material(
      color: const Color(0xFF111214),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: evidence.needsReview
              ? const Color(0x55F5A623)
              : const Color(0x1430D158),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded || evidence.needsReview,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
        title: Text(
          evidence.needsReview ? 'Needs your review' : 'How this was read',
          style: TextStyle(
            color: evidence.needsReview
                ? const Color(0xFFF5A623)
                : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          evidence.needsReview
              ? 'Confirm the uncertain details before this becomes inventory.'
              : 'See the visible details used for this result.',
          style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
        ),
        children: [
          if (evidence.reviewReasons.isNotEmpty) ...[
            ...evidence.reviewReasons.map(
              (reason) => _EvidenceRow(
                icon: Icons.priority_high_rounded,
                label: 'Review',
                value: reason,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if ((evidence.identificationReasoning ?? '').isNotEmpty)
            _EvidenceRow(
              icon: Icons.visibility_outlined,
              label: 'Why this identification',
              value: evidence.identificationReasoning!,
            ),
          _EvidenceRow(
            icon: Icons.fact_check_outlined,
            label: 'Identification confidence',
            value: _percent(evidence.identityConfidence),
          ),
          _EvidenceRow(
            icon: Icons.center_focus_strong_outlined,
            label: 'Object detection confidence',
            value: _percent(evidence.detectionConfidence),
          ),
          if ((evidence.ocrText ?? '').isNotEmpty)
            _EvidenceRow(
              icon: Icons.text_fields_rounded,
              label: 'Visible text',
              value:
                  '${evidence.ocrText} · ${_percent(evidence.ocrConfidence)} confidence',
            ),
          if ((barcode ?? '').isNotEmpty ||
              (evidence.barcodeSymbology ?? '').isNotEmpty)
            _EvidenceRow(
              icon: Icons.qr_code_2_rounded,
              label: 'Barcode',
              value: [
                if ((barcode ?? '').isNotEmpty) barcode!,
                if ((evidence.barcodeSymbology ?? '').isNotEmpty)
                  evidence.barcodeSymbology!,
                if (evidence.barcodeConfidence != null)
                  '${_percent(evidence.barcodeConfidence)} confidence',
              ].join(' · '),
            ),
          if (hasMeasurements)
            _EvidenceRow(
              icon: Icons.straighten_rounded,
              label: 'Measured size',
              value: [
                '${evidence.lengthMm?.toStringAsFixed(1) ?? '—'} × ${evidence.widthMm?.toStringAsFixed(1) ?? '—'} mm',
                if ((evidence.measurementConfidence ?? '').isNotEmpty)
                  '${evidence.measurementConfidence} confidence',
                if ((evidence.measurementMethod ?? '').isNotEmpty)
                  evidence.measurementMethod!,
              ].join(' · '),
            ),
          if ((evidence.measurementAssumption ?? '').isNotEmpty)
            _EvidenceRow(
              icon: Icons.info_outline_rounded,
              label: 'Measurement note',
              value: evidence.measurementAssumption!,
            ),
          ...evidence.warnings.map(
            (warning) => _EvidenceRow(
              icon: Icons.warning_amber_rounded,
              label: 'Analysis note',
              value: warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0x99FFFFFF), size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
