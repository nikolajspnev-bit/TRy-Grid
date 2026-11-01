# TRy Grid: Anleitung

Eine App, ein Code, läuft auf iPhone und Android.

## Teil 1: Einmal am Mac einrichten (ca. 30 Minuten)

1. **Xcode** einmal öffnen und warten, bis es fertig installiert ist. Wenn es fragt, **iOS** mit anhaken.
2. **VS Code** laden und installieren: code.visualstudio.com
3. In VS Code links auf **Erweiterungen** klicken (Symbol mit den vier Kästchen), **Flutter** suchen, **Installieren**.
4. Tasten **Cmd + Shift + P** drücken, **Flutter: New Project** eintippen, Enter.
   Unten rechts kommt "Could not find a Flutter SDK". Auf **Download SDK** klicken und einen Ordner wählen (zum Beispiel deinen Benutzerordner). Warten.
   Danach auf **Add SDK to PATH** klicken. Das Fenster für ein neues Projekt kannst du mit Esc schließen.
5. VS Code einmal komplett beenden und neu öffnen.

## Teil 2: App aufs iPhone

1. Die Datei **TRyCollage.zip** laden und entpacken (zum Beispiel in "Dokumente").
2. In VS Code: **Datei > Ordner öffnen** und den Ordner **try_collage** wählen.
3. **Einmalig signieren:**
   Im Finder in **try_collage/ios** die Datei **Runner.xcworkspace** doppelklicken. Xcode öffnet sich.
   Links oben auf **Runner** klicken, dann oben den Reiter **Signing & Capabilities**.
   Bei **Team** auf **Add an Account** und mit deiner Apple ID anmelden. Danach bei Team deinen Namen wählen.
   Ist der Bundle Identifier rot, ändere ihn in etwas Eigenes, zum Beispiel `de.nikolajtry.collage`.
   Xcode wieder schließen.
4. iPhone per Kabel an den Mac, entsperren, **Vertrauen** tippen.
5. Auf dem iPhone: **Einstellungen > Datenschutz & Sicherheit > Entwicklermodus** einschalten. Das iPhone startet neu.
6. In VS Code oben im Menü **Terminal > Neues Terminal**. Unten eintippen:
   ```
   flutter run --release
   ```
   Enter drücken. Wenn er fragt, welches Gerät, die Zahl vor deinem iPhone eintippen. Das erste Mal dauert ein paar Minuten.
7. Beim ersten Mal sagt das iPhone "Nicht vertrauenswürdiger Entwickler":
   **Einstellungen > Allgemein > VPN & Geräteverwaltung**, deine Apple ID antippen, **Vertrauen**.
   Dann die App **TRy Grid** öffnen.

Mit kostenloser Apple ID läuft die App 7 Tage. Danach einfach Schritt 4 und 6 wiederholen.

## Teil 3: App an Android Freunde geben

1. **Android Studio** laden und installieren: developer.android.com/studio
   Einmal öffnen und den Einrichtungs Assistenten mit "Next" durchklicken. Danach kannst du es schließen.
2. In VS Code im Terminal eintippen:
   ```
   flutter doctor --android-licenses
   ```
   Jede Frage mit `y` und Enter bestätigen.
3. Dann:
   ```
   flutter build apk
   ```
4. Fertige Datei: **try_collage/build/app/outputs/flutter-apk/app-release.apk**
   Die schickst du deinem Freund, zum Beispiel per WhatsApp, Mail oder Google Drive.
   Er tippt die Datei an und erlaubt einmal "Apps aus dieser Quelle installieren".

Später im Play Store: einmalig 25 $ für ein Google Entwicklerkonto.

## Teil 4: App an iPhone Freunde geben (TestFlight)

Das geht nur mit dem **Apple Developer Programm (99 $ im Jahr)**: developer.apple.com/programs
Die Freischaltung dauert manchmal 1 bis 2 Tage. Sag Bescheid, sobald du drin bist, dann gehen wir TestFlight Schritt für Schritt zusammen durch. Deine Freunde laden dann nur die App "TestFlight" und tippen auf deinen Einladungslink.

## So benutzt du die App

- **Leeres Feld antippen:** Foto wählen. Oder unten bei **Fotos** mehrere auf einmal hinzufügen.
- **Foto antippen:** zoomen und verschieben, ersetzen oder entfernen.
- **Foto gedrückt halten und ziehen:** mit einem anderen Feld tauschen.
- Oben links **Format** wählen (9:16, 4:5, 1:1 und mehr).
- **Layout:** Raster (Felder und Spalten) oder Bento (feste Mischungen aus groß und klein).
- **Stil:** Rand, Ecken, Abstand, Hintergrundfarbe.
- Oben rechts **Exportieren:** Größe wählen, dann "In Fotos sichern" oder "Teilen".

## Wenn etwas nicht klappt

Mach ein Foto vom Fehler (oder kopiere den roten Text aus dem Terminal) und schick ihn mir.
