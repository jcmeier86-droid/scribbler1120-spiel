# Spielfigur: der Schreiberling

- `Reference/charakterbogen.png` – verbindliche Vorlage (Scribbler1120)
- `Reference/rueckansicht_freigestellt.png` – Platzhalter im Spiel, bis das 3D-Modell fertig ist

## Weg zum 3D-Modell (Meilenstein 2)
1. Aus dem Charakterbogen per KI ein erstes Modell erzeugen (z. B. Meshy oder Tripo, Eingabe: Vorder-, Seiten- und Rückansicht).
2. In Mixamo hochladen, automatisch riggen, Animationen „Idle“, „Walk“, „Jump“ hinzufügen.
3. In Blender nacharbeiten (Proportionen, Farben Trachtblau #1A2E61, Türrot #7A2B30), als GLB exportieren:
   `Export/schreiberling.glb` – Animationen genau „Idle“, „Walk“, „Jump“ benennen.
4. Das Spiel erkennt die Datei automatisch und ersetzt den Platzhalter. Der Tusche-Shader sorgt für Konturen.
