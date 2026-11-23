# Hinweise für Claude Code – Scribbler1120 Spiel

- Godot 4.7.2, Renderer „Compatibility“, GDScript. Spiel muss im Browser (Web-Export ohne Threads) und auf Handys laufen.
- Die Spielfigur heißt immer „der Schreiberling“.
- Bildstil: `00_Concept/Styleguide/masterprompt_spielwelt.md` – reale Gegenwart, gezeichnet im Scribbler1120-Stil; nichts künstlich historisieren.
- Farben: Türrot #7A2B30, Trachtblau #1A2E61, Vereinsgrün #2E6B3E, Tinte #1E1E1C, Grau #6B6A65, Linie #E7E5DF, Fläche #FAF9F6.
- Welt wird aus `03_World/Geographic_Data/<ortsteil>.json` gebaut (x Osten, z Süden, Meter). Neue Ortsteile über `03_World/tools/osm_to_json.py`.
- Keine Stockfotos (z. B. Alamy-Luftbilder) ins Repo – nur als Vorlage verwenden.
- Texte im Spiel auf Deutsch; Geschichtsangaben nur mit Quelle, Platzhalter als solche kennzeichnen.
- Jeder Push auf `main` baut automatisch die Web-Version und veröffentlicht sie über GitHub Pages.
- Testen lokal: `godot --headless --path . --quit-after 60` (Skriptfehler) und `godot --path . -- --at=kirche --shot=bild.png` (Bild).
