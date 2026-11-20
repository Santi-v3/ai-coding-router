# Santi KI Router — Multi-Agent Workflow Routing

> A local PowerShell-based router for assigning development tasks to AI coding assistants based on complexity, verification needs and approval requirements.

**Focus:** AI Orchestration · Developer Automation · PowerShell · Human-in-the-loop Controls

**Problem and approach:** Different AI development tools have different capabilities and usage limits. This prototype routes tasks according to their risk and complexity, while reserving critical modifications for secondary review and human approval.

**Maturity:** Personal development prototype. The actual providers available depend on local installations and service access.

---

## Setup, routing and usage

Ein lokaler, projektunabhaengiger Aufgaben-Router fuer Claude Code, Codex und kostenlose OpenCode-Modelle.

## Routing

| Schwierigkeit | Primaer | Pruefung |
| --- | --- | --- |
| einfach | kostenloses Modell | automatische Projekt-Verifikation |
| mittel | staerkeres kostenloses Modell | unabhaengiges kostenloses Review |
| schwierig | Claude Sonnet oder Codex | jeweils die andere Haupt-KI |
| kritisch | Claude/Codex nur im Plan-Modus | zweite Haupt-KI + menschliche Freigabe |

Kritische Aufgaben werden nie automatisch angewendet. Aufgaben zur Umgehung von Lizenzen, Abos, Aktivierung oder Zugangskontrollen werden abgelehnt.

## Verwendung

Die sichere Standardeinstellung zeigt nur die Route an:

```powershell
& '.\Santi-KI-Router.ps1' -Project 'C:\Pfad\zum\Projekt' -Task 'Fuege einen Export-Button hinzu'
```

Plan erstellen oder Aenderungen anwenden:

```powershell
& '.\Santi-KI-Router.ps1' -Project 'C:\Pfad\zum\Projekt' -Task 'Analysiere die Architektur' -Mode plan
& '.\Santi-KI-Router.ps1' -Project 'C:\Pfad\zum\Projekt' -Task 'Ergaenze einen kleinen Test' -Mode apply
```

Route gezielt steuern:

```powershell
& '.\Santi-KI-Router.ps1' -Project $PWD -Task 'Aufgabe' -Tier hard -MainAI codex -Mode plan
& '.\Santi-KI-Router.ps1' -Project $PWD -Task 'Aufgabe' -Tier hard -MainAI claude -Mode plan
```

## Neues Projekt anbinden

```powershell
& '.\Install-ProjectPolicy.ps1' -Project 'C:\Pfad\zum\Projekt'
```

Das installiert kleine `AGENTS.md`- und `CLAUDE.md`-Dateien in das Projekt. Vorhandene Dateien werden nicht ueberschrieben.

## Voraussetzungen

- PowerShell 5.1 oder neuer
- mindestens einer der Clients: `opencode`, `claude`, `codex`
- Anmeldung beim jeweiligen Dienst, wenn Claude oder Codex genutzt wird

Alle Laufprotokolle landen im Zielprojekt unter `.agent-runs/`. Geheimnisse gehoeren weder in Aufgaben noch in Commits.
