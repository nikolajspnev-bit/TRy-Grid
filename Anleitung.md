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

1. Auf github.com/nikolajspnev-bit/TRy-Grid auf den grünen Knopf **Code > Download ZIP** tippen und die Datei entpacken (zum Beispiel in "Dokumente").
2. In VS Code: **Datei > Ordner öffnen** und den Ordner **TRy-Grid-main** wählen.
3. **Einmalig signieren:**
   Im Finder in **TRy-Grid-main/ios** die Datei **Runner.xcworkspace** doppelklicken. Xcode öffnet sich.
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

## Updates aufs iPhone holen

**Einmalig:** Im Terminal
```
cd ~/Documents
git clone https://github.com/nikolajspnev-bit/TRy-Grid.git
```
Dann in VS Code den Ordner **Dokumente/TRy-Grid** öffnen und einmal signieren (Teil 2, Schritt 3).

**Bei jedem Update** (und wenn die App nach 7 Tagen abläuft): iPhone per Kabel dran, dann
```
git pull
flutter run --release
```
Gespeicherte Collagen bleiben erhalten.

## Teil 3: Android App (gratis, ohne Android Studio)

GitHub baut die App nach jedem Update automatisch. Du musst nichts installieren.

1. Auf dem Android Handy diesen Link öffnen:
   https://github.com/nikolajspnev-bit/TRy-Grid/releases/latest/download/TRy-Grid.apk
2. Die Datei **TRy-Grid.apk** antippen.
3. Beim ersten Mal **Apps aus dieser Quelle installieren** erlauben.
4. Fertig. Den Link kannst du einfach an Freunde schicken.

**Einmalig wichtig:** Trag den App Schlüssel in GitHub ein (Datei **android_schluessel/GitHub_Secrets.md** in den Projektdateien, 4 Felder kopieren). Sonst müssen Freunde die App vor jedem Update löschen und verlieren dabei ihre gespeicherten Collagen.

## Teil 4: iPhone Freunde (TestFlight, 99 € im Jahr)

**Vorher:** Apple Developer Programm abschließen: developer.apple.com/programs (Freischaltung dauert oft 1 bis 2 Tage).

1. Auf **appstoreconnect.apple.com** > **Apps** > **+** > **Neue App**.
   Name: TRy Grid. Sprache: Deutsch. Bundle ID: **de.trymedia.tryCollage** auswählen (falls sie fehlt, erst auf developer.apple.com unter Identifiers anlegen). SKU: trygrid.
2. Am Mac den Ordner **TRy-Grid-main** in VS Code öffnen und im Terminal eintippen:
   ```
   flutter build ipa
   ```
3. Danach **ios/Runner.xcworkspace** in Xcode öffnen. Oben im Menü **Product > Archive**.
4. Im Fenster das kommt: **Distribute App** > **TestFlight & App Store** > **Distribute**. Warten (ca. 10 bis 30 Minuten, bis Apple den Build verarbeitet hat).
5. In App Store Connect bei deiner App auf **TestFlight**.
   Links bei **Externe Tests** eine Gruppe anlegen, den Build hinzufügen und **Öffentlichen Link** einschalten.
   Beim ersten Mal prüft Apple den Build kurz (meist unter einem Tag).
6. Den Link schickst du Freunden. Sie laden die App **TestFlight** und tippen auf den Link.

Ein Build läuft nach 90 Tagen ab. Für ein Update: in **pubspec.yaml** die Zahl hinter dem + erhöhen (zum Beispiel 1.0.0+2), dann Schritt 2 bis 5 wiederholen.

## So benutzt du die App

- **Leeres Feld antippen:** mehrere Fotos wählen, sie füllen ab diesem Feld auf.
- **Foto antippen:** zoomen und verschieben, ersetzen oder entfernen.
- **Foto gedrückt halten und ziehen:** mit einem anderen Feld tauschen.
- **Linien ziehen:** Felder größer oder kleiner machen. Sie rasten an Drittel, Hälfte und Slide Kanten ein.
- Oben links **Meine Collagen:** alles wird automatisch gespeichert. Antippen öffnet, Mülleimer löscht, **Neu** startet eine leere Collage.
- **Format:** Collage oder Karussell (mit Aufteilung Durchlaufend, Pro Slide, Brücke).
- **LOOK:** Film Farben, Blitz, Halation, Black Mist, Körnung, Vignette. Für alle Fotos oder einzeln.
- **Export:** 1080p oder 4K, beim Karussell auf Wunsch mit Gesamtbild.

## Wenn etwas nicht klappt

Mach ein Foto vom Fehler (oder kopiere den roten Text aus dem Terminal) und schick ihn mir.
