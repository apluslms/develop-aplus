#!/bin/bash

OS=$(uname -s)
COMPOSE_PROJECT_NAME=aplus
if [ -z "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="docker-compose.yml"
fi
DOCKER_SOCK=/var/run/docker.sock
[ -e "$DOCKER_SOCK" ] || { echo "ERROR: docker socket $DOCKER_SOCK doesn't exists. Do you have docker-ce installed?." >&2; exit 1; }
USER_ID=$(id -u)
USER_GID=$(id -g)

if [ $USER_ID -eq 0 ] || [ "$OS" = 'Darwin' ]; then
    DOCKER_GID=0
    if ! [ -e $DOCKER_SOCK ]; then
        echo "No docker socket detected in $DOCKER_SOCK. Is docker installed and active?" >&2
    fi
else
    DOCKER_GID=$(stat -c '%g' $DOCKER_SOCK)
    if ! [ -w $DOCKER_SOCK ]; then
        echo "Your user does not have write access to docker." >&2
        echo "It is recommended that you add yourself to that group (sudo adduser $USER docker; and then logout and login again)." >&2
        echo "Alternatively, you can execute this script as sudo." >&2
        exit 1
    fi
fi

if [[ $(docker compose version) != *"version"* ]]; then
    echo "ERROR: Unable to find docker compose plugin. Are you sure it is installed?" >&2
    exit 1
fi

DATA_PATH=_data
has_data=$(grep -F "$DATA_PATH" "$COMPOSE_FILE"|grep -vE '^\s*#')
[ "$has_data" ] && mkdir -p "$DATA_PATH"

ACOS_LOG_PATH=_data/acos
has_acos_log=$(grep -F "$ACOS_LOG_PATH" "$COMPOSE_FILE"|grep -vE '^\s*#')
[ "$has_acos_log" ] && mkdir -p "$ACOS_LOG_PATH"

export COMPOSE_PROJECT_NAME USER_ID USER_GID DOCKER_GID

pid=
stop_requested=

request_stop() {
    stop_requested=1
}

onexit() {
    trap - INT
    # Send SIGHUP to the childs of docker compose to silence their output (detach them from controlling tty)
    [ "$pid" ] && { pkill -SIGHUP -P $pid; } || true
    if [ -t 0 ]; then
        stty sane
    fi
    echo
    read -rp "  Remove persistent data? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Stop containers and remove volumes
        COMPOSE_ANSI=never docker compose down --volumes --remove-orphans
        remove_data
    else
        # Stop containers
        COMPOSE_ANSI=never docker compose stop
        echo -e "\nData was not removed. You can remove it with: $0 --clean"
    fi
    rm -rf /tmp/aplus || true
    exit 0
}

clean() {
    echo " !! Removing persistent data !! "
    COMPOSE_ANSI=never docker compose down --volumes --remove-orphans
    remove_data
}

remove_data() {
    if [ "$DATA_PATH" -a -e "$DATA_PATH" ]; then
        echo "Removing $DATA_PATH"
        rm -rf "$DATA_PATH" || true
    fi
}

update() {
    docker compose pull
    res=$?
    [ $res -eq 0 ] && touch "$COMPOSE_FILE"
    return $res
}

while [ "$1" ]; do
    case "$1" in
        -c|--clean)
            clean
            exit 0
            ;;
        -u|--update)
            update
            exit $?
            ;;
        *)
            echo "Invalid option $1" >&2
            exit 1
            ;;
    esac
    shift
done

docker compose version

if [ $(($(date +%s) - $(date -r "$COMPOSE_FILE" +%s))) -gt 604800 ]; then
    # Pull updates weekly
    echo "Checking for updates to the service images..."
    update
    echo
fi

mkdir -p /tmp/aplus
trap request_stop INT
if [ "$OS" = 'Darwin' ]; then
    perl -e 'use POSIX qw(setsid); setsid(); exec @ARGV' -- docker compose up & pid=$!
else
    setsid docker compose up & pid=$!
fi

help_n=24 # Show first info after 24 seconds
while [ -z "$stop_requested" ] && kill -0 $pid 2>/dev/null; do
    while read -rs -t 0; do read -rs -t 0.1; done # Flush input
    read -rsn1 -t 1 i # Read a byte
    read_status=$?
    [ "$stop_requested" ] && break
    # (1 or 142) -> timeout (1s). Show help every 300 times (every 5 minutes)
    [[ $read_status != 0 ]] && { ((--help_n > 0)) && continue || help_n=300; }
    case "$i" in
        q|Q) break ;;
    esac

    # Print status and help
    echo
    echo "  List of alive containers:"
    { docker container ls --filter "name=^${COMPOSE_PROJECT_NAME}-"  --format "{{.ID}}" | xargs docker container inspect --format '	{{.Name}}	{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}	{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} {{end}}'; } 2>/dev/null || true
    echo
    echo "  Press Q or ^C to stop all"
    echo
done
onexit
