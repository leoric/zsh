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

factorio_tag() {
  local info_path mod_version tag_name

  # Locate info.json anywhere under the current folder, preferring the one closest to it
  # (uses awk to rank by path depth instead of GNU find's -printf, which BSD/macOS find lacks)
  info_path=$(find . -name "info.json" -not -path "*/build/*" -not -path "*/.git/*" \
    | awk -F/ '{print NF, $0}' | sort -n | head -n1 | cut -d' ' -f2-)

  if [[ -z "$info_path" ]]; then
    echo "❌ Error: info.json not found anywhere under $(pwd)" >&2
    return 1
  fi

  mod_version=$(jq -r '.version' "$info_path")

  if [[ -z "$mod_version" || "$mod_version" == "null" ]]; then
    echo "❌ Error: Failed to parse 'version' from $info_path" >&2
    return 1
  fi

  tag_name="v${mod_version}"

  git tag "$tag_name" && echo "✅ Created tag $tag_name (from $info_path)"
}

factorio_deploy() {
    # 1. Save the starting directory absolute path
    local start_dir="$PWD"

    # Check for the existence of info.json in the current directory root
    if [ ! -f "info.json" ]; then
        echo "❌ Error: info.json not found in the current directory!"
        return 1
    fi

    echo "Parsing info.json..."
    
    # Use macOS built-in JavaScript engine to safely parse JSON
    local mod_name=$(osascript -l JavaScript -e "const fs = Application('System Events'); JSON.parse(JSON.stringify(require('fs').readFileSync('info.json', 'utf8'))).name" 2>/dev/null)
    local mod_version_raw=$(osascript -l JavaScript -e "const json = JSON.parse(JSON.stringify(require('fs').readFileSync('info.json', 'utf8'))); json.version" 2>/dev/null)

    # Fast fallback to awk if the JS engine fails
    if [ -z "$mod_name" ]; then
        mod_name=$(awk -F'"' '/"name"/{print $4}' info.json)
        mod_version_raw=$(awk -F'"' '/"version"/{print $4}' info.json)
    fi

    if [ -z "$mod_name" ] || [ -z "$mod_version_raw" ]; then
        echo "❌ Error: Failed to parse 'name' or 'version' from info.json"
        return 1
    fi

    local mod_version="${mod_name}_${mod_version_raw}"
    local zip_name="${mod_version}.zip"
    
    # 2. Define target destinations
    local mega_dir="$HOME/MEGA/games/factorio"
    local mods_dir="$HOME/Library/Application Support/factorio/mods"
    local target_link="$mods_dir/$zip_name"
    local tmp_dir="/tmp/factorio_build_$$"

    # Use Zsh's try/always block to guarantee cleanup and return home
    {
        echo "Starting deployment for mod: ${mod_name} (Version: ${mod_version_raw})..."

        # 3. Clean up existing symlink or file in Factorio mods directory
        if [ -L "$target_link" ]; then
            unlink "$target_link"
        elif [ -e "$target_link" ]; then
            echo -n "\n⚠️ Warning: '$target_link' already exists and is NOT a symlink. Overwrite? (y/N): "
            read -k 1 reply
            echo ""
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                rm -rf "$target_link"
            else
                echo "❌ Deployment aborted by user. Exiting."
                return 1
            fi
        fi

        # 4. Isolated Build: Create a clean structure inside /tmp
        echo "Creating isolated archive building structure..."
        mkdir -p "$tmp_dir/$mod_version"
        
        # Copy everything from current directory to the correctly named temp folder
        # Excluding git, macos metadata, and potential loop links
        rsync -a --exclude='.git*' --exclude='.DS_Store' --exclude='__MACOSX' "./" "$tmp_dir/$mod_version/"

        # Step into tmp, zip it from there, and move to MEGA
        cd "$tmp_dir" && \
        zip -r "$zip_name" "$mod_version" -x "*.DS_Store" -x "__MACOSX*" -x "*/images/*" && \
        mv "$zip_name" "$mega_dir/" && \

        # 5. Create the proper symlink inside mods_dir pointing to MEGA
        cd "$mods_dir" && \
        ln -s "$mega_dir/$zip_name" "$zip_name" && \
        
        # Open Factorio
        open "/Applications/Games/Factorio.app" && \
        echo "✅ Deployment complete! Symlink created in mods folder. Factorio is launching."

    } always {
        # 6. Safe Cleanup: Always wipe the temp build folder and return to project root
        if [ -d "$tmp_dir" ]; then
            rm -rf "$tmp_dir"
        fi
        cd "$start_dir"
    }
}

