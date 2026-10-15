<#
BIMBridge uninstaller

Removes what the BIMBridge installer added: the BIMBridge skills, the pyrevit MCP server
registrations in Claude Desktop, Claude Code and Codex, and turns pyRevit's agent host off.
pyRevit itself stays installed.

Run it in a normal PowerShell window:

    irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/uninstall.ps1 | iex

Set BIMBRIDGE_KEEP_AGENT=1 before running to leave pyRevit's agent host on.
#>

function Uninstall-BIMBridge {
    $ErrorActionPreference = 'Stop'
    $SkillNames = @('bimbridge', 'mep-review')
    $McpName = 'pyrevit'

    function Write-Ok([string]$Text) { Write-Host ('[OK] ' + $Text) -ForegroundColor Green }
    function Write-Note([string]$Text) { Write-Host ('[!!] ' + $Text) -ForegroundColor Yellow }

    function Invoke-Native([string]$Exe, [string[]]$Arguments) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $lines = @()
        $code = 1
        try {
            $lines = @(& $Exe @Arguments 2>&1 | ForEach-Object { $_.ToString() })
            $code = $LASTEXITCODE
        }
        catch {
            $lines = @($_.Exception.Message)
        }
        finally {
            $ErrorActionPreference = $previous
        }
        foreach ($line in $lines) {
            if ($line -and $line.Trim()) { Write-Host ('     ' + $line.TrimEnd()) }
        }
        return $code
    }

    function Write-Utf8File([string]$Path, [string]$Text) {
        [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
    }

    function Find-Tool([string]$Name) {
        $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Path }
        foreach ($folder in @((Join-Path $env:USERPROFILE '.local\bin'), (Join-Path $env:APPDATA 'npm'), (Join-Path $env:USERPROFILE 'scoop\shims'))) {
            foreach ($extension in @('.exe', '.cmd', '.bat')) {
                $candidate = Join-Path $folder ($Name + $extension)
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
        }
        return $null
    }

    function Find-PyRevitExe {
        $candidates = @(
            (Join-Path $env:APPDATA 'pyRevit-Master\bin\pyrevit.exe'),
            (Join-Path $env:ProgramFiles 'pyRevit-Master\bin\pyrevit.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\pyRevit-Master\bin\pyrevit.exe'),
            (Join-Path $env:ProgramFiles 'pyRevit\bin\pyrevit.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\pyRevit\bin\pyrevit.exe')
        )
        $command = Get-Command 'pyrevit.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $candidates = @($command.Path) + $candidates }
        foreach ($candidate in $candidates) {
            if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
        }
        return $null
    }

    $pyrevit = Find-PyRevitExe

    # 1. Claude Code and Codex registrations (through pyRevit, which uses their own commands)
    if ($pyrevit) {
        if (Find-Tool 'claude') {
            if ((Invoke-Native $pyrevit @('mcp', 'uninstall', 'claude')) -eq 0) { Write-Ok 'Removed from Claude Code.' }
        }
        if (Find-Tool 'codex') {
            if ((Invoke-Native $pyrevit @('mcp', 'uninstall', 'codex')) -eq 0) { Write-Ok 'Removed from Codex / ChatGPT.' }
        }
    }

    # 2. Codex config.toml entry added directly by the installer
    $toml = Join-Path $env:USERPROFILE '.codex\config.toml'
    if (Test-Path -LiteralPath $toml) {
        $text = [System.IO.File]::ReadAllText($toml)
        $pattern = '(?ms)^\[mcp_servers\.' + $McpName + '\][^\r\n]*\r?\n.*?(?=^\[|\z)'
        $match = [regex]::Match($text, $pattern)
        if ($match.Success -and $match.Value -match 'pyrevit\.exe') {
            Write-Utf8File $toml ($text.Remove($match.Index, $match.Length))
            Write-Ok 'Removed from .codex\config.toml'
        }
    }

    # 3. Claude Desktop configs
    $paths = @((Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'))
    $packages = Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path -LiteralPath $packages) {
        foreach ($package in @(Get-ChildItem -LiteralPath $packages -Directory -Filter '*Claude*' -ErrorAction SilentlyContinue)) {
            $paths += (Join-Path $package.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json')
        }
    }
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $config = [System.IO.File]::ReadAllText($path) | ConvertFrom-Json
            $servers = $config.mcpServers
            if ($null -ne $servers -and ($servers.PSObject.Properties.Name -contains $McpName)) {
                $command = [string]$servers.$McpName.command
                if ($command -match 'pyrevit\.exe$') {
                    Copy-Item -LiteralPath $path -Destination ($path + '.bimbridge-backup') -Force
                    $servers.PSObject.Properties.Remove($McpName)
                    Write-Utf8File $path ($config | ConvertTo-Json -Depth 64)
                    Write-Ok ('Removed from Claude Desktop: {0}' -f $path)
                }
            }
        }
        catch {
            Write-Note ('Could not update {0}: {1}' -f $path, $_.Exception.Message)
        }
    }

    # 4. Skills
    $pyRevitData = Join-Path $env:APPDATA 'pyRevit'
    if ($env:PYREVIT_PATH_OVERRIDE) { $pyRevitData = $env:PYREVIT_PATH_OVERRIDE }
    $skillsDir = Join-Path $pyRevitData 'agent\skills'
    foreach ($name in $SkillNames) {
        $folder = Join-Path $skillsDir $name
        if (Test-Path -LiteralPath $folder) {
            Remove-Item -LiteralPath $folder -Recurse -Force
            Write-Ok ('Removed skill {0}' -f $name)
        }
    }

    # 5. Agent host
    if ($pyrevit) {
        $otherSkills = @()
        if (Test-Path -LiteralPath $skillsDir) { $otherSkills = @(Get-ChildItem -LiteralPath $skillsDir -Directory) }
        if ($otherSkills.Count -eq 0) {
            [void](Invoke-Native $pyrevit @('configs', 'agent', 'skills', 'disable'))
        }
        else {
            Write-Note 'Other user skills are still in the skills folder: user skills stay on.'
        }
        if ($env:BIMBRIDGE_KEEP_AGENT -eq '1') {
            Write-Note 'pyRevit agent host left on (BIMBRIDGE_KEEP_AGENT=1).'
        }
        else {
            [void](Invoke-Native $pyrevit @('configs', 'agent', 'disable'))
            Write-Ok 'pyRevit agent host turned off. Turn it back on with: pyrevit configs agent enable'
        }
    }

    Write-Host ''
    Write-Ok 'BIMBridge removed. pyRevit is still installed (remove it from Windows Settings > Apps if you want).'
    Write-Host 'Restart Revit and your AI app to apply.'
}

try {
    Uninstall-BIMBridge
}
catch {
    Write-Host ('[XX] Unexpected error: {0}' -f $_.Exception.Message) -ForegroundColor Red
}
