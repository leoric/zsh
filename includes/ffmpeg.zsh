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

fcrop() {
  if [[ -z "$1" ]]; then
    echo "Usage: fcrop <video_file>"
    return 1
  fi
  ffmpeg -i "$1" -vf cropdetect=24:16:0 -f null -
}

ff() {
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
