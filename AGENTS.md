# Agent instructions

If you were asked to install BIMBridge or connect an AI app to Revit, follow [INSTALL.md](INSTALL.md).

Repository layout:

- `install.ps1`, `uninstall.ps1`: Windows PowerShell 5.1+ scripts. Keep them ASCII-only and compatible with Windows PowerShell 5.1 (no `??`, no ternary, no `&&`).
- `skills/<name>/SKILL.md`: skills for pyRevit's agent runtime. Front matter needs `name` (lowercase letters, digits, dashes) and `description` (240 characters at most). Python examples must run on IronPython 2.7, so no f-strings.
- `README.md`: user documentation, in English with a short French section.
