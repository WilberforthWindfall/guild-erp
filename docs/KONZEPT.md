# Guild ERP – Konzept, Regeln und Versionsgeschichte

(Übernommen aus den Projektnotizen des Claude-Chats „Guild ERP“, Stand 18.10.2026 / Version 1.3.)

Eigenständiges WoW-Forever-Add-on „Guild ERP“ (läuft ohne Reiseführer/ForeverDashboard).
Grundidee des Nutzers (Barlor): wie ein MRP in SAP – „Wunschrezept“ wählen → Stückliste → Bedarfsdeckung über alle Charaktere (eigene + Frau, später Gilde) → fehlende Teile als Bestellung/BANF.
Stand 17.10. (Nutzer): „Funktional bin ich hoch zufrieden. Jetzt gehts um den letzten Feinschliff.“

## Vorgaben des Nutzers
- Weder technisch noch optisch überladen.
- Grundregeln: nur offizielle Add-on-Schnittstelle, NUR LESEN, keine Automatisierung (kein automatisches Handeln, Verschicken, Kaufen), Code offen, kostenlos, Nachrichten gedrosselt, keine Blizzard-Grafiken außer aus dem Spielclient. Nutzer: „Streng an Blizzard-Richtlinien halten – ich will nicht gesperrt werden.“
- KEIN „Herstellen“-Knopf. Ausnahmen vom Nur-Lesen: (1) Knopf „Im Berufefenster öffnen“ (öffnet, wählt Rezept, trägt Anzahl ein; Herstellen klickt der Spieler). (2) Guild-Found: fremden Handel automatisch schließen + einmal freundlich flüstern – nur bei gesetztem Haken.
- Bestellungen und Planaufträge sind nur VERMERKE; Übergeben (Handel/Post/Gildenbank/Verzaubern im Handel) macht jeder selbst.
- Auktionshaus: nur SUCHEN und LESEN (Preise), nie kaufen/bieten/einstellen. Preise werden NICHT geteilt.
- GRUNDREGEL Stornieren: Guild ERP storniert nie etwas bei anderen; es sagt Bescheid, jeder entscheidet selbst.
- FRAKTIONEN: Allianz-Charaktere lesen/sehen nur Allianz-Daten, Horde nur Horde (1.2.1).
- GUILD-FOUND: Haken in den Optionen (Standard aus). Guild ERP nur innerhalb der Gilde; Handel von Nicht-Gildenmitgliedern automatisch ablehnen mit freundlicher Antwort; Post: fremde Post markieren + „Zurücksenden“ nur auf Klick, Warnung beim Schreiben an Nicht-Gilde (Blizzard-Senden-Knopf bleibt unberührt) (1.3).
- REGEL Werkstatt ↔ Katalog: Werkstatt = nur Berufe/Rezepte der EIGENEN Charaktere (auch Zweitcharaktere). Katalog = alles, was andere können, ohne das, was der gerade gespielte Charakter selbst kann, und ohne seelengebundene Ergebnisse. Rezepte der eigenen Zweitcharaktere bleiben im Katalog sichtbar.
- Planaufträge (Nutzer sagt auch „PLAUF“): Fokus auf die des gespielten Charakters; die anderer Charaktere in einem eigenen, auf-/zuklappbaren Bereich.
- Bestellungen: Maus über einer Zeile zeigt den Spiel-Tooltip, „was es ist“.
- Werkstatt-Rezeptbuch: Baumstruktur nach derselben Logik wie im Katalog (Gruppen des Spiels).
- „Noch nicht gelernt“: NICHT SPOILERN, „mitlernen“ – nur Rezepte zeigen, bei denen bekannt ist, wo man sie lernt (Lehrer/Händler schon besucht; Beute-Drops merken). STANDALONE-Aufgabe: siehe docs/POLISHING.md Abschnitt 3.
- Spiel-Look: gesamte Optik wie das Berufefenster, umschaltbar in den Optionen; „sieht gut aus“. Idee: Anzahl „[n]“ herstellbar hinter dem Rezeptnamen.
- Reiter-Reihenfolge in den Optionen einstellbar.
- Bedienung: Auswahllisten = Lieblingsnutzerführung. Einfache Sprache, Deutsch, eine Frage auf einmal, früh Entwürfe zeigen, vor UI-Umbauten eine Vorschau zeigen.
- Die Frau des Nutzers spielt „Zwerg Pudel(muetze)“ (u. a. Verzauberin). Der Nutzer heißt im Spiel „Barlor Rostbart“; Zweitcharakter „Herr Mine“.

