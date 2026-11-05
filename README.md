# Guild ERP

Ein Add-on für **World of Warcraft: Forever**, das dir beim Herstellen hilft – wie eine kleine Warenwirtschaft für dich, deine Twinks und deine Gilde.

- **Werkstatt**: Wähle ein Rezept und sieh sofort, welche Zutaten du schon hast (Tasche, Bank, andere Charaktere), was du herstellen kannst und was noch fehlt.
- **Planaufträge**: Merk dir, was du herstellen willst; Zusagen anderer zählen mit.
- **Bestellungen**: Bestell Zutaten oder fertige Sachen bei deiner Gruppe oder Gilde. Alles nur als Notiz – übergeben wird ganz normal im Spiel.
- **Katalog**: Wer in deiner Gruppe oder Gilde kann was herstellen?
- **Auktionshaus**: zeigt, was fehlende Zutaten ungefähr kosten.
- **Guild-Found** (Option): alles nur innerhalb der Gilde; Handel mit Fremden wird freundlich abgelehnt.

## Installation
1. Lade die neueste ZIP-Datei unter **Releases** herunter.
2. WoW beenden, die ZIP-Datei entpacken (rechte Maustaste → „Alle extrahieren…“).
3. Den Ordner **GuildERP** in den Add-on-Ordner von WoW Forever kopieren (`…\World of Warcraft\<Spielversion>\Interface\AddOns\`).
4. WoW starten. Mit **/gerp** öffnest du Guild ERP, mit **/gerp optionen** die Einstellungen.

Tipp: Öffne bei jedem deiner Charaktere einmal das Berufefenster und die Bank – dann kennt Guild ERP Rezepte und Vorräte.

## Was Guild ERP nicht tut
Guild ERP hält sich streng an die Regeln von Blizzard: Es **liest nur**. Es kauft, verkauft, verschickt oder stellt nichts automatisch her. Auktionshaus-Preise werden nur gesucht und gelesen. Fundorte von Rezepten und gelesene Preise teilt Guild ERP nur mit Spielern deiner Fraktion, die Guild ERP ebenfalls haben; das kannst du in den Optionen abschalten. Einzige Ausnahme: Mit der Option „Guild-Found“ schließt es Handelsanfragen von Nicht-Gildenmitgliedern und antwortet einmal freundlich.

## Mitmachen / Entwicklung
Siehe `CLAUDE.md`, `docs/POLISHING.md` und `docs/KONZEPT.md`. Tests: `tests/run_all.sh`.

## Lizenz
Frei nutzbar unter der MIT-Lizenz, siehe `LICENSE`.
