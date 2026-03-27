#!/bin/bash
# pages_to_docx_watcher.sh
# Monitors a folder (including subfolders) for .pages file saves and auto-exports to .docx
#
# Usage: ./pages_to_docx_watcher.sh /path/to/your/folder

WATCH_DIR="${1:-$HOME/Documents/F/Open-To-Work/2026-NewBoat/03-26-Department-for-Child-Protection}"

echo "📁 Watching: $WATCH_DIR"
echo "   Any saved .pages file will be auto-exported to .docx and .pdf"
echo "   Press Ctrl+C to stop"

convert_to_docx() {
    local pages_file="$1"
    local dir
    dir=$(dirname "$pages_file")
    local base
    base=$(basename "$pages_file" .pages)
    local docx_file="$dir/$base.docx"
    local pdf_file="$dir/$base.pdf"

    echo "🔄 Change detected: $pages_file"
    echo "   → Exporting: $docx_file"
    echo "   → Exporting: $pdf_file"

    osascript <<EOF
set pagesPath to (POSIX file "$pages_file") as alias
set docxPath to POSIX file "$docx_file"
set pdfPath to POSIX file "$pdf_file"

tell application "Pages"
    set wasRunning to running
    set isOpen to false
    set targetDoc to missing value

    if wasRunning then
        repeat with d in every document
            try
                if (file of d) as alias = pagesPath then
                    set isOpen to true
                    set targetDoc to d
                    exit repeat
                end if
            end try
        end repeat
    end if

    if isOpen then
        -- Document is open: export in place without touching the window.
        try
            export targetDoc to docxPath as Microsoft Word
        end try
        try
            export targetDoc to pdfPath as PDF
        end try
    end if
    -- If not open (file was just closed), skip — the last save was already exported.
end tell
EOF

    if [ $? -eq 0 ]; then
        echo "   ✅ Done: $docx_file"
        echo "   ✅ Done: $pdf_file"
    else
        echo "   ❌ Failed: please make sure Pages is installed"
    fi
}

# .pages is a package (directory); fswatch reports changes to files inside the package.
# We extract the .pages package path and deduplicate to avoid processing one save multiple times.
LAST_CONVERTED=""
LAST_TIME=0

fswatch -0 -r "$WATCH_DIR" | while IFS= read -r -d '' changed_file; do

    # Extract the .pages package path from the changed file path
    if [[ "$changed_file" =~ (.*\.pages)(/|$) ]]; then
        pages_file="${BASH_REMATCH[1]}"

        # Deduplicate: process the same file at most once every 5 seconds
        now=$(date +%s)
        if [[ "$pages_file" == "$LAST_CONVERTED" && $(( now - LAST_TIME )) -lt 5 ]]; then
            continue
        fi
        LAST_CONVERTED="$pages_file"
        LAST_TIME=$now

        convert_to_docx "$pages_file"
    fi
done