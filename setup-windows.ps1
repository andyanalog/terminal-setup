<#
  Omarchy-style terminal setup for Windows
  ----------------------------------------
  Tokyo Night Windows Terminal, CaskaydiaMono Nerd Font, Starship prompt,
  Linux-style commands (ls, cat, grep, rm -rf...), eza/bat/fzf/zoxide,
  lazygit, lazydocker and LazyVim.

  Run from any PowerShell window:
      powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1

  Safe to re-run: installed tools are skipped and settings are backed up.
#>

$ErrorActionPreference = 'Stop'
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Info($m) { Write-Host "    $m" -ForegroundColor DarkGray }
function Warn($m) { Write-Host "    ! $m" -ForegroundColor Yellow }
function Write-Utf8NoBom($path, $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Add-UserPath($dir) {
    $up = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($up -split ';') -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', ($up.TrimEnd(';') + ";$dir"), 'User')
    }
}

# Store apps (winget, pwsh) live here; it is sometimes missing from PATH
$windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
Add-UserPath $windowsApps
Refresh-Path

# ─────────────────────────────────────────────────────────────
Step 'Installing tools with winget'
$winget = Join-Path $windowsApps 'winget.exe'
if (-not (Test-Path $winget)) { throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run." }

$packages = @(
    'Git.Git', 'Microsoft.WindowsTerminal', 'Microsoft.PowerShell',
    'Starship.Starship', 'eza-community.eza', 'sharkdp.bat', 'junegunn.fzf', 'ajeetdsouza.zoxide',
    'Fastfetch-cli.Fastfetch', 'aristocratos.btop4win',
    'JesseDuffield.lazygit', 'JesseDuffield.Lazydocker',
    'Neovim.Neovim', 'BurntSushi.ripgrep.MSVC', 'sharkdp.fd', 'zig.zig'
)
foreach ($id in $packages) {
    & $winget list --id $id -e --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) { Info "$id (already installed)"; continue }
    & $winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -eq 0) { Info "$id installed" } else { Warn "$id failed (exit $LASTEXITCODE)" }
}
Refresh-Path

# ─────────────────────────────────────────────────────────────
Step 'Installing tree-sitter CLI (needed by LazyVim)'
$localBin = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force $localBin | Out-Null
Add-UserPath $localBin
Refresh-Path
if (Get-Command tree-sitter -ErrorAction SilentlyContinue) {
    Info 'already installed'
} else {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $gz = Join-Path $env:TEMP 'tree-sitter.gz'
    try {
        Invoke-WebRequest "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-windows-$arch.gz" -OutFile $gz -UseBasicParsing
        $in = [IO.File]::OpenRead($gz)
        $out = [IO.File]::Create("$localBin\tree-sitter.exe")
        $unzip = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $unzip.CopyTo($out); $unzip.Dispose(); $out.Dispose(); $in.Dispose()
        Info 'installed'
    } catch {
        if (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g tree-sitter-cli | Out-Null; Info 'installed with npm' }
        else { Warn "could not install tree-sitter: $($_.Exception.Message)" }
    }
}

# ─────────────────────────────────────────────────────────────
Step 'Installing CaskaydiaMono Nerd Font'
$fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$hasFont = (Get-ItemProperty $fontReg -ErrorAction SilentlyContinue).PSObject.Properties.Name -match 'CaskaydiaMono' -or
           (Test-Path 'C:\Windows\Fonts\CaskaydiaMonoNerdFont-Regular.ttf')
if ($hasFont) {
    Info 'already installed'
} else {
    $tmp = Join-Path $env:TEMP 'nf-caskaydia'
    New-Item -ItemType Directory -Force $tmp | Out-Null
    Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip' -OutFile "$tmp\font.zip" -UseBasicParsing
    Expand-Archive "$tmp\font.zip" "$tmp\x" -Force
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    if (-not (Test-Path $fontReg)) { New-Item $fontReg -Force | Out-Null }
    Get-ChildItem "$tmp\x" -Filter 'CaskaydiaMonoNerdFont-*.ttf' | ForEach-Object {
        Copy-Item $_.FullName $fontDir -Force
        New-ItemProperty -Path $fontReg -Name "$($_.BaseName) (TrueType)" -Value (Join-Path $fontDir $_.Name) -PropertyType String -Force | Out-Null
    }
    Info 'installed'
}

