#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Omarchy-style terminal setup for macOS
#
#  Installs Homebrew (if needed), Ghostty terminal with Tokyo Night colors,
#  CaskaydiaMono Nerd Font, Starship prompt, eza/bat/fzf/zoxide,
#  lazygit, lazydocker and LazyVim. Configures zsh (the macOS default).
#
#  Run:   bash setup-macos.sh
#  Safe to re-run: installed tools are skipped and configs are backed up.
#  After it finishes, use the Ghostty app as your terminal.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    \033[2m%s\033[0m\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ─────────────────────────────────────────────────────────────
step "Homebrew"
if ! have brew; then
  info "installing Homebrew (it will ask for your password)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
have brew || { echo "Homebrew install failed"; exit 1; }
info "ready ($(brew --prefix))"

# ─────────────────────────────────────────────────────────────
step "Installing tools"
for f in git starship eza bat fzf zoxide fastfetch btop lazygit lazydocker neovim ripgrep fd zsh-autosuggestions; do
  if brew list --formula "$f" >/dev/null 2>&1; then info "$f (already installed)"
  else brew install "$f" >/dev/null && info "$f installed" || warn "$f failed"; fi
done
# tree-sitter CLI (LazyVim uses it for syntax highlighting)
if have tree-sitter; then info "tree-sitter (already installed)"
else brew install tree-sitter-cli >/dev/null 2>&1 || brew install tree-sitter >/dev/null; info "tree-sitter installed"; fi

for c in font-caskaydia-mono-nerd-font ghostty; do
  if brew list --cask "$c" >/dev/null 2>&1; then info "$c (already installed)"
  else brew install --cask "$c" >/dev/null && info "$c installed" || warn "$c failed"; fi
done

# ─────────────────────────────────────────────────────────────
step "Theming Ghostty (Tokyo Night)"
GHOSTTY="$HOME/.config/ghostty/config"
mkdir -p "$(dirname "$GHOSTTY")"
[ -f "$GHOSTTY" ] && cp "$GHOSTTY" "$GHOSTTY.bak"
cat > "$GHOSTTY" <<'EOF'
font-family = CaskaydiaMono Nerd Font
font-size = 14
window-padding-x = 14
window-padding-y = 14
background-opacity = 0.92
cursor-style = bar
macos-option-as-alt = true
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
info "done"

# ─────────────────────────────────────────────────────────────
step "Writing Starship prompt config (~/.config/starship.toml)"
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
step "Adding aliases and prompt to zsh (~/.zshrc)"
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
# remove a previous copy of our block so re-runs don't duplicate it
awk '/# >>> omarchy-style >>>/{s=1} !s{print} /# <<< omarchy-style <<</{s=0}' "$ZSHRC" > "$ZSHRC.omarchy.tmp"
cat "$ZSHRC.omarchy.tmp" > "$ZSHRC"; rm -f "$ZSHRC.omarchy.tmp"
cat >> "$ZSHRC" <<'EOF'

# >>> omarchy-style >>>
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
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

# Tab menu, case-insensitive completion, Up/Down search history for what you've typed
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Grey suggestions from your history as you type (press → to accept)
[ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide   >/dev/null && eval "$(zoxide init --cmd cd zsh)"
command -v fzf      >/dev/null && source <(fzf --zsh)
# <<< omarchy-style <<<
EOF
info "updated $ZSHRC"

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
printf '\n\033[1;32mAll done! Open the Ghostty app (Applications) and you are set.\033[0m\n'
printf '\033[2mTry: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch\033[0m\n'
