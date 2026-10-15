fcrop() {
  if [[ -z "$1" ]]; then
    echo "Usage: fcrop <video_file>"
    return 1
  fi
  ffmpeg -i "$1" -vf cropdetect=24:16:0 -f null -
}

ff1() {
    codec=(-c:v h264_videotoolbox -crf 31)
    vf_stack=("scale=-1:360")

    # Adjust second argument if it contains ":"
    if [[ "$2" == *:* ]]; then
        second_arg="00:$2"
    else
        second_arg="$2"
    fi

    # Construct FFmpeg command
    cmd=(ffmpeg -hide_banner -i "$1" "${codec[@]}" -c:a copy -preset fast -t 1)
    [[ -n "$second_arg" ]] && cmd+=(-ss "$second_arg")
    cmd+=(-vf "${vf_stack[*]}" -y "${1%.*}_1.mp4")

    # **Formatted output display**
    echo -n "Executing:"
    for arg in "${cmd[@]}"; do
        [[ "$arg" == "$1" || "$arg" == "${1%.*}_1.mp4" ]] && printf ' "%s"' "$arg" || printf ' %s' "$arg"
    done
    echo

    # Run command
    "${cmd[@]}"
}

# ffbr <file> [720] [-p percent]
# Prints the target video bitrate in kbps (default: 65% of source).
# With 720, the short side is capped at 720 (width if vertical, height otherwise),
# and the bitrate is scaled by the resulting pixel-count ratio.
ffbr() {
    local input="$1" use720=0 pct=65 w h br
    shift
    while (( $# )); do
        case "$1" in
            720) use720=1 ;;
            -p)  pct="$2"; shift ;;
        esac
        shift
    done

    if [[ -z "$input" || ! -f "$input" ]]; then
        echo "ffbr: usage: ffbr <file> [720] [-p percent]" >&2
        return 1
    fi

    local probe
    probe=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,bit_rate \
        -of default=nw=1 "$input")

    w=$(awk -F= '$1=="width"{print $2; exit}' <<< "$probe")
    h=$(awk -F= '$1=="height"{print $2; exit}' <<< "$probe")
    br=$(awk -F= '$1=="bit_rate"{print $2; exit}' <<< "$probe")

    # Fall back to container bitrate (mkv/webm etc.)
    if [[ ! "$br" =~ ^[0-9]+$ ]]; then
        br=$(ffprobe -v error -show_entries format=bit_rate -of default=nw=1:nk=1 "$input")
    fi

    if [[ ! "$br" =~ ^[0-9]+$ || ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; then
        echo "ffbr: couldn't read width/height/bitrate" >&2
        return 1
    fi

    awk -v w="$w" -v h="$h" -v b="$br" -v p="$pct" -v s="$use720" 'BEGIN {
        short = (w < h) ? w : h
        ratio = 1
        if (s && short > 720) { r = 720 / short; ratio = r * r }
        k = int(b * (p / 100) * ratio / 1000)
        if (k < 100) k = 100
        print k
    }'
}

