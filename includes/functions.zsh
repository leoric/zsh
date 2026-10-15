# Convert .webp to .png using dwebp
png() {
    dwebp "$1" -o "$(basename "$1" .webp).png"
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