vibe_advance() {
    # Emulate standard zsh behavior and isolate options
    emulate -L zsh
    
    local VERSION_TYPE="minor"
    local MANUAL_VERSION=""
    local NEW_VERSION=""

    # 1. Smart argument processing
    if [[ -n "$1" && "$1" == *.** ]]; then
        MANUAL_VERSION="$1"
    else
        while (( $# > 0 )); do
            case "$1" in
                -v|--version)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        MANUAL_VERSION="$2"
                        shift 2
                    else
                        echo "Error: Flag $1 requires a version argument (e.g., 1.2.3)"
                        return 1
                    fi
                    ;;
                1|major) VERSION_TYPE="major"; shift ;;
                2|minor) VERSION_TYPE="minor"; shift ;;
                3|patch) VERSION_TYPE="patch"; shift ;;
                *)
                    echo "Error: Unknown argument '$1'"
                    echo "Usage: vibe_advance [major|minor|patch | 1|2|3] [X.X.X]"
                    return 1
                    ;;
            esac
        done
    fi

    # 2. If a manual version is provided, validate and pad it
    if [[ -n "$MANUAL_VERSION" ]]; then
        if [[ ! "$MANUAL_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
            echo "Error: Version '$MANUAL_VERSION' must contain only digits separated by dots (e.g., 1, 1.4, or 1.4.0)"
            return 1
        fi

        local -a m_parts
        m_parts=(${(s:.:)MANUAL_VERSION})
        
        local m_major=${m_parts[1]:-0}
        local m_minor=${m_parts[2]:-0}
        local m_patch=${m_parts[3]:-0}
        
        MANUAL_VERSION="${m_major}.${m_minor}.${m_patch}"

        if git rev-parse "v$MANUAL_VERSION" >/dev/null 2>&1 || \
           git rev-parse "$MANUAL_VERSION" >/dev/null 2>&1 || \
           git log --all --grep="^$MANUAL_VERSION$" -n 1 >/dev/null 2>&1; then
            echo "Error: Version $MANUAL_VERSION already exists in Git history (as a tag or commit subject)!"
            return 1
        fi
        
        NEW_VERSION="$MANUAL_VERSION"
    fi

    # 3. Stage everything
    git add -A

    # 4. Extract commit message from CHANGELOG.txt diff safely
    # This filters out the header diff lines (+++ b/ or --- a/) entirely
    local COMMIT_MSG
    COMMIT_MSG=$(git diff --staged CHANGELOG.txt | sed -n '/^+++/d; /^+/s/^+//p')

    if [[ -z "$COMMIT_MSG" ]]; then
        echo "Error: No new changes found in CHANGELOG.txt to generate a commit message."
        return 1
    fi

    # 5. If auto-incrementing, calculate the new version
    if [[ -z "$MANUAL_VERSION" ]]; then
        local LATEST_TAG
        # Sort tags by semantic version natively using git, fallback to v0.0.0 if empty
        LATEST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -n 1 2>/dev/null)
        if [[ -z "$LATEST_TAG" ]]; then
            LATEST_TAG="v0.0.0"
        fi
        local CURRENT_VERSION=${LATEST_TAG#v}

        local -a parts
        parts=(${(s:.:)CURRENT_VERSION})
        local major=${parts[1]:-0}
        local minor=${parts[2]:-0}
        local patch=${parts[3]:-0}

        case "$VERSION_TYPE" in
            major) (( major++ )); minor=0; patch=0 ;;
            minor) (( minor++ )); patch=0 ;;
            patch) (( patch++ )) ;;
        esac

        NEW_VERSION="${major}.${minor}.${patch}"
        echo "Auto-incrementing version: $CURRENT_VERSION -> $NEW_VERSION"
    else
        echo "Using manual version: $NEW_VERSION"
    fi

    # 6. Commit changes and create a tag safely
    echo "Commit message:\n$COMMIT_MSG"
    echo "---"

    if ! git commit -m "$NEW_VERSION" -m "$COMMIT_MSG"; then
        echo "Error: Git commit failed."
        return 1
    fi

    if ! git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION"; then
        echo "Error: Tagging failed. Rollback commit..."
        git reset --soft HEAD~1
        return 1
    fi

    echo "Successfully committed and tagged as v$NEW_VERSION"
}