# ─────────────────────────────────────────────────────────────
Step 'Writing Starship prompt config (~\.config\starship.toml)'
$starshipToml = @'
# Omarchy-style minimal prompt (Tokyo Night)
add_newline = true
command_timeout = 300
format = "$directory$git_branch$git_status$python$conda$cmd_duration$line_break$character"

[character]
success_symbol = "[❯](bold cyan)"
error_symbol = "[✗](bold red)"

[directory]
style = "bold blue"
truncation_length = 3
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
format = "[$symbol$branch]($style) "
style = "italic purple"

[git_status]
format = '[$all_status$ahead_behind]($style)'
style = "cyan"
ahead = "⇡${count} "
behind = "⇣${count} "
diverged = "⇕ "
conflicted = " "
up_to_date = ""
untracked = "? "
modified = " "
stashed = ""
staged = "+ "
renamed = "» "
deleted = "✘ "

[python]
format = '[${symbol}${version}( \($virtualenv\))]($style) '
symbol = " "
style = "yellow"

[conda]
format = '[$symbol$environment]($style) '
symbol = " "
style = "green"
ignore_base = true

[cmd_duration]
min_time = 2000
format = "[ $duration]($style) "
style = "dimmed yellow"
'@
$starshipPath = "$env:USERPROFILE\.config\starship.toml"
if (Test-Path $starshipPath) { Copy-Item $starshipPath "$starshipPath.bak" -Force }
Write-Utf8NoBom $starshipPath $starshipToml

# ─────────────────────────────────────────────────────────────
Step 'Writing PowerShell profile (~\.config\powershell\profile.ps1)'
$profileText = @'
# ─────────────────────────────────────────────────────────────
#  Omarchy-style PowerShell profile (Tokyo Night + Linux commands)
# ─────────────────────────────────────────────────────────────
if ($global:OmarchyProfileLoaded) { return }
$global:OmarchyProfileLoaded = $true

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Real GNU tools that ship with Git for Windows (grep, sed, awk, touch, head, tail, wc, rm, cp, mv...)
# Appended to the END of PATH so Windows' own tools still win when names clash (find, sort).
$gitUsrBin = 'C:\Program Files\Git\usr\bin'
if ((Test-Path $gitUsrBin) -and ($env:PATH -notlike "*$gitUsrBin*")) { $env:PATH += ";$gitUsrBin" }

# ── Remove PowerShell aliases that hide the Linux versions ───
foreach ($a in 'ls','cat','rm','cp','mv','rmdir','diff','sort','curl','wget') {
    if (Test-Path "Alias:$a") { Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue }
}
if (Test-Path Function:mkdir) { Remove-Item Function:mkdir -Force }   # so `mkdir -p a/b/c` works

# ── Listing (eza) ────────────────────────────────────────────
function ls  { eza --icons=auto --group-directories-first @args }
function ll  { eza -lh --icons=auto --group-directories-first --git @args }
function la  { eza -lah --icons=auto --group-directories-first --git @args }
function lt  { eza --tree --level=2 --icons=auto --group-directories-first @args }
function lta { eza --tree --level=2 -a --icons=auto --group-directories-first @args }

# ── Files & text ─────────────────────────────────────────────
$env:BAT_THEME = 'ansi'   # follows the terminal's Tokyo Night colors
# (these forward piped input, so `ps | grep code` and `cat x | grep y` work)
function cat  { if ($MyInvocation.ExpectingInput) { $input | bat --style=plain --paging=never @args } else { bat --style=plain --paging=never @args } }
function grep { if ($MyInvocation.ExpectingInput) { $input | Out-String -Stream | grep.exe --color=auto @args } else { grep.exe --color=auto @args } }
function ff   { if ($MyInvocation.ExpectingInput) { $input | fzf @args } else { fzf --preview 'bat --style=numbers --color=always {}' @args } }
function which($name) {
    Get-Command $name -All -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Source) { $_.Source } else { "$($_.Name): $($_.CommandType)" }
    }
}
function open { if ($args) { Invoke-Item @args } else { Invoke-Item . } }
function export { foreach ($kv in $args) { $k, $v = $kv -split '=', 2; Set-Item "Env:$k" $v } }

# ── Navigation ───────────────────────────────────────────────
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

# ── Shortcuts (same as Omarchy) ──────────────────────────────
Set-Alias g git
function lg  { lazygit @args }
function lzg { lazygit @args }
function lzd { lazydocker @args }
function n   { if ($args) { nvim @args } else { nvim . } }   # `n` alone opens the current folder
Set-Alias vim nvim
Set-Alias vi  nvim
$env:EDITOR = 'nvim'

