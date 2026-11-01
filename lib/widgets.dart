import 'package:flutter/material.dart';

import 'theme.dart';

const _label = TextStyle(fontSize: 13, color: AppColors.text);
const _value = TextStyle(
  fontSize: 13,
  color: AppColors.muted,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Regler in einer Zeile: Name, Wert, Regler.
class RowSlider extends StatelessWidget {
  const RowSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.divisions,
    this.onStart,
    this.display,
  });

  final String label;
  final double value, min, max;
  final int? divisions;
  final VoidCallback? onStart;
  final ValueChanged<double>? onChanged;
  final String? display;

  @override
  Widget build(BuildContext context) {
    final changed = value != min;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: _label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChangeStart: onStart == null ? null : (_) => onStart!(),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              display ?? '${value.round()}',
              textAlign: TextAlign.right,
              style: _value.copyWith(color: changed ? AppColors.accent : AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Regler mit Name und Wert darüber (für zwei Regler nebeneinander).
class StackSlider extends StatelessWidget {
  const StackSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onStart,
  });

  final String label;
  final int value, min, max;
  final VoidCallback? onStart;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Text(label, style: _label),
              const Spacer(),
              Text('$value', style: _value.copyWith(color: AppColors.accent)),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChangeStart: onStart == null ? null : (_) => onStart!(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

/// Zwei oder mehr Modi als Text mit feinem Strich unter dem aktiven.
class ModeTabs extends StatelessWidget {
  const ModeTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String, IconData)> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: i == selected ? AppColors.accent : AppColors.line,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      options[i].$2,
                      size: 15,
                      color: i == selected ? AppColors.accent : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      options[i].$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: i == selected ? AppColors.text : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Auswahl aus wenigen Optionen in Kästchen.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null ? null : () => onChanged!(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? AppColors.panel : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: i == selected ? AppColors.accent : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        options[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: i == selected
                              ? AppColors.text
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Schlichte Aktionszeile: Text links, Symbol rechts.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppColors.muted
        : (accent ? AppColors.accent : AppColors.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: color)),
                const Spacer(),
                Icon(icon, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
