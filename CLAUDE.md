# Absprachen mit Nikolaj für TRy Grid

- Antworten auf Deutsch, Anleitungen sehr einfach (Anfänger). Keine Gedankenstriche in sichtbaren Texten.
- Eigene App, keine Kopie von ULTRAGRID: eigener Name, eigenes Design. Stil minimalistisch, Schrift JetBrains Mono, dunkel, Orange #E8702A nur als Akzent.
- Flutter Projekt im Repo Wurzelverzeichnis. Vor dem Push `flutter analyze` ohne Fehler und im Browser in Handygröße testen.
- Die Webseite baut sich bei jedem Push auf `main` automatisch (GitHub Pages über Actions). Base href ist `/TRy-Grid/`.
- Vorschau und Export laufen über `paintCollage` in `lib/painter.dart`. Effekte immer relativ zur Leinwandbreite (unit = Breite / 400), damit Vorschau und Export gleich aussehen.
