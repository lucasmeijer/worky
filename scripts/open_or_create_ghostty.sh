#!/bin/bash

# Usage: ./open_or_create_ghostty.sh <directory>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

WORKDIR="$1"

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

    osascript <<END
tell application "Ghostty"
    activate

    tell application "System Events"
        keystroke "n" using {command down}
    end tell

    delay 0.5

    tell application "System Events"
        keystroke "cd '$WORKDIR' && clear"
        keystroke return
    end tell
end tell
END

    echo "Created new window in: $WORKDIR"
fi
