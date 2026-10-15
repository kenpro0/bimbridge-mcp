# BIMBridge: install guide for AI agents

This file is for an AI agent (Claude Code, Codex, or similar) asked to install BIMBridge on the user's Windows PC. Follow it step by step and keep the user informed in their own language.

## What gets installed

- **pyRevit 7 or newer**, only if it is missing or older. Its built-in MCP server (`pyrevit mcp`) is what connects AI apps to Revit.
- **pyRevit's agent host**, turned on, and **pyRevit user skills**, turned on.
- **The BIMBridge skills** (`bimbridge`, `mep-review`), copied to `%APPDATA%\pyRevit\agent\skills`.
- **The `pyrevit` MCP server**, registered with Claude Desktop, and with Claude Code and Codex / ChatGPT when they are installed.

The installer never changes other MCP servers. It backs up the Claude Desktop config (`claude_desktop_config.json.bimbridge-backup`) before editing it.

## Step 1. Tell the user two things

1. If pyRevit has to be installed or updated, Revit must be closed. Ask the user to save their work and close Revit before you continue.
2. Windows may ask for permission to install .NET or WebView2, which pyRevit needs. The user should click **Yes**.

## Step 2. Run the installer

Run this in PowerShell as the normal user, not as administrator. Downloading pyRevit can take several minutes, so give the command a long timeout (10 minutes):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex"
```

Read the whole output:

- `[OK]` a step worked.
- `[..]` a step is running.
- `[!!]` a warning. Read it: some need the user.
- `[XX]` an error. The installer stopped. Fix the cause (see Troubleshooting), then run the same command again. Running it twice is safe.

The installer saves a full log to `%TEMP%\bimbridge-install.log`.

## Step 3. Check the result

```powershell
pyrevit agent status
```

Expected first line: `Agent host: enabled (policy: ask, default engine: ..., user skills: enabled)`. "No running Revit with the agent host" is normal until Revit is started.

If `pyrevit` is not found in this shell, use the full path: `%APPDATA%\pyRevit-Master\bin\pyrevit.exe`.

## Step 4. Tell the user what to do next

1. Start Revit and open a model. If Revit is already open, click **pyRevit > Reload**.
2. Quit the AI app completely and open it again, so it loads the new MCP server.
   - Claude Desktop: right-click the Claude icon near the clock, then **Quit**.
   - Claude Code: start a new session.
   - ChatGPT desktop app: quit and reopen it.
3. In a new chat, try: « Lis le skill bimbridge, puis décris mon modèle Revit ouvert. » (or in English: "Read the bimbridge skill, then describe my open Revit model.")
4. When the AI changes the model, Revit shows an approval prompt first: **Keep** or **Discard**. Each kept change is one undo step.

You are probably running in the session that did the install: the `pyrevit` tools only appear after the restart.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `[XX] Revit is open` | Ask the user to save and close Revit, then run the installer again. |
| pyRevit download or install fails | The network may block GitHub. Ask the user to install pyRevit 7+ by hand from https://github.com/pyrevitlabs/pyRevit/releases (file `pyRevit_<version>_signed.exe`), then run the installer again. |
| `Claude Code command not found` | Normal when the user only has Claude Desktop. If they install Claude Code later, run `pyrevit mcp install claude`. |
| Claude Desktop config is not valid JSON | The installer leaves it untouched and prints the entry to add. Fix `%APPDATA%\Claude\claude_desktop_config.json`, then run the installer again. |
| No `pyrevit` tools after the restart | Check that the Claude Desktop config has `mcpServers.pyrevit` with `"args": ["mcp"]` and a `command` pointing to `pyrevit.exe`. Read `%APPDATA%\Claude\logs\mcp-server-pyrevit.log`. |
| Tools say no Revit is running | Revit isn't open, or pyRevit wasn't reloaded after the agent host was turned on. Run `pyrevit agent status`. |
| Revit version missing from `pyrevit attached` | pyRevit isn't loaded in that Revit. Run `pyrevit attach master default --installed`, then restart Revit. |
| `get_skill("bimbridge")` says the skill doesn't exist | Run `pyrevit configs agent skills enable`, check that `%APPDATA%\pyRevit\agent\skills\bimbridge\SKILL.md` exists, restart the AI app. |
| A change seems stuck | Revit is waiting for the user's approval (Keep / Discard). |

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/uninstall.ps1 | iex"
```

It removes the BIMBridge skills and the MCP registrations, and turns the agent host off. pyRevit stays installed.

## Rules

- Never run anything as administrator.
- Don't change the agent policy (`ask` by default) unless the user asks.
- Don't edit or remove other MCP servers in any config file.
- Don't install anything that this guide doesn't list.
