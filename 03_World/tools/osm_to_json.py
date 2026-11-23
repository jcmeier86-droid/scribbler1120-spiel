#!/usr/bin/env python3
"""OpenStreetMap-Export (.osm) -> Ortsteil-Datei für das Spiel (03_World/Geographic_Data/<name>.json)

Aufruf:
  python3 osm_to_json.py map.osm dorfmitte "Dorfmitte" [--center LAT LON] [--merge alte_datei.json]

- Gebäude: alle Wege mit building=* (Grundriss in Metern, Höhe aus height / building:levels, sonst Schätzung)
- Straßen: highway=* mit Name und Breite nach Straßentyp
- Bäche: waterway=stream/river
- Mit --merge werden Stationen, Plattformen, Startpunkt und Tallinien aus einer bestehenden Datei übernommen.
Koordinaten: x nach Osten, z nach Süden, Ursprung = center (Standard: Mitte der Daten).
Kartendaten © OpenStreetMap-Mitwirkende (ODbL) – Quellenangabe im Spiel anzeigen.
"""
import json, math, sys, xml.etree.ElementTree as ET

WIDTH = {"primary": 7.5, "secondary": 7, "tertiary": 6.5, "unclassified": 5.5, "residential": 5.5,
         "living_street": 4.5, "service": 3.5, "track": 3, "footway": 2, "path": 1.5, "pedestrian": 4}
ROOFS = ["#C8643C", "#B9572F", "#D47546", "#A94F2E", "#C96A40"]

def main():
    a = sys.argv[1:]
    if len(a) < 3:
        print(__doc__); sys.exit(1)
    src, area, name = a[0], a[1], a[2]
    center = None; merge = None
    if "--center" in a:
        i = a.index("--center"); center = (float(a[i + 1]), float(a[i + 2]))
    if "--merge" in a:
        merge = json.load(open(a[a.index("--merge") + 1], encoding="utf-8"))
    root = ET.parse(src).getroot()
    nodes = {n.get("id"): (float(n.get("lat")), float(n.get("lon"))) for n in root.iter("node")}
    if center is None:
        lats = [v[0] for v in nodes.values()]; lons = [v[1] for v in nodes.values()]
        center = ((min(lats) + max(lats)) / 2, (min(lons) + max(lons)) / 2)
    kx = 111320 * math.cos(math.radians(center[0])); kz = 110540
    to_xz = lambda lat, lon: [round((lon - center[1]) * kx, 2), round(-(lat - center[0]) * kz, 2)]
    buildings, roads, water = [], [], []
    for w in root.iter("way"):
        tags = {t.get("k"): t.get("v") for t in w.iter("tag")}
        pts = [to_xz(*nodes[nd.get("ref")]) for nd in w.iter("nd") if nd.get("ref") in nodes]
        if len(pts) < 2:
            continue
        if "building" in tags and len(pts) >= 4:
            if pts[0] == pts[-1]:
                pts = pts[:-1]
            h = tags.get("height")
            lv = tags.get("building:levels")
            height = float(h.split()[0]) if h else (float(lv) * 2.9 if lv else 6.0)
            kind = tags.get("building")
            buildings.append({"id": "osm_" + w.get("id"), "name": tags.get("name", tags.get("addr:street", "") + " " + tags.get("addr:housenumber", "")).strip() or "Gebäude",
                              "footprint": pts, "height": round(height, 1), "roof": "gable" if len(pts) == 4 else "flat",
                              "wall": "#F1EEE6", "roof_color": ROOFS[len(buildings) % len(ROOFS)], "style": "putz", "osm_building": kind})
        elif "highway" in tags and tags["highway"] in WIDTH:
            roads.append({"name": tags.get("name", ""), "width": WIDTH[tags["highway"]], "main": tags["highway"] in ("primary", "secondary", "tertiary"), "points": pts})
        elif tags.get("waterway") in ("stream", "river", "ditch"):
            water.append({"name": tags.get("name", "Bach"), "points": pts})
    out = {"area": area, "name": name, "source": "Kartendaten © OpenStreetMap-Mitwirkende (ODbL)", "units": "Meter, x nach Osten, z nach Süden",
           "center_latlon": center, "start": [0, 0], "valley_extra": [], "roads": roads, "water": water, "buildings": buildings, "stations": [], "platforms": []}
    if merge:
        for key in ("stations", "platforms", "start", "valley_extra"):
            out[key] = merge.get(key, out[key])
    dst = f"../Geographic_Data/{area}.json"
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(buildings)} Gebäude, {len(roads)} Straßen, {len(water)} Bäche -> {dst}")

if __name__ == "__main__":
    main()
