# Landro Longshot Randomized Code Automation

**Package version: 3.0.0**  
**Documentation / Dokumentation: English + Deutsch**

---

# English

## What's new in 3.0.0

Since the public v2.0.0 release, the addon has received substantial reliability improvements to menu learning and automatic navigation, plus German/English localization:

- **More reliable hierarchical menu learning:** the addon checks the active NPC dialogue against the selected route context and learned menu options, instead of relying on similar labels alone.
- **Automatic navigation through “Other Actions”:** when the selected option is not visible on Landro's short product list, the addon can open the navigation-only “Other Actions” entry and continue. This entry is not saved as a route step.
- **Safer route changes:** the latest selection takes priority when the user changes a path while an old code popup is closing. The old popup is not recorded as the endpoint for the newly selected route.
- **Improved recovery:** when popup cancellation leaves no NPC dialogue open, the selected route remains queued so navigation can resume after Landro is opened again.
- **More accurate endpoint detection:** a route is considered complete only after the actual key/code-entry popup is observed. An empty menu by itself is not enough, and a new path row is added only when a real submenu is found.
- **No fixed 20-step path limit:** path rows and route handling can grow dynamically; practical limits still depend on the game client and available resources.
- **Bug fix for menu-context normalization:** prevent the extra return value from Lua's `string.gsub` from being treated as a bogus path entry, which could make the learner skip a required menu click.
- **German and English localization:** most visible UI labels, minimap tooltips, and key workflow/status messages are centralized in `Localization.lua`. The client locale `deDE` selects German; other locales use English text.
- **Updated documentation:** installation, setup, the route-learning workflow, and troubleshooting have been refreshed.

The navigation-only entry is recognized by its German and English wording. The equivalent wording on other localized game clients may not be detected reliably. A small number of diagnostic/runtime messages may also remain hard-coded.
## Overview

Automates repetitive code-entry attempts at Landro Longshot in World of Warcraft. It learns the NPC dialogue path you select, automatically navigates the required menu options, generates non-repeating random numeric codes for each run (5–50 digits), enters and confirms each code, and tracks progress. You can configure the number of attempts (default: 100) and code length (default: 25). You must speak to Landro again between attempts; the addon does not start a new NPC interaction by itself. It generates random code guesses, not verified valid codes, so success is not guaranteed.

The route is selected through the addon's dropdowns. The addon learns real menu options from the live in-game dialogs; it does not rely on manually typed partial menu labels.

## Features

- Generate non-repeating random numeric codes within each run.
- Configure the number of code attempts (default: **100**).
- Configure code length from **5 to 50 digits** (default: **25**).
- Learn a parent-aware, hierarchical route from actual NPC gossip options.
- Automatically create the next path row when a selected option opens a real submenu.
- Treat the actual key/code-entry popup as the terminal endpoint; a blank menu alone is not considered an endpoint.
- Automatically navigate the configured route when the required menus are visible or can be reached through Landro's navigation option.
- Cancel an outdated code popup when the configured route changes, then attempt to resume the newest route.
- Show status, progress, the next code, the previous code, and copy buttons.
- Save settings and learned menu information between reloads and logins.
- Use the minimap button to open the addon or reset the learned menu data.
- Support dynamically growing paths without an addon-defined fixed maximum depth. Practical limits still depend on the WoW client and resources.

## Important terminology: the “Other actions” navigation option

Landro can show a short product/reward list before exposing the full action list. On a German game client, the navigation-only option is displayed as **“Habt Ihr noch andere Aktionen anzubieten?”**. In this documentation, it is called the **“other actions” navigation option**.

This entry is a navigation control, **not a path step**. When needed, the addon selects it to open the complete list of actions, then continues with the route selected in the addon. Do not choose it as a configured route step.

## Installation

1. Extract the `LandroRandomizedCodeAutomation` folder from the release ZIP.
2. Place it in the World of Warcraft AddOns folder, usually `_retail_/Interface/AddOns/` for Retail.
3. Confirm that `LandroRandomizedCodeAutomation.toc` is directly inside the folder and that the `Core/` and `UI/` subfolders are present.
4. Enable the addon in the AddOns list and reload the interface or restart the game.

Do not rename the folder or move individual Lua files: the TOC file loads them by their relative paths.

## First-time setup and learning a route

