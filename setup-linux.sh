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

case "$(uname -m)" in
  x86_64|amd64)  ARCH_RE='(x86_64|amd64|x64)' ;;
  aarch64|arm64) ARCH_RE='(arm64|aarch64)' ;;
  *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac

# URL of the newest GitHub release asset whose name matches a regex
gh_asset() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
    | grep -iE "$2" | head -n1 || true
}
# Download a .tar.gz and copy one binary from it into ~/.local/bin
install_from_tar() {  # <url> <binary-name>
  local tmp f; tmp="$(mktemp -d)"
  curl -fsSL "$1" -o "$tmp/pkg.tar.gz"
  tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
  f="$(find "$tmp" -type f -name "$2" | head -n1)"
  install -m 755 "$f" "$BIN/$2"
  rm -rf "$tmp"
}
github_tool() {  # <binary> <repo> <asset-regex>
  if have "$1"; then info "$1 (already installed)"; return; fi
  local url; url="$(gh_asset "$2" "$3")"
  if [ -z "$url" ]; then warn "could not find a download for $1"; return; fi
  install_from_tar "$url" "$1" && info "$1 installed from GitHub"
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
if ! have starship; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN" >/dev/null && info "starship installed"
else info "starship (already installed)"; fi

# zoxide from its installer (distro versions are often too old for `--cmd cd`)
if ! have zoxide || ! zoxide init --cmd cd bash >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null && info "zoxide installed"
else info "zoxide (already installed)"; fi

github_tool eza        eza-community/eza       "eza_${ARCH_RE}-unknown-linux-gnu\.tar\.gz$"
github_tool fastfetch  fastfetch-cli/fastfetch "fastfetch-linux-${ARCH_RE}\.tar\.gz$"
github_tool lazygit    jesseduffield/lazygit    "lazygit_[^/]*_linux_${ARCH_RE}\.tar\.gz$"
github_tool lazydocker jesseduffield/lazydocker "lazydocker_[^/]*_linux_${ARCH_RE}\.tar\.gz$"

# Neovim: LazyVim needs 0.11.2 or newer (distro packages are often older)
nvim_ok() {
  have nvim || return 1
  local v; v="$(nvim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  local maj min pat; IFS=. read -r maj min pat <<<"$v"
  [ "$maj" -gt 0 ] || [ "$min" -gt 11 ] || { [ "$min" -eq 11 ] && [ "$pat" -ge 2 ]; }
}
if nvim_ok; then info "neovim (already installed)"; else
  url="$(gh_asset neovim/neovim "nvim-linux-${ARCH_RE}\.tar\.gz$")"
  rm -rf "$HOME/.local/opt/nvim"; mkdir -p "$HOME/.local/opt/nvim"
  curl -fsSL "$url" | tar -xz -C "$HOME/.local/opt/nvim" --strip-components=1
  ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$BIN/nvim"
  info "neovim installed from GitHub"
fi

# tree-sitter CLI (LazyVim uses it to build syntax highlighting)
if have tree-sitter; then info "tree-sitter (already installed)"; else
  url="$(gh_asset tree-sitter/tree-sitter "tree-sitter-linux-${ARCH_RE}\.gz$")"
  if [ -n "$url" ]; then
    curl -fsSL "$url" | gunzip > "$BIN/tree-sitter" && chmod +x "$BIN/tree-sitter" && info "tree-sitter installed"
  else warn "could not find tree-sitter download"; fi
fi

# ─────────────────────────────────────────────────────────────
step "Installing CaskaydiaMono Nerd Font"
if fc-list 2>/dev/null | grep -qi "CaskaydiaMono Nerd"; then info "already installed"; else
  FONT_DIR="$HOME/.local/share/fonts/CaskaydiaMono"; mkdir -p "$FONT_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip -o "$tmp/font.zip"
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
  git clone --depth 1 -q https://github.com/LazyVim/starter "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"
  info "LazyVim starter installed"
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
nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || warn "plugin sync reported a problem; open nvim to finish"
info "plugins installed"

# ─────────────────────────────────────────────────────────────
printf '\n\033[1;32mAll done! Open a new terminal (or run: source ~/.bashrc).\033[0m\n'
printf '\033[2mTry: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch\033[0m\n'
