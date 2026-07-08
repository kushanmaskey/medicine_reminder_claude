#!/bin/bash

# Usage: ./resize_images.sh [directory]
# Resizes images to meet Google Play Store phone screenshot requirements:
#   - PNG or JPEG
#   - Each side between 320 and 3,840 px
#   - 16:9 or 9:16 aspect ratio
#   - Under 8 MB per file

DIR="${1:-.}"
MIN_PX=320
MAX_PX=3840
MAX_BYTES=8388608  # 8 MB

check_aspect_ratio() {
    local w=$1 h=$2
    # Allow 2% tolerance for near-16:9 or 9:16
    local landscape=$(echo "scale=4; r=$w/$h; d=r-16/9; if(d<0)d=-d; if(d<0.04)1 else 0" | bc)
    local portrait=$(echo "scale=4; r=$h/$w; d=r-16/9; if(d<0)d=-d; if(d<0.04)1 else 0" | bc)
    if [[ "$landscape" == "1" || "$portrait" == "1" ]]; then
        echo "ok"
    else
        echo "warn"
    fi
}

find "$DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
    w=$(sips -g pixelWidth  "$file" | awk '/pixelWidth/  {print $2}')
    h=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')

    if [[ -z "$w" || -z "$h" ]]; then
        echo "SKIP  (unreadable): $(basename "$file")"
        continue
    fi

    # Scale down if either side exceeds 3,840 px
    if (( w > MAX_PX || h > MAX_PX )); then
        echo "RESIZE (scaling down): $(basename "$file") — ${w}×${h} → longest side ${MAX_PX}px"
        sips -Z "$MAX_PX" "$file" --out "$file" > /dev/null
        w=$(sips -g pixelWidth  "$file" | awk '/pixelWidth/  {print $2}')
        h=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')
    fi

    # Warn if either side is below 320 px (can't auto-fix without distortion)
    if (( w < MIN_PX || h < MIN_PX )); then
        echo "WARN  (too small):  $(basename "$file") — ${w}×${h}, each side must be ≥ ${MIN_PX}px"
        continue
    fi

    # Check aspect ratio
    ar=$(check_aspect_ratio "$w" "$h")
    if [[ "$ar" == "warn" ]]; then
        echo "WARN  (aspect ratio): $(basename "$file") — ${w}×${h} is not 16:9 or 9:16"
    fi

    # Check file size
    size=$(stat -f%z "$file")
    if (( size > MAX_BYTES )); then
        size_mb=$(echo "scale=1; $size/1048576" | bc)
        echo "WARN  (file too large): $(basename "$file") — ${size_mb}MB exceeds 8MB limit"
    fi

    if [[ "$ar" == "ok" && "$size" -le "$MAX_BYTES" ]]; then
        echo "OK    ${w}×${h}: $(basename "$file")"
    fi
done

echo ""
echo "Done. Fix any WARN items manually before uploading."