# ── Bash-style line editing ──────────────────────────────────
#  Ctrl+A/E start/end, Ctrl+U/K kill line, Ctrl+W delete word, Ctrl+R history search
try {
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
    Set-PSReadLineOption -Colors @{
        Command = '#7aa2f7'; Parameter = '#bb9af7'; String = '#9ece6a'; Number = '#ff9e64'
        Variable = '#7dcfff'; Operator = '#89ddff'; Comment = '#565f89'; Keyword = '#bb9af7'
        Type = '#2ac3de'; Member = '#7dcfff'; InlinePrediction = '#565f89'; Error = '#f7768e'
    }
} catch { }

# ── Prompt & smart cd ────────────────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # `cd` learns your folders: `cd proj` jumps to the most-used match
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
'@
$profilePath = "$env:USERPROFILE\.config\powershell\profile.ps1"
if (Test-Path $profilePath) { Copy-Item $profilePath "$profilePath.bak" -Force }
New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
Set-Content -Path $profilePath -Value $profileText -Encoding UTF8   # with BOM so Windows PowerShell 5.1 reads it too

# Locate PowerShell 7
Refresh-Path
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $pwsh) {
    foreach ($c in "$env:ProgramFiles\PowerShell\7\pwsh.exe", "$windowsApps\pwsh.exe") { if (Test-Path $c) { $pwsh = $c; break } }
}
if (-not $pwsh) { Warn 'PowerShell 7 not found, using Windows PowerShell'; $pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }

# Also load it from the normal $PROFILE, so VS Code etc. get it.
# (Windows Defender "Controlled Folder Access" may block this; Windows Terminal still works.)
try {
    $userProfile = & $pwsh -NoProfile -Command '$PROFILE'
    $line = '. "$HOME\.config\powershell\profile.ps1"'
    New-Item -ItemType Directory -Force (Split-Path $userProfile) -ErrorAction Stop | Out-Null
    $existing = if (Test-Path $userProfile) { Get-Content $userProfile -Raw } else { '' }
    if ($existing -notlike "*\.config\powershell\profile.ps1*") { Add-Content -Path $userProfile -Value $line -ErrorAction Stop }
    Info "linked from $userProfile"
} catch {
    Warn 'could not write $PROFILE in Documents (Controlled Folder Access?). Windows Terminal loads the profile directly.'
}

