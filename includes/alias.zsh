alias alais='alias'
alias ag='alias | grep'

if command -v eza >/dev/null 2>&1; then
    # eza aliases
    alias eza='eza --git --icons --color=auto --classify=auto --color-scale=all'
    alias ls='eza'
    alias lt='eza --tree'
    alias ll='eza -A'
    alias la='eza -a'
    alias l1='eza -1'
    alias l='eza -la'
else
    # Fallback standard ls aliases
    alias ls='ls --color=auto -F'
    alias ll='ls -A'
    alias la='ls -a'
    alias l1='ls -1'
    alias l='ls -al'
fi

# Search shortcut (works for both eza and standard ls)
alias lg='la | grep'

alias md='mkdir -p'
alias rd='rmdir'

if [ -n "$ZSH_VERSION" ]; then
    alias cp='nocorrect cp'
    alias mv='nocorrect mv'
    alias rm='nocorrect rm'
fi

alias _='sudo'
alias please='sudo'
alias cpr='cp -r'
alias rmr='rm -r'
alias cps='_ cp -r'
alias rms='_ rm -r'
alias mvs='_ mv'
alias vis='_ vim'

alias apti='_ apt install'
alias aptu='_ apt update'
alias aptr='_ apt remove'
alias apta='_ apt autoremove'
alias aptp='_ apt purge'

alias h='history'
alias grep='grep -E'
alias cal='cal -m'
alias df='df -h'
alias du='du -h'

alias tm='tmux'
alias tma='tm att -t'
alias tmaa='tm att -t 0'
alias psa='ps afux'
alias psg='ps aux | grep'

alias fp='ffprobe'
alias dv='yt-dlp'
alias commit='commit --timeout 30s'

if [ -n "$ZSH_VERSION" ]; then
    alias zmv='noglob zmv'

    alias -g F='--filter'
    alias -g T='--testdox'
    alias -g C='|ccze'
    alias -g M='|more'
    alias -g L='|less'
    alias -g H='|head'
    alias -g T='|tail'
    alias -g N='2>/dev/null'
    alias -g G='|grep'
    alias -g GI='|grep -i'
    alias -g GN='|grep -n'
    alias -g S='|sort'
    alias -g SU='|sort -u'

    alias -g KU='| iconv -c -f koi8r -t utf8'
    alias -g CU='| iconv -c -f cp1251 -t utf8'
    alias -g UK='| iconv -c -f utf8 -t koi8r'
    alias -g UC='| iconv -c -f utf8 -t cp1251'
fi

srv () {
        _ /etc/init.d/$1 $2
}

# Open Sublime Text
subl() {
    /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl "$@"
}

up() {
  local count=${1:-1}
  for ((i = 1; i <= count; i++)); do
    cd ..
  done
}

un () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1        ;;
            *.tar.gz)    tar xzf $1     ;;
            *.tar.xz)    tar xJf $1     ;;
            *.bz2)       bunzip2 $1       ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1     ;;
            *.tar)       tar xf $1        ;;
            *.tbz2)      tar xjf $1      ;;
            *.tgz)       tar xzf $1       ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1    ;;
            *)           echo "epic fail with '$1'..." ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}


pk () {
    if [ $1 ] ; then
        case $1 in
            tbz)   	tar cjvf $2.tar.bz2 $2      ;;
            tgz)   	tar czvf $2.tar.gz  $2   	;;
            txz)   	tar cJvf $2.tar.xz  $2   	;;
            tar)  	tar cpvf $2.tar  $2       ;;
			bz2)	bzip $2 ;;
            gz)		gzip -c -9 -n $2 > $2.gz ;;
			zip)   	zip -r $2.zip $2   ;;
            7z)    	7z a $2.7z $2    ;;
            *)     	echo "'$1' cannot be packed via pk()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