1. **Open the addon.** Left-click its minimap button to show or hide the main window.
2. **Talk to Landro Longshot.** The addon detects the fixed opening/root option and reads the currently visible Gossip menu.
3. **Choose Step 2 in the addon window.** Step 1 is detected automatically and is not a user-configurable route step.
4. **Follow the dynamically added steps.** After you choose a menu option, the addon attempts to navigate to it. If that option opens a submenu, the addon learns its available options and creates the next row. Choose the next desired option there.
5. **Wait for the real code-entry popup.** The route is marked complete only after the addon's popup detection observes Landro's actual key/code-entry dialog. When the status says **“Path complete — you can start”**, the endpoint has been learned.
6. **If the status asks for an interaction, follow that instruction.** For example, talk to Landro again or leave the appropriate Gossip dialog open. This is a recovery instruction for a dialog that the addon cannot safely identify; it is not a requirement to manually configure every menu step.

### Changing a route

- Change the route using the addon's dropdowns.
- When a parent step changes, all later selections are cleared because their old parent/child relationship may no longer be valid.
- The addon attempts to close an old code-entry popup and navigate using the newest selected route.
- An endpoint is not considered valid simply because a step has no learned children. The actual code-entry popup must be observed.
- The configuration controls are locked while the automation is running. Stop the run before changing the route or resetting learned data.

### Learning reset

To start learning from scratch, **stop the automation first**, then **right-click the minimap button**. This clears learned NPC menu branches and endpoint records, and clears the route selections beyond the fixed root. The configured code count, code length, window position, and minimap position are retained.

The reset is intentionally blocked while the automation is running, because clearing route data during a run could invalidate the active route.

## Running code attempts

1. Set **Number of Codes** and **Code Length**.
2. Confirm the route is complete and the status allows starting.
3. Press **Start**. If the current Gossip dialog matches the selected route, the addon can continue from it. Otherwise, follow the displayed status instruction; the addon will try the available navigation fallback when appropriate.
4. When Landro's code-entry popup opens, the addon fills the generated code and confirms it.
5. After the popup closes, that attempt is counted as complete. The addon then waits for you to interact with Landro again for the next iteration.
6. Press **Stop** to end the run early. Learned menus and endpoints are retained, and the progress counter is cleared.

The addon does not automatically start a new NPC interaction between attempts; the player must speak to Landro again for each iteration.

## Minimap button and window controls

- **Left-click:** Open or close the addon window.
- **Right-click:** Reset learned NPC menus and route selections (only while stopped).
- **Drag:** Move the minimap button around the minimap.
- **Esc:** Close the main window or the code-copy window.
- The current and previous code fields have **Copy** buttons. The copy dialog selects the code text so it can be copied with Ctrl+C.

## Localization status

Most visible UI labels, minimap tooltips, and workflow/status messages are now routed through `Localization.lua`. German text is selected when the WoW locale is `deDE`; all other locales use the English fallback branch. This provides a German and English interface, not a full translation into every WoW language.

The automatic detection of Landro’s navigation-only “other actions” option recognizes German and English wording. On clients using another game language, the corresponding menu entry may not be detected reliably, even though the addon UI itself falls back to English.

## Troubleshooting

- **Step 2 is not selectable:** Open Landro's initial dialog so the addon can learn the real menu options. If the current dialog is only the short product list, wait for or allow the addon to use the “other actions” navigation option.
- **A step says to open a submenu:** The selected parent branch has not yet been learned or the current dialog could not be matched safely. Follow the exact status message and re-open Landro if requested.
- **The path is not marked complete:** Select the desired entries in order and make sure the final selection actually opens the key/code-entry popup.
- **The addon does not resume from the open dialog:** Speak to Landro again or use the status instruction. Do not reset learning unless you intentionally want to discard the learned menu tree.
- **You see a Lua error:** Save the complete error text, note the WoW client version and the action that triggered it, then report those details with the issue.

The addon stores configuration and learned menu data in the `LLRCA_DB` SavedVariables table. Avoid manually editing the SavedVariables file while the game is running.

---

# Deutsch

## Neu in Version 3.0.0

Seit der öffentlich veröffentlichten Version v2.0.0 wurden die Menülernung und die automatische Navigation deutlich zuverlässiger gemacht. Hinzu kommt die deutsche und englische Lokalisierung:

