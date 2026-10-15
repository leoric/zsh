py() {
  if [[ -z "$VIRTUAL_ENV" ]]; then
    source ~/py.env/bin/activate
  fi
  python3 "$@"
}

python3() {
    if [[ "$1" == "-m" && "$2" == "pip" && "$3" == "install" ]]; then
        shift 3
        local packages=("$@")

        if command python3 -m pip install "${packages[@]}"; then
            return 0
        fi

        echo "pip install failed, trying Homebrew..."

        if brew install "${packages[@]}"; then
            return 0
        fi

        echo "Homebrew failed, trying pipx..."
        pipx install "${packages[@]}"
        return $?
    fi

    command python3 "$@"
}