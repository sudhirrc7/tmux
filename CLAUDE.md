# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal tmux config. `tmux.conf` holds the options, keybindings and TPM plugin
list; `theme/` is a self-contained theme engine (no theme plugin is used);
`scripts/` holds two workspace launchers. `README.md` is the user-facing doc and
lists every keybinding, theme and style, so keep it in sync when any of those change.

`plugins/` is gitignored: TPM installs plugins there (TPM itself is at
`~/.tmux/plugins/tpm`). Don't edit plugin code.

## Commands

There is no build or test suite.

- Reload: `tmux source-file ~/.config/tmux/tmux.conf`
- Shell syntax check: `bash -n theme/theme.sh theme/stats.sh`
- Test on an isolated server so the user's running tmux and saved state are untouched:

  ```sh
  export XDG_STATE_HOME=<scratch dir>          # keeps theme state out of ~/.local/state
  tmux -L themetest -f ~/.config/tmux/tmux.conf new-session -d -s test -x 190 -y 20
  tmux -L themetest run-shell "~/.config/tmux/theme/theme.sh set nord"
  tmux -L themetest show -gv status-left       # inspect generated options
  tmux -L themetest show-messages              # config errors land here
  tmux -L themetest kill-server
  ```

  Pre-existing noise in `show-messages` (`invalid option: @tilish-*`,
  `unknown variable: FLOAX_*`, `TMUX_PLUGIN_MANAGER_PATH`) comes from plugins and is not
  caused by the theme.
- `tmux send-keys` writes into a pane and bypasses key tables, so it cannot test a
  `prefix + X` binding. Run the bound command with `run-shell` instead. It does work
  for driving an fzf picker that is already running in a pane.

## Theme engine (`theme/`)

`theme.sh` is a single bash script with subcommands (`init`, `pick`, `pick-style`,
`next`/`prev`, `next-style-cycle`/`prev-style-cycle`, `set`, `transparent`, `list`, plus
internal `preview`, `preview-style`, `next-style`, `header` used by the fzf bindings).

Flow: `render <theme> <style>` sources `palettes/<theme>.sh`, picks separator glyphs
for the style, and writes a complete tmux config to
`${XDG_STATE_HOME:-~/.local/state}/tmux/theme.conf`; `apply` then runs
`tmux source-file` on it. `tmux.conf` calls `theme.sh init` at startup, before TPM.

State files in that directory: `theme`, `theme-style`, `theme-transparent` (the
remembered choices, which override the `@theme_default`, `@theme_style` and
`@theme_transparent` options), and `theme-style.preview` (only exists while the
theme picker's `ctrl-s` is previewing a style; Esc deletes it, Enter promotes it).

Palettes define `BG SURFACE OVERLAY FG MUTED ACCENT RED GREEN YELLOW BLUE MAGENTA
CYAN ORANGE`, optionally `ACCENT_FG` (defaults to `BG`), `PREFIX` (defaults to
`YELLOW`) and `COPY` (defaults to `BLUE`). `farblue*` and `neonprism` are copied
from the user's own Neovim themes in `~/personal/farblue.nvim` and
`~/personal/neonprism.nvim` (mapped the way their lualine themes are); if those
palettes change, update the tmux copies by hand.

Styles: `glyphs <style>` sets `L` (closes a segment on its right), `R` (opens a
segment on its left), `T` (thin divider) and `INV`. Every segment edge goes through
`sep open|close <left colour> <right colour>`, never a hand-written `#[fg=..,bg=..]$L`,
because inverted styles (`INV=1`: `bubble-concave`, `arrow-reverse`) draw the glyph in
the neighbouring segment's colour. A new style is one `case` line in `glyphs` plus its
name in `STYLES`.

Text-only styles (`minimal`, `dots`, `underline`) set `MIN` in `glyphs` instead of
glyphs; `render` then calls `render_minimal`, which builds `left`/`right`/`window`/
`current` and `wsep` (window separator) without any segment backgrounds, and
`style_sample` has a matching branch for the picker preview.

`round` and `flat` are kept as aliases of `bubble` and `straight` for old state files.

`stats.sh` is called through `#()` jobs in the status line. Up and down run as two
separate jobs, so they share one network sample through a cache in
`$TMPDIR/tmux-theme-<uid>/net` that refreshes at most once per second.

## Gotchas

- **Private-use glyphs get stripped by the Write/Edit tools.** Nerd Font icons in the
  BMP private-use range (U+E000-U+F8FF, e.g. the powerline separators, U+F489 terminal,
  U+F179 Apple, U+F4BC CPU) silently disappear. Icons in the supplementary range
  (U+F0000+, the `󰍛`-style ones) survive. Separators are therefore built from bytes in
  `glyphs()` (`$'\xee\x82\xbc'`), and existing BMP icons were inserted with Python.
  Edit `theme.sh` and `stats.sh` with a Python script (read, `str.replace`, write), and
  after any change check that the icons are still there:
  `python3 -c "print([hex(ord(c)) for c in open('theme/theme.sh').read() if 0xe000<=ord(c)<=0xf8ff])"`
  should list `0xf489` and `0xf179`; the same check on `stats.sh` should list `0xf4bc`.
- **Hex colours must be lowercase.** tmux expands `#D`, `#F`, `#H`, `#I`, `#P`, `#S`,
  `#T`, `#W` and `#h` inside formats, so a colour like `#D27E99` would turn into a pane
  id followed by `27E99`.
- **No `#` in `#()` arguments.** The job runs through `sh`, where ` #...` starts a
  comment. Colours are passed to `stats.sh` without the leading `#` (`${GREEN#\#}`) and
  it adds it back.
- The generated `theme.conf` uses single-quoted values so tmux does not expand `$` or
  `~`; nothing that render writes may contain a single quote.
- Scripts must stay compatible with bash 3.2 (macOS `/bin/bash`): no associative arrays,
  no `${var,,}`, no `$'\u....'`.
- The fzf pickers use `--with-shell 'bash -c'` because the user's `$SHELL` is fish.

## Conventions

- `tmux.conf`: `#` comments, single-quoted strings, the theme section sits just
  before `run '~/.tmux/plugins/tpm/tpm'`, which stays last.
- Shell: `set -u`, `local` for function variables, lowercase function names, comments
  only where the reason isn't obvious.
- New keybindings: check the prefix table first (`tmux list-keys -T prefix`), and remember
  that plugins bind keys too (resurrect `C-s`/`C-r`, sessionx `O`, floax `p`, fzf-links
  `C-h`, tmux-fzf `C-f`, tilish uses `Alt` in the root table).