- **Zuverlässigeres hierarchisches Menülernen:** Das Add-on gleicht den geöffneten NPC-Dialog mit dem ausgewählten Pfadkontext und den gelernten Menüoptionen ab, statt sich allein auf ähnliche Bezeichnungen zu verlassen.
- **Automatische Navigation über „Weitere Aktionen“:** Ist der gewählte Menüpunkt auf Landros kurzer Produktliste nicht sichtbar, kann das Add-on die reine Navigationsoption öffnen und anschließend fortfahren. Diese Option wird nicht als Pfadschritt gespeichert.
- **Sicherere Pfadänderungen:** Wenn während des Schließens eines alten Codefensters mehrere Pfadänderungen vorgenommen werden, hat die neueste Auswahl Vorrang. Das alte Popup wird nicht fälschlich als Endpunkt des neu gewählten Pfades gespeichert.
- **Verbesserte Wiederaufnahme:** Ist nach dem Abbrechen eines Popups kein NPC-Dialog mehr geöffnet, bleibt der Lernauftrag vorgemerkt. Die Navigation kann fortgesetzt werden, sobald Landro wieder angesprochen wird.
- **Genauere Endpunkterkennung:** Ein Pfad gilt erst dann als vollständig, wenn das tatsächliche Schlüssel-/Code-Eingabefenster erkannt wurde. Ein leeres Menü allein genügt nicht; ein weiterer Pfadschritt wird nur bei einem echten Untermenü angelegt.
- **Keine feste Grenze von 20 Pfadschritten:** Pfadzeilen und Routenverwaltung wachsen dynamisch. Praktische Grenzen ergeben sich weiterhin aus dem Spielclient und den verfügbaren Ressourcen.
- **Fehlerkorrektur bei der Menütext-Normalisierung:** Der zusätzliche Rückgabewert von Lua `string.gsub` wird nicht mehr versehentlich als ungültiger Pfadschritt interpretiert, wodurch zuvor ein notwendiger Menüklick übersprungen werden konnte.
- **Deutsche und englische Lokalisierung:** Die meisten sichtbaren UI-Beschriftungen, Minimap-Tooltips und wichtigen Ablauf-/Statusmeldungen sind zentral in `Localization.lua` hinterlegt. Bei `deDE` werden deutsche Texte verwendet; andere Sprachcodes nutzen englische Texte.
- **Aktualisierte Dokumentation:** Installation, Einrichtung, Ablauf des Menülernens und Fehlerbehebung wurden überarbeitet.

Die reine Navigationsoption wird anhand deutscher und englischer Formulierungen erkannt. Bei anderen Spielsprachen wird die entsprechende Option möglicherweise nicht zuverlässig erkannt. Einige Diagnose-/Laufzeitmeldungen können weiterhin fest codiert sein.
## Überblick

Automatisiert wiederholte Code-Eingaben bei Landro Longshot in World of Warcraft. Das Add-on lernt den von dir gewählten NPC-Dialogpfad, navigiert automatisch durch die benötigten Menüoptionen, erzeugt pro Durchlauf nicht wiederholte zufällige Zahlencodes (5–50 Stellen), trägt jeden Code ein, bestätigt die Eingabe und zeigt den Fortschritt an. Anzahl der Versuche (Standard: 100) und Codelänge (Standard: 25) sind einstellbar. Zwischen den Versuchen musst du Landro erneut ansprechen; das Add-on startet keine neue NPC-Interaktion von selbst. Es erzeugt zufällige Codeversuche, keine bestätigten gültigen Codes; ein Erfolg ist nicht garantiert.

Der Pfad wird über die Dropdowns des Addons festgelegt. Das Addon lernt echte Menüoptionen aus den geöffneten Spiel-Dialogen; es ist nicht auf frei eingetippte oder teilweise übereinstimmende Menünamen angewiesen.

## Funktionen

- Erzeugt pro Durchlauf nicht wiederholte Zufallscodes.
- Konfigurierbare Anzahl von Codeversuchen (Standard: **100**).
- Einstellbare Codelänge von **5 bis 50 Ziffern** (Standard: **25**).
- Lernt hierarchische Menüpfade anhand der tatsächlichen NPC-Gossip-Optionen.
- Legt automatisch den nächsten Pfadpunkt an, wenn eine Auswahl ein echtes Untermenü öffnet.
- Erkennt das tatsächliche Schlüssel-/Code-Eingabefenster als Endpunkt; ein leeres oder noch unbekanntes Menü gilt nicht automatisch als Endpunkt.
- Navigiert den konfigurierten Pfad automatisch, wenn die benötigten Menüs sichtbar oder über Landros Navigationsoption erreichbar sind.
- Bricht bei Pfadänderungen ein veraltetes Codefenster ab und versucht, mit dem zuletzt gewählten Pfad fortzufahren.
- Zeigt Status, Fortschritt, nächsten und vorherigen Code sowie Kopier-Schaltflächen.
- Speichert Einstellungen und gelernte Menüinformationen über Neuladen und erneute Anmeldungen hinweg.
- Öffnet das Addon über das Minimap-Symbol und setzt darüber die gelernten Menüdaten zurück.
- Unterstützt dynamisch wachsende Pfade ohne fest im Addon vorgegebene maximale Tiefe. Praktische Grenzen ergeben sich weiterhin durch WoW-Client und verfügbare Ressourcen.

