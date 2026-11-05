# Guild ERP – Übergabe für die „Polishing“-Sitzung in Claude Code

Stand: 5.11.2026 · Version **1.3 (Beta)** · erstellt aus dem bisherigen Claude-Chat „Guild ERP“.

## 1. Ziel der Sitzung
Guild ERP ist funktional fertig („Funktional bin ich hoch zufrieden“). Jetzt, wo WoW Forever erschienen ist (4.11.2026), soll es **professionalisiert** und den **Gildenfreunden** zur Verfügung gestellt werden:
1. Auf **GitHub** bringen (Repository, Versionen, Releases zum Herunterladen).
2. **Standalone vollständig**: alles muss ohne den Reiseführer funktionieren (der ist noch Alpha).
3. Feinschliff: Code-Struktur, Robustheit, Optik, Texte, Tests.

## 2. Was Guild ERP kann (Kurzfassung)
- **Werkstatt**: Rezeptbuch aller eigenen Charaktere (nach den Gruppen des Spiels, aufklappbar), Wunschrezept → mehrstufige Stückliste mit Ampel (Tasche, Bank, andere Charaktere, Händler, herstellbar, fehlt), Unter-Zutaten, Knopf „Im Berufefenster öffnen“.
- **Planaufträge (PLAUF)**: Vormerken, Zusagen anderer zählen blau mit, Auftragsnetz (Kacheln mit Linien), eigene oben, andere Charaktere zuklappbar.
- **Bestellungen**: Bestellschein an Gruppe/Gilde oder eine Person, Zusagen mit Lieferweg, Stornieren mit Abhängigkeiten, Tooltips.
- **Katalog**: Wer kann was (eigene Twinks + Mitspieler über Abgleich), Zutaten-Baum, direkt bestellen.
- **Auktionshaus**: liest Preise der benötigten Zutaten (min/Schnitt), nur suchen.
- **Optionen**: Aussehen (dunkel / Spiel-Look wie das Berufefenster), Reiter-Reihenfolge, Hinweis-Art, Ton, Chat, Minimap-Knopf, AH-Modus, Fenstergröße, **Guild-Found**.
- **Guild-Found**: Abgleich nur über die Gilde; fremder Handel wird geschlossen + freundliche Antwort; fremde Post markiert + „Zurücksenden“ auf Klick; Warnung beim Schreiben an Nicht-Gilde.
- Allianz/Horde strikt getrennt.

Details, Regeln, Entscheidungen und Versionsgeschichte: `docs/KONZEPT.md`.

## 3. Standalone ohne Reiseführer – Ist-Stand und Aufgabe
**Erledigt in 1.4 (Sammeln von Lehrer, Händler, Beute; Spieltest und Teilen stehen noch aus). Früherer Stand:** Die **einzige** Stelle, die den Reiseführer nutzt, ist `Reisefuehrer()` / `GraueRezepte()` (Werkstatt-Bereich **„Noch nicht gelernt“**). Sie liest `ForeverDashboardData.catalog.recipes` (Lehrer/Händler, die der Reiseführer beim Ansprechen gemerkt hat: Name, Zone, Koordinaten, Kosten, nötige Fertigkeit) und `characters[].recipeCollections[].missing`. Ohne Reiseführer fehlt dieser Bereich einfach; alles andere läuft. Weitere Fundstellen nur in Texten (Zeilen mit „Reiseführer“, z. B. „aus dem Reiseführer“, „Der Reiseführer merkt sich den Ort …“) und in `/gerp info`.

**Aufgabe (wichtigster Punkt):** Guild ERP soll diese Quellen **selbst** sammeln, nur lesend, und den Reiseführer höchstens als zusätzliche Quelle mit einbeziehen:
- **Lehrer**: beim Öffnen des Lehrerfensters (`TRAINER_SHOW`) die angebotenen Rezepte lesen (Name, Kosten, nötige Fertigkeit) + Lehrername, Zone, Koordinaten (`C_Map`). Nur lesen, nichts lernen.
- **Händler**: beim Öffnen eines Händlers (`MERCHANT_SHOW`, es gibt schon `HaendlerLesen` für Zutaten) auch Rezept-Gegenstände (Gegenstandsklasse „Rezept“) mit Preis merken.
- **Beute** (Wunsch des Nutzers, „mitlernen“): wenn ein Rezept gedroppt wird (`LOOT_OPENED`/`LOOT_READY`, Rezept-Gegenstand im Beutefenster), merken, bei welchem Gegner – fortlaufend ergänzen.
- **Kein Spoilern**: nur Rezepte zeigen, deren Quelle wirklich schon gesehen wurde (so ist es seit 1.1.5). Die Spiel-Liste „alle fehlenden Rezepte“ nicht ungefiltert zeigen.
- Optional: diese Quellen beim Abgleich mit der Gruppe/Gilde teilen (rückwärtsverträglich, gedrosselt).
- Texte „aus dem Reiseführer“ neutral formulieren; `## OptionalDeps: ForeverDashboard` darf bleiben.
- Datenvorschlag: `GuildERPData.quellen[Rezeptname] = { {art="Lehrer|Händler|Beute", wer, zone, x, y, kosten, skill, at}, … }`.

