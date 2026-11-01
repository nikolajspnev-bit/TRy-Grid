import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Farbwähler: Feld für Sättigung und Helligkeit, Regenbogen für den Farbton
/// und ein HEX Feld. Gibt die gewählte Farbe zurück oder null bei Abbrechen.
Future<Color?> showColorPicker(BuildContext context, Color initial) {
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (_) => _ColorPicker(initial: initial),
  );
}

String colorToHex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return '#${[ch(c.r), ch(c.g), ch(c.b)].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
}

Color? hexToColor(String text) {
  var t = text.trim().replaceAll('#', '');
  if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _ColorPicker extends StatefulWidget {
  const _ColorPicker({required this.initial});
  final Color initial;

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController hex = TextEditingController(text: colorToHex(widget.initial));

  Color get color => hsv.toColor();

  void _set(HSVColor v) {
    setState(() => hsv = v);
    hex.text = colorToHex(v.toColor());
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Hintergrund', style: TextStyle(fontSize: 14)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 22)),
              ],
            ),
            const SizedBox(height: 8),
            // Sättigung (links nach rechts) und Helligkeit (oben nach unten).
            AspectRatio(
              aspectRatio: 1.6,
              child: LayoutBuilder(builder: (context, c) {
                void pick(Offset p) => _set(hsv
                    .withSaturation((p.dx / c.maxWidth).clamp(0.0, 1.0))
                    .withValue(1 - (p.dy / c.maxHeight).clamp(0.0, 1.0)));
                return GestureDetector(
                  onPanDown: (e) => pick(e.localPosition),
                  onPanUpdate: (e) => pick(e.localPosition),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor()],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: hsv.saturation * c.maxWidth - 10,
                          top: (1 - hsv.value) * c.maxHeight - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Farbton als Regenbogen.
            SizedBox(
              height: 28,
              child: LayoutBuilder(builder: (context, c) {
                void pick(Offset p) => _set(hsv.withHue((p.dx / c.maxWidth).clamp(0.0, 1.0) * 359.9));
                return GestureDetector(
                  onPanDown: (e) => pick(e.localPosition),
                  onPanUpdate: (e) => pick(e.localPosition),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: hsv.hue / 360 * c.maxWidth - 7,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 28,
                          decoration: BoxDecoration(
                            color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: hex,
                    cursorColor: AppColors.accent,
                    style: const TextStyle(fontSize: 14),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'HEX',
                      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (t) {
                      final c = hexToColor(t);
                      if (c != null) setState(() => hsv = HSVColor.fromColor(c));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, color),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text('Fertig', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
