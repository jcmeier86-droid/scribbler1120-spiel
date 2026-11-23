# Werkzeuge für die Spielwelt

## OpenStreetMap -> Ortsteil
1. Auf openstreetmap.org den Ortsteil heranzoomen, „Exportieren“ → Datei `map.osm`.
2. `python3 osm_to_json.py map.osm dorfmitte "Dorfmitte" --merge ../Geographic_Data/dorfmitte.json`
3. Spiel starten – Gebäude, Straßen und Bäche stehen an ihrer echten Stelle. Stationen und Startpunkt werden aus der alten Datei übernommen (Koordinaten ggf. nachziehen).

## Gezeichnete Fassaden
Bild aus der Bildwerkstatt (Masterprompt, gerade Fassadenansicht) als `03_World/Buildings/<gebaeude-id>/fassade.png` ablegen.
Das Spiel legt es automatisch auf die Wände dieses Gebäudes. Die Gebäude-IDs stehen in der Ortsteil-Datei.

## Höhen
Das Gelände wird derzeit aus den Tallinien (Rhene, Bicke) geschätzt. Nächster Schritt: echtes Höhenraster (z. B. Hessen DGM1 oder SRTM) einlesen.
