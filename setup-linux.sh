#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Omarchy-style terminal setup for Linux
#  Ubuntu/Debian (apt), Fedora (dnf), Arch (pacman). Works on WSL too.
#
#  Tokyo Night colors, CaskaydiaMono Nerd Font, Starship prompt,
#  eza/bat/fzf/zoxide, lazygit, lazydocker and LazyVim.
#
#  Run:   bash setup-linux.sh
#  Safe to re-run: installed tools are skipped and configs are backed up.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    \033[2m%s\033[0m\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$PATH"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
IS_WSL=false; grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

# ─────────────────────────────────────────────────────────────
#  Pinned downloads: exact versions + SHA-256 fingerprints.
#  Every file is checked before it is used; a mismatch stops the script.
#  Hashes were cross-checked against each project's own checksum files.
#  To update a tool: change its URL and hash (GitHub shows each file's
#  sha256 on the release page).
# ─────────────────────────────────────────────────────────────
GH=https://github.com
declare -A URL SHA
pin() { URL[$1]="$2"; SHA[$1]="$3"; }

case "$(uname -m)" in
  x86_64|amd64)
    pin starship   $GH/starship/starship/releases/download/v1.27.0/starship-x86_64-unknown-linux-musl.tar.gz 10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89
    pin zoxide     $GH/ajeetdsouza/zoxide/releases/download/v0.10.0/zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz 2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae
    pin eza        $GH/eza-community/eza/releases/download/v0.23.5/eza_x86_64-unknown-linux-gnu.tar.gz 35c70c5c43c29108075e58b893234c67ef585f0b53a7eaf8e9e7d4eec9f339b4
    pin fastfetch  $GH/fastfetch-cli/fastfetch/releases/download/2.71.0/fastfetch-linux-amd64.tar.gz abf5c99a3702cce8d3c7fa2cccd3ac205076ae0f2e45bced24a42a68821702d6
    pin lazygit    $GH/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_linux_x86_64.tar.gz 0a23f429a95f0d09db298b3c291536d818de066aa5a85c255806f0490ff6656b
    pin lazydocker $GH/jesseduffield/lazydocker/releases/download/v0.25.2/lazydocker_0.25.2_Linux_x86_64.tar.gz 0d9dbfc26068b218e7ed84b104748cadc6e3cf733c0afd35465306fb39b9523c
    pin nvim       $GH/neovim/neovim/releases/download/v0.12.6/nvim-linux-x86_64.tar.gz 474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
    pin treesitter $GH/tree-sitter/tree-sitter/releases/download/v0.27.2/tree-sitter-linux-x64.gz 7ed56d152c52437397b9fcaa43cf341f49933cecc1ca291843f0d347c6e2cb3a
    ;;
  aarch64|arm64)
    pin starship   $GH/starship/starship/releases/download/v1.27.0/starship-aarch64-unknown-linux-musl.tar.gz 341f5cbf24699fa0b27ec88965ad25f862ea09e15d35a543fd6ffdff1d2aa00d
    pin zoxide     $GH/ajeetdsouza/zoxide/releases/download/v0.10.0/zoxide-0.10.0-aarch64-unknown-linux-musl.tar.gz f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641
    pin eza        $GH/eza-community/eza/releases/download/v0.23.5/eza_aarch64-unknown-linux-gnu.tar.gz 40b87ae8628aa2ff0f0d2dc24ab52f689631366385c3da630bae745671fd71ec
    pin fastfetch  $GH/fastfetch-cli/fastfetch/releases/download/2.71.0/fastfetch-linux-aarch64.tar.gz 458248f2b3abab9c5e0a5b9df12cdcd1a966b355ddd5f3244a5eb47d17d33412
    pin lazygit    $GH/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_linux_arm64.tar.gz ac0b48237f3d0283813e7154ec063237e519532feb0470c0881a1793ee78fd42
    pin lazydocker $GH/jesseduffield/lazydocker/releases/download/v0.25.2/lazydocker_0.25.2_Linux_arm64.tar.gz 005c38b685aaa557e7d646d83a3dadb5024340eeed8c6a2e1949eee6f530de23
    pin nvim       $GH/neovim/neovim/releases/download/v0.12.6/nvim-linux-arm64.tar.gz 8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815
    pin treesitter $GH/tree-sitter/tree-sitter/releases/download/v0.27.2/tree-sitter-linux-arm64.gz 34fcc5c4fa7bdd2058a2a45a03b6eb9a49b03a93b6d52ec750f99b1516d98d33
    ;;
  *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
pin font $GH/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaMono.zip de0cf0969685720f958788400cce5a065d6bb49ff1f865c964341a604b01cbd8
LAZYVIM_STARTER_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99

