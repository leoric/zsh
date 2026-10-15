unalias d 2>/dev/null
alias d='docker'

dc() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        DOCKER_COMPOSE="./docker-local/docker-compose.linux.yml"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        DOCKER_COMPOSE="./docker-local/docker-compose.macos.yml"
    else
        DOCKER_COMPOSE="./docker-local/docker-compose.yml"
    fi
    
    if [ ! -f ./docker-compose.yml ] && [ -f "$DOCKER_COMPOSE" ] ; then
        docker-compose -f "$DOCKER_COMPOSE" "$@"
    else
        docker-compose "$@"
    fi
}

alias dcu='dc up'
alias dcud='dcu -d'
alias dcd='dc down'
alias dcr='dcd && dcud'

dce() {
    case "$1" in
        php)
            dc exec -u www-data php "${@:2}"
        ;;
        co)
            dc exec -u www-data php php -d xdebug.mode='off' /opt/composer.phar "${@:2}"
        ;;
        ci)
            dc exec -u www-data php php -d xdebug.mode='off' /opt/composer.phar install "${@:2}"
        ;;
        cr)
            dc exec -u www-data php php -d xdebug.mode='off' /opt/composer.phar require "${@:2}"
        ;;
        ca)
            dc exec -u www-data php php -d xdebug.mode='off' /opt/composer.phar dumpautoload "${@:2}"
        ;;
        u)
            dc exec -u www-data php php -d xdebug.mode='off' bin/phpunit"${@:2}"
        ;;
        c)
            dc exec -u www-data php php -d xdebug.mode='off' bin/console "${@:2}"
        ;;
        cd)
            dc exec -u www-data php php bin/console "${@:2}"
        ;;
        cc)
            dc exec -u www-data php php -d xdebug.mode='off' bin/console ca:cl "${@:2}"
        ;;
        bcm|dmm)
            dc exec -u www-data php php -d xdebug.mode='off' bin/console d:m:m -n --all-or-nothing "${@:2}"
        ;;
        bcd|dmd)
            dc exec -u www-data php php -d xdebug.mode='off' bin/console d:m:diff "${@:2}"
        ;;
        bcc)
            dc exec -u www-data php php bin/console rabbit:cons "${@:2}"
        ;;
        *)
            dc exec "$@"
        ;;
    esac
}
