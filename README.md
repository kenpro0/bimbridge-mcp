# BIMBridge: connect Claude and ChatGPT to Revit

Talk to your Revit model. BIMBridge sets up the **MCP server built into pyRevit 7** in one step, connects it to Claude Desktop (free plan included), Claude Code and ChatGPT, and adds **BIMBridge skills** so the AI works cleanly in your models.

> The bridge between the AI and Revit is the official MCP server of [pyRevit](https://github.com/pyrevitlabs/pyRevit) (pyRevitLabs). BIMBridge adds the one-prompt install, the AI app setup, the skills and the documentation.

## What you get

- **The AI reads your open model**: levels, elements, parameters, views, selection.
- **The AI edits the model** with scripts that run inside Revit, **after you approve them** in Revit (**Keep** to accept, **Discard** to cancel). Each kept change can be undone with a single Ctrl+Z.
- **The AI sees the result** through view captures.
- **BIMBridge skills**: a working method (metric units, staged builds, visual checks) and an MEP review (open connectors, systems, insulation, slopes, circuits).

## Requirements

- Windows 10 or 11, Revit 2022 or newer
- Claude Desktop (free or paid), Claude Code, or the ChatGPT app with Codex
- pyRevit 7 or newer: installed automatically if missing

## Installation

### Option A: one prompt (Claude Pro or higher)

In Claude Desktop, open the **Code** tab (or start Claude Code), then paste:

```
Install BIMBridge to connect Claude to my Revit: https://github.com/kenpro0/bimbridge-mcp
Follow the INSTALL.md file step by step, then tell me what to do next.
```

Claude follows [INSTALL.md](INSTALL.md), a step-by-step guide written for AI agents. It asks before each command, unless you set the permission mode to **Auto**. Windows may also ask permission to install .NET or WebView2 for pyRevit: click **Yes**.

### Option B: one command (free plan, or without Claude Code)

1. Close Revit.
2. Open **PowerShell** (not as administrator) and paste:

```powershell
irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex
```

### Next

1. Start Revit and open a model. If Revit asks about the pyRevit add-in, click **Always Load**. If Revit is already open: **pyRevit > Reload**.
2. Quit your AI app completely and open it again. For Claude Desktop: right-click the Claude icon near the clock, then **Quit**.
3. Start a new chat and try one of the prompts below.

## Prompts to try

- "Use the bimbridge skill and tell me what model is open in Revit right now."
- "Create a 10 × 8 m house with two 3 m levels and a gable roof."
- "Take a 3D capture of the model and tell me what you see."
- "Run an MEP review of my model with the mep-review skill."
- "Select all the ducts that are not in any system."
- "Create the Statue of Liberty in the open model." (attach a few reference photos to the message)

Write in any language: the AI answers in yours.

## How it works

```
Claude / ChatGPT  ⇄  pyRevit MCP server (pyrevit.exe mcp)  ⇄  pyRevit agent in Revit  ⇄  your model
```

- Reading needs no confirmation. Every change shows an approval prompt in Revit, with the changed elements isolated on screen.
- The default policy is `ask` (approve every change). Change it in **pyRevit > Settings > Agent Runtime (MCP)** or from the command line:
  - `pyrevit configs agent policy readonly`: read only
  - `pyrevit configs agent policy ask`: approve every change
  - `pyrevit configs agent policy auto`: no approval (handy for filming a demo; use it only on a copy of the model)

## Security and privacy

- What the AI reads in your model (names, parameters, results) is sent to the AI provider (Anthropic, OpenAI). Check your projects' confidentiality rules before using it on a real project.
- pyRevit keeps the history of the scripts it runs for 14 days in `%APPDATA%\pyRevit\agent`.
- Run your first tests on a copy of your model.

## Included skills

| Skill | What it does |
|---|---|
| `bimbridge` | Working method: metric units, tagged and re-runnable build stages, visual checks with captures, replies in your language |
| `mep-review` | Read-only MEP review: content, open connectors, elements outside any system, list of systems, uninsulated ducts and pipes, drainage slopes, devices without a circuit |

The skills are copied to `%APPDATA%\pyRevit\agent\skills`. You can add your own there (a folder with a `SKILL.md` file).

## Update

Run the install command again. It updates the skills and the configuration without duplicating anything.

## Uninstall

```powershell
irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/uninstall.ps1 | iex
```

This removes the BIMBridge skills and the MCP connections it added, and turns off the pyRevit agent. pyRevit stays installed.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Revit is open" during the install | Close Revit and run the command again. |
| The AI doesn't see the `pyrevit` tools | Quit the app completely (icon near the clock > Quit) and reopen it. |
| "No running Revit" | Start Revit, or click **pyRevit > Reload**. |
| A change seems stuck | Revit is waiting for your approval (**Keep** / **Discard**). |
| Anything else | Open an [issue](../../issues) and attach the file `%TEMP%\bimbridge-install.log`. |

## Credits and license

- MCP server and Revit agent: [pyRevit](https://github.com/pyrevitlabs/pyRevit), by pyRevitLabs (GPL-3.0 license).
- BIMBridge (installer, skills, documentation): MIT license, see [LICENSE](LICENSE).

---

## En français

BIMBridge connecte Claude Desktop (plan gratuit compris), Claude Code et ChatGPT / Codex à Revit grâce au serveur MCP intégré à pyRevit 7, et ajoute les skills BIMBridge.

- **Avec Claude Pro ou plus** : dans l'onglet **Code** de Claude Desktop, collez ce prompt :

  ```
  Installe BIMBridge pour connecter Claude à mon Revit : https://github.com/kenpro0/bimbridge-mcp
  Suis le fichier INSTALL.md étape par étape, puis dis-moi quoi faire ensuite.
  ```

- **Plan gratuit** : fermez Revit, puis collez dans PowerShell : `irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex`

Ensuite, démarrez Revit, quittez complètement Claude et rouvrez-le, puis demandez : « Lis le skill bimbridge, puis décris mon modèle Revit ouvert. » Chaque modification attend votre validation dans Revit (**Keep** / **Discard**), et l'IA vous répond en français.