# Download a pinned file over HTTPS and verify its SHA-256, or stop
fetch() {  # <pin-name> <output-file>
  curl --proto '=https' --tlsv1.2 -fsSL "${URL[$1]}" -o "$2"
  local got; got="$(sha256sum "$2" | cut -d' ' -f1)"
  if [ "$got" != "${SHA[$1]}" ]; then
    rm -f "$2"
    printf '\n\033[1;31mSECURITY: checksum mismatch for %s, refusing to install.\033[0m\n  expected %s\n  got      %s\n' "$1" "${SHA[$1]}" "$got" >&2
    exit 1
  fi
}
# Install one binary from a pinned .tar.gz into ~/.local/bin
install_pinned() {  # <pin-name> <binary-name>
  if have "$2"; then info "$2 (already installed)"; return; fi
  local tmp f; tmp="$(mktemp -d)"
  fetch "$1" "$tmp/pkg.tar.gz"
  tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
  # prefer .../bin/<name> (some archives also ship a completion script with the same name)
  f="$(find "$tmp" -type f -path "*/bin/$2" | head -n1)"
  [ -n "$f" ] || f="$(find "$tmp" -maxdepth 2 -type f -name "$2" | head -n1)"
  [ -n "$f" ] || { warn "could not find $2 inside its download"; rm -rf "$tmp"; return; }
  install -m 755 "$f" "$BIN/$2"
  rm -rf "$tmp"
  info "$2 installed (checksum verified)"
}

