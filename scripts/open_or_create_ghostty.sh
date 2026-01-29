#!/bin/bash

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

echo "Looking for Ghostty window with directory: $WORKDIR"
echo "Target URL: $TARGET_URL"
echo ""

# Search for existing window with this AXDocument
FOUND_WINDOW=$(osascript <<END
tell application "System Events"
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

if [ "$FOUND_WINDOW" != "0" ]; then
    echo "Found existing window #$FOUND_WINDOW - bringing to foreground"

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

    echo "Done!"
else
    echo "No existing window found - creating new one"

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

    osascript <<END
tell application "Ghostty"
    activate

    tell application "System Events"
        keystroke "n" using {command down}
    end tell

    delay 0.5

    tell application "System Events"
        keystroke "$SETUP_CMD"
        keystroke return
    end tell
end tell
END

    echo "Created new window in: $WORKDIR"
fi
