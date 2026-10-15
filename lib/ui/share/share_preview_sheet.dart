import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formatters.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import 'share_card.dart';

/// Preview-then-share. The card is rendered in the tree at full resolution and
/// scaled down with a FittedBox, so what the user approves is pixel-for-pixel
/// what gets exported — no second implementation to drift out of sync.
class SharePreviewSheet extends StatefulWidget {
  const SharePreviewSheet({required this.record, super.key});

  final RunRecord record;

  static Future<void> show(BuildContext context, RunRecord record) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (_) => SharePreviewSheet(record: record),
    );
  }

  @override
  State<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<SharePreviewSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _capture();
      final file = await _writePng(bytes);
      Haptics.success();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: file.uri.pathSegments.last)],
        subject: widget.record.title,
        text: _caption(),
        sharePositionOrigin: _originFor(context),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not export the image: $e');
      Haptics.error();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// iPad requires the share sheet to be anchored to a rect, or it throws.
  Rect? _originFor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String _caption() {
    final pace = Fmt.pace(widget.record.paceSecPerKm);
    final base = '${widget.record.distanceKm.toStringAsFixed(2)} km · '
        '${Fmt.clock(widget.record.elapsed)}';
    final pacePart = pace == null ? '' : ' · $pace /km';
    return '${widget.record.title} — $base$pacePart\nZero to 5K';
  }

  Future<Uint8List> _capture() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // pixelRatio 1 — the card is already laid out at 1080×1350.
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('PNG encode returned no data');
    return data.buffer.asUint8List();
  }

  Future<File> _writePng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final stamp = widget.record.startedAt.millisecondsSinceEpoch;
    final file = File('${dir.path}/run-$stamp.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = media.size.height * 0.62;

    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.emberHigh,
        borderRadius: M3EShape.sheet,
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + media.viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.ink.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('SHARE YOUR RUN', style: AppType.eyebrow(size: 14)),
              const Spacer(),
              Text('1080 × 1350', style: AppType.label(size: 11)),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: available,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                // The boundary wraps the *scaled* child, so capture() renders
                // at the child's own resolution only if we keep them separate.
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ShareCard(record: widget.record, width: 1080),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: AppType.label(size: 12, color: AppPalette.emberAccent),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _ShareButton(busy: _busy, onTap: _share),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PillTap(
      onTap: busy ? null : onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.emberSurface),
            )
          else
            const Icon(Icons.ios_share_rounded, size: 19, color: AppPalette.emberSurface),
          const SizedBox(width: 10),
          Text(
            busy ? 'EXPORTING' : 'SHARE',
            style: AppType.buttonLabel(size: 15).copyWith(color: AppPalette.emberSurface),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PillTap(
      onTap: onTap,
      child: Text(
        label.toUpperCase(),
        style: AppType.buttonLabel(size: 15).copyWith(color: AppPalette.ink.withValues(alpha: 0.85)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PillTap extends StatefulWidget {
  const _PillTap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PillTap> createState() => _PillTapState();
}

class _PillTapState extends State<_PillTap> with SingleTickerProviderStateMixin {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              Haptics.light();
              widget.onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(_down ? 0.965 : 1.0, _down ? 0.965 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.onTap == null ? AppPalette.ink.withValues(alpha: 0.08) : AppPalette.ink,
          borderRadius: M3EShape.full,
        ),
        child: widget.child,
      ),
    );
  }
}
