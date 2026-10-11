#!/usr/bin/env bash
#
# tmux theme engine
#   theme.sh init         apply the remembered theme (run from tmux.conf)
#   theme.sh pick         fzf picker with live preview
#   theme.sh next|prev    cycle through themes
#   theme.sh pick-style   separator style picker with live preview
#   theme.sh next-style-cycle|prev-style-cycle   cycle separator styles
#   theme.sh set <name>   apply and remember a theme
#   theme.sh transparent  toggle the transparent status bar
#   theme.sh list         list available themes
#
# Palettes live in palettes/<name>.sh. The last choice is stored in
# ${XDG_STATE_HOME:-~/.local/state}/tmux so it survives tmux restarts.

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$DIR/theme.sh"
PALETTES="$DIR/palettes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
THEME_FILE="$STATE_DIR/theme"
STYLE_FILE="$STATE_DIR/theme-style"
TRANSPARENT_FILE="$STATE_DIR/theme-transparent"
PREVIEW_STYLE_FILE="$STATE_DIR/theme-style.preview"
GENERATED="$STATE_DIR/theme.conf"
STYLES="slant slant-back trapezoid trapezoid-down bubble bubble-concave arrow arrow-reverse flame pixel blocks ice straight minimal dots underline primeagen"

mkdir -p "$STATE_DIR"

tmux_opt() {
  local value
  value=$(tmux show -gqv "$1" 2>/dev/null)
  echo "${value:-$2}"
}

