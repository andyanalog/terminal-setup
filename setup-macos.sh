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
#  Pinned downloads: exact versions + SHA-256 fingerprints.
#  To update: change the URL and hash (GitHub shows each file's sha256
#  on the release page). Everything else comes from Homebrew, which
#  verifies its own downloads.
# ─────────────────────────────────────────────────────────────
HOMEBREW_PKG_URL=https://github.com/Homebrew/brew/releases/download/7.0.12/Homebrew.pkg
HOMEBREW_PKG_SHA=a9825310dce8d94bc97f70140700089183c3a894b1048501d933865d7c2441bd
LAZYVIM_STARTER_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99

# ─────────────────────────────────────────────────────────────
step "Homebrew"
if ! xcode-select -p >/dev/null 2>&1; then
  info "installing Apple's Command Line Tools (a window will pop up)"
  xcode-select --install || true
  echo "When the Command Line Tools finish installing, run this script again."
  exit 0
fi
if ! have brew; then
  info "installing Homebrew from its signed installer (it will ask for your password)"
  tmp="$(mktemp -d)"
  curl --proto '=https' --tlsv1.2 -fsSL "$HOMEBREW_PKG_URL" -o "$tmp/Homebrew.pkg"
  got="$(shasum -a 256 "$tmp/Homebrew.pkg" | cut -d' ' -f1)"
  if [ "$got" != "$HOMEBREW_PKG_SHA" ]; then
    printf '\033[1;31mSECURITY: Homebrew.pkg checksum mismatch, refusing to install.\033[0m\n' >&2; exit 1
  fi
  if ! pkgutil --check-signature "$tmp/Homebrew.pkg" | grep -q "signed by a developer certificate issued by Apple"; then
    printf '\033[1;31mSECURITY: Homebrew.pkg is not signed by an Apple Developer ID, refusing to install.\033[0m\n' >&2; exit 1
  fi
  sudo installer -pkg "$tmp/Homebrew.pkg" -target /
  rm -rf "$tmp"
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
printf '\n\033[1;32mAll done! Open the Ghostty app (Applications) and you are set.\033[0m\n'
printf '\033[2mTry: ls, ll, lt, cat, ff, n (LazyVim), lg (lazygit), lzd (lazydocker), btop, fastfetch\033[0m\n'
