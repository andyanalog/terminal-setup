# terminal-setup

Omarchy-style terminal on Windows, Linux and macOS: Tokyo Night colors, CaskaydiaMono Nerd Font,
Starship prompt, Linux-style commands, lazygit, lazydocker and LazyVim.

| System | Run | Then |
|---|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` | Reopen Windows Terminal |
| Linux / WSL | `bash setup-linux.sh` | Open a new terminal |
| macOS | `bash setup-macos.sh` | Open the Ghostty app |

All scripts are safe to run again. They skip what's installed and back up configs they replace (`.bak`).

## Commands you get

| Command | Does |
|---|---|
| `ls` `ll` `la` `lt` | List files (icons, details, hidden, tree) |
| `cat file` | Show a file with syntax colors |
| `ff` | Fuzzy-find a file with preview |
| `cd proj` | Jump to your most-used folder matching "proj" |
| `..` `...` | Go up one / two folders |
| `n` / `vim` | LazyVim (`n` alone opens the current folder) |
| `lg` / `lzd` | lazygit / lazydocker |
| `g` | git |
| `btop`, `fastfetch` | System monitor, system info |

On Windows, `grep`, `rm -rf`, `touch`, `head`, `tail`, `mkdir -p`, `which`, `export` also work like Linux.

## LazyVim tweaks
- Normal line numbers (not relative): `lua/config/options.lua`
- No autocomplete popup in `.txt` / Markdown: `lua/plugins/completion.lua`

## Where the configs live
| | Windows | Linux / macOS |
|---|---|---|
| Prompt | `~\.config\starship.toml` | `~/.config/starship.toml` |
| Shell | `~\.config\powershell\profile.ps1` | `~/.bashrc` / `~/.zshrc` (between `omarchy-style` markers) |
| Terminal | Windows Terminal `settings.json` | `~/.config/alacritty/` or `~/.config/ghostty/` |
| LazyVim | `%LOCALAPPDATA%\nvim` | `~/.config/nvim` |