list_themes() {
  local file
  for file in "$PALETTES"/*.sh; do basename "$file" .sh; done
}

saved_theme() {
  local name
  name=$(cat "$THEME_FILE" 2>/dev/null)
  [ -n "$name" ] && [ -f "$PALETTES/$name.sh" ] || name=$(tmux_opt @theme_default everforest-dark)
  echo "$name"
}

saved_style() {
  local style
  style=$(cat "$STYLE_FILE" 2>/dev/null)
  echo "${style:-$(tmux_opt @theme_style slant)}"
}

saved_transparent() {
  local value
  value=$(cat "$TRANSPARENT_FILE" 2>/dev/null)
  echo "${value:-$(tmux_opt @theme_transparent off)}"
}

preview_style() {
  cat "$PREVIEW_STYLE_FILE" 2>/dev/null || saved_style
}

load_palette() {
  [ -f "$PALETTES/$1.sh" ] || return 1
  ACCENT_FG='' PREFIX='' COPY=''
  . "$PALETTES/$1.sh"
  ACCENT_FG=${ACCENT_FG:-$BG}
  PREFIX=${PREFIX:-$YELLOW}
  COPY=${COPY:-$BLUE}
}

# Powerline glyphs, built from bytes so editors cannot mangle them.
#   L: closes a segment toward the right, R: opens a segment from the left, T: thin divider
#   INV: the glyph is drawn in the neighbouring segment's colour instead (reversed shapes)
#   MIN: a text-only style with no segment backgrounds (see render_minimal)
glyphs() {
  local b=$'\xee\x82' c=$'\xee\x83'
  INV='' MIN=''
  case $1 in
    slant-back)     L="$b"$'\xb8' R="$b"$'\xbe' T="$b"$'\xb9' ;;
    trapezoid)      L="$b"$'\xb8' R="$b"$'\xba' T='│' ;;
    trapezoid-down) L="$b"$'\xbc' R="$b"$'\xbe' T='│' ;;
    bubble|round)   L="$b"$'\xb4' R="$b"$'\xb6' T='│' ;;
    bubble-concave) L="$b"$'\xb6' R="$b"$'\xb4' T='│' INV=1 ;;
    arrow)          L="$b"$'\xb0' R="$b"$'\xb2' T="$b"$'\xb1' ;;
    arrow-reverse)  L="$b"$'\xb2' R="$b"$'\xb0' T="$b"$'\xb3' INV=1 ;;
    flame)          L="$c"$'\x80' R="$c"$'\x82' T='│' ;;
    pixel)          L="$c"$'\x84' R="$c"$'\x85' T='│' ;;
    blocks)         L="$c"$'\x86' R="$c"$'\x87' T='│' ;;
    ice)            L="$c"$'\x88' R="$c"$'\x8a' T='│' ;;
    straight|flat)  L='' R='' T='│' ;;
    minimal|dots|underline|primeagen) L='' R='' T='' MIN=$1 ;;
    *)              L="$b"$'\xbc' R="$b"$'\xba' T="$b"$'\xbb' ;;
  esac
}

# transition <open|close> <left colour> <right colour>: sets TF/TB/TG (fg, bg, glyph)
transition() {
  local left=$2 right=$3
  [ "$left" = default ] && [ -n "$INV" ] && left=$BG
  [ "$right" = default ] && [ -n "$INV" ] && right=$BG
  if [ "$1" = close ]; then
    TG=$L
    if [ -n "$INV" ]; then TF=$right TB=$2; else TF=$left TB=$3; fi
  else
    TG=$R
    if [ -n "$INV" ]; then TF=$left TB=$3; else TF=$right TB=$2; fi
  fi
}

sep() {
  transition "$@"
  echo "#[fg=$TF,bg=$TB]$TG"
}

# Text-only status line: colour and spacing instead of filled segments.
render_minimal() {
  local div='  ' badge="#{?client_prefix,󰌌 ,#{?pane_in_mode,󰆏 ,}}" mark='' zoom
  zoom="#{?window_zoomed_flag,#[fg=$YELLOW] 󰁌,}"
  case $MIN in
    primeagen)
      # tmux's stock status line, as ThePrimeagen runs it, in the theme's colours
      window="#[fg=$FG]#I:#W#{?window_flags,#{window_flags}, }"
      current="#[fg=$FG,underscore]#I:#W#{?window_flags,#{window_flags}, }#[nounderscore]"
      wsep=' '
      justify=left
      left="#[fg=#{?client_prefix,$PREFIX,#{?pane_in_mode,$COPY,$FG}}][#S] "
      right="#[fg=$FG]#{?window_bigger,[#{window_offset_x}#,#{window_offset_y}] ,}\"#{=21:pane_title}\" %H:%M %d-%b-%y"
      if [ "$show_stats" = on ]; then
        right="#($stats mem $levels)  #($stats cpu $levels)  $right"
      fi
      return
      ;;
    dots)
      div="#[fg=$OVERLAY] · "
      window="#[fg=$OVERLAY]○ #[fg=$MUTED]#W#{?window_zoomed_flag, 󰁌,}#{?window_bell_flag,#[fg=$RED] 󰂞,}"
      current="#[fg=$ACCENT]● #[fg=$FG,bold]#W$zoom#[nobold]"
      wsep='   '
      ;;
    underline)
      mark=",underscore,us=$mode"
      window="#[fg=$MUTED] #I #W#{?window_zoomed_flag, 󰁌,}#{?window_bell_flag,#[fg=$RED] 󰂞,} "
      current="#[fg=$FG,bold,underscore,us=$ACCENT] #I #W$zoom #[nobold,nounderscore]"
      wsep=' '
      ;;
    *)
      window="#[fg=$MUTED]#I #W#{?window_zoomed_flag, 󰁌,}#{?window_bell_flag,#[fg=$RED] 󰂞,}"
      current="#[fg=$ACCENT,bold]#I #[fg=$FG]#W$zoom#[nobold]"
      wsep='   '
      ;;
  esac

  left=" #[fg=$mode,bold$mark]$badge#S#[nobold,nounderscore]$div#[fg=$MUTED]%H:%M"
  right="#[fg=$MUTED]%a %d %b$div#[fg=$ACCENT,bold]#h "
  if [ "$show_stats" = on ]; then
    left+="$div#($stats mem $levels)$div#($stats up ${MUTED#\#} ${FG#\#})"
    right="#($stats down ${MUTED#\#} ${FG#\#})$div#($stats cpu $levels)$div$right"
  fi
}

render() {
  local name=$1 style=$2 bg stats levels mode icon host left right window current show_stats
  local wsep=' ' justify=absolute-centre
  load_palette "$name" || return 1
  glyphs "$style"

  bg=$BG
  [ "$(saved_transparent)" = on ] && bg=default
  stats="$DIR/stats.sh"
  levels="${GREEN#\#} ${YELLOW#\#} ${RED#\#}"
  mode="#{?client_prefix,$PREFIX,#{?pane_in_mode,$COPY,$ACCENT}}"
  icon="#{?client_prefix,󰌌,#{?pane_in_mode,󰆏,}}"
  host='󰒋'
  [ "$(uname -s)" = Darwin ] && host=''

  show_stats=$(tmux_opt @theme_stats on)

  if [ -n "$MIN" ]; then
    render_minimal
  else
    left="#[fg=$ACCENT_FG,bg=$mode,bold] $icon #S #[nobold]$(sep close "$mode" "$SURFACE")"
    left+="#[fg=$FG,bg=$SURFACE] 󰥔 %H:%M $(sep close "$SURFACE" "$bg")#[default] "
    right=" $(sep open "$bg" "$SURFACE")#[fg=$FG,bg=$SURFACE] 󰃭 %a %d %b "
    right+="$(sep open "$SURFACE" "$ACCENT")#[fg=$ACCENT_FG,bg=$ACCENT,bold] $host #h "
    if [ "$show_stats" = on ]; then
      left+="#($stats mem $levels)  #($stats up ${MUTED#\#} ${FG#\#})"
      right="#($stats down ${MUTED#\#} ${FG#\#})  #($stats cpu $levels)$right"
    fi

    window="#[fg=$MUTED,bg=$bg] #I #[fg=$OVERLAY]$T#[fg=$MUTED] #W"
    window+="#{?window_zoomed_flag, 󰁌,}#{?window_bell_flag,#[fg=$RED] 󰂞,} "
    current="$(sep open "$bg" "$ACCENT")#[fg=$ACCENT_FG,bg=$ACCENT,bold] #I #[nobold]$(sep close "$ACCENT" "$SURFACE")"
    current+="#[fg=$FG,bg=$SURFACE,bold] #W#{?window_zoomed_flag,#[fg=$YELLOW] 󰁌,} #[nobold]$(sep close "$SURFACE" "$bg")"
  fi

  cat > "$GENERATED" <<EOF
set -g @theme '$name'
set -g @theme_active_style '$style'
set -g status-interval 2
set -g status-justify $justify
set -g status-style 'bg=$bg,fg=$FG'
set -g status-left-length 120
set -g status-right-length 120
set -g status-left '$left'
set -g status-right '$right'
set -g window-status-separator '$wsep'
set -g window-status-style 'bg=$bg,fg=$MUTED'
set -g window-status-current-style 'bg=$bg,fg=$FG'
set -g window-status-activity-style 'bg=$bg,fg=$YELLOW'
set -g window-status-bell-style 'bg=$bg,fg=$RED'
set -g window-status-format '$window'
set -g window-status-current-format '$current'
set -g pane-border-style 'fg=$OVERLAY'
set -g pane-active-border-style 'fg=$ACCENT'
set -g message-style 'bg=$SURFACE,fg=$FG'
set -g message-command-style 'bg=$SURFACE,fg=$ACCENT'
set -g mode-style 'bg=$OVERLAY,fg=$FG'
set -g copy-mode-match-style 'bg=$SURFACE,fg=$YELLOW'
set -g copy-mode-current-match-style 'bg=$YELLOW,fg=$ACCENT_FG'
set -g copy-mode-mark-style 'bg=$MAGENTA,fg=$ACCENT_FG'
set -g popup-style 'bg=$bg,fg=$FG'
set -g popup-border-style 'bg=$bg,fg=$ACCENT'
set -g popup-border-lines rounded
set -g menu-style 'bg=$BG,fg=$FG'
set -g menu-selected-style 'bg=$ACCENT,fg=$ACCENT_FG'
set -g menu-border-style 'fg=$OVERLAY'
set -g menu-border-lines rounded
set -g display-panes-colour '$MUTED'
set -g display-panes-active-colour '$ACCENT'
set -g clock-mode-colour '$ACCENT'
EOF
}

apply() {
  render "$1" "$2" && tmux source-file "$GENERATED"
}

set_theme() {
  apply "$1" "$(saved_style)" || { tmux display-message "Unknown theme: $1"; return 1; }
  echo "$1" > "$THEME_FILE"
  tmux display-message "󰏘  Theme: $1"
}

toggle_transparent() {
  local value=on
  [ "$(saved_transparent)" = on ] && value=off
  echo "$value" > "$TRANSPARENT_FILE"
  apply "$(saved_theme)" "$(saved_style)"
  tmux display-message "󰏘  Transparent status bar: $value"
}

cycle_theme() {
  local current themes count index=0 i
  current=$(saved_theme)
  themes=($(list_themes))
  count=${#themes[@]}
  for i in "${!themes[@]}"; do
    [ "${themes[$i]}" = "$current" ] && index=$i
  done
  set_theme "${themes[$(( (index + $1 + count) % count ))]}"
}

hex_to_rgb() {
  printf '%d;%d;%d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"
}

swatch_line() {
  local name=$1 color line kind rgb r g b
  load_palette "$name"
  rgb=$(hex_to_rgb "$BG")
  IFS=';' read -r r g b <<< "$rgb"
  kind='󰖔'
  [ $(( (r * 299 + g * 587 + b * 114) / 1000 )) -gt 140 ] && kind='󰖨'
  line=$(printf '%-22s %s  \e[48;2;%sm    \e[0m ' "$name" "$kind" "$rgb")
  for color in "$ACCENT" "$RED" "$ORANGE" "$YELLOW" "$GREEN" "$CYAN" "$BLUE" "$MAGENTA"; do
    line+=$(printf '\e[38;2;%sm●\e[0m ' "$(hex_to_rgb "$color")")
  done
  echo "$line"
}

cycle_style() {
  local current styles count index=0 i
  current=$(saved_style)
  styles=($STYLES)
  count=${#styles[@]}
  for i in "${!styles[@]}"; do
    [ "${styles[$i]}" = "$current" ] && index=$i
  done
  set_style "${styles[$(( (index + $1 + count) % count ))]}"
}

set_style() {
  apply "$(saved_theme)" "$1" || return 1
  echo "$1" > "$STYLE_FILE"
  tmux display-message "󰏘  Style: $1"
}

ansi() {
  printf '\e[38;2;%s;48;2;%sm%s' "$(hex_to_rgb "$1")" "$(hex_to_rgb "$2")" "$3"
}

# A miniature status bar drawn with the current theme, so each style can be seen in the list.
style_sample() {
  glyphs "$1"
  local line
  if [ -n "$MIN" ]; then
    case $MIN in
      primeagen)
        line=$(ansi "$FG" "$BG" '[main] ')$(printf '\e[4m')$(ansi "$FG" "$BG" '1:nvim*')$(printf '\e[24m')
        line+=$(ansi "$FG" "$BG" ' 2:zsh-        "host" 14:02 11-Oct-26 ')
        ;;
      dots)
        line=$(ansi "$ACCENT" "$BG" " main")$(ansi "$OVERLAY" "$BG" " · ")$(ansi "$MUTED" "$BG" "09:41     ")
        line+=$(ansi "$ACCENT" "$BG" "● ")$(ansi "$FG" "$BG" "nvim   ")$(ansi "$OVERLAY" "$BG" "○ ")$(ansi "$MUTED" "$BG" "zsh ")
        ;;
      underline)
        line=$(printf '\e[4m')$(ansi "$ACCENT" "$BG" " main")$(printf '\e[24m')$(ansi "$MUTED" "$BG" "  09:41     ")
        line+=$(printf '\e[4m')$(ansi "$FG" "$BG" " 1 nvim ")$(printf '\e[24m')$(ansi "$MUTED" "$BG" "  2 zsh ")
        ;;
      *)
        line=$(ansi "$ACCENT" "$BG" " main")$(ansi "$MUTED" "$BG" "  09:41     ")
        line+=$(ansi "$ACCENT" "$BG" "1 ")$(ansi "$FG" "$BG" "nvim   ")$(ansi "$MUTED" "$BG" "2 zsh ")
        ;;
    esac
    printf '%s\e[0m' "$line"
    return
  fi
  line=$(ansi "$ACCENT_FG" "$ACCENT" "  main ")
  transition close "$ACCENT" "$SURFACE"; line+=$(ansi "$TF" "$TB" "$TG")
  line+=$(ansi "$FG" "$SURFACE" " 󰥔 09:41 ")
  transition close "$SURFACE" "$BG"; line+=$(ansi "$TF" "$TB" "$TG")
  line+=$(ansi "$FG" "$BG" "  ")
  transition open "$BG" "$ACCENT"; line+=$(ansi "$TF" "$TB" "$TG")
  line+=$(ansi "$ACCENT_FG" "$ACCENT" " 1 ")
  transition close "$ACCENT" "$SURFACE"; line+=$(ansi "$TF" "$TB" "$TG")
  line+=$(ansi "$FG" "$SURFACE" " nvim ")
  transition close "$SURFACE" "$BG"; line+=$(ansi "$TF" "$TB" "$TG")
  line+=$(ansi "$MUTED" "$BG" " 2 ")$(ansi "$OVERLAY" "$BG" "$T")$(ansi "$MUTED" "$BG" " zsh ")
  printf '%s\e[0m' "$line"
}

pick_style() {
  local current index selection
  current=$(saved_style)
  index=$(echo $STYLES | tr ' ' '\n' | grep -nx "$current" | cut -d: -f1)
  load_palette "$(saved_theme)"

  selection=$(
    for style in $STYLES; do
      printf '%-16s %s\n' "$style" "$(style_sample "$style")"
    done |
      fzf --ansi --no-sort --cycle --layout=reverse --no-scrollbar --info=hidden \
        --with-shell 'bash -c' \
        --prompt '󰏘  ' --pointer '▌' --gutter ' ' \
        --header 'enter apply · esc cancel' --header-first \
        --color "bg:$BG,bg+:$SURFACE,fg:$MUTED,fg+:$FG,hl:$ACCENT,hl+:$ACCENT" \
        --color "pointer:$ACCENT,prompt:$ACCENT,header:$MUTED,gutter:$BG,separator:$OVERLAY" \
        --bind "load:pos(${index:-1})" \
        --bind "focus:execute-silent('$SELF' preview-style {1})"
  )

  if [ -n "$selection" ]; then
    set_style "${selection%% *}"
  else
    apply "$(saved_theme)" "$current"
  fi
}

picker_header() {
  echo "enter apply · esc cancel · ctrl-s style: $(preview_style)"
}

next_style() {
  local current next first='' found=''
  current=$(preview_style)
  for next in $STYLES; do
    [ -z "$first" ] && first=$next
    [ -n "$found" ] && { echo "$next"; return; }
    [ "$next" = "$current" ] && found=1
  done
  echo "$first"
}

pick() {
  local current index selection
  current=$(saved_theme)
  rm -f "$PREVIEW_STYLE_FILE"
  index=$(list_themes | grep -nx "$current" | cut -d: -f1)
  load_palette "$current"

  selection=$(
    list_themes | while read -r name; do swatch_line "$name"; done |
      fzf --ansi --no-sort --cycle --layout=reverse --no-scrollbar --info=hidden \
        --with-shell 'bash -c' \
        --prompt '󰏘  ' --pointer '▌' --gutter ' ' \
        --header "$(picker_header)" --header-first \
        --color "bg:$BG,bg+:$SURFACE,fg:$MUTED,fg+:$FG,hl:$ACCENT,hl+:$ACCENT" \
        --color "pointer:$ACCENT,prompt:$ACCENT,header:$MUTED,gutter:$BG,separator:$OVERLAY" \
        --bind "load:pos(${index:-1})" \
        --bind "focus:execute-silent('$SELF' preview {1})" \
        --bind "ctrl-s:execute-silent('$SELF' next-style {1})+transform-header('$SELF' header)"
  )

  if [ -n "$selection" ]; then
    [ -f "$PREVIEW_STYLE_FILE" ] && mv "$PREVIEW_STYLE_FILE" "$STYLE_FILE"
    set_theme "${selection%% *}"
  else
    rm -f "$PREVIEW_STYLE_FILE"
    apply "$current" "$(saved_style)"
  fi
}

case ${1:-init} in
  init)       apply "$(saved_theme)" "$(saved_style)" ;;
  pick)       pick ;;
  pick-style) pick_style ;;
  next-style-cycle) cycle_style 1 ;;
  prev-style-cycle) cycle_style -1 ;;
  preview-style) apply "$(saved_theme)" "$2" ;;
  next)       cycle_theme 1 ;;
  prev)       cycle_theme -1 ;;
  set)        set_theme "$2" ;;
  transparent) toggle_transparent ;;
  list)       list_themes ;;
  preview)    apply "$2" "$(preview_style)" ;;
  next-style) style=$(next_style); echo "$style" > "$PREVIEW_STYLE_FILE"; apply "$2" "$style" ;;
  header)     picker_header ;;
  *)          echo "usage: theme.sh [init|pick|next|prev|set <name>|transparent|list]" >&2; exit 1 ;;
esac
