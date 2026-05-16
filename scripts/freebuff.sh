#!/bin/bash

SESSION=$(tmux display-message -p '#{session_name}')
CURRENT_WINDOW=$(tmux display-message -p '#{window_index}')
CURRENT_DIR=$(tmux display-message -p '#{pane_current_path}')

# Duplicate prevention: check if current window already has 9 panes
PANE_COUNT=$(tmux list-panes -t "$SESSION:$CURRENT_WINDOW" | wc -l)
if [ "$PANE_COUNT" -ge 9 ]; then
  tmux display-message "codex workspace already exists in this window!"
  exit 0
fi

# Save original window name and prevent automatic renaming
ORIGINAL_NAME=$(tmux display-message -p '#{window_name}')
tmux set-window-option -t "$SESSION:$CURRENT_WINDOW" automatic-rename off

# Create 9 panes in a 3x3 grid
# 3 columns
tmux split-window -h -t "$SESSION:$CURRENT_WINDOW.0"
tmux split-window -h -t "$SESSION:$CURRENT_WINDOW.1"
# Column 0: split vertically twice
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.0"
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.3"
# Column 1: split vertically twice
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.1"
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.5"
# Column 2: split vertically twice
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.2"
tmux split-window -v -t "$SESSION:$CURRENT_WINDOW.7"

tmux select-layout -t "$SESSION:$CURRENT_WINDOW" tiled

# Send 'codex' to the 8 newly created panes (indices 1-8) in the current directory
for PANE_IDX in 1 2 3 4 5 6 7 8; do
  tmux send-keys -t "$SESSION:$CURRENT_WINDOW.$PANE_IDX" "cd '$CURRENT_DIR' && codex" Enter
done

# Return to original window and restore its name
tmux select-window -t "$SESSION:$CURRENT_WINDOW"
tmux rename-window -t "$SESSION:$CURRENT_WINDOW" "$ORIGINAL_NAME"
tmux display-message "codex workspace created: 9 panes in current directory"