## Wichtiger Begriff: die Navigationsoption „Weitere Aktionen“

Landro zeigt manchmal zunächst eine kurze Produkt-/Belohnungsliste, bevor die vollständige Aktionsliste verfügbar ist. Auf einem deutschen Spielclient heißt die reine Navigationsoption **„Habt Ihr noch andere Aktionen anzubieten?“**. In dieser Dokumentation wird sie als **Navigationsoption „Weitere Aktionen“** bezeichnet.

Dieser Eintrag ist **kein Pfadschritt**, sondern dient nur der Navigation. Wenn nötig, wählt das Addon ihn aus, öffnet damit die vollständige Aktionsliste und setzt anschließend den im Addon eingestellten Pfad fort. Wähle ihn nicht als eigenen Pfadpunkt.

## Installation

1. Entpacke den Ordner `LandroRandomizedCodeAutomation` aus dem Release-ZIP.
2. Lege ihn im AddOns-Verzeichnis von World of Warcraft ab, bei Retail normalerweise unter `_retail_/Interface/AddOns/`.
3. Prüfe, ob sich `LandroRandomizedCodeAutomation.toc` direkt im Addon-Ordner befindet und die Unterordner `Core/` und `UI/` vorhanden sind.
4. Aktiviere das Addon in der Addon-Liste und lade das Interface neu oder starte das Spiel neu.

Benenne den Ordner nicht um und verschiebe keine einzelnen Lua-Dateien: Die TOC-Datei lädt sie über ihre relativen Pfade.

## Erste Einrichtung und Lernen eines Pfades

1. **Addon öffnen.** Linksklick auf das Minimap-Symbol zeigt das Hauptfenster an oder blendet es aus.
2. **Landro Longshot ansprechen.** Das Addon erkennt den festen Start-/Root-Eintrag und liest das aktuell sichtbare Gossip-Menü.
3. **Punkt 2 im Addon auswählen.** Punkt 1 wird automatisch erkannt und kann nicht als normaler Pfadschritt geändert werden.
4. **Die dynamisch hinzukommenden Punkte auswählen.** Nach deiner Auswahl versucht das Addon, zu diesem Menüpunkt zu navigieren. Öffnet sich ein Untermenü, lernt das Addon dessen Optionen und legt den nächsten Punkt an. Dort wählst du die gewünschte Folgeoption aus.
5. **Auf das echte Code-Eingabefenster warten.** Der Pfad gilt erst als vollständig, nachdem die Erkennung das tatsächliche Schlüssel-/Code-Eingabefenster von Landro gesehen hat. Wenn der Status **„Pfad vollständig – du kannst starten“** anzeigt, wurde der Endpunkt gelernt.
6. **Statusanweisungen beachten.** Beispielsweise kann es erforderlich sein, Landro erneut anzusprechen oder den passenden Gossip-Dialog geöffnet zu lassen. Das ist eine Rückfallanweisung, falls der aktuelle Dialog nicht sicher zugeordnet werden kann; es bedeutet nicht, dass du jeden Menüpunkt manuell konfigurieren musst.

### Einen Pfad ändern

- Ändere den Pfad ausschließlich über die Dropdowns des Addons.
- Wenn du einen übergeordneten Punkt änderst, werden alle späteren Auswahlen gelöscht, weil deren bisherige Eltern-Kind-Beziehung nicht mehr gültig sein muss.
- Das Addon versucht, ein altes Code-Eingabefenster zu schließen und anhand des zuletzt gewählten Pfades erneut zu navigieren.
- Ein Endpunkt wird nicht allein deshalb angenommen, weil keine Folgeoptionen gelernt wurden. Das echte Code-Eingabefenster muss erkannt werden.
- Während die Automatisierung läuft, sind Konfigurationsschaltflächen gesperrt. Stoppe den Vorgang, bevor du den Pfad änderst oder gelernte Daten zurücksetzt.

### Gelerntes zurücksetzen

Wenn du komplett neu lernen möchtest, **stoppe zuerst die Automatisierung** und führe dann einen **Rechtsklick auf das Minimap-Symbol** aus. Dadurch werden gelernte NPC-Menüzweige und Endpunktdaten gelöscht sowie alle Pfadauswahlen nach dem festen Root geleert. Anzahl der Codes, Codelänge, Fensterposition und Minimap-Position bleiben erhalten.

