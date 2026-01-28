#!/bin/bash

# List all Ghostty windows with their titles and AXDocument (working directory)

osascript <<'END'
tell application "System Events"
    tell process "Ghostty"
        if (count of windows) is 0 then
            return "No Ghostty windows found"
        end if

        set output to ""

        repeat with i from 1 to (count of windows)
            set w to window i
            set winTitle to title of w

            try
                set axDoc to value of attribute "AXDocument" of w
                set output to output & "Window " & i & ":" & linefeed
                set output to output & "  Title: " & winTitle & linefeed
                set output to output & "  AXDocument: " & axDoc & linefeed & linefeed
            on error
                set output to output & "Window " & i & ":" & linefeed
                set output to output & "  Title: " & winTitle & linefeed
                set output to output & "  AXDocument: <none>" & linefeed & linefeed
            end try
        end repeat

        return output
    end tell
end tell
END