# ─────────────────────────────────────────────────────────────
Step 'Theming Windows Terminal (Tokyo Night)'
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSettings) { Copy-Item $wtSettings "$wtSettings.backup-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force }
$wtScript = @'
param($p, $pwsh)
New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
$raw = if (Test-Path $p) { Get-Content $p -Raw } else { '' }
if ([string]::IsNullOrWhiteSpace($raw)) { $raw = '{}' }
$s = $raw | ConvertFrom-Json -AsHashtable

if (-not $s.profiles) { $s.profiles = @{} }
if ($s.profiles -is [array]) { $s.profiles = @{ list = $s.profiles } }
if (-not $s.profiles.list) { $s.profiles.list = @() }
if (-not $s.profiles.defaults) { $s.profiles.defaults = @{} }

$scheme = @{
  name = 'Tokyo Night'; background = '#1A1B26'; foreground = '#A9B1D6'; cursorColor = '#C0CAF5'; selectionBackground = '#33467C'
  black = '#15161E'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'; blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
  brightBlack = '#414868'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'; brightYellow = '#E0AF68'; brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'; brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5'
}
$s.schemes = @(@($s.schemes | Where-Object { $_ -and $_.name -ne 'Tokyo Night' }) + $scheme)

$theme = @{
  name = 'Tokyo Night'
  window = @{ applicationTheme = 'dark'; useMica = $false }
  tab = @{ background = '#1A1B26FF'; unfocusedBackground = '#16161EFF'; showCloseButton = 'hover' }
  tabRow = @{ background = '#16161EFF'; unfocusedBackground = '#16161EFF' }
}
$s.themes = @(@($s.themes | Where-Object { $_ -and $_.name -ne 'Tokyo Night' }) + $theme)
$s.theme = 'Tokyo Night'

$defaults = @{
  colorScheme = 'Tokyo Night'; font = @{ face = 'CaskaydiaMono Nerd Font'; size = 11 }
  padding = '14'; opacity = 92; useAcrylic = $true; cursorShape = 'bar'
  scrollbarState = 'hidden'; intenseTextStyle = 'bright'
}
foreach ($k in $defaults.Keys) { $s.profiles.defaults[$k] = $defaults[$k] }

# Our PowerShell profile, loading ~\.config\powershell\profile.ps1
$guid = '{4f3a1b6e-6d2c-4c39-9a57-0a5c0e7a1d11}'
$autoPwsh = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # Terminal's auto-generated PowerShell 7 entry
$list = @($s.profiles.list | Where-Object { $_ -and $_.guid -ne $guid })
$auto = $list | Where-Object { $_.guid -eq $autoPwsh } | Select-Object -First 1
if ($auto) { $auto.hidden = $true } else { $list += @{ guid = $autoPwsh; hidden = $true } }
$mine = @{
  guid = $guid; name = 'PowerShell'; hidden = $false; startingDirectory = '%USERPROFILE%'
  commandline = ('"' + $pwsh + '" -NoLogo -NoExit -Command ". ''%USERPROFILE%\.config\powershell\profile.ps1''"')
}
$s.profiles.list = @($mine) + $list
$s.defaultProfile = $guid
$s.initialCols = 110
$s.initialRows = 32
$s.tabWidthMode = 'titleLength'

$s | ConvertTo-Json -Depth 32 | Set-Content $p -Encoding utf8
'@
$wtScriptPath = Join-Path $env:TEMP 'omarchy-wt-theme.ps1'
Set-Content $wtScriptPath $wtScript -Encoding UTF8
if ($pwsh -like '*pwsh.exe') {
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $wtScriptPath $wtSettings $pwsh
    if ($LASTEXITCODE -eq 0) { Info 'done' } else { Warn 'could not update Windows Terminal settings' }
} else {
    Warn 'PowerShell 7 is required to edit Windows Terminal settings; re-run after it installs.'
}

# ─────────────────────────────────────────────────────────────
Step 'Setting up LazyVim'
$nvimDir = "$env:LOCALAPPDATA\nvim"
$isLazyVim = (Test-Path "$nvimDir\lua\config\lazy.lua") -and ((Get-Content "$nvimDir\lua\config\lazy.lua" -Raw) -match 'LazyVim')
if (-not $isLazyVim) {
    $stamp = Get-Date -Format yyyyMMdd-HHmmss
    foreach ($d in $nvimDir, "$env:LOCALAPPDATA\nvim-data") {
        if (Test-Path $d) { Move-Item $d "$d.bak-$stamp"; Info "backed up $d -> $d.bak-$stamp" }
    }
    git clone --depth 1 https://github.com/LazyVim/starter $nvimDir 2>&1 | Out-Null
    Remove-Item "$nvimDir\.git" -Recurse -Force -ErrorAction SilentlyContinue
    Info 'LazyVim starter installed'
} else {
    Info 'LazyVim already installed, keeping your config'
}

# Normal line numbers instead of relative ones
$optionsLua = "$nvimDir\lua\config\options.lua"
$optionsText = if (Test-Path $optionsLua) { Get-Content $optionsLua -Raw } else { '' }
if ($optionsText -notmatch 'relativenumber\s*=\s*false') {
    $optionsText = $optionsText.TrimEnd() + "`n`n-- Show normal line numbers (1, 2, 3...) instead of distance from the cursor`nvim.opt.relativenumber = false`n"
    Write-Utf8NoBom $optionsLua $optionsText
}

# No autocomplete popup in plain text / Markdown
Write-Utf8NoBom "$nvimDir\lua\plugins\completion.lua" @'
-- Turn off the autocomplete popup when writing plain text / notes.
-- It stays on for code files. To disable it everywhere, make enabled return false.
local no_complete = { "text", "markdown" }

return {
  "saghen/blink.cmp",
  opts = {
    enabled = function()
      return not vim.tbl_contains(no_complete, vim.bo.filetype)
    end,
  },
}
'@

Info 'downloading plugins (first run takes a minute)...'
Refresh-Path
nvim --headless "+Lazy! sync" +qa 2>&1 | Out-Null
Info 'plugins installed'

# ─────────────────────────────────────────────────────────────
Write-Host "`nAll done! Close every Windows Terminal window and open it again." -ForegroundColor Green
Write-Host "Try: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch" -ForegroundColor DarkGray
