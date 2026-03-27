#!/bin/bash
# pages_to_docx_watcher.sh
# 监控指定文件夹（含子文件夹），当 .pages 文件被保存时，自动导出 .docx
#
# 用法: ./pages_to_docx_watcher.sh /path/to/your/folder

WATCH_DIR="${1:-$HOME/Documents/F/Open-To-Work/2026-NewBoat/03-26-Department-for-Child-Protection}"

echo "📁 开始监控: $WATCH_DIR"
echo "   任何 .pages 文件保存后，将自动生成同名 .docx 和 .pdf"
echo "   按 Ctrl+C 停止"

convert_to_docx() {
    local pages_file="$1"
    local dir
    dir=$(dirname "$pages_file")
    local base
    base=$(basename "$pages_file" .pages)
    local docx_file="$dir/$base.docx"
    local pdf_file="$dir/$base.pdf"

    echo "🔄 检测到变更: $pages_file"
    echo "   → 正在导出: $docx_file"
    echo "   → 正在导出: $pdf_file"

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
        echo "   ✅ 完成: $docx_file"
        echo "   ✅ 完成: $pdf_file"
    else
        echo "   ❌ 失败: 请确认 Pages 已安装"
    fi
}

# .pages 是一个包（目录），fswatch 递归监控时会上报包内部的文件变更路径
# 需要从内部路径提取出 .pages 包的路径，并做去重（防止同一次保存触发多次）
LAST_CONVERTED=""
LAST_TIME=0

fswatch -0 -r "$WATCH_DIR" | while IFS= read -r -d '' changed_file; do

    # 从变更路径中提取 .pages 包路径（匹配 *.pages 或 *.pages/ 内部路径）
    if [[ "$changed_file" =~ (.*\.pages)(/|$) ]]; then
        pages_file="${BASH_REMATCH[1]}"

        # 去重：同一文件 5 秒内只处理一次（关闭文件时会产生多个事件，需更长窗口）
        now=$(date +%s)
        if [[ "$pages_file" == "$LAST_CONVERTED" && $(( now - LAST_TIME )) -lt 5 ]]; then
            continue
        fi
        LAST_CONVERTED="$pages_file"
        LAST_TIME=$now

        convert_to_docx "$pages_file"
    fi
done