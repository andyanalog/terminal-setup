<#
  Omarchy-style terminal setup for Windows
  ----------------------------------------
  Tokyo Night Windows Terminal, CaskaydiaMono Nerd Font, Starship prompt,
  Linux-style commands (ls, cat, grep, rm -rf...), eza/bat/fzf/zoxide,
  lazygit, lazydocker, LazyVim, and the GlazeWM tiling window manager
  with an Omarchy-style Zebar top bar.

  Run from any PowerShell window:
      powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1

  Terminal only, no tiling window manager:
      powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 -SkipGlazeWM

  Safe to re-run: installed tools are skipped and settings are backed up.
#>
param([switch]$SkipGlazeWM)

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

# ─────────────────────────────────────────────────────────────
#  Pinned downloads: exact versions + SHA-256 fingerprints.
#  Every file is checked before it is used; a mismatch stops the script.
#  Hashes were cross-checked against each project's own checksum files.
#  To update: change the URL and hash (GitHub shows each file's sha256
#  on the release page). Everything else comes from winget, which
#  verifies each installer's hash itself.
# ─────────────────────────────────────────────────────────────
$Pins = @{
    'treesitter-x64'   = @{ Url = 'https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.2/tree-sitter-windows-x64.gz';   Sha = '230779ee4a729e3044d4a8ed57490b776ea1bac0671d12afbd6f5b4d1878f1d0' }
    'treesitter-arm64' = @{ Url = 'https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.2/tree-sitter-windows-arm64.gz'; Sha = '45be92c6537758f7c9a880f4598d45b435b6fa0b5a4ab5d48284b1e9b2225a11' }
    'font'             = @{ Url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaMono.zip';             Sha = 'de0cf0969685720f958788400cce5a065d6bb49ff1f865c964341a604b01cbd8' }
}
$LazyVimStarterCommit = '803bc181d7c0d6d5eeba9274d9be49b287294d99'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Run a native program without Windows PowerShell treating its progress
# messages (stderr) as fatal errors; fail only on a real non-zero exit code
function Invoke-Native([scriptblock]$cmd, $what) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $cmd 2>&1 | Out-Null } finally { $ErrorActionPreference = $old }
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" }
}
# Download a pinned file over HTTPS and verify its SHA-256, or stop
function Get-Pinned($name, $outFile) {
    $pin = $Pins[$name]
    Invoke-WebRequest $pin.Url -OutFile $outFile -UseBasicParsing
    $got = (Get-FileHash $outFile -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $pin.Sha) {
        Remove-Item $outFile -Force
        throw "SECURITY: checksum mismatch for $name, refusing to install.`n  expected $($pin.Sha)`n  got      $got"
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
if (-not $SkipGlazeWM) { $packages += 'glzr-io.glazewm', 'glzr-io.zebar' }
foreach ($id in $packages) {
    try { Invoke-Native { & $winget list --id $id -e --disable-interactivity } 'check'; Info "$id (already installed)"; continue } catch { }
    try { Invoke-Native { & $winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity } $id; Info "$id installed" }
    catch { Warn "$($_.Exception.Message)" }
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
    Get-Pinned "treesitter-$arch" $gz
    $in = [IO.File]::OpenRead($gz)
    $out = [IO.File]::Create("$localBin\tree-sitter.exe")
    $unzip = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
    $unzip.CopyTo($out); $unzip.Dispose(); $out.Dispose(); $in.Dispose()
    Remove-Item $gz -Force
    Info 'installed (checksum verified)'
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
    Get-Pinned 'font' "$tmp\font.zip"
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
    # pinned starter commit (git verifies the content matches the commit hash)
    Invoke-Native { git init -q $nvimDir } 'git init'
    Invoke-Native { git -C $nvimDir fetch -q --depth 1 https://github.com/LazyVim/starter $LazyVimStarterCommit } 'downloading LazyVim'
    Invoke-Native { git -C $nvimDir checkout -q FETCH_HEAD } 'git checkout'
    Remove-Item "$nvimDir\.git" -Recurse -Force -ErrorAction SilentlyContinue
    # pinned plugin versions (LazyVim installs exactly these commits)
    Write-Utf8NoBom "$nvimDir\lazy-lock.json" @'
{
  "LazyVim": { "branch": "main", "commit": "999700997f72227187d49d8b92667183dc7fc809" },
  "blink.cmp": { "branch": "main", "commit": "78336bc89ee5365633bcf754d93df01678b5c08f" },
  "bufferline.nvim": { "branch": "main", "commit": "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3" },
  "catppuccin": { "branch": "main", "commit": "edefef779ab08ce1a4a404713e3012b0d202bd35" },
  "conform.nvim": { "branch": "master", "commit": "016802de402556da54c36bd7359b441266b01cdd" },
  "flash.nvim": { "branch": "main", "commit": "5f0f270fdc7c5b0c21d903ee85b9cb06f2ac636a" },
  "friendly-snippets": { "branch": "main", "commit": "b2ea5c41a150ba72fb656eedb4ed0a86d138d945" },
  "gitsigns.nvim": { "branch": "main", "commit": "ef707fb93301a9b856f36eae4c8f56f5b988a794" },
  "grug-far.nvim": { "branch": "main", "commit": "91b7e58b6ffc6ddad5acb7a7c1df21257724449e" },
  "lazy.nvim": { "branch": "main", "commit": "85c7ff3711b730b4030d03144f6db6375044ae82" },
  "lazydev.nvim": { "branch": "main", "commit": "ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d" },
  "lualine.nvim": { "branch": "master", "commit": "221ce6b2d999187044529f49da6554a92f740a96" },
  "mason-lspconfig.nvim": { "branch": "main", "commit": "55eceab8975036ac43a4176cbfe0d4bf1ddae93f" },
  "mason.nvim": { "branch": "main", "commit": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d" },
  "mini.ai": { "branch": "main", "commit": "a4f5648dedf435e6306205135d1babb563b55d28" },
  "mini.icons": { "branch": "main", "commit": "eab3e692d796d78ea6ffc978d8a380ff26fcf4e3" },
  "mini.pairs": { "branch": "main", "commit": "03eb1f0062a2cee5314d1ac3939246e4bb21352e" },
  "noice.nvim": { "branch": "main", "commit": "7bfd942445fb63089b59f97ca487d605e715f155" },
  "nui.nvim": { "branch": "main", "commit": "10fc361835c856ba4233ef5ea135b919bf3dce97" },
  "nvim-lint": { "branch": "master", "commit": "52107ce2076a27a285af781248e2c59bad817cd0" },
  "nvim-lspconfig": { "branch": "master", "commit": "993d048db0d83d8e8ba3f9cb376456321acdcce3" },
  "nvim-treesitter": { "branch": "main", "commit": "19bdfc04f40ed2ccb3340591d125f759b0406875" },
  "nvim-treesitter-textobjects": { "branch": "main", "commit": "5c7b0263797dfd1bd6202f2b219f3b53a80b2187" },
  "nvim-ts-autotag": { "branch": "main", "commit": "d7220b55e16ed3c04e88086256def5d282429493" },
  "persistence.nvim": { "branch": "main", "commit": "b20b2a7887bd39c1a356980b45e03250f3dce49c" },
  "plenary.nvim": { "branch": "master", "commit": "74b06c6c75e4eeb3108ec01852001636d85a932b" },
  "snacks.nvim": { "branch": "main", "commit": "882c996cf28183f4d63640de0b4c02ec886d01f2" },
  "todo-comments.nvim": { "branch": "main", "commit": "31e3c38ce9b29781e4422fc0322eb0a21f4e8668" },
  "tokyonight.nvim": { "branch": "main", "commit": "cdc07ac78467a233fd62c493de29a17e0cf2b2b6" },
  "trouble.nvim": { "branch": "main", "commit": "bd67efe408d4816e25e8491cc5ad4088e708a69a" },
  "ts-comments.nvim": { "branch": "main", "commit": "a59d6092213447450191122c9346f309161504cb" },
  "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" }
}
'@
    Info 'LazyVim starter installed (pinned)'
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
try { Invoke-Native { nvim --headless "+Lazy! restore" +qa } 'plugin install'; Info 'plugins installed' }
catch { Warn 'plugin install reported a problem; open nvim to finish' }

# ─────────────────────────────────────────────────────────────
#  GlazeWM: tiling windows, gaps, borders and Omarchy's Super-key
#  shortcuts. Zebar draws the top bar (Omarchy's Waybar).
# ─────────────────────────────────────────────────────────────
if ($SkipGlazeWM) {
    Step 'Skipping GlazeWM (-SkipGlazeWM)'
} else {
Step 'Configuring GlazeWM tiling window manager (~\.glzr\glazewm\config.yaml)'
$glazeConfig = @'
# Omarchy-style GlazeWM config (Tokyo Night)
# Super = the Windows key. Win+Shift+P pauses tiling, Win+Shift+R reloads this file.
# Full command list: https://github.com/glzr-io/glazewm#all-commands

general:
  # Zebar draws the Omarchy-style top bar
  startup_commands: ['shell-exec zebar']
  shutdown_commands: ['shell-exec taskkill /IM zebar.exe /F']
  config_reload_commands: []
  focus_follows_cursor: false
  toggle_workspace_on_refocus: false
  cursor_jump:
    enabled: true
    trigger: 'monitor_focus'
  hide_method: 'cloak'
  show_all_in_taskbar: false

# Omarchy: 5px around each window (10px between them), 10px to the screen edge.
# The bar docks like the taskbar (Windows reserves its 26px), so top is 10px too.
gaps:
  scale_with_dpi: true
  inner_gap: '10px'
  outer_gap:
    top: '10px'
    right: '10px'
    bottom: '10px'
    left: '10px'

# Borders and square corners need Windows 11
window_effects:
  focused_window:
    border:
      enabled: true
      color: '#7aa2f7'
    # Omarchy windows have no title bars. Set to true to hide them here too
    # (some apps draw badly without one).
    hide_title_bar:
      enabled: false
    corner_style:
      enabled: true
      style: 'square'
    transparency:
      enabled: false
      opacity: '95%'
  other_windows:
    border:
      enabled: true
      color: '#414868'
    hide_title_bar:
      enabled: false
    corner_style:
      enabled: true
      style: 'square'
    transparency:
      enabled: false
      opacity: '95%'

window_behavior:
  initial_state: 'tiling'
  state_defaults:
    floating:
      centered: true
      shown_on_top: false
    fullscreen:
      # true: Win+F maximizes and the top bar stays visible. false: true fullscreen.
      maximized: true
      shown_on_top: false

workspaces:
  - name: '1'
  - name: '2'
  - name: '3'
  - name: '4'
  - name: '5'
  - name: '6'
  - name: '7'
  - name: '8'
  - name: '9'
  - name: '10'
    display_name: '0'

window_rules:
  - commands: ['ignore']
    match:
      - window_process: { equals: 'zebar' }
      - window_title: { regex: '[Pp]icture.in.[Pp]icture' }
        window_class: { regex: 'Chrome_WidgetWin_1|MozillaDialogClass' }
      - window_process: { equals: 'PowerToys' }
        window_class: { regex: 'HwndWrapper\[PowerToys\.PowerAccent.*?\]' }
      - window_title: { equals: 'Command Palette' }
        window_class: { equals: 'WinUIDesktopWin32WindowClass' }
      - window_process: { equals: 'PowerToys' }
        window_title: { regex: '.*? - Peek' }
      - window_process: { equals: 'Lively' }
        window_class: { regex: 'HwndWrapper' }
      - window_process: { equals: 'EXCEL' }
        window_class: { not_regex: 'XLMAIN' }
      - window_process: { equals: 'WINWORD' }
        window_class: { not_regex: 'OpusApp' }
      - window_process: { equals: 'POWERPNT' }
        window_class: { not_regex: 'PPTFrameClass' }

keybindings:
  # ── Apps (same keys as Omarchy) ──────────────────────────
  # Tools go through `cmd /c`: Windows Terminal can't find programs on
  # the user PATH (winget's Links folder) when given a bare name.
  - commands: ['shell-exec wt']
    bindings: ['lwin+enter']
  - commands: ['shell-exec explorer']
    bindings: ['lwin+shift+f']
  - commands: ['shell-exec wt cmd /c nvim']
    bindings: ['lwin+shift+n']
  - commands: ['shell-exec wt cmd /c lazydocker']
    bindings: ['lwin+shift+d']
  - commands: ['shell-exec wt cmd /c btop']
    bindings: ['lwin+ctrl+t']

  # ── Windows ──────────────────────────────────────────────
  - commands: ['close']
    bindings: ['lwin+w']
  - commands: ['toggle-floating --centered']
    bindings: ['lwin+t']
  - commands: ['toggle-fullscreen']
    bindings: ['lwin+f']
  - commands: ['toggle-tiling-direction']
    bindings: ['lwin+j']

  # Focus with Super + arrows, swap with Super + Shift + arrows
  - commands: ['focus --direction left']
    bindings: ['lwin+left']
  - commands: ['focus --direction right']
    bindings: ['lwin+right']
  - commands: ['focus --direction up']
    bindings: ['lwin+up']
  - commands: ['focus --direction down']
    bindings: ['lwin+down']
  - commands: ['move --direction left']
    bindings: ['lwin+shift+left']
  - commands: ['move --direction right']
    bindings: ['lwin+shift+right']
  - commands: ['move --direction up']
    bindings: ['lwin+shift+up']
  - commands: ['move --direction down']
    bindings: ['lwin+shift+down']

  # Resize with Super + - / =  (add Shift for height)
  - commands: ['resize --width -5%']
    bindings: ['lwin+oem_minus']
  - commands: ['resize --width +5%']
    bindings: ['lwin+oem_plus']
  - commands: ['resize --height -5%']
    bindings: ['lwin+shift+oem_minus']
  - commands: ['resize --height +5%']
    bindings: ['lwin+shift+oem_plus']

  # ── Workspaces ───────────────────────────────────────────
  - commands: ['focus --next-active-workspace']
    bindings: ['lwin+tab']
  - commands: ['focus --prev-active-workspace']
    bindings: ['lwin+shift+tab']
  - commands: ['focus --recent-workspace']
    bindings: ['lwin+ctrl+tab']

  # Move the current workspace to another monitor
  - commands: ['move-workspace --direction left']
    bindings: ['lwin+shift+alt+left']
  - commands: ['move-workspace --direction right']
    bindings: ['lwin+shift+alt+right']
  - commands: ['move-workspace --direction up']
    bindings: ['lwin+shift+alt+up']
  - commands: ['move-workspace --direction down']
    bindings: ['lwin+shift+alt+down']

  # Super + 1-9/0: go to workspace
  # Super + Shift + 1-9/0: move window there and follow it
  # Super + Shift + Alt + 1-9/0: move window there silently
  - { commands: ['focus --workspace 1'],  bindings: ['lwin+1'] }
  - { commands: ['focus --workspace 2'],  bindings: ['lwin+2'] }
  - { commands: ['focus --workspace 3'],  bindings: ['lwin+3'] }
  - { commands: ['focus --workspace 4'],  bindings: ['lwin+4'] }
  - { commands: ['focus --workspace 5'],  bindings: ['lwin+5'] }
  - { commands: ['focus --workspace 6'],  bindings: ['lwin+6'] }
  - { commands: ['focus --workspace 7'],  bindings: ['lwin+7'] }
  - { commands: ['focus --workspace 8'],  bindings: ['lwin+8'] }
  - { commands: ['focus --workspace 9'],  bindings: ['lwin+9'] }
  - { commands: ['focus --workspace 10'], bindings: ['lwin+0'] }
  - { commands: ['move --workspace 1', 'focus --workspace 1'],   bindings: ['lwin+shift+1'] }
  - { commands: ['move --workspace 2', 'focus --workspace 2'],   bindings: ['lwin+shift+2'] }
  - { commands: ['move --workspace 3', 'focus --workspace 3'],   bindings: ['lwin+shift+3'] }
  - { commands: ['move --workspace 4', 'focus --workspace 4'],   bindings: ['lwin+shift+4'] }
  - { commands: ['move --workspace 5', 'focus --workspace 5'],   bindings: ['lwin+shift+5'] }
  - { commands: ['move --workspace 6', 'focus --workspace 6'],   bindings: ['lwin+shift+6'] }
  - { commands: ['move --workspace 7', 'focus --workspace 7'],   bindings: ['lwin+shift+7'] }
  - { commands: ['move --workspace 8', 'focus --workspace 8'],   bindings: ['lwin+shift+8'] }
  - { commands: ['move --workspace 9', 'focus --workspace 9'],   bindings: ['lwin+shift+9'] }
  - { commands: ['move --workspace 10', 'focus --workspace 10'], bindings: ['lwin+shift+0'] }
  - { commands: ['move --workspace 1'],  bindings: ['lwin+shift+alt+1'] }
  - { commands: ['move --workspace 2'],  bindings: ['lwin+shift+alt+2'] }
  - { commands: ['move --workspace 3'],  bindings: ['lwin+shift+alt+3'] }
  - { commands: ['move --workspace 4'],  bindings: ['lwin+shift+alt+4'] }
  - { commands: ['move --workspace 5'],  bindings: ['lwin+shift+alt+5'] }
  - { commands: ['move --workspace 6'],  bindings: ['lwin+shift+alt+6'] }
  - { commands: ['move --workspace 7'],  bindings: ['lwin+shift+alt+7'] }
  - { commands: ['move --workspace 8'],  bindings: ['lwin+shift+alt+8'] }
  - { commands: ['move --workspace 9'],  bindings: ['lwin+shift+alt+9'] }
  - { commands: ['move --workspace 10'], bindings: ['lwin+shift+alt+0'] }

  # ── GlazeWM itself (not in Omarchy) ──────────────────────
  # Pause tiling and all these shortcuts (games, presentations). Press again to resume.
  - commands: ['wm-toggle-pause']
    bindings: ['lwin+shift+p']
  - commands: ['wm-reload-config']
    bindings: ['lwin+shift+r']
  - commands: ['wm-exit']
    bindings: ['lwin+shift+escape']
'@
$glazePath = "$env:USERPROFILE\.glzr\glazewm\config.yaml"
if (Test-Path $glazePath) { Copy-Item $glazePath "$glazePath.bak" -Force }
Write-Utf8NoBom $glazePath $glazeConfig

Step 'Writing Omarchy-style top bar for Zebar (~\.glzr\zebar\omarchy-style)'
# A self-contained widget: no downloaded scripts or fonts. It talks to GlazeWM
# over its local IPC socket (ws://127.0.0.1:6123) and uses the Nerd Font installed above.
$zebarDir = "$env:USERPROFILE\.glzr\zebar"
$zpack = @'
{
  "$schema": "https://github.com/glzr-io/zebar/raw/v3.0.0/resources/zpack-schema.json",
  "name": "omarchy-style",
  "version": "1.0.0",
  "description": "Omarchy-style Tokyo Night top bar for GlazeWM.",
  "tags": ["topbar"],
  "previewImages": [],
  "repositoryUrl": "https://github.com/andyanalog/terminal-setup",
  "widgets": [
    {
      "name": "bar",
      "htmlPath": "./bar.html",
      "zOrder": "normal",
      "shownInTaskbar": false,
      "focused": false,
      "resizable": false,
      "transparent": true,
      "includeFiles": ["*.html"],
      "caching": { "defaultDuration": 0, "rules": [] },
      "privileges": { "shellCommands": [] },
      "presets": [
        {
          "name": "default",
          "anchor": "top_left",
          "offsetX": "0px",
          "offsetY": "0px",
          "width": "100%",
          "height": "26px",
          "monitorSelection": { "type": "all" },
          "dockToEdge": { "enabled": true, "edge": "top", "windowMargin": "0px" }
        }
      ]
    }
  ]
}
'@
$barHtml = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<style>
  :root { --bg: #1a1b26; --fg: #a9b1d6; --red: #f7768e; }
  html, body { margin: 0; height: 100%; overflow: hidden; }
  body {
    background: var(--bg); color: var(--fg);
    font-family: 'CaskaydiaMono Nerd Font', 'CaskaydiaMono NF', monospace; font-size: 12px;
    user-select: none; cursor: default;
  }
  .bar { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; height: 100%; padding: 0 8px; }
  .left, .right { display: flex; align-items: center; }
  .right { justify-content: flex-end; }
  button { all: unset; cursor: pointer; }
  .ws { padding: 0 6px; margin: 0 1.5px; min-width: 9px; text-align: center; }
  .ws.empty { opacity: .5; }
  .mod { min-width: 12px; margin: 0 7.5px; text-align: center; }
  .paused { color: var(--red); }
  [hidden] { display: none !important; }
</style>
</head>
<body>
<div class="bar">
  <div class="left">
    <button class="mod" id="logo" title="Terminal (Super + Enter)">&#xF17A;</button>
    <div id="workspaces"></div>
  </div>
  <button id="clock"></button>
  <div class="right">
    <button class="mod paused" id="paused" title="Tiling paused (Super + Shift + P)" hidden>PAUSED</button>
    <button class="mod" id="cpu" title="Activity (btop)">&#xF035B;</button>
    <span class="mod" id="battery" hidden></span>
  </div>
</div>
<script>
  // Workspaces 1-5 are always shown, like Omarchy. The active one becomes a dot.
  const PERSISTENT = ['1', '2', '3', '4', '5'];
  const ACTIVE = '\u{F14FB}';
  const BATTERY = ['\u{F007A}','\u{F007B}','\u{F007C}','\u{F007D}','\u{F007E}','\u{F007F}','\u{F0080}','\u{F0081}','\u{F0082}','\u{F0079}'];
  const CHARGING = ['\u{F089C}','\u{F0086}','\u{F0087}','\u{F0088}','\u{F089D}','\u{F0089}','\u{F089E}','\u{F008A}','\u{F008B}','\u{F0085}'];
  const $ = id => document.getElementById(id);

  let sock = null, monitors = [], queued = false;
  const send = msg => { if (sock && sock.readyState === WebSocket.OPEN) sock.send(msg); };
  const run = cmd => send('command ' + cmd);

  function connect() {
    sock = new WebSocket('ws://127.0.0.1:6123');
    sock.onopen = () => {
      send('sub -e workspace_activated workspace_deactivated workspace_updated focus_changed ' +
           'focused_container_moved window_managed window_unmanaged monitor_added monitor_removed ' +
           'monitor_updated pause_changed');
      send('query monitors');
      send('query paused');
    };
    sock.onmessage = e => {
      const msg = JSON.parse(e.data);
      if (msg.messageType === 'client_response') {
        if (msg.clientMessage === 'query monitors' && msg.data) { monitors = msg.data.monitors; renderWorkspaces(); }
        if (msg.clientMessage === 'query paused') $('paused').hidden = msg.data !== true;
      } else if (msg.messageType === 'event_subscription' && msg.data) {
        if (msg.data.eventType === 'pause_changed') $('paused').hidden = !msg.data.isPaused;
        else if (!queued) { queued = true; setTimeout(() => { queued = false; send('query monitors'); }, 30); }
      }
    };
    sock.onclose = () => { monitors = []; renderWorkspaces(); setTimeout(connect, 2000); };
  }

  // The monitor this bar sits on (GlazeWM reports physical pixels)
  function myMonitor() {
    const r = window.devicePixelRatio || 1;
    const x = (window.screenX + window.innerWidth / 2) * r, y = (window.screenY + 1) * r;
    const inside = monitors.find(m => x >= m.x && x < m.x + m.width && y >= m.y && y < m.y + m.height);
    if (inside) return inside;
    const dist = m => Math.hypot(m.x - window.screenX * r, m.y - window.screenY * r);
    return monitors.slice().sort((a, b) => dist(a) - dist(b))[0];
  }

  function renderWorkspaces() {
    const box = $('workspaces');
    box.textContent = '';
    if (!monitors.length) return;
    const me = myMonitor();
    const mine = me ? me.children : [];
    const elsewhere = new Set(monitors.filter(m => m !== me).flatMap(m => m.children.map(w => w.name)));
    const names = [...new Set([...PERSISTENT.filter(n => !elsewhere.has(n)), ...mine.map(w => w.name)])];
    names.sort((a, b) => (parseInt(a, 10) || 99) - (parseInt(b, 10) || 99) || a.localeCompare(b));
    for (const name of names) {
      const ws = mine.find(w => w.name === name);
      const btn = document.createElement('button');
      btn.className = 'ws' + (!ws || !ws.children.length ? ' empty' : '');
      btn.textContent = ws && ws.isDisplayed ? ACTIVE : ((ws && ws.displayName) || (name === '10' ? '0' : name));
      btn.onclick = () => run('focus --workspace ' + name);
      box.appendChild(btn);
    }
  }

  // Clock: "Monday 14:32", click for "09 November W45 2026"
  let altClock = false;
  function isoWeek(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
    return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 864e5 + 1) / 7);
  }
  function tick() {
    const d = new Date(), pad = n => String(n).padStart(2, '0');
    $('clock').textContent = altClock
      ? `${pad(d.getDate())} ${d.toLocaleDateString(undefined, { month: 'long' })} W${pad(isoWeek(d))} ${d.getFullYear()}`
      : `${d.toLocaleDateString(undefined, { weekday: 'long' })} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }
  $('clock').onclick = () => { altClock = !altClock; tick(); };
  setInterval(tick, 1000); tick();

  $('logo').onclick = () => run('shell-exec wt');
  $('cpu').onclick = () => run('shell-exec wt cmd /c btop');

  // Battery (hidden on desktops: browsers report those as "full and charging")
  if (navigator.getBattery) {
    navigator.getBattery().then(b => {
      const show = () => {
        const el = $('battery'), pct = Math.round(b.level * 100);
        const noBattery = b.charging && b.level === 1 && b.chargingTime === 0;
        el.hidden = noBattery;
        el.textContent = (b.charging ? CHARGING : BATTERY)[Math.min(9, Math.floor(b.level * 10))];
        el.title = `${pct}%${b.charging ? ' (charging)' : ''}`;
      };
      ['levelchange', 'chargingchange', 'chargingtimechange'].forEach(ev => b.addEventListener(ev, show));
      show();
    }).catch(() => {});
  }

  connect();
</script>
</body>
</html>
'@
$zebarSettings = @'
{
  "$schema": "https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json",
  "startupConfigs": [
    { "pack": "omarchy-style", "widget": "bar", "preset": "default" }
  ]
}
'@
Write-Utf8NoBom "$zebarDir\omarchy-style\zpack.json" $zpack
Write-Utf8NoBom "$zebarDir\omarchy-style\bar.html" $barHtml
$zebarSettingsPath = "$zebarDir\settings.json"
if (Test-Path $zebarSettingsPath) { Copy-Item $zebarSettingsPath "$zebarSettingsPath.bak" -Force }
Write-Utf8NoBom $zebarSettingsPath $zebarSettings

Step 'Starting GlazeWM (and at every sign-in)'
Refresh-Path
$glazeExe = "$env:ProgramFiles\glzr.io\GlazeWM\glazewm.exe"
if (-not (Test-Path $glazeExe)) {
    # the CLI on PATH lives in a cli\ folder next to the main app
    $cli = (Get-Command glazewm -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($cli) { $glazeExe = Join-Path (Split-Path (Split-Path $cli)) 'glazewm.exe' }
}
if (Test-Path $glazeExe) {
    # Same registry entry as GlazeWM's own tray option "Run on system startup"
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GlazeWM' -Value "`"$glazeExe`""
    Info 'starts at sign-in (untick "Run on system startup" in its tray menu to stop that)'
    if (Get-Process glazewm -ErrorAction SilentlyContinue) {
        Info 'already running: press Win+Shift+R to load the new config'
    } else {
        Start-Process $glazeExe
        Info 'started'
    }
} else {
    Warn 'GlazeWM not found; install it with: winget install glzr-io.glazewm'
}
}

# ─────────────────────────────────────────────────────────────
Write-Host "`nAll done! Close every Windows Terminal window and open it again." -ForegroundColor Green
Write-Host "Try: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch" -ForegroundColor DarkGray
if (-not $SkipGlazeWM) {
    Write-Host "Windows now tile like Omarchy: Win+Enter terminal, Win+W close, Win+1..9 workspaces, Win+Shift+P pause." -ForegroundColor DarkGray
}