## Berufefenster-Optik (ausgelesen 17.10. per /gerp optik; Rohdaten docs/optik-berufefenster.txt)
- Rahmen: NineSlice „PortraitFrameTemplate“-Atlanten (UI-Frame-PortraitMetal-CornerTopLeft, UI-Frame-Metal-*). Porträt 62×62. Titel GameFontNormal gold. Schließen RedButton-Exit.
- Hintergrund: Profession-Background-Template2, Professions-background-summarylist, Profession-background-card-<Beruf> + common-insideframe.
- Liste: common-search-border-*, common-search-magnifyingglass, common-dropdown-b-button, common-button-list-collapseExpand (+ -minus/-plus), Game15Font_Shadow, GameFontHighlight_NoShadow, Professions_Recipe_Active/-Hover, minimal-scrollbar-*.
- Karte rechts: auctionhouse-itemicon-border-white; Professions-Slot-bg/-Frame; Professions-skillbar-*.
- Knöpfe: 128-RedButton-*, Seitenreiter common-sidetab / -selected / -hover.

## Technischer Hintergrund WoW Forever
- Retail-Client (12.x-API, Mainline-UI, C_AuctionHouse), Start 4.11.2026. Midnight-Add-on-Beschränkungen gelten. Berufefenster = retail ProfessionsFrame mit Forever-Grafiken. Beta-Interface-Nummer 16001 (Live prüfen!).
- Skill-Linien in Forever sind Unter-Linien (z. B. Schmiedekunst 2938, Verzauberkunst 2940) → Berufe zusätzlich über den Namen erkennen (Kat.BERUF_NAME).
- AH: SendSearchQuery max. 100/Minute; ReplicateItems nicht verwendet.
- Rezept-ID = Zauber-ID. GetRecipeSchematic liefert auch für fremde Rezepte Zutaten (bestätigt).
- NAMEN: Pflicht-Vor- und Nachnamen, eindeutig nur die Kombination; UnitName = Vorname, CHAT_MSG_ADDON-Absender = voller Name; eigene Add-on-Nachrichten kommen als Echo zurück. Offen: ob Flüstern an GetUnitName("NPC", true) im Spiel ankommt (Guild-Found-Antwort).
- Spielschrift kennt keine Symbole wie ◆ ✓ → Texturen. „ScrollFrameTemplate“ statt alter Scrollleiste. Deckende Hintergründe gegen durchscheinende Namensplaketten.
- Verlinkte Berufefenster anderer Spieler dürfen nicht als eigene gelesen werden (Kat.FremdesFenster, GetProfessions-Abgleich).

## Version 1.3 (Beta) – 18.10.2026 (Spieltest steht aus)
- Option settings.optionen.gilde (Haken „Guild-Found“). O.GildeModus(), O.Wir() („Gilde“/„Gruppe“).
- Abgleich: B.InGruppe() = IsInGuild(), B.Kanal() = "GUILD"; Empfang nur, wenn (Kanal == "GUILD") == Guild-Found → Spieler mit und ohne Haken reden NICHT miteinander. Hallo (O.GildeStart: "H~2" + B.StandSenden) beim Einloggen und Einschalten. B.Mitglieder = online Gildenmitglieder (O.GildeOnline).
- Gildenliste: O.GildeLesen (C_GuildInfo.GuildRoster höchstens alle 30 s, GetGuildRosterInfo), O.InGilde(name) über B.Gleich; eigene Charaktere zählen als Gilde.
- Handel (TRADE_SHOW, O.HandelPruefen): UnitIsInMyGuild("NPC"), sonst Gildenliste; nicht in Gilde → CancelTrade, Chat-Meldung, einmal je Spieler/5 Min. und nie im Kampf Flüstern.
- Post: Fenster GuildERPPost am MailFrame listet Spielerbriefe von Nicht-Gildenmitgliedern mit „Zurücksenden“ (ReturnInboxItem nur auf Klick). SendMailNameEditBox:HookScript("OnTextChanged") → rote Warnung.
- Test sim22.

