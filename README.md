# terminal-setup

Omarchy-style terminal on Windows, Linux and macOS: Tokyo Night colors, CaskaydiaMono Nerd Font,
Starship prompt, Linux-style commands, lazygit, lazydocker and LazyVim.

![Demo: fastfetch, ls/ll/lt, cat and grep, LazyVim and lazygit in a Tokyo Night terminal](demo.gif)

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

## Security

Nothing is downloaded and run blindly. Every download is either verified by a package manager or pinned to an exact version and checked against a SHA-256 hash written in the script. If a hash doesn't match, the script stops before using the file.

| Source | How it's verified |
|---|---|
| winget (Windows) | winget checks each installer's SHA-256 from its manifest |
| apt / dnf / pacman (Linux) | Packages are GPG-signed by the distro |
| Homebrew (macOS) | Homebrew checks SHA-256 for every package |
| Homebrew itself (macOS) | Pinned `Homebrew.pkg` + SHA-256 + Apple Developer ID signature check |
| GitHub release files (font, tree-sitter, and Linux fallbacks: starship, zoxide, eza, fastfetch, lazygit, lazydocker, neovim) | Pinned version + SHA-256, cross-checked against each project's own checksum files |
| LazyVim | Starter pinned to a commit; plugins pinned with `lazy-lock.json` |

The pins live at the top of each script. To update a tool, change its URL and hash (GitHub shows each file's sha256 on its release page).

Scripts never ask for or store passwords. `sudo` is only used on Linux to run the package manager, and only when something is missing. On macOS it's only used to install the signed Homebrew package.

## Where the configs live
| | Windows | Linux / macOS |
|---|---|---|
| Prompt | `~\.config\starship.toml` | `~/.config/starship.toml` |
| Shell | `~\.config\powershell\profile.ps1` | `~/.bashrc` / `~/.zshrc` (between `omarchy-style` markers) |
| Terminal | Windows Terminal `settings.json` | `~/.config/alacritty/` or `~/.config/ghostty/` |
| LazyVim | `%LOCALAPPDATA%\nvim` | `~/.config/nvim` |