Während die Automatisierung läuft, wird das Zurücksetzen absichtlich verhindert, weil das Löschen der Pfaddaten den aktiven Durchlauf ungültig machen könnte.

## Codeversuche durchführen

1. Stelle **Anzahl Codes** und **Codelänge** ein.
2. Prüfe, ob der Pfad vollständig ist und der Status das Starten erlaubt.
3. Drücke **Start**. Wenn der geöffnete Gossip-Dialog zum ausgewählten Pfad passt, kann das Addon dort fortsetzen. Andernfalls folge der Statusanweisung; wenn möglich, verwendet das Addon automatisch die nötige Navigationsoption.
4. Sobald Landros Code-Eingabefenster geöffnet wird, trägt das Addon den erzeugten Code ein und bestätigt ihn.
5. Nachdem sich das Fenster schließt, zählt der Versuch als abgeschlossen. Anschließend wartet das Addon darauf, dass du Landro für die nächste Iteration erneut ansprichst.
6. Mit **Stop** kannst du vorzeitig beenden. Gelernte Menüs und Endpunkte bleiben erhalten, der Fortschrittszähler wird geleert.

Das Addon startet zwischen den Versuchen nicht selbstständig eine neue NPC-Interaktion. Für jede Iteration musst du Landro erneut ansprechen.

## Minimap-Symbol und Fenstersteuerung

- **Linksklick:** Addon-Fenster öffnen oder schließen.
- **Rechtsklick:** Gelernte NPC-Menüs und Pfadauswahlen zurücksetzen (nur bei gestopptem Ablauf).
- **Ziehen:** Minimap-Symbol um die Minimap verschieben.
- **Esc:** Hauptfenster oder Code-Kopierfenster schließen.
- Für den aktuellen und vorherigen Code gibt es jeweils eine **Kopieren**-Schaltfläche. Im Kopierfenster ist der Text markiert und kann mit Strg+C kopiert werden.

## Stand der Lokalisierung

Die meisten sichtbaren UI-Beschriftungen, Minimap-Tooltips und Ablauf-/Statusmeldungen werden jetzt zentral über `Localization.lua` geladen. Bei der WoW-Spracheinstellung `deDE` erscheinen deutsche Texte; alle anderen Sprachcodes verwenden den englischen Fallback. Das Addon bietet damit eine deutsche und englische Benutzeroberfläche, aber keine vollständige Übersetzung in jede WoW-Sprache.

Die reine Navigationsoption „Weitere Aktionen“ wird anhand deutscher und englischer Formulierungen erkannt. Auf Spielclients mit einer anderen Sprache wird die entsprechende Menüoption möglicherweise nicht zuverlässig erkannt, auch wenn die Addon-Oberfläche englische Texte verwendet.

## Fehlerbehebung

- **Punkt 2 ist nicht auswählbar:** Öffne Landros Startdialog, damit das Addon die realen Menüoptionen lernen kann. Wenn nur die kurze Produktliste angezeigt wird, warte auf die automatische Navigation oder ermögliche dem Addon, die Option „Weitere Aktionen“ zu verwenden.
- **Ein Punkt fordert dazu auf, ein Untermenü zu öffnen:** Der übergeordnete Menüzweig wurde noch nicht gelernt oder der aktuelle Dialog konnte nicht sicher zugeordnet werden. Folge der genauen Statusmeldung und sprich Landro erneut an, falls gefordert.
- **Der Pfad wird nicht als vollständig erkannt:** Wähle die gewünschten Einträge der Reihe nach aus und prüfe, ob die letzte Auswahl wirklich Landros Schlüssel-/Code-Eingabefenster öffnet.
- **Das Addon setzt den Pfad beim geöffneten Dialog nicht fort:** Sprich Landro erneut an oder folge der Statusanweisung. Setze die Lerninformationen nicht zurück, außer du möchtest den gesamten gelernten Menübaum bewusst verwerfen.
- **Lua-Fehler:** Speichere den vollständigen Fehlertext, notiere WoW-Clientversion und die unmittelbar davor ausgeführte Aktion und gib diese Informationen zusammen mit dem Fehler weiter.

Das Addon speichert Konfiguration und gelernte Menüinformationen in der SavedVariables-Tabelle `LLRCA_DB`. Bearbeite oder lösche die SavedVariables-Datei nicht manuell, während das Spiel läuft.
