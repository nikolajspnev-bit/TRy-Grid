# TRy Grid

Collage App von TRy-Media für Story, Feed und mehr. Ein Code für Webseite, iPhone und Android (Flutter).

**Webseite:** https://nikolajspnev-bit.github.io/TRy-Grid/
Jede Änderung auf `main` baut die Webseite automatisch neu (GitHub Actions, Datei `.github/workflows/webseite.yml`).

**Aufs Handy als App:** siehe [Anleitung.md](Anleitung.md).

## Funktionen
- Formate 9:16, 4:5, 3:4, 2:3, 1:1, 1.91:1, 16:9
- Raster (bis 12 Felder, 5 Spalten) und Bento (per "Mischen" neu angeordnet)
- Trennlinien ziehen, Nachbarfelder passen sich an, Pixelgröße wird angezeigt
- Rand, Ecken, Abstand, Hintergrund
- FX: Halation, Black Mist, Körnung, "Halten: Original"
- Foto antippen: zoomen, verschieben, ersetzen. Halten und ziehen: tauschen
- Export als PNG in 1080p oder 4K

## Aufbau
- `lib/models.dart` Formate, Layouts, Trennlinien
- `lib/painter.dart` Zeichnen der Collage und Film Look (Vorschau und Export nutzen denselben Code)
- `lib/editor.dart` Hauptbildschirm
- `lib/crop.dart` Zuschneiden, `lib/export.dart` Export, `lib/widgets.dart` Bedienelemente, `lib/theme.dart` Farben und Schrift

Schrift: JetBrains Mono (OFL, siehe `assets/fonts/OFL.txt`).
