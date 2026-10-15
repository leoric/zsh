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