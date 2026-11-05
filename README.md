# Guild ERP

Ein kostenloses Add-on für **World of Warcraft: Forever**, das dir beim Herstellen hilft. Du wählst ein Rezept und siehst sofort, welche Zutaten du schon hast, was noch fehlt und wer aus deiner Gilde es herstellen kann.

*Das Add-on ist noch in der Testphase (Beta). Es kann also noch kleine Fehler geben.*

## Was es kann

- **Werkstatt:** Wähle ein Rezept. Eine Farbe zeigt dir bei jeder Zutat, ob sie in deiner Tasche liegt, auf der Bank, bei einem anderen deiner Charaktere, oder ob sie noch fehlt.
- **Noch nicht gelernt:** Guild ERP merkt sich, wo du Rezepte gesehen hast: beim Lehrer, beim Händler oder als Beute. Mit Ort und Preis.
- **Planaufträge:** Merk dir, was du herstellen willst. Sagt dir jemand Zutaten zu, zählt das mit.
- **Bestellungen:** Bitte deine Gruppe oder Gilde um Zutaten oder fertige Sachen. Das ist nur eine Notiz. Übergeben wird ganz normal im Spiel, per Handel, Post oder Gildenbank.
- **Katalog:** Sieh nach, wer aus deiner Gruppe oder Gilde was herstellen kann.
- **Auktionshaus:** Zeigt dir, was fehlende Zutaten ungefähr kosten.

## So installierst du es

1. Lade unter **[Releases](https://github.com/WilberforthWindfall/guild-erp/releases/latest)** die ZIP-Datei herunter. Du findest sie ganz unten auf der Seite bei „Assets“. Dafür brauchst du kein Konto.
2. Beende WoW.
3. Klick mit der rechten Maustaste auf die ZIP-Datei und wähle **„Alle extrahieren…“**.
4. Kopiere den entpackten Ordner **GuildERP** in diesen Ordner:
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`
   Falls Windows nach einer Erlaubnis fragt, klick auf **Fortsetzen**. Hast du WoW woanders installiert, such dort nach dem Ordner `_forever_`.
5. Starte WoW. Klick in der Charakterauswahl unten links auf **AddOns** und schau, ob **Guild ERP** einen Haken hat.

**Wichtig:** In den Ordner `AddOns` gehört genau der Ordner `GuildERP`, nicht noch ein weiterer Ordner darum herum. Sonst findet das Spiel das Add-on nicht.

**Neue Version:** WoW beenden, den alten Ordner `GuildERP` durch den neuen ersetzen. Deine gemerkten Daten bleiben erhalten.

**Entfernen:** Den Ordner `GuildERP` löschen.

## Erste Schritte

1. Öffne bei jedem deiner Charaktere einmal sein **Berufefenster** und die **Bank**. So lernt Guild ERP deine Rezepte und Vorräte kennen.
2. Tippe im Chat **`/gerp`**. Die Werkstatt öffnet sich.
3. Wähle links oben einen Beruf und klick auf ein Rezept. Rechts siehst du, was du dafür brauchst.
4. Sprich unterwegs einfach Lehrer und Händler an. Guild ERP merkt sich dann, was es dort gibt.

Damit ihr euch gegenseitig seht, braucht **jeder** das Add-on. Seid zusammen in einer Gruppe, oder schaltet „Guild-Found“ ein (siehe unten).

| Eingabe im Chat | Was passiert |
|---|---|
| `/gerp` | Fenster öffnen oder schließen |
| `/gerp optionen` | Einstellungen |
| `/gerp info` | Zeigt, was über deine Charaktere bekannt ist |
| `/gerp abgleich` | Hilft, wenn du die Rezepte der anderen nicht siehst |
| `/gerp hilfe` | Zeigt alle Befehle |

## Guild-Found

Das ist eine Einstellung für alle, die nur innerhalb ihrer Gilde handeln wollen. Du findest sie unter `/gerp optionen`, von Anfang an ist sie ausgeschaltet. Ist sie an:

- gleicht Guild ERP nur noch mit deiner Gilde ab, auch ohne Gruppe,
- schließt es Handelsfenster von Spielern außerhalb der Gilde und antwortet ihnen einmal freundlich,
- listet es Post von außerhalb der Gilde neben dem Briefkasten auf, mit einem Knopf zum Zurücksenden, den du selbst klickst,
- warnt es dich, wenn du jemandem außerhalb der Gilde schreibst.

Am besten stellt ihr diese Einstellung in der Gilde alle gleich ein. Sonst sehen sich die Spieler gegenseitig nicht.

## Was Guild ERP nicht tut

Guild ERP liest nur, was du im Spiel siehst. Es kauft, verkauft, bietet, verschickt und stellt **nichts** von selbst her. Es gibt zwei Ausnahmen:

- Der Knopf „Im Berufefenster öffnen“ wählt das Rezept und die Anzahl aus. **Herstellen klickst du selbst.**
- Guild-Found schließt, wenn du es einschaltest, Handelsfenster von Fremden und antwortet einmal (siehe oben).

Das Add-on ist kostenlos, und jeder kann den Code lesen.

Guild ERP nutzt nur die normale Add-on-Schnittstelle des Spiels und soll sich an Blizzards Add-on-Regeln halten. Eine Prüfung oder Freigabe durch Blizzard gibt es aber nicht. Du nutzt es auf eigene Verantwortung.

## Was deine Mitspieler von dir sehen

Daten gehen nur an Spieler in deiner Gruppe oder Gilde, die **ebenfalls Guild ERP haben** und zu **deiner Fraktion** gehören. Nach außen geht nichts, es gibt keinen Server und keine Website dahinter.

| Das bekommen deine Mitspieler | |
|---|---|
| Die Namen deiner Charaktere dieser Fraktion, **auch deiner Twinks**, und ihre Rezepte | immer |
| Deine Bestellungen, Zusagen und Lieferungen | immer |
| Fundorte von Rezepten, die du gesehen hast (mit Ort und Preis beim Lehrer oder Händler) | abschaltbar |
| Auktionshaus-Preise, die du gelesen hast | abschaltbar |

Abschalten kannst du die letzten beiden Zeilen unter `/gerp optionen` → **„Fundorte und Preise teilen“**. Dann bekommst du auch von anderen keine mehr.

**Nicht** geteilt werden: was in deinen Taschen und auf deiner Bank liegt, und dein Gold.

Geteilte Preise sind Angaben anderer Spieler und können falsch oder veraltet sein. Darum steht in der Liste dabei, wie alt ein Preis ist und von wem er kommt.

## Hilfe

Etwas klappt nicht? Sag in der Gilde Bescheid oder schreib unter **[Issues](https://github.com/WilberforthWindfall/guild-erp/issues)** (dafür brauchst du ein kostenloses GitHub-Konto). Hilfreich sind deine Version (steht bei `/gerp info` ganz oben), ein Bildschirmfoto und der Text einer Fehlermeldung, falls eine erscheint.

Eine ausführliche Anleitung liegt dem Add-on bei: die Datei `LIESMICH.txt` im Ordner `GuildERP`.

## Für Entwickler

Siehe [CLAUDE.md](CLAUDE.md), [docs/POLISHING.md](docs/POLISHING.md) und [docs/KONZEPT.md](docs/KONZEPT.md). Die Tests starten mit `tests/run_all.sh` (Lua 5.1). Die Testdaten sind privat und nicht im Projekt enthalten, die Tests laufen darum noch nicht ohne sie.

## Lizenz

Frei nutzbar unter der [MIT-Lizenz](LICENSE).
