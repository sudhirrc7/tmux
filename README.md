# tmux config

My tmux setup: a `C-a` prefix, vi copy mode, a handful of TPM plugins, and a
self-contained theme engine with 37 colour themes and 16 status bar styles that
can be switched live from a popup picker. The last theme, style and transparency
choice is remembered across tmux restarts.

## Requirements

- tmux 3.4 or newer (tested with 3.7)
- A [Nerd Font](https://www.nerdfonts.com/) in the terminal (icons and powerline separators)
- A terminal with true colour support (Ghostty, kitty, WezTerm, iTerm2, ...)
- [fzf](https://github.com/junegunn/fzf), a recent release (tested with 0.74), for the pickers
- [TPM](https://github.com/tmux-plugins/tpm) at `~/.tmux/plugins/tpm`
- bash (any version from 3.2 works)

## Install

```sh
git clone <this repo> ~/.config/tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux                     # then press prefix + I to install the plugins
```

tmux reads `~/.config/tmux/tmux.conf` automatically. After editing it, reload with:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```

## Keybindings

The prefix is `Ctrl-a`.

### Theme

| Keys           | Action                                                          |
| -------------- | --------------------------------------------------------------- |
| `prefix T`     | Theme picker with live preview (`ctrl-s` inside cycles styles)  |
| `prefix C-t`   | Next theme                                                      |
| `prefix M-t`   | Previous theme                                                  |
| `prefix S`     | Separator style picker with live preview                        |
| `prefix M-s`   | Next style                                                      |
| `prefix M-S`   | Previous style                                                  |
| `prefix B`     | Toggle the transparent status bar                               |

In both pickers, moving the cursor applies the theme or style immediately.
`Enter` keeps it, `Esc` restores what you had before.

### General

| Keys           | Action                                                          |
| -------------- | --------------------------------------------------------------- |
| `prefix C-a`   | Toggle the status bar                                           |
| `prefix g`     | lazygit in a popup, in the current pane's directory             |
| `prefix *`     | opencode in a popup, one persistent session per directory       |
| `prefix v`     | Turn the current window into a 3x3 grid of opencode panes       |
| `prefix V`     | Turn the current window into a 3x3 grid of codex panes          |

### Copy mode (vi)

| Keys  | Action                 |
| ----- | ---------------------- |
| `v`   | Start selection        |
| `V`   | Select line            |
| `C-v` | Toggle block selection |

### Plugins

| Keys            | Plugin                                                        |
| --------------- | ------------------------------------------------------------- |
| `prefix O`      | [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) session picker |
| `prefix p`      | [tmux-floax](https://github.com/omerxx/tmux-floax) floating pane         |
| `prefix C-f`    | [tmux-fzf](https://github.com/sainnhe/tmux-fzf) command menu              |
| `prefix C-h`    | [tmux-fzf-links](https://github.com/alberti42/tmux-fzf-links) open links and file paths |
| `prefix C-s` / `prefix C-r` | [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) save / restore |
| `Alt` + keys    | [tmux-tilish](https://github.com/jabirali/tmux-tilish) i3-style window management (`main-vertical` layout) |

Also loaded: tmux-sensible and tmux-yank.

## Theme engine

Everything lives in [`theme/`](theme):

| File                 | Purpose                                                                 |
| -------------------- | ----------------------------------------------------------------------- |
| `theme/theme.sh`     | Builds the status bar from a palette and style, runs the pickers, remembers choices |
| `theme/stats.sh`     | Memory, CPU and network numbers for the status bar (macOS and Linux)     |
| `theme/palettes/*.sh`| One file of colours per theme                                            |

The status bar shows the session name (which changes colour while the prefix is
held or the pane is in copy mode), the time, the window list in the centre, the
date and the hostname. With `@theme_stats 'on'` it also shows memory, CPU and
network upload/download, coloured green, yellow or red by load.

The theme also colours pane borders, messages, menus, popups and copy-mode
highlights.

### Themes

| Family       | Themes |
| ------------ | ------ |
| Catppuccin   | `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte` |
| Tokyo Night  | `tokyonight-night`, `tokyonight-storm`, `tokyonight-moon`, `tokyonight-day` |
| Gruvbox      | `gruvbox-dark`, `gruvbox-light`, `gruvbox-material` |
| Everforest   | `everforest-dark`, `everforest-light` |
| GitHub       | `github-dark`, `github-dark-dimmed`, `github-light` |
| Rosé Pine    | `rose-pine`, `rose-pine-moon`, `rose-pine-dawn` |
| Kanagawa     | `kanagawa-wave`, `kanagawa-dragon` |
| Ayu          | `ayu-dark`, `ayu-mirage` |
| My own       | `farblue`, `farblue-midnight` (from `~/personal/farblue.nvim`), `neonprism` (from `~/personal/neonprism.nvim`) |
| Others       | `nord`, `onedark`, `dracula`, `solarized-dark`, `nightfox`, `carbonfox`, `oxocarbon`, `monokai-pro`, `sonokai`, `cyberdream`, `poimandres` |

### Styles

| Style            | Look                                    |
| ---------------- | --------------------------------------- |
| `slant`          | `/  /` slanted edges (default)          |
| `slant-back`     | `\  \` slanted the other way            |
| `trapezoid`      | `/‾\` segments                          |
| `trapezoid-down` | `\_/` segments                          |
| `bubble`         | Rounded pills                           |
| `bubble-concave` | Inward curves                           |
| `arrow`          | Classic powerline arrows                |
| `arrow-reverse`  | Arrows pointing the other way           |
| `flame`, `pixel`, `blocks`, `ice` | Decorative Nerd Font edges |
| `straight`       | Plain flat blocks                       |
| `minimal`        | Text only: no backgrounds, no glyphs; current window in the accent colour |
| `dots`           | Text only, items split by `·`, windows marked `●` (current) and `○` |
| `underline`      | Text only, the session and current window are underlined |

### Options

Set in `tmux.conf`. The first three are only defaults: once you pick something
with a key, that choice wins.

| Option                | Default           | Meaning                                         |
| --------------------- | ----------------- | ----------------------------------------------- |
| `@theme_default`      | `everforest-dark` | Theme used until one is picked                  |
| `@theme_style`        | `slant`           | Style used until one is picked                  |
| `@theme_transparent`  | `off`             | Status bar uses the terminal background         |
| `@theme_stats`        | `off`             | Show memory, CPU and network in the status bar  |

Choices are saved in `${XDG_STATE_HOME:-~/.local/state}/tmux/` (`theme`,
`theme-style`, `theme-transparent`). Delete those files to fall back to the
options above.

### Adding a theme

Copy any file in `theme/palettes/` to `theme/palettes/<name>.sh` and change the
colours. It shows up in the picker and the cycle keys straight away.

```sh
# My Theme
BG=#1e1e2e        # status bar background
SURFACE=#313244   # segment background (time, date, current window name)
OVERLAY=#45475a   # dividers, inactive pane borders, selection
FG=#cdd6f4        # main text
MUTED=#7f849c     # inactive windows
ACCENT=#cba6f7    # session, current window number, hostname, active border
RED=#f38ba8
GREEN=#a6e3a1
YELLOW=#f9e2af
BLUE=#89b4fa
MAGENTA=#f5c2e7
CYAN=#94e2d5
ORANGE=#fab387
# Optional overrides
ACCENT_FG=#1e1e2e # text on accent blocks (defaults to BG)
PREFIX=#f9e2af    # session block while the prefix is held (defaults to YELLOW)
COPY=#89b4fa      # session block in copy mode (defaults to BLUE)
```

Write hex colours in lowercase (see [CLAUDE.md](CLAUDE.md) for why).

### Command line

```sh
theme/theme.sh list               # available themes
theme/theme.sh set nord           # apply and remember a theme
theme/theme.sh next | prev        # cycle themes
theme/theme.sh next-style-cycle   # cycle styles (also prev-style-cycle)
theme/theme.sh transparent        # toggle transparency
```
