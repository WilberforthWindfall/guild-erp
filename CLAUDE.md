# CLAUDE.md – Guild ERP (WoW-Forever-Add-on)

Dauerhafte Hinweise für Claude Code in diesem Repository. Ausführliche Übergabe: `docs/POLISHING.md`, Fachkonzept und Versionsgeschichte: `docs/KONZEPT.md`.

## Unverhandelbare Regeln (Blizzard-Richtlinien – „ich will nicht gesperrt werden“)
- Nur die offizielle Add-on-Schnittstelle. **Keine geschützten Funktionen**, kein Taint von Blizzard-Fenstern (keine Blizzard-Knöpfe ersetzen/sperren; nur `HookScript`).
- **Nur lesen, keine Automatisierung**: nichts automatisch kaufen, verkaufen, bieten, einstellen, verschicken, herstellen.
- Einzige Ausnahmen:
  1. Knopf „Im Berufefenster öffnen“ (öffnet, wählt Rezept, trägt Anzahl ein – **Herstellen klickt der Spieler**).
  2. Option **Guild-Found**: fremden Handel per `CancelTrade` schließen + **einmal** freundlich flüstern (max. 1×/5 Min. je Spieler, nie im Kampf).
- Auktionshaus: nur suchen/lesen (gedrosselt), nie kaufen/bieten/einstellen. **Preise werden nicht geteilt.**
- Bestellungen/Planaufträge sind nur **Vermerke**. Guild ERP storniert nie etwas bei anderen, es sagt nur Bescheid.
- Add-on-Nachrichten gedrosselt (1 Nachricht / 1,2 s, nichts im Kampf). Code offen, kostenlos.
- Keine Blizzard-Grafiken außer denen aus dem Spielclient (Atlas-Namen, Texturpfade).
- Allianz sieht nur Allianz-Daten, Horde nur Horde.
- **Standalone**: Guild ERP muss vollständig ohne den Reiseführer (`ForeverDashboard`) funktionieren. Der Reiseführer ist nur eine optionale Zusatzquelle (`## OptionalDeps`).

## Technik
- Client: WoW Forever = Retail-Client (12.x-API, Mainline-UI, Midnight-Beschränkungen), Start 4.11.2026. Lua 5.1.
- Alles steckt derzeit in **einer** Datei `GuildERP/GuildERP.lua` (~8.800 Zeilen). Wegen der Lua-Grenze von 200 lokalen Variablen pro Funktion/Hauptteil stehen Funktionen in Tabellen: `K` (Konstanten), `B` (Bestellungen/Abgleich), `P` (Planaufträge), `A` (Auktionshaus), `Kat` (Katalog), `O` (Optionen, Spiel-Look, Guild-Found). **Keine neuen lokalen Namen im Hauptteil**, sondern in diese Tabellen.
- Bezeichner und Kommentare deutsch; Kommentare ohne Umlaute (ae/oe/ue), Texte für Spieler mit Umlauten (UTF-8).
- Namen in WoW Forever: Vor- **und** Nachname; nur die Kombination ist eindeutig. `UnitName` liefert nur den Vornamen, der `CHAT_MSG_ADDON`-Absender den vollen Namen. Helfer: `B.Name`, `B.Vorname`, `B.Gleich`, `B.Ich`, `B.Anzeige`.
- Gespeicherte Daten: `GuildERPData` (Aufbau in `docs/KONZEPT.md` → „Datenmodell“).
- Abgleich-Protokoll: Präfix `GERP1`, Kanal PARTY/RAID bzw. GUILD (Guild-Found). Nachrichten `H~2`, `I`, `S~`, `Q~`, `K`, `B`, Teile `X~nr~teil~gesamt~inhalt`. Rückwärtsverträglich halten (alte Versionen ignorieren unbekannte Teile).

## Testen
- `tests/run_all.sh` (braucht `lua5.1`; ggf. `sudo apt install lua5.1`). Muss mit „Fehler: 0“ enden.
- Die Sims nutzen eine WoW-Attrappe (`tests/stubs.lua`) und echte Testdaten aus `tests/fixtures/` (**privat, nicht hochladen** – stehen in `.gitignore`).
- Neue Funktion → neue Sim nach dem Muster der vorhandenen (`sim17` Optik, `sim22` zwei Spieler + Gilde).

## Version und Auslieferung
- Version an **vier** Stellen erhöhen: Kopfkommentar Zeile 1 und `K.VERSION` in `GuildERP.lua`, `## Version` in `GuildERP.toc`, Abschnitt „Neu in …“ in `GuildERP/LIESMICH.txt`.
- Spiel-Ordner des Nutzers (Beta): `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\GuildERP\` – für die Live-Version den richtigen Ordner beim Nutzer erfragen.
- `## Interface:` in der `.toc` muss zur Live-Version passen (im Spiel: `/dump select(4, GetBuildInfo())`).
- Weitergabe als ZIP mit genau einem Ordner `GuildERP/` darin.
