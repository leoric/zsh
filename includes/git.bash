alias g='git'

alias ga='git add'
alias gaa='git add --all'
alias gall='git add --all'
alias gapa='git add --patch'

alias gb='git branch'
alias gba='git branch -a'
alias gbda='git branch --merged | command grep -vE "^(\*|\s*main\s*$)" | command xargs -n 1 git branch -d'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'

alias gm='git commit -m'
alias gma='git commit -a -m'
alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gcn!='git commit -v --no-edit --amend'
alias gcs='git commit -S'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcan!='git commit -v -a --no-edit --amend'
alias gcans!='git commit -v -a -s --no-edit --amend'
alias gcb='git checkout -b'
alias gcf='git config --list'
alias gcl='git clone --recursive'
alias gclean='git clean -fd'
alias gpristine='git reset --hard && git clean -dfx'
alias gcm='git checkout main'
alias gco='git checkout'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'

alias gd='git diff'
alias gdl='git diff HEAD~1 HEAD'
alias gdf='git diff --name-status'
alias gdc='git diff --cached'
alias dct='git describe --tags `git rev-list --tags --max-count=1`'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gdw='git diff --word-diff'

alias gf='git fetch --all --prune'
alias gfa='git fetch --all --prune --tags'
alias gf='git fetch --all --prune --verbose'
alias gftv='git fetch --all --prune --tags --verbose'
alias gfo='git fetch origin'

alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias git-svn-dcommit-push='git svn dcommit && git push github main:svntrunk'

alias gk='\gitk --all --branches'
alias gke='\gitk --all $(git log -g --pretty=format:%h)'

alias gl='git log'
alias gls='git log --stat -p'
alias glg='git log --graph'
alias gll='git log --graph --decorate --all'
alias glm='git log --graph --max-count=10'
alias glo='git log --oneline --decorate'
alias ggc="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all"
alias ggoc='git log --oneline --decorate --graph'
alias ggo='git log --oneline --decorate --graph --all'
alias glp="_git_log_prettily"

alias gme='git merge'
alias gmeom='git merge origin/main'
alias gmt='git mergetool --no-prompt'
alias gmtvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/main'

alias gu='git pull'
alias guum='git pull upstream main'
alias gup='git pull --rebase'
alias gupv='git pull --rebase -v'

alias gp='git push'
alias gpd='git push --dry-run'
alias gpoat='git push origin --all && git push origin --tags'
alias gpu='git push upstream'
alias gpv='git push -v'
alias gpf='git push --force'  # Force push (use with care!)

alias gt='git tag'            # Create or list tags
alias gtd='git tag -d'        # Delete a local tag
alias gtp='git push --tags'   # Push all tags to remote

alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase -i'
alias grbm='git rebase main'
alias grbs='git rebase --skip'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias gru='git reset --'
alias gr1='git reset --soft HEAD^'
alias grmv='git remote rename'
alias grrm='git remote remove'
alias grset='git remote set-url'
alias grt='cd $(git rev-parse --show-toplevel || echo ".")'
alias grup='git remote update'
alias grv='git remote -v'

alias gs='git status'
alias gss='git status -s' # short
alias gsb='git status -sb' # short with branch

alias gsh='git show'
alias gsps='git show --pretty=short --show-signature'

alias gsd='git svn dcommit'
alias gsr='git svn rebase'

alias gsi='git submodule init'
alias gsu='git submodule update'

alias gst='git stash save'
alias gsta='git stash apply'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'

alias gts='git tag -s'
alias gtv='git tag | sort -V'

alias gunignore='git update-index --no-assume-unchanged'

alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit -m "--wip--"'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