# ─────────────────────────────────────────────────────────────
step "Installing packages"
if have apt-get; then
  # Only call sudo when something is actually missing (re-runs need no password)
  missing=()
  for p in git curl unzip tar gzip fontconfig build-essential ripgrep fd-find bat fzf eza btop fastfetch; do
    dpkg -s "$p" >/dev/null 2>&1 && continue
    apt-cache show "$p" >/dev/null 2>&1 && missing+=("$p")   # skip ones this release doesn't have
  done
  if [ ${#missing[@]} -gt 0 ]; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y "${missing[@]}"
  else
    info "all apt packages already installed"
  fi
  # Debian/Ubuntu ship these under different names
  have batcat && ! have bat && ln -sf "$(command -v batcat)" "$BIN/bat"
  have fdfind && ! have fd  && ln -sf "$(command -v fdfind)" "$BIN/fd"
elif have dnf; then
  $SUDO dnf install -y git curl unzip tar gzip fontconfig gcc gcc-c++ make ripgrep fd-find bat fzf zoxide btop
  for p in eza fastfetch; do $SUDO dnf install -y "$p" >/dev/null 2>&1 || true; done
elif have pacman; then
  $SUDO pacman -Syu --needed --noconfirm git curl unzip tar gzip fontconfig base-devel ripgrep fd bat fzf \
    zoxide btop eza fastfetch starship neovim lazygit
  for p in lazydocker tree-sitter-cli; do $SUDO pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 || true; done
else
  warn "No apt/dnf/pacman found. Make sure git, curl, unzip, tar and a C compiler are installed."
fi

# ─────────────────────────────────────────────────────────────
step "Installing tools missing from the package manager"
install_pinned starship starship

# zoxide: distro versions are often too old for `--cmd cd`, so replace those
if have zoxide && ! zoxide init --cmd cd bash >/dev/null 2>&1; then
  tmp="$(mktemp -d)"; fetch zoxide "$tmp/z.tar.gz"; tar -xzf "$tmp/z.tar.gz" -C "$tmp"
  install -m 755 "$tmp/zoxide" "$BIN/zoxide"; rm -rf "$tmp"; info "zoxide updated (checksum verified)"
else
  install_pinned zoxide zoxide
fi

install_pinned eza        eza
install_pinned fastfetch  fastfetch
install_pinned lazygit    lazygit
install_pinned lazydocker lazydocker

# Neovim: LazyVim needs 0.11.2 or newer (distro packages are often older)
nvim_ok() {
  have nvim || return 1
  local v; v="$(nvim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  local maj min pat; IFS=. read -r maj min pat <<<"$v"
  [ "$maj" -gt 0 ] || [ "$min" -gt 11 ] || { [ "$min" -eq 11 ] && [ "$pat" -ge 2 ]; }
}
if nvim_ok; then info "neovim (already installed)"; else
  tmp="$(mktemp -d)"; fetch nvim "$tmp/nvim.tar.gz"
  rm -rf "$HOME/.local/opt/nvim"; mkdir -p "$HOME/.local/opt/nvim"
  tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local/opt/nvim" --strip-components=1; rm -rf "$tmp"
  ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$BIN/nvim"
  info "neovim installed (checksum verified)"
fi

# tree-sitter CLI (LazyVim uses it to build syntax highlighting)
if have tree-sitter; then info "tree-sitter (already installed)"; else
  tmp="$(mktemp -d)"; fetch treesitter "$tmp/ts.gz"
  gunzip -c "$tmp/ts.gz" > "$BIN/tree-sitter"; chmod +x "$BIN/tree-sitter"; rm -rf "$tmp"
  info "tree-sitter installed (checksum verified)"
fi

# ─────────────────────────────────────────────────────────────
step "Installing CaskaydiaMono Nerd Font"
if fc-list 2>/dev/null | grep -qi "CaskaydiaMono Nerd"; then info "already installed"; else
  FONT_DIR="$HOME/.local/share/fonts/CaskaydiaMono"; mkdir -p "$FONT_DIR"
  tmp="$(mktemp -d)"
  fetch font "$tmp/font.zip"
  unzip -oq "$tmp/font.zip" 'CaskaydiaMonoNerdFont-*.ttf' -d "$FONT_DIR"
  rm -rf "$tmp"; fc-cache -f >/dev/null
  info "installed"
fi
$IS_WSL && info "(WSL: the font and colors come from Windows Terminal; run setup-windows.ps1 there)"

# ─────────────────────────────────────────────────────────────
step "Writing Starship prompt config (~/.config/starship.toml)"
mkdir -p "$HOME/.config"
[ -f "$HOME/.config/starship.toml" ] && cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak"
cat > "$HOME/.config/starship.toml" <<'EOF'
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
EOF

# ─────────────────────────────────────────────────────────────
step "Adding aliases and prompt to your shell"
strip_block() {  # remove a previous copy of our block so re-runs don't duplicate it
  [ -f "$1" ] || return 0
  awk '/# >>> omarchy-style >>>/{s=1} !s{print} /# <<< omarchy-style <<</{s=0}' "$1" > "$1.omarchy.tmp"
  cat "$1.omarchy.tmp" > "$1"; rm -f "$1.omarchy.tmp"
}
common_block() {
cat <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim
export BAT_THEME=ansi

# Listing
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -lh --icons=auto --group-directories-first --git'
alias la='eza -lah --icons=auto --group-directories-first --git'
alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
alias lta='eza --tree --level=2 -a --icons=auto --group-directories-first'

# Files & text
alias cat='bat --style=plain --paging=never'
alias grep='grep --color=auto'
ff() { fzf --preview 'bat --style=numbers --color=always {}' "$@"; }

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Shortcuts (same as Omarchy)
alias g='git'
alias lg='lazygit'
alias lzg='lazygit'
alias lzd='lazydocker'
alias vim='nvim'
alias vi='nvim'
n() { if [ $# -eq 0 ]; then nvim .; else nvim "$@"; fi; }
if grep -qi microsoft /proc/version 2>/dev/null; then
  open() { explorer.exe "${1:-.}"; }
elif command -v xdg-open >/dev/null 2>&1; then
  open() { xdg-open "${1:-.}" >/dev/null 2>&1; }
fi
EOF
}
bash_block() {
cat <<'EOF'
if [[ $- == *i* ]]; then
  # Up/Down search history for what you've already typed
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
  bind 'set completion-ignore-case on'
  command -v starship >/dev/null && eval "$(starship init bash)"
  command -v zoxide   >/dev/null && eval "$(zoxide init --cmd cd bash)"
  if fzf --bash >/dev/null 2>&1; then eval "$(fzf --bash)"
  elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then . /usr/share/doc/fzf/examples/key-bindings.bash; fi
fi
EOF
}
zsh_block() {
cat <<'EOF'
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [ -f "$f" ] && source "$f" && break
done
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide   >/dev/null && eval "$(zoxide init --cmd cd zsh)"
fzf --zsh >/dev/null 2>&1 && source <(fzf --zsh)
EOF
}
write_rc() {  # <file> <bash|zsh>
  strip_block "$1"
  {
    echo ""
    echo "# >>> omarchy-style >>>"
    common_block
    if [ "$2" = zsh ]; then zsh_block; else bash_block; fi
    echo "# <<< omarchy-style <<<"
  } >> "$1"
  info "updated $1"
}
touch "$HOME/.bashrc"
write_rc "$HOME/.bashrc" bash
[ -f "$HOME/.zshrc" ] && write_rc "$HOME/.zshrc" zsh

# ─────────────────────────────────────────────────────────────
if ! $IS_WSL; then
  step "Theming terminal apps (Tokyo Night)"
  backup() { [ -f "$1" ] && cp "$1" "$1.bak"; mkdir -p "$(dirname "$1")"; }

  if ! have alacritty && ! have ghostty && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    info "installing Alacritty (the terminal Omarchy uses)"
    if have apt-get; then $SUDO apt-get install -y alacritty >/dev/null 2>&1 || true
    elif have dnf; then $SUDO dnf install -y alacritty >/dev/null 2>&1 || true
    elif have pacman; then $SUDO pacman -S --needed --noconfirm alacritty >/dev/null 2>&1 || true; fi
  fi

  if have alacritty; then
    backup "$HOME/.config/alacritty/alacritty.toml"
    cat > "$HOME/.config/alacritty/alacritty.toml" <<'EOF'
[window]
padding = { x = 14, y = 14 }
opacity = 0.92

[font]
normal = { family = "CaskaydiaMono Nerd Font", style = "Regular" }
size = 11

[cursor]
style = { shape = "Beam" }

[colors.primary]
background = "#1a1b26"
foreground = "#a9b1d6"

[colors.cursor]
cursor = "#c0caf5"
text = "#1a1b26"

[colors.selection]
background = "#33467c"
text = "#c0caf5"

[colors.normal]
black = "#15161e"
red = "#f7768e"
green = "#9ece6a"
yellow = "#e0af68"
blue = "#7aa2f7"
magenta = "#bb9af7"
cyan = "#7dcfff"
white = "#a9b1d6"

[colors.bright]
black = "#414868"
red = "#f7768e"
green = "#9ece6a"
yellow = "#e0af68"
blue = "#7aa2f7"
magenta = "#bb9af7"
cyan = "#7dcfff"
white = "#c0caf5"
EOF
    info "Alacritty themed"
  fi

  if have ghostty; then
    backup "$HOME/.config/ghostty/config"
    cat > "$HOME/.config/ghostty/config" <<'EOF'
font-family = CaskaydiaMono Nerd Font
font-size = 11
window-padding-x = 14
window-padding-y = 14
background-opacity = 0.92
cursor-style = bar
background = #1a1b26
foreground = #a9b1d6
cursor-color = #c0caf5
selection-background = #33467c
selection-foreground = #c0caf5
palette = 0=#15161e
palette = 1=#f7768e
palette = 2=#9ece6a
palette = 3=#e0af68
palette = 4=#7aa2f7
palette = 5=#bb9af7
palette = 6=#7dcfff
palette = 7=#a9b1d6
palette = 8=#414868
palette = 9=#f7768e
palette = 10=#9ece6a
palette = 11=#e0af68
palette = 12=#7aa2f7
palette = 13=#bb9af7
palette = 14=#7dcfff
palette = 15=#c0caf5
EOF
    info "Ghostty themed"
  fi
fi

# ─────────────────────────────────────────────────────────────
step "Setting up LazyVim"
NVIM_DIR="$HOME/.config/nvim"
if [ -f "$NVIM_DIR/lua/config/lazy.lua" ] && grep -q LazyVim "$NVIM_DIR/lua/config/lazy.lua"; then
  info "LazyVim already installed, keeping your config"
else
  stamp="$(date +%Y%m%d-%H%M%S)"
  for d in "$NVIM_DIR" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [ -e "$d" ] && mv "$d" "$d.bak-$stamp" && info "backed up $d"
  done
  # pinned starter commit (git verifies the content matches the commit hash)
  git init -q "$NVIM_DIR"
  git -C "$NVIM_DIR" fetch -q --depth 1 https://github.com/LazyVim/starter "$LAZYVIM_STARTER_COMMIT"
  git -C "$NVIM_DIR" checkout -q FETCH_HEAD
  rm -rf "$NVIM_DIR/.git"
  # pinned plugin versions (LazyVim installs exactly these commits)
  cat > "$NVIM_DIR/lazy-lock.json" <<'EOF'
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
EOF
  info "LazyVim starter installed (pinned)"
fi

# Normal line numbers instead of relative ones
OPTS="$NVIM_DIR/lua/config/options.lua"
if ! grep -qE 'relativenumber *= *false' "$OPTS" 2>/dev/null; then
  printf '\n-- Show normal line numbers (1, 2, 3...) instead of distance from the cursor\nvim.opt.relativenumber = false\n' >> "$OPTS"
fi

# No autocomplete popup in plain text / Markdown
mkdir -p "$NVIM_DIR/lua/plugins"
cat > "$NVIM_DIR/lua/plugins/completion.lua" <<'EOF'
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
EOF

info "downloading plugins (first run takes a minute)..."
nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || warn "plugin install reported a problem; open nvim to finish"
info "plugins installed"

# ─────────────────────────────────────────────────────────────
printf '\n\033[1;32mAll done! Open a new terminal (or run: source ~/.bashrc).\033[0m\n'
printf '\033[2mTry: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch\033[0m\n'
