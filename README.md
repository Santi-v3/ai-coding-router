# AI Coding Router

A PowerShell prototype that classifies development tasks and selects a local coding-assistant workflow. It explores how task complexity, review and human approval can guide developer automation.

## What it does

The router reads `router.config.json`, classifies a task using configured keywords or an explicit tier, and proposes a worker and verification route. Its default mode shows the route without applying changes. Plan and apply modes depend on locally installed and authenticated `opencode`, `claude` or `codex` clients. A separate installer adds small policy templates to a target project without overwriting existing files. Runs are written to the target project's `.agent-runs/` directory.

This is a personal prototype: model names and free-provider availability are configuration examples, not guarantees of current access, quality or price.

## Structure

- `Santi-KI-Router.ps1`: classification, routing and execution modes.
- `router.config.json`: tiers, keywords and provider candidates.
- `Install-ProjectPolicy.ps1`: opt-in project policy templates.
- `templates/`: the policy files installed in a selected project.
- `Start-Router.cmd`: Windows command launcher.

## Use

Requires PowerShell 5.1+ and at least one configured coding client for actual execution. Review the script and target project before enabling apply mode.

```powershell
& './Santi-KI-Router.ps1' -Project 'C:\path\to\project' -Task 'Add an export button'
& './Santi-KI-Router.ps1' -Project 'C:\path\to\project' -Task 'Analyze the architecture' -Mode plan
& './Install-ProjectPolicy.ps1' -Project 'C:\path\to\project'
```

Critical tasks are intended for review and human approval. This routing policy is not a security sandbox. Do not put credentials, customer data or confidential code into task descriptions sent to external providers.

## Status and verification

Prototype. There is no automated test suite or CI workflow in this repository; commands were checked against the repository files but were not executed in this environment because PowerShell and the coding clients are unavailable here.

## License and author

MIT; see [LICENSE](LICENSE). Created by **Santino Burkhardt** as a personal developer automation project, independent of his employer.
