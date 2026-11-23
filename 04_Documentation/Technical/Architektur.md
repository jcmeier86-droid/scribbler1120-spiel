# Technischer Aufbau (Meilenstein 1)

- Godot 4.3, Renderer „Compatibility“ (läuft im Browser und auf Handys)
- `02_Game/Scenes/Main.tscn` + `Scripts/main.gd`: lädt einen Ortsteil aus `03_World/Geographic_Data/*.json`
- `terrain.gd`: Gelände (Talkessel-Schätzung) mit Kollision; `surface()` liefert die exakte Bodenhöhe
- `world_builder.gd`: Straßen, Bäche, Gebäude als 3D-Körper (Fassadenbild oder Fachwerk-Textur), Kirche als Basilika mit Turm, Plattformen, Stationen, Federn
- `player.gd`: Schreiberling – 360°-Bewegung relativ zur Kamera, Springen, Kamera mit SpringArm; lädt automatisch `schreiberling.glb`, sonst Platzhalter
- Shader: `ink_toon` (Farbstufen, Schraffur, Papierkorn), `ink_outline` (Tuschekontur), `paper` (Papier über dem Bild)
- Steuerung: WASD/Pfeile, Leertaste springen, Enter/F lesen, Q/E Kamera, rechte Maustaste drehen, Gamepad; Touch: linke Bildhälfte = Joystick, Knopf „Hopp!“
- Testhilfe: `godot --path . -- --at=kirche --yaw=180 --shot=bild.png`