## Version 1.2.1 – 1.0 (Beta)
- 1.2.1 Fraktionen getrennt (Kat.Text, Kat.Sammeln, B.KenneRezept, P.AndereFraktion). sim21.
- 1.2 Planaufträge: erst eigene, dann „Planaufträge anderer Charaktere (n)“ (startet zu). sim20.
- 1.1.9 Reihenfolge der Reiter (settings.optionen.reiter). sim19.
- 1.1.8 keine fremden/verlinkten Berufefenster lesen + Aufräumen beim Einloggen. sim18.
- 1.1.7/1.1.6 Spiel-Look (settings.optionen.look; O.Teil/O.LookAnwenden/O.Atlas). sim17.
- 1.1.5 „Noch nicht gelernt“ nur mit Quelle; /gerp optik. sim16.
- 1.1.4 Gruppen des Spiels (+Abgleich, rückwärtsverträglich). sim15. 1.1.3 Werkstatt-Gruppen. sim14.
- 1.1.2 Tooltip auf Bestellzeilen. 1.1.1 Katalog ohne eigene/seelengebundene. 1.1 Katalog-Gruppen, Zutaten-Baum, Minimap-Knopf, Optionen.
- 1.0 volle Namen, Katalog-Bestellungen, Stornieren (im Spiel bestätigt).

## Frühere Versionen
- 0.9.x: Stand-Abgleich ("H~2", "I", "S", "Q", "K"), Katalog, Diagnose, Namensvergleich, Tooltips.
- 0.8: Auktionshaus-Preise. 0.7: Unter-Zutaten, Auftragsnetz. 0.6: Planaufträge. 0.5: Bestellungen. 0.4–0.1: Werkstatt-Grundlagen.

## Datenmodell (GuildERPData)
- characters[Realm-Name] {name, voll, faction, recipes[Beruf][rezeptID], bags, bagsAt, bank, bankAt}
- recipes[rezeptID] {name, icon, profession, professionID (Unter-Linie), itemID, reagents{{itemID, count}}, numMade, kategorie, at}
- items[itemID] {name, icon, q, bind}; vendors; prices[Fraktion][itemID] = {min, avg, n, at} oder {leer, at}
- plans[rezeptID] {id, rezeptID, menge, wer (Vorname des Herstellers), at, fuer{[orderId]={n, von, mats, quittiert}}}
- orders[id] {id, von, an, fuer, notiz, at, status, kopfRev, gesehen{}, plan, mats, ausgeblendet, zeilen{{itemID, rezeptID, n, zusagen{[Name]={n, weg 1..4, g, at}}}}}
- fremd[voller Name] {von, at, berufe[Beruf][rezeptID]=itemID}; fremdStand; katNamen; katGruppe; neues
- settings {ansicht, beruf, wunsch, menge, window, zu, katBeruf, katRezept, optionen{gilde, look, reiter, hinweis, ton, chat, minimap, ah, groesse, winkel}}
- diagnostics {abgleich, optik, lookFehler, fremdesFenster, aufgeraeumt, …}

## Weitere Anforderungen
1. Standalone-Quellen für „Noch nicht gelernt“ (Lehrer, Händler, Beute) – siehe POLISHING.md.
2. Spieltest Guild-Found (Handel, Flüstern, Post, Gildenabgleich mit vielen Online-Mitgliedern).
3. Spiel-Look auf die übrigen Fenster ausdehnen, „[n]“ in der Liste.
4. Nutzungsbedingungen prüfen, bevor die Gilde Guild ERP nutzt.
5. Gildenbank als Bestandsquelle (nur lesbar bei offenem Gildenbankfenster).
