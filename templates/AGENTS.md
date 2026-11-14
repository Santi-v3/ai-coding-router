# Projektregeln fuer KI-Agenten

- Nutze den zentralen Router unter `C:\Users\santi\Documents\Santi KI Router\Santi-KI-Router.ps1`, wenn Aufgaben an andere Modelle delegiert werden sollen.
- Einfache und mittlere, klar abgegrenzte Arbeiten duerfen an kostenlose Modelle gehen.
- Schwierige Arbeiten gehen an Claude oder Codex und erhalten eine unabhaengige Pruefung.
- Kritische Arbeiten (Treiber, Kernel, Registry, Authentifizierung, Geheimnisse, Sicherheit, Zahlungen oder Produktion) bleiben im Plan-Modus und brauchen eine menschliche Freigabe.
- Keine Lizenz-, Abo-, Aktivierungs- oder Zugangskontrollen umgehen.
- Keine Zugangsdaten in Prompts, Logs oder Commits schreiben.
- Bestehende Aenderungen respektieren. Nach Schreibzugriff die passenden Builds und Tests ausfuehren.
- Router-Vorschau: `& 'C:\Users\santi\Documents\Santi KI Router\Santi-KI-Router.ps1' -Project $PWD -Task '<Aufgabe>'`
- Explizite Ausfuehrung: dieselbe Zeile mit `-Mode apply`; fuer Planung `-Mode plan`.
