#!/bin/bash

LOG_DIR="${HOME}/Library/Logs/Worky"
LOG_FILE="${LOG_DIR}/ghostty.log"
DEBUG_GHOSTTY="${WORKY_GHOSTTY_DEBUG:-0}"
mkdir -p "$LOG_DIR"
exec 3>>"$LOG_FILE"
exec 2>>"$LOG_FILE"
PS4='+ $(date "+%Y-%m-%d %H:%M:%S") '
if [ "$DEBUG_GHOSTTY" = "1" ]; then
    set -x
fi

log() {
    printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$*" >&3
}

log "==== Ghostty script start: args=[$*] pid=$$ ===="

dump_windows() {
    local snapshot
    snapshot=$(osascript <<'END'
tell application "System Events"
    if not (exists process "Ghostty") then return "Ghostty not running"
    tell process "Ghostty"
        if (count of windows) is 0 then return "Ghostty windows: 0"
        set output to "Ghostty windows: " & (count of windows) & linefeed
        repeat with i from 1 to (count of windows)
            set w to window i
            set winTitle to title of w
            try
                set axDoc to value of attribute "AXDocument" of w
            on error
                set axDoc to "<none>"
            end try
            set output to output & "  [" & i & "] " & winTitle & " | " & axDoc & linefeed
        end repeat
        return output
    end tell
end tell
END
)
    log "$snapshot"
}

find_window_index() {
    local result
    result=$(osascript <<END
tell application "System Events"
    if not (exists process "Ghostty") then
        return "0"
    end if
    tell process "Ghostty"
        if (count of windows) is 0 then
            return "0"
        end if

        repeat with i from 1 to (count of windows)
            set w to window i
            try
                set axDoc to value of attribute "AXDocument" of w
                if axDoc is "$TARGET_URL" then
                    return i as string
                end if
            end try
        end repeat

        return "0"
    end tell
end tell
END
)
    if [ $? -ne 0 ]; then
        echo "Error: AppleScript failed while searching Ghostty windows" >&2
        log "AppleScript failed while searching Ghostty windows"
        exit 1
    fi
    echo "$result"
}

# Usage:
#   ./open_or_create_ghostty.sh <directory> [rgb_color]
#   ./open_or_create_ghostty.sh --get-active
# rgb_color format: "R,G,B" (e.g., "255,128,64") or "#RRGGBB" (e.g., "#FF8040")

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <directory> [rgb_color]"
    echo "       $0 --get-active"
    echo "  rgb_color format: 'R,G,B' or '#RRGGBB'"
    exit 1
fi

