# Visualisierungs- & Art-Direction-Anweisung: Scribbler 1120 (Godot 4.7.2, Renderer Compatibility)

## 1. Visuelles Leitbild ("Living Sketchbook")
Übersetze die reale Architektur von Adorf (Diemelsee) in einen handgezeichneten Comic- und Tusche-Stil. Das Bild muss wirken wie eine kolorierte Federzeichnung auf leichtem Papier – ohne fotorealistische PBR-Texturen, Glanzlichter oder moderne Objekte.

### Verbindliche Farbpalette
- `TUERROT`: `#7A2B30` — Satteldächer, Holztüren, Fensterläden, Wappenschild-Grund
- `TRACHTBLAU`: `#1A2E61` — Langer Gehrock des Schreiberlings (visueller Hauptkontrast)
- `VEREINSGRUEN`: `#2E6B3E` — Ovale Raseninsel im Domänenhof, Wiesen, Laubkronen, Fortschrittsbalken
- `TINTE`: `#1E1E1C` — 3D-Outlines, Fachwerkbalken, Schraffuren, Schieferhelm-Akzente, UI-Rahmen
- `GRAU`: `#6B6A65` — Bruchsteinmauerwerk der Basilika St. Johannis, Schattenflächen
- `GRAU_HELL`: `#9A9992` — Kopfsteinpflaster, Freitreppe, Dorfbrunnen, Steinmauern
- `LINIE`: `#E7E5DF` — Pflastersteinfugen, Sekundärkonturen
- `FLAECHE`: `#FAF9F6` — Fachwerk-Putzfelder, Papier-Overlay, UI-Pergamentkarten

---

## 2. Shader-Pipeline (Zwingend umsetzen)

### A. `shaders/ink_toon.gdshader` (Toon-Lichtstufen & Schraffur-Schatten)
Jede 3D-Oberfläche verwendet dieses `ShaderMaterial` als Hauptmaterial:
- **Lichtmodell:** `render_mode diffuse_toon, specular_toon;` mit harter, klarer Licht-Schatten-Kante (`smoothstep` um `0.45` mit Breite `0.03`).
- **Schraffur-Schatten (Cross-Hatching):** In den Schattenbereichen (`NdotL * ATTENUATION < 0.45`) wird eine prozedurale oder gekachelte diagonale Tusche-Schraffur in `TINTE` (`#1E1E1C`) eingeblendet.
- **Oberfläche:** `ROUGHNESS = 0.95`, `SPECULAR = 0.05` (matte Papier-/Aquarell-Anmutung).

### B. `shaders/ink_outline.gdshader` (Inverted-Hull Tintenlinien)
Wird als `next_pass` auf jedes 3D-Material gelegt, um die charakteristischen schwarzen Federkonturen zu erzeugen:
- `render_mode cull_front, unshaded;`
- Extrudiert Vertices entlang der Normalen: `VERTEX += NORMAL * outline_width;` (Standardwert `0.02` bis `0.03`).
- `ALBEDO = vec3(0.118, 0.118, 0.110);` (`#1E1E1C` / `TINTE`).

### C. `shaders/paper_overlay.gdshader` (Screen-Space Papiergefühl)
Liegt als bildschirmfüllendes `ColorRect` (`mouse_filter = IGNORE`) auf einem `CanvasLayer` über der 3D-Szene:
- Mischt eine feine, statische Papierkörnung und den warmen Grundton `FLAECHE` (`#FAF9F6`) subtil über das gerenderte 3D-Bild (Blend-Stärke ca. `0.25–0.35`, Körnung `0.03–0.04`).

---

## 3. Lichtstimmung & Kamera-Inszenierung
- **Beleuchtung (`DirectionalLight3D` + `WorldEnvironment`):**
  - Warmes, leicht goldenes Nachmittagslicht im flachen Winkel (ca. `35°–45°` Elevation), damit Gebäude und Bäume markante, schraffierte Schatten über Hof und Platz werfen.
  - Kein dunkles Ambient-Light: Umgebungslicht hell und warm (`#FAF9F6` / `#E7E5DF`) halten, damit Schatten nie schwarz absaufen, sondern wie graue Tusche-Lavierung (`#6B6A65`) wirken.
  - Keinen realistischen Nebel, Bloom oder Lens-Flares aktivieren.
- **Kamera-Perspektive:**
  - Leicht erhöhte Diorama-/Third-Person-Perspektive (`FOV` ca. `40°–45°` für eine kompakte, illustrierte Raumwirkung).

---

## 4. Visuelle Ausgestaltung der Architektur & Props
- **Fachwerkhäuser (Hofdomäne & Dorf):**
  - Putzflächen in `FLAECHE` (`#FAF9F6`), klar gegliedert durch dunkle Fachwerkbalken in `TINTE` (`#1E1E1C`).
  - Steile Satteldächer in `TUERROT` (`#7A2B30`) mit angedeuteten Ziegelreihen-Linien.
  - Zweiläufige Freitreppe am Domänen-Haupthaus in `GRAU_HELL` (`#9A9992`) mit kleinem Vordach.
- **Basilika St. Johannis:**
  - Massiver quadratischer Westturm und dreischiffiges Langhaus aus Bruchstein in `GRAU` (`#6B6A65`) mit feinen Steinschraffuren und spitzem Schieferhelm in `TINTE` (`#1E1E1C`).
- **Boden & Vegetation:**
  - Hof- und Platzflächen in `GRAU_HELL` (`#9A9992`) mit unregelmäßigen Pflasterstein-Konturen in `TINTE` (`#1E1E1C`).
  - Ovale Raseninsel im Domänenhof und geschwungene Laubkronen der Bäume in `VEREINSGRUEN` (`#2E6B3E`) mit gezeichneten Blatt-Konturen.
  - Historische Requisiten im gleichen Tusche-Stil: Holzfässer, Stapelkisten, hölzerne Leiterwagen und der steinerne Dorfbrunnen.

---

## 5. Visuelles HUD- & UI-Design
- **Typografie:** `Fraunces` für Überschriften/Ortsnamen, `Inter` für Fließtexte.
- **Tintenfass-Anzeige (Unten links):** Gezeichnetes Tusche-Icon eines Tintenfasses mit Schreibfeder, direkt daneben ein schmaler Fortschrittsbalken in `VEREINSGRUEN` (`#2E6B3E`) mit `TINTE`-Rahmen (`#1E1E1C`).
- **Notizbuch-Karten (Pop-up):** Pergament-Panel in `FLAECHE` (`#FAF9F6`) mit doppelter `TINTE`-Kontur (`#1E1E1C`), verziert mit dem Wappenschild-Symbol (weiße Feder auf `TUERROT` `#7A2B30`).