## 4. Feinschliff-Liste (Vorschlag, Reihenfolge mit dem Nutzer abstimmen)
1. **Live-Version prüfen**: `## Interface: 16001` war der Beta-Client. Im Spiel `/dump select(4, GetBuildInfo())` und anpassen; Add-on-Ordner der Live-Version beim Nutzer erfragen (Beta lag unter `_classic_beta_`).
2. **Code aufteilen** in mehrere Dateien (in der `.toc` auflisten), gemeinsamer Namensraum über `local ADDON, ns = ...`; Lua-Grenze 200 lokale Namen beachten. Verhalten darf sich nicht ändern – Sims vorher/nachher.
3. **Gespeicherte Daten versionieren** (`GuildERPData.schema`) und Umzüge (Migrationen) sauber machen.
4. **Spiel-Look** auf die kleinen Fenster ausdehnen (Bestellschein, Zusage, Stornieren, Hinweis, Optionen, Preise, Auftragsnetz, Post-Liste). Rohdaten der Spielgrafiken: `docs/optik-berufefenster.txt`. Frage an den Nutzer: Spiel-Look als Standard?
5. **„[n]“** hinter Rezeptnamen (wie oft mit Taschen-Inhalt herstellbar), wie im Berufefenster.
6. **Gildenabgleich bei vielen Online-Mitgliedern** prüfen (Nachrichtenmenge, Drosselung, evtl. Stand nur auf Nachfrage senden).
7. **Texte** durchsehen (einheitlich, kurz, freundlich); evtl. Vorbereitung für Englisch (Entscheidung Nutzer).
8. **Fehlerschutz** (erledigt in 1.4): Ereignisse, Klicks, Zeitgeber und Befehle laufen über `O.Sicher`, neue Fenster über `O.Rahmen`, neue Zeitgeber über `O.Nach`; Fehler stehen in `/gerp info`. In den Tests reicht `GERP_STRENG` sie weiter. Fehler beim Laden der Datei selbst fängt das nicht ab.
9. **Tests automatisieren**: `tests/run_all.sh` in GitHub Actions (Lua 5.1), dazu `luacheck` mit `.luacheckrc` (WoW-Globale). Veraltete Sims (sim7, sim11, sim12, sim10v) an die Testdaten anpassen oder entfernen.
10. **Testdaten anonymisieren** (Charakternamen in `tests/fixtures/`), damit die Tests auch öffentlich laufen können – bis dahin bleiben sie in `.gitignore`.
11. **Auslieferung**: GitHub-Release mit ZIP (`GuildERP/` als einziger Ordner); optional CurseForge/Wago über den BigWigs-Packager (`.pkgmeta`) – Entscheidung Nutzer.
12. **README für Gildenfreunde** (deutsch, ohne Fachbegriffe): Installation, erste Schritte, Guild-Found, Regeln, Datenschutz (teilt Rezepte, Bestellungen, Fundorte und Auktionshaus-Preise, nur mit Spielern, die Guild ERP haben; Teilen der Fundorte und Preise abschaltbar).

## 5. Noch nicht im Spiel geprüft
- Auktionshaus-Preise (seit 0.8) – zuletzt im Spiel gesehen, aber nicht systematisch getestet.
- Guild-Found (1.3): Kommt das Flüstern an (Vor- + Nachname)? Klappt `CancelTrade` ohne Fehlermeldung? Post-Liste neben dem Briefkasten.
- Spiel-Look in allen Ansichten, Reiter-Reihenfolge, Planauftrag-Bereich anderer Charaktere (1.2), Fraktionstrennung (1.2.1).

## 6. Offene Entscheidungen für den Nutzer (je einzeln fragen)
- Lizenz für GitHub (Vorschlag: MIT – „frei, mit Namensnennung“) und ob das Repository öffentlich oder privat ist.
- Wo die Gildenfreunde herunterladen: nur GitHub-Releases oder zusätzlich CurseForge/Wago.
- Spiel-Look als Standard?
- Nur Deutsch oder zusätzlich Englisch?
- ~~Quellen und Preise teilen?~~ Entschieden am 5.11.2026: ja, beides, nur zwischen Spielern mit Guild ERP, abschaltbar.

## 7. GitHub – Ablauf (übernimmt Claude Code)
1. Nutzer meldet sich einmal bei GitHub an (`gh auth login` – Schritt für Schritt erklären) oder hat schon ein Konto.
2. Repository anlegen (Vorschlag Name: `guild-erp`), diesen Ordner als ersten Stand einchecken (ohne `tests/fixtures/`).
3. Arbeit in Zweigen, kleine Schritte, je Schritt Sims laufen lassen.
4. Für jede Version: Version an vier Stellen erhöhen (siehe `CLAUDE.md`), Tag `v1.x.y`, Release mit ZIP.

## 8. Arbeitsweise, die sich bewährt hat
- Nach jeder Änderung: Sims laufen lassen, dann die Dateien in den Add-on-Ordner des Nutzers kopieren und um `/reload` bitten; um Bildschirmfotos bitten, wenn etwas Optisches geändert wurde.
- Diagnose im Spiel: `/gerp abgleich` (Abgleich), `/gerp optik` (liest das offene Berufefenster aus), `/gerp info`, `/gerp optionen`.
- Die gespeicherten Daten des Nutzers liegen unter `…\WTF\Account\<Konto>\SavedVariables\GuildERP.lua` – gut zur Fehlersuche (nach `/reload` aktuell).
- Bei Spieldetails, bei denen man unsicher ist: Nutzer fragen statt raten.