if [ "$1" = "--get-active" ]; then
    ACTIVE_AXDOC=$(osascript <<'END'
tell application "System Events"
    if not (exists process "Ghostty") then return ""
    tell process "Ghostty"
        set targetWindow to missing value
        try
            set focusedWindow to value of attribute "AXFocusedWindow"
            if focusedWindow is not missing value then set targetWindow to focusedWindow
        end try
        if targetWindow is missing value then
            repeat with w in windows
                try
                    set isMain to value of attribute "AXMain" of w
                    if isMain is true then
                        set targetWindow to w
                        exit repeat
                    end if
                end try
            end repeat
        end if
        if targetWindow is missing value then
            if (count of windows) > 0 then set targetWindow to window 1
        end if
        if targetWindow is missing value then return ""
        try
            set axDoc to value of attribute "AXDocument" of targetWindow
            return axDoc as string
        on error
            return ""
        end try
    end tell
end tell
return ""
END
)
    if [ $? -ne 0 ]; then
        echo "Error: AppleScript failed while reading active Ghostty window" >&2
        log "AppleScript failed while reading active Ghostty window"
        exit 1
    fi

    log "active axdoc raw: [$ACTIVE_AXDOC]"
    ACTIVE_AXDOC="$(echo "$ACTIVE_AXDOC" | tr -d '\r' | tr -d '\n')"
    if [ -z "$ACTIVE_AXDOC" ] || [ "$ACTIVE_AXDOC" = "missing value" ]; then
        exit 0
    fi

    if [[ "$ACTIVE_AXDOC" == file://* ]]; then
        RAW_PATH="${ACTIVE_AXDOC#file://}"
        if [[ "$RAW_PATH" == /* ]]; then
            :
        elif [[ "$RAW_PATH" == //* ]]; then
            RAW_PATH="/${RAW_PATH#//}"
        else
            RAW_PATH="/$RAW_PATH"
        fi
        if command -v /usr/bin/python3 >/dev/null 2>&1; then
            RAW_PATH="$(/usr/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$RAW_PATH")"
        fi
    else
        RAW_PATH="$ACTIVE_AXDOC"
    fi

    RAW_PATH="${RAW_PATH%/}"
    if [ -n "$RAW_PATH" ]; then
        log "active path: [$RAW_PATH]"
        echo "$RAW_PATH"
    fi
    exit 0
fi

WORKDIR="$1"
BG_COLOR="$2"

# Convert to absolute path
if [[ "$WORKDIR" != /* ]]; then
    WORKDIR="$(cd "$WORKDIR" 2>/dev/null && pwd)" || {
        echo "Error: Directory '$1' does not exist or is not accessible"
        exit 1
    }
fi

# Verify directory exists
if [ ! -d "$WORKDIR" ]; then
    echo "Error: Directory '$WORKDIR' does not exist"
    exit 1
fi

# Parse and validate background color if provided
OSC_COLOR=""
if [ -n "$BG_COLOR" ]; then
    if [[ "$BG_COLOR" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
        # Hex format: #RRGGBB
        HEX="${BASH_REMATCH[1]}"
        R=$((16#${HEX:0:2}))
        G=$((16#${HEX:2:2}))
        B=$((16#${HEX:4:2}))
    elif [[ "$BG_COLOR" =~ ^([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})$ ]]; then
        # RGB format: R,G,B
        R="${BASH_REMATCH[1]}"
        G="${BASH_REMATCH[2]}"
        B="${BASH_REMATCH[3]}"
        # Validate ranges
        if [ "$R" -gt 255 ] || [ "$G" -gt 255 ] || [ "$B" -gt 255 ]; then
            echo "Error: RGB values must be between 0 and 255"
            exit 1
        fi
    else
        echo "Error: Invalid color format. Use 'R,G,B' or '#RRGGBB'"
        exit 1
    fi

    # Convert to hex format for OSC sequence
    printf -v OSC_COLOR "#%02x%02x%02x" "$R" "$G" "$B"
    echo "Background color: $OSC_COLOR (R=$R, G=$G, B=$B)"
fi

# Convert to file:// URL (add trailing slash like AXDocument does)
TARGET_URL="file://${WORKDIR}/"

log "looking for Ghostty window with directory: [$WORKDIR]"
log "target url: [$TARGET_URL]"
echo "Looking for Ghostty window with directory: $WORKDIR"
echo "Target URL: $TARGET_URL"
echo ""

if [ "$DEBUG_GHOSTTY" = "1" ]; then
    dump_windows
fi
# Search for existing window with this AXDocument
FOUND_WINDOW=$(find_window_index)
log "found window index: [$FOUND_WINDOW]"

if [ "$FOUND_WINDOW" != "0" ]; then
    echo "Found existing window #$FOUND_WINDOW - bringing to foreground"
    log "bringing existing window #$FOUND_WINDOW to foreground"

    osascript <<END
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    tell process "Ghostty"
        set frontmost to true
        set w to window $FOUND_WINDOW
        perform action "AXRaise" of w
    end tell
end tell
END
    if [ $? -ne 0 ]; then
        echo "Error: AppleScript failed while focusing Ghostty window #$FOUND_WINDOW" >&2
        log "AppleScript failed while focusing Ghostty window #$FOUND_WINDOW"
        exit 1
    fi

    echo "Done!"
else
    echo "No existing window found - creating new one"
    log "no existing window found; creating new window"

    # Get directory name for title
    DIR_NAME=$(basename "$WORKDIR")

    # Build commands - using echo with -e to handle escape sequences
    if [ -n "$OSC_COLOR" ]; then
        # OSC 11 sets background color: ESC ] 11 ; COLOR BEL
        # Use echo -e to interpret escape sequences
        SETUP_CMD="cd '$WORKDIR' && echo -e '\\\\033]11;$OSC_COLOR\\\\007' && clear"
    else
        SETUP_CMD="cd '$WORKDIR' && clear"
    fi

    log "setup command: [$SETUP_CMD]"
    osascript <<END
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    repeat 20 times
        if exists process "Ghostty" then exit repeat
        delay 0.1
    end repeat
    if not (exists process "Ghostty") then error "Ghostty process not running"
    tell process "Ghostty"
        set frontmost to true
        set startCount to count of windows
    end tell
    keystroke "n" using {command down}
end tell

repeat 10 times
    tell application "System Events"
        tell process "Ghostty"
            if (count of windows) > startCount then exit repeat
        end tell
    end tell
    delay 0.02
end repeat

tell application "System Events"
    tell process "Ghostty"
        if (count of windows) is startCount then error "Ghostty did not open a new window"
        set targetWindow to window 1
        if targetWindow is missing value then error "Ghostty did not provide a focusable window"
        try
            set value of attribute "AXFocusedWindow" to targetWindow
        end try
        perform action "AXRaise" of targetWindow
        set frontmost to true
    end tell
end tell

tell application "System Events"
    keystroke "$SETUP_CMD"
    keystroke return
end tell
END
    if [ $? -ne 0 ]; then
        echo "Error: AppleScript failed while creating Ghostty window" >&2
        log "AppleScript failed while creating Ghostty window"
        exit 1
    fi
    if [ "$DEBUG_GHOSTTY" = "1" ]; then
        dump_windows
    fi
    CREATED_WINDOW=$(find_window_index)
    log "post-create window index: [$CREATED_WINDOW]"
    if [ "$CREATED_WINDOW" = "0" ]; then
        echo "Error: Ghostty window not created or not matching target directory" >&2
        log "Ghostty window not created or not matching target directory"
        exit 1
    fi

    echo "Created new window in: $WORKDIR"
fi
