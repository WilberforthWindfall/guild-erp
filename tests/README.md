# Tests

`tests/run_all.sh` lädt `GuildERP/GuildERP.lua` in Lua 5.1 mit einer nachgebauten WoW-Schnittstelle (`stubs.lua`) und spielt Abläufe durch (Simulationen `sim*.lua`).

- Voraussetzung: `lua5.1` (z. B. `sudo apt install lua5.1`) oder `LUA=/pfad/zu/lua5.1 tests/run_all.sh`.
- Testdaten: `fixtures/GuildERP_SV.lua` und `fixtures/ForeverDashboard_SV.lua` sind echte gespeicherte Daten des Entwicklers (Stand 17.10.2026, Beta). Sie enthalten Charakternamen und bleiben deshalb **privat** (`.gitignore`). Ziel: anonymisierte Testdaten.
- Mehrspieler-Sims (`sim10`–`sim13`, `sim15`, `sim22`) starten zwei Add-on-Instanzen (Barlor und Zwerg) und leiten Add-on-Nachrichten zwischen ihnen weiter. Das 3. Argument ist die Add-on-Datei für den zweiten Spieler (für Tests mit gemischten Versionen).
- `sim7`, `sim11`, `sim12`, `sim10v` passen nicht mehr zu den aktuellen Testdaten (Testannahmen, kein Add-on-Fehler) und laufen nur zur Info.

| Sim | prüft |
|---|---|
| sim5, sim6 | Werkstatt, Stückliste, Ampel mit echten Daten |
| sim8, sim8b | Bestellungen zwischen zwei Spielern |
| sim9 | Auktionshaus-Preise |
| sim10, sim13 | Abgleich, Katalog, volle Namen |
| sim14 | Gruppen im Rezeptbuch |
| sim15 | Gruppen des Spiels + Abgleich (gemischte Versionen) |
| sim16 | /gerp optik |
| sim17 | Spiel-Look an/aus |
| sim18 | fremde/verlinkte Berufefenster, Aufräumen |
| sim19 | Reiter-Reihenfolge |
| sim20 | Planaufträge eigener vs. anderer Charaktere |
| sim21 | Allianz/Horde getrennt |
| sim22 | Guild-Found: Gildenabgleich, Handel, Post |
| sim23 | Standalone: Lehrer, Händler und Beute ohne Reiseführer sammeln und anzeigen |
| sim24 | Teilen: Fundorte und Preise, neuerer Preis gewinnt, Fraktionen getrennt, Option aus |
