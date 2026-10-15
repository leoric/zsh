# Convert images to .webp, using clipboard text as output name if available
wp() {
    # Get the filename without extension
    local base="${1%.*}"

    # Test if the base matches 'image' or 'image (number)'
    local condition1=$(echo "$base" | grep -E '^image(\s\([0-9]+\))?$')

    # Get clipboard content
    local clipboard_content=$(pbpaste)

    # Check if clipboard is non-empty and suitable for a filename
    if [[ -n "$clipboard_content" && "$clipboard_content" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        local condition2=1
    else
        local condition2=""
    fi

    # Determine the output filename
    if [[ -n "$condition1" && -n "$condition2" ]]; then
        output_name="$clipboard_content"
    else
        output_name="$base"
    fi

    # Convert to WebP
    cwebp -q 85 -alpha_q 100 -m 6 "$1" -o "$output_name.webp"
}

# Convert and remove original file
wpr() {
    wp "$1" && rm "$1"
}