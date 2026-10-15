# Prints the output base name: the clipboard text if the file is named
# "image" / "image (N)" and the clipboard is a filename-safe string,
# otherwise the file's own base name.
_av_name() {
    if ! command -v pbpaste >/dev/null 2>&1; then
        echo "av: 'pbpaste' not found in PATH" >&2
        return 1
    fi

    local base="${1%.*}"

    # Test if the base matches 'image' or 'image (number)'
    local condition1=$(echo "$base" | grep -E '^image(\s\([0-9]+\))?$')

    # Get clipboard content
    local clipboard_content=$(pbpaste)

    # Check if clipboard is non-empty and suitable for a filename
    local condition2=""
    if [[ -n "$clipboard_content" && "$clipboard_content" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        condition2=1
    fi

    if [[ -n "$condition1" && -n "$condition2" ]]; then
        echo "$clipboard_content"
    else
        echo "$base"
    fi
}

# Convert images to .avif, using clipboard text as output name if available
# Fixed-quality AVIF encode.
# Usage: av [-q quality] <file>   (quality 0-100, default 90)
av() {
    local OPTIND=1 opt
    local q=90

    while getopts ":q:" opt; do
        case "$opt" in
            q) q="$OPTARG" ;;
            :) echo "av: option -$OPTARG requires an argument" >&2; return 1 ;;
            *) echo "Usage: av [-q quality] <file>" >&2; return 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    if [[ -z "$1" ]]; then
        echo "Usage: av [-q quality] <file>" >&2
        return 1
    fi

    if [[ ! "$q" =~ ^[0-9]+$ ]] || (( q > 100 )); then
        echo "av: quality must be an integer 0-100" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "av: not a file: $1" >&2
        return 1
    fi

    if ! command -v avifenc >/dev/null 2>&1; then
        echo "av: 'avifenc' not found in PATH" >&2
        return 1
    fi

    local output_name
    output_name="$(_av_name "$1")" || return 1

    if ! avifenc -q "$q" --qalpha 100 -s 0 "$1" "$output_name.avif"; then
        echo "av: AVIF encoding failed" >&2
        return 1
    fi

    echo "$1 -> $output_name.avif  (fixed q=$q, qalpha=100 -- no SSIMULACRA2 check)"
}

# AVIF encode with SSIMULACRA2 quality search.
# Usage: avs <file>
# Falls back to `av` (q=90) if the search tooling is missing.
avs() {
    if [[ -z "$1" ]]; then
        echo "Usage: avs <file>" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "avs: not a file: $1" >&2
        return 1
    fi

    if ! command -v avifenc >/dev/null 2>&1; then
        echo "avs: 'avifenc' not found in PATH" >&2
        return 1
    fi

    #
    # The quality search needs ssymulacra2 plus the tooling it's
    # built on top of. If any of those are missing, fall back to
    # the fixed-quality `av` instead of failing outright.
    #
    local HAVE_SEARCH=1
    local _av_missing=""
    for cmd in ssymulacra2 magick mktemp awk tail sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            HAVE_SEARCH=0
            _av_missing="$cmd"
            break
        fi
    done

    if (( ! HAVE_SEARCH )); then
        printf '\e[1;5;31m*** avs: WARNING: "%s" not found — falling back to av (fixed q=90), no quality check performed ***\e[0m\n' \
            "$_av_missing" >&2
        av -q 90 "$1"
        return $?
    fi

    local output_name
    output_name="$(_av_name "$1")" || return 1

    local TARGET_SCORE=90
    local MIN_Q=60
    local MAX_Q=90
    local SPEED=0

    local work
    work="$(mktemp -d "${TMPDIR:-/tmp}/av.XXXXXX")"
    if [[ -z "$work" || ! -d "$work" ]]; then
        echo "avs: could not create temp dir" >&2
        return 1
    fi

    # Decode once to a canonical PNG -- this is what every trial
    # AVIF gets scored against, and what the final AVIF is encoded
    # from too, so the reported score matches the shipped file.
    local reference="$work/reference.png"
    if ! magick "$1" "$reference" >"$work/decode-source.log" 2>&1; then
        echo "avs: could not decode source image" >&2
        sed 's/^/  /' "$work/decode-source.log" >&2
        rm -rf "$work"
        return 1
    fi

    local _av_score=""

    _av_encode_test() {
        local q="$1"
        local avif="$work/test-${q}.avif"
        local decoded="$work/test-${q}.png"

        if ! avifenc --qcolor "$q" --qalpha "$q" -s "$SPEED" "$reference" "$avif" \
            >"$work/avifenc-${q}.log" 2>&1
        then
            return 1
        fi

        if ! magick "$avif" "$decoded" >"$work/decode-${q}.log" 2>&1; then
            return 1
        fi

        _av_score="$(ssymulacra2 "$reference" "$decoded" 2>/dev/null | tail -n 1)"
        [[ -n "$_av_score" ]]
    }

    local low=$MIN_Q high=$MAX_Q best=0 best_score=""

    if ! _av_encode_test "$MAX_Q"; then
        echo "avs: quality test failed at q=$MAX_Q" >&2
        unfunction _av_encode_test 2>/dev/null
        rm -rf "$work"
        return 1
    fi

    if awk -v s="$_av_score" -v t="$TARGET_SCORE" 'BEGIN { exit !(s >= t) }'; then
        best="$MAX_Q"
        best_score="$_av_score"

        while (( low <= high )); do
            local q=$(( (low + high) / 2 ))

            if ! _av_encode_test "$q"; then
                echo "avs: quality test failed at q=$q" >&2
                unfunction _av_encode_test 2>/dev/null
                rm -rf "$work"
                return 1
            fi

            if awk -v s="$_av_score" -v t="$TARGET_SCORE" 'BEGIN { exit !(s >= t) }'; then
                best="$q"
                best_score="$_av_score"
                high=$((q - 1))
            else
                low=$((q + 1))
            fi
        done
    else
        best="$MAX_Q"
        best_score="$_av_score"
        echo "avs: WARNING: SSIMULACRA2 $best_score < target $TARGET_SCORE at q=100 (using q=100 anyway)" >&2
    fi

    unfunction _av_encode_test 2>/dev/null

    if ! avifenc --qcolor "$best" --qalpha "$best" -s "$SPEED" "$reference" "$output_name.avif" \
        >"$work/final.log" 2>&1
    then
        echo "avs: final AVIF encoding failed" >&2
        sed 's/^/  /' "$work/final.log" >&2
        rm -rf "$work"
        return 1
    fi

    echo "$1 -> $output_name.avif  (q=$best, SSIMULACRA2=$best_score)"

    rm -rf "$work"
}

# Convert and remove original file
avr() {
    av "$1" && rm "$1"
}

# Convert .webp to .png using dwebp
png() {
    dwebp "$1" -o "$(basename "$1" .webp).png"
}

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

