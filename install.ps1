<#
BIMBridge installer

Connects Claude Desktop (free plan included), Claude Code and ChatGPT / Codex to Revit
through the MCP server built into pyRevit 7, and installs the BIMBridge skills.

Run it in a normal PowerShell window (not as administrator):

    irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex

Running it again is safe: it updates the skills and the configuration without duplicating them.

Optional environment variables, set before running:
    BIMBRIDGE_REPO                 GitHub repo to take the skills from (default kenpro0/bimbridge-mcp)
    BIMBRIDGE_BRANCH               Branch to take the skills from (default main)
    BIMBRIDGE_NO_PYREVIT_INSTALL   Set to 1 to never install or update pyRevit
#>

function Install-BIMBridge {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $BridgeVersion = '0.1.0'
    $Repo = 'kenpro0/bimbridge-mcp'
    if ($env:BIMBRIDGE_REPO) { $Repo = $env:BIMBRIDGE_REPO }
    $Branch = 'main'
    if ($env:BIMBRIDGE_BRANCH) { $Branch = $env:BIMBRIDGE_BRANCH }
    $SkillNames = @('bimbridge', 'mep-review')
    $McpName = 'pyrevit'
    $MinimumPyRevitMajor = 7

    function Write-Step([string]$Text) { Write-Host ('[..] ' + $Text) -ForegroundColor Cyan }
    function Write-Ok([string]$Text) { Write-Host ('[OK] ' + $Text) -ForegroundColor Green }
    function Write-Note([string]$Text) { Write-Host ('[!!] ' + $Text) -ForegroundColor Yellow }
    function Write-Fail([string]$Text) { Write-Host ('[XX] ' + $Text) -ForegroundColor Red }

    # Runs a native program, shows its output indented, returns its exit code.
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
            $code = 1
        }
        finally {
            $ErrorActionPreference = $previous
        }
        foreach ($line in $lines) {
            if ($line -and $line.Trim()) { Write-Host ('     ' + $line.TrimEnd()) }
        }
        return $code
    }

    function Get-NativeText([string]$Exe, [string[]]$Arguments) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $text = (& $Exe @Arguments 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
            return @{ Code = $LASTEXITCODE; Text = $text }
        }
        catch {
            return @{ Code = 1; Text = $_.Exception.Message }
        }
        finally {
            $ErrorActionPreference = $previous
        }
    }

    function Write-Utf8File([string]$Path, [string]$Text) {
        $folder = Split-Path -Parent $Path
        if ($folder -and -not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
    }

    function Test-IsAdmin {
        try {
            $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            return $false
        }
    }

    function Get-RevitYears {
        $years = @()
        foreach ($year in 2019..2032) {
            $exe = Join-Path $env:ProgramFiles ('Autodesk\Revit {0}\Revit.exe' -f $year)
            if (Test-Path -LiteralPath $exe) { $years += $year }
        }
        return $years
    }

    function Find-Tool([string]$Name) {
        $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Path }
        $folders = @(
            (Join-Path $env:USERPROFILE '.local\bin'),
            (Join-Path $env:APPDATA 'npm'),
            (Join-Path $env:USERPROFILE 'scoop\shims')
        )
        foreach ($folder in $folders) {
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
            if ($candidate -and (Test-Path -LiteralPath $candidate)) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
        return $null
    }

    function Get-PyRevitVersionText([string]$Exe) {
        try {
            $info = (Get-Item -LiteralPath $Exe).VersionInfo
            $text = [string]$info.ProductVersion
            if (-not $text) { $text = [string]$info.FileVersion }
            $match = [regex]::Match($text, '\d+\.\d+\.\d+')
            if ($match.Success) { return ('pyRevit ' + $match.Value) }
        }
        catch { }
        return 'pyRevit'
    }

    # pyRevit 7+ has the agent runtime: "pyrevit configs agent" prints "Agent host is ...".
    function Test-AgentSupport([string]$Exe) {
        $run = Get-NativeText $Exe @('configs', 'agent')
        return ($run.Code -eq 0 -and $run.Text -match 'Agent host')
    }

    function Install-PyRevit {
        $temp = Join-Path $env:TEMP ('bimbridge-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $installer = $null
        try {
            Write-Step 'Looking for the latest pyRevit release on GitHub...'
            $headers = @{ 'User-Agent' = 'bimbridge-installer'; 'Accept' = 'application/vnd.github+json' }
            # Assign first: Windows PowerShell 5.1 writes a JSON array as one object.
            $response = Invoke-RestMethod -Uri 'https://api.github.com/repos/pyrevitlabs/pyRevit/releases?per_page=20' -Headers $headers
            $releases = @($response)
            $stable = @($releases | Where-Object { -not $_.draft -and -not $_.prerelease })
            $preview = @($releases | Where-Object { -not $_.draft -and $_.prerelease })
            $picked = $null
            foreach ($release in ($stable + $preview)) {
                foreach ($asset in @($release.assets)) {
                    $match = [regex]::Match([string]$asset.name, '^pyRevit_(\d+)\.[0-9.]+_signed\.exe$')
                    if ($match.Success -and [int]$match.Groups[1].Value -ge $MinimumPyRevitMajor) {
                        $picked = $asset
                        break
                    }
                }
                if ($picked) { break }
            }
            if ($picked) {
                $installer = Join-Path $temp $picked.name
                Write-Step ('Downloading {0}...' -f $picked.name)
                Invoke-WebRequest -Uri $picked.browser_download_url -OutFile $installer -UseBasicParsing
            }
            else {
                Write-Note 'No pyRevit 7 installer found in the GitHub releases.'
            }
        }
        catch {
            Write-Note ('GitHub download failed: {0}' -f $_.Exception.Message)
            $installer = $null
        }

        if ($installer -and (Test-Path -LiteralPath $installer)) {
            Write-Step 'Installing pyRevit. Windows may ask permission to install .NET or WebView2: click Yes.'
            $process = Start-Process -FilePath $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-') -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                Write-Note ('The pyRevit installer ended with code {0}.' -f $process.ExitCode)
            }
        }
        else {
            $winget = Find-Tool 'winget'
            if ($winget) {
                Write-Step 'Installing pyRevit with winget...'
                [void](Invoke-Native $winget @('install', '--id', 'pyRevit.pyRevit', '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements'))
            }
        }
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }

    function Get-SkillsSource {
        if ($PSScriptRoot) {
            $local = Join-Path $PSScriptRoot 'skills'
            if (Test-Path -LiteralPath (Join-Path $local 'bimbridge\SKILL.md')) {
                return $local
            }
        }
        $temp = Join-Path $env:TEMP ('bimbridge-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $zip = Join-Path $temp 'bimbridge.zip'
        $url = 'https://github.com/{0}/archive/refs/heads/{1}.zip' -f $Repo, $Branch
        Write-Step ('Downloading the BIMBridge skills from {0}...' -f $Repo)
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        try {
            Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
        }
        catch {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $temp)
        }
        $root = Get-ChildItem -LiteralPath $temp -Directory | Select-Object -First 1
        if (-not $root) { throw 'The downloaded archive is empty.' }
        return (Join-Path $root.FullName 'skills')
    }

    function Get-ClaudeDesktopConfigPaths {
        $paths = @((Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'))
        $packages = Join-Path $env:LOCALAPPDATA 'Packages'
        if (Test-Path -LiteralPath $packages) {
            foreach ($package in @(Get-ChildItem -LiteralPath $packages -Directory -Filter '*Claude*' -ErrorAction SilentlyContinue)) {
                $candidate = Join-Path $package.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json'
                if (Test-Path -LiteralPath $candidate) { $paths += $candidate }
            }
        }
        return $paths
    }

    # Adds or updates mcpServers.pyrevit in a Claude Desktop config, keeping everything else.
    function Set-ClaudeDesktopEntry([string]$Path, [string]$Exe) {
        $raw = ''
        if (Test-Path -LiteralPath $Path) { $raw = [System.IO.File]::ReadAllText($Path) }
        if ($raw.Trim().Length -gt 0) {
            try {
                $config = $raw | ConvertFrom-Json
            }
            catch {
                Write-Note ('{0} is not valid JSON, left untouched. Add this under "mcpServers" by hand: "{1}": {{ "command": "{2}", "args": ["mcp"] }}' -f $Path, $McpName, $Exe.Replace('\', '\\'))
                return $false
            }
            if ($config -isnot [System.Management.Automation.PSCustomObject]) {
                Write-Note ('{0} has an unexpected format, left untouched.' -f $Path)
                return $false
            }
            # Keep the user's original config: back it up only once.
            $backup = $Path + '.bimbridge-backup'
            if (-not (Test-Path -LiteralPath $backup)) {
                Copy-Item -LiteralPath $Path -Destination $backup
            }
        }
        else {
            $config = New-Object PSObject
        }

        if (-not ($config.PSObject.Properties.Name -contains 'mcpServers') -or $null -eq $config.mcpServers) {
            $config | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value (New-Object PSObject) -Force
        }
        $entry = New-Object PSObject
        $entry | Add-Member -MemberType NoteProperty -Name 'command' -Value $Exe
        $entry | Add-Member -MemberType NoteProperty -Name 'args' -Value @('mcp')
        $config.mcpServers | Add-Member -MemberType NoteProperty -Name $McpName -Value $entry -Force

        Write-Utf8File $Path ($config | ConvertTo-Json -Depth 64)
        return $true
    }

    # Adds [mcp_servers.pyrevit] to Codex's config.toml when the codex command is not available.
    function Set-CodexTomlEntry([string]$Exe) {
        $path = Join-Path $env:USERPROFILE '.codex\config.toml'
        $text = ''
        if (Test-Path -LiteralPath $path) { $text = [System.IO.File]::ReadAllText($path) }
        if ($text -match ('(?m)^\s*\[mcp_servers\.' + $McpName + '\]')) {
            return 'exists'
        }
        if ($Exe.Contains("'")) {
            $command = '"' + $Exe.Replace('\', '\\').Replace('"', '\"') + '"'
        }
        else {
            $command = "'" + $Exe + "'"
        }
        $block = "[mcp_servers.$McpName]`ncommand = $command`nargs = [`"mcp`"]`n"
        if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += "`n" }
        if ($text.Length -gt 0) { $text += "`n" }
        Write-Utf8File $path ($text + $block)
        return 'added'
    }

    # ---------------------------------------------------------------- start
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch { }

    Write-Host ''
    Write-Host ('BIMBridge installer {0}: Claude and ChatGPT connected to Revit through pyRevit' -f $BridgeVersion) -ForegroundColor White
    Write-Host ''

    if ($env:OS -ne 'Windows_NT') {
        Write-Fail 'BIMBridge needs Windows (Revit runs only on Windows).'
        return
    }
    if (Test-IsAdmin) {
        Write-Note 'This window runs as administrator. If you are not the only user of this PC, run the installer again from a normal PowerShell window so everything is set up for your own account.'
    }

    # 1. Revit
    $years = @(Get-RevitYears)
    if ($years.Count -gt 0) {
        Write-Ok ('Revit found: {0}' -f ($years -join ', '))
    }
    else {
        Write-Note 'No Revit found in Program Files. Continuing: pyRevit will attach to Revit once it is installed.'
    }

    # 2. pyRevit 7+
    $pyrevit = Find-PyRevitExe
    $hasAgent = $false
    if ($pyrevit) { $hasAgent = Test-AgentSupport $pyrevit }

    if ($pyrevit -and $hasAgent) {
        Write-Ok ('{0} found, with its MCP server: {1}' -f (Get-PyRevitVersionText $pyrevit), $pyrevit)
    }
    else {
        if ($pyrevit) {
            Write-Note ('{0} has no MCP server: BIMBridge needs pyRevit {1} or newer.' -f (Get-PyRevitVersionText $pyrevit), $MinimumPyRevitMajor)
        }
        else {
            Write-Note 'pyRevit is not installed.'
        }
        if ($env:BIMBRIDGE_NO_PYREVIT_INSTALL -eq '1') {
            Write-Fail ('Install pyRevit {0}+ from https://github.com/pyrevitlabs/pyRevit/releases, then run this installer again.' -f $MinimumPyRevitMajor)
            return
        }
        if (Get-Process -Name 'Revit' -ErrorAction SilentlyContinue) {
            Write-Fail 'Revit is open. Save your work, close Revit, then run this installer again.'
            return
        }
        Install-PyRevit
        $pyrevit = Find-PyRevitExe
        if (-not $pyrevit -or -not (Test-AgentSupport $pyrevit)) {
            Write-Fail ('pyRevit {0}+ could not be installed automatically. Install it from https://github.com/pyrevitlabs/pyRevit/releases (file pyRevit_<version>_signed.exe), then run this installer again.' -f $MinimumPyRevitMajor)
            return
        }
        Write-Ok ('{0} installed: {1}' -f (Get-PyRevitVersionText $pyrevit), $pyrevit)
    }

    # 3. Agent host and user skills
    Write-Step 'Turning on the pyRevit agent host (the MCP bridge inside Revit)...'
    if ((Invoke-Native $pyrevit @('configs', 'agent', 'enable')) -ne 0) {
        Write-Fail 'Could not turn on the agent host. Try: pyrevit configs agent enable'
        return
    }
    if ((Invoke-Native $pyrevit @('configs', 'agent', 'skills', 'enable')) -ne 0) {
        Write-Note 'Could not turn on user skills. Try: pyrevit configs agent skills enable'
    }
    Write-Ok 'Agent host and user skills are on.'

    # 4. BIMBridge skills
    $pyRevitData = Join-Path $env:APPDATA 'pyRevit'
    if ($env:PYREVIT_PATH_OVERRIDE) { $pyRevitData = $env:PYREVIT_PATH_OVERRIDE }
    $skillsTarget = Join-Path $pyRevitData 'agent\skills'
    try {
        $skillsSource = Get-SkillsSource
        New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null
        $installed = @()
        foreach ($name in $SkillNames) {
            $source = Join-Path $skillsSource $name
            if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
                Write-Note ('Skill "{0}" is missing from the download, skipped.' -f $name)
                continue
            }
            $target = Join-Path $skillsTarget $name
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
            $installed += $name
        }
        Write-Ok ('Skills installed in {0}: {1}' -f $skillsTarget, ($installed -join ', '))
    }
    catch {
        Write-Note ('Could not install the BIMBridge skills: {0}. The connection to Revit still works without them.' -f $_.Exception.Message)
    }

    # 5. MCP clients
    $configured = @()

    $claudeCli = Find-Tool 'claude'
    if ($claudeCli) {
        Write-Step 'Registering the pyrevit MCP server with Claude Code...'
        if ((Invoke-Native $pyrevit @('mcp', 'install', 'claude')) -eq 0) {
            Write-Ok 'Claude Code: done (user scope).'
            $configured += 'Claude Code'
        }
        else {
            Write-Note 'Claude Code registration failed. Try later: pyrevit mcp install claude'
        }
    }
    else {
        Write-Note 'Claude Code command not found: skipped (normal if you only use Claude Desktop).'
    }

    $desktopFound = (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Claude')) -or (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'AnthropicClaude'))
    $desktopDone = $false
    foreach ($path in @(Get-ClaudeDesktopConfigPaths)) {
        try {
            if (Set-ClaudeDesktopEntry $path $pyrevit) {
                Write-Ok ('Claude Desktop: {0}' -f $path)
                $desktopDone = $true
            }
        }
        catch {
            Write-Note ('Could not update {0}: {1}' -f $path, $_.Exception.Message)
        }
    }
    if ($desktopDone -and $desktopFound) {
        $configured += 'Claude Desktop'
    }
    elseif ($desktopDone) {
        Write-Note 'Claude Desktop is not installed yet: its config is ready for when you install it (claude.ai/download).'
    }

    $codexCli = Find-Tool 'codex'
    if ($codexCli) {
        Write-Step 'Registering the pyrevit MCP server with Codex (ChatGPT)...'
        if ((Invoke-Native $pyrevit @('mcp', 'install', 'codex')) -eq 0) {
            Write-Ok 'Codex / ChatGPT: done.'
            $configured += 'ChatGPT / Codex'
        }
        else {
            Write-Note 'Codex registration failed. Try later: pyrevit mcp install codex'
        }
    }
    elseif (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.codex')) {
        try {
            $state = Set-CodexTomlEntry $pyrevit
            if ($state -eq 'added') { Write-Ok 'ChatGPT / Codex: added to .codex\config.toml' }
            else { Write-Ok 'ChatGPT / Codex: already configured.' }
            $configured += 'ChatGPT / Codex'
        }
        catch {
            Write-Note ('Could not update .codex\config.toml: {0}' -f $_.Exception.Message)
        }
    }

    # 6. Status
    Write-Step 'Revit versions pyRevit is attached to:'
    [void](Invoke-Native $pyrevit @('attached'))
    Write-Step 'pyRevit agent status:'
    [void](Invoke-Native $pyrevit @('agent', 'status'))

    Write-Host ''
    if ($configured.Count -gt 0) {
        Write-Ok ('BIMBridge is installed. Connected apps: {0}' -f ($configured -join ', '))
    }
    else {
        Write-Note 'pyRevit and the skills are ready, but no AI app was found. Install Claude Desktop (claude.ai/download), then run this installer again.'
    }
    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor White
    Write-Host '  1. Start Revit and open a model. If Revit is already open, click pyRevit > Reload.'
    Write-Host '  2. Quit your AI app completely and open it again.'
    Write-Host '     Claude Desktop: right-click the Claude icon near the clock > Quit. Claude Code: start a new session.'
    Write-Host '  3. Try: "Lis le skill bimbridge, puis decris mon modele Revit ouvert."'
    Write-Host '     or:  "Read the bimbridge skill, then describe my open Revit model."'
    Write-Host '  4. When Claude changes the model, Revit asks you first: Keep or Discard.'
    Write-Host ''
}

$bimbridgeLog = Join-Path $env:TEMP 'bimbridge-install.log'
$bimbridgeTranscript = $false
try {
    Start-Transcript -Path $bimbridgeLog -Force | Out-Null
    $bimbridgeTranscript = $true
}
catch { }
try {
    Install-BIMBridge
}
catch {
    Write-Host ('[XX] Unexpected error: {0}' -f $_.Exception.Message) -ForegroundColor Red
}
finally {
    if ($bimbridgeTranscript) {
        try { Stop-Transcript | Out-Null } catch { }
        Write-Host ('Install log: {0}' -f $bimbridgeLog)
    }
}