ff() {
    codec=(-c:v hevc_videotoolbox -tag:v hvc1 -r 23.98 -b:a 64k -ar 44100 -movflags +faststart -pix_fmt nv12 -color_range pc -sws_flags lanczos)
    vf_stack=()
    start_mark=""
    end_mark=""
    to_flag=0
    q=""
    use264=0
    use720=0

    time_re='^[0-9:.]+$'
    reserved_args=(720 264)

    is_reserved() {
        local val="$1" r
        for r in "${reserved_args[@]}"; do
            [[ "$val" == "$r" ]] && return 0
        done
        return 1
    }

    # Input file
    input_file="$1"
    shift

    # Detect start_mark / end_mark
    if [[ "$1" =~ $time_re ]] && ! is_reserved "$1"; then
        [[ "$1" == *:* ]] && start_mark="00:$1" || start_mark="$1"
        shift
        if [[ "$1" =~ $time_re ]] && ! is_reserved "$1"; then
            [[ "$1" == *:* ]] && end_mark="00:$1" || end_mark="$1"
            [[ "$1" == *:* ]] && to_flag=1 || to_flag=0
            shift
        fi
    fi

    # Probe source: height, fps, bitrate
    probe=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=height,bit_rate,r_frame_rate \
        -of default=nw=1 "$input_file")

    src_h=$(awk -F= '$1=="height"{print $2; exit}' <<< "$probe")
    src_br=$(awk -F= '$1=="bit_rate"{print $2; exit}' <<< "$probe")
    fps=$(awk -F= '$1=="r_frame_rate"{print $2; exit}' <<< "$probe" | awk -F'/' '{ if ($2) print $1/$2; else print $1 }')

    # Fall back to container bitrate if the stream doesn't report one (mkv/webm etc.)
    if [[ ! "$src_br" =~ ^[0-9]+$ ]]; then
        src_br=$(ffprobe -v error -show_entries format=bit_rate -of default=nw=1:nk=1 "$input_file")
    fi

    (( $(printf "%.0f" "$fps") > 30 )) && vf_stack+=("fps=30")

    # Parse remaining args
    extra_args=()
    vf_flag=0
    while (( $# )); do
        case "$1" in
            264)
                use264=1
                codec=(-c:v h264_videotoolbox)
                vf_flag=0
                ;;
            720)
                use720=1
                vf_stack+=("scale='if(gt(ih,720),-1,iw)':'if(gt(ih,720),720,ih)'")
                vf_flag=0
                ;;
            -q)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "ff: -q requires a value" >&2
                    return 1
                fi
                q="$2"
                shift
                vf_flag=0
                ;;
            -vf)
                vf_flag=1
                ;;
            *)
                if [[ $vf_flag -eq 1 && ! "$1" =~ ^- ]]; then
                    vf_stack+=("$1")
                else
                    vf_flag=0
                    extra_args+=("$1")
                fi
                ;;
        esac
        shift
    done

    # Quality / bitrate
    if [[ -n "$q" ]]; then
        codec+=(-q:v "$q")
    elif (( use264 == 0 )); then
        if [[ "$src_br" =~ ^[0-9]+$ && "$src_h" =~ ^[0-9]+$ ]]; then
            # Pixel-count ratio after the 720 scale (height-capped, aspect preserved)
            ratio=1
            if (( use720 )) && (( src_h > 720 )); then
                ratio=$(awk -v h="$src_h" 'BEGIN{ r=720/h; printf "%.6f", r*r }')
            fi
            kbps=$(awk -v b="$src_br" -v r="$ratio" 'BEGIN{ printf "%d", b*0.65*r/1000 }')
            (( kbps < 100 )) && kbps=100
            codec+=(-b:v "${kbps}k")
        else
            echo "ff: couldn't read source bitrate, falling back to -q:v 50" >&2
            codec+=(-q:v 50)
        fi
    fi

    # Build command
    cmd=(ffmpeg -hide_banner -i "$input_file" "${codec[@]}")
    [[ -n "$start_mark" ]] && cmd+=(-ss "$start_mark")
    [[ -n "$end_mark" ]] && cmd+=($([[ $to_flag -eq 1 ]] && echo "-to" || echo "-t") "$end_mark")
    [[ ${#vf_stack[@]} -gt 0 ]] && cmd+=(-vf "$(IFS=,; echo "${vf_stack[*]}")")
    cmd+=("${extra_args[@]}" -y "${input_file%.*}_.mp4")

    # Print it pretty
    echo -n "Executing:"
    for arg in "${cmd[@]}"; do
        [[ "$arg" == "$input_file" || "$arg" == "${input_file%.*}_.mp4" ]] && printf ' "%s"' "$arg" || printf ' %s' "$arg"
    done
    echo

    "${cmd[@]}"
}

# obsolete
ffq() {
    codec=(-c:v hevc_videotoolbox -tag:v hvc1 -q:v 50 -r 23.98 -b:a 64k -ar 44100 -movflags +faststart -pix_fmt nv12 -color_range pc -sws_flags lanczos )
    vf_stack=()
    add_fps=0
    start_mark=""
    end_mark=""


    # Time regex
    time_re='^[0-9:.]+$'

    # Reserved numeric argument values that are *not* times
    reserved_args=("720";"264")

    # Helper to check if value is a reserved keyword
    is_reserved() {
        local val="$1"
        for r in "${reserved_args[@]}"; do
            [[ "$val" == "$r" ]] && return 0
        done
        return 1
    }

    # Input file
    input_file="$1"
    shift

    # Detect start_mark
    if [[ "$1" =~ $time_re ]] && ! is_reserved "$1"; then
        [[ "$1" == *:* ]] && start_mark="00:$1" || start_mark="$1"
        shift
        # Detect end_mark (only if start mark is given!)
        if [[ "$1" =~ $time_re ]] && ! is_reserved "$1"; then
            [[ "$1" == *:* ]] && end_mark="00:$1" || end_mark="$1"
            [[ "$1" == *:* ]] && to_flag=1 || to_flag=0
            shift
        fi
    fi

    # Get FPS and apply fps filter if needed
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$input_file" | awk -F'/' '{ if ($2) print $1/$2; else print $1 }')
    (( $(printf "%.0f" "$fps") > 30 )) && vf_stack+=("fps=30")

    # Parse remaining args
    extra_args=()
    vf_flag=0
    for arg in "$@"; do
        if [[ "$arg" == "264" ]]; then
            codec=(-c:v h264_videotoolbox)
        elif [[ "$arg" == "720" ]]; then
            vf_stack+=("scale='if(gt(ih,720),-1,iw)':'if(gt(ih,720),720,ih)'")
        elif [[ "$arg" == "-vf" ]]; then
            vf_flag=1
        elif [[ $vf_flag -eq 1 && ! "$arg" =~ ^- ]]; then
            vf_stack+=("$arg")
        else
            vf_flag=0
            extra_args+=("$arg")
        fi
    done

    # Build command
    cmd=(ffmpeg -hide_banner -i "$input_file" "${codec[@]}")
    [[ -n "$start_mark" ]] && cmd+=(-ss "$start_mark")
    [[ -n "$end_mark" ]] && cmd+=($([[ $to_flag -eq 1 ]] && echo "-to" || echo "-t") "$end_mark")
    [[ ${#vf_stack[@]} -gt 0 ]] && cmd+=(-vf "$(IFS=,; echo "${vf_stack[*]}")")
    cmd+=("${extra_args[@]}" -y "${input_file%.*}_.mp4")

    # Print it pretty
    echo -n "Executing:"
    for arg in "${cmd[@]}"; do
        [[ "$arg" == "$input_file" || "$arg" == "${input_file%.*}_.mp4" ]] && printf ' "%s"' "$arg" || printf ' %s' "$arg"
    done
    echo

    # Run it
    "${cmd[@]}"
}

ff4() {
  ff "$@" 264
}

ff7() {
  ff "$@" 720
}
