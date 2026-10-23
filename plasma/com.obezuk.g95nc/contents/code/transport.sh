#!/usr/bin/bash
# Process/lock transport only. Monitor protocol decisions live in Monitor.js.
# One short-lived server owns flock and executes requests sequentially.
set -eu
umask 077
export LC_ALL=C
root="${TMPDIR:-/tmp}/g95nc-$(id -u)"
mkdir -p -- "$root"
[[ ! -L "$root" && -O "$root" && $(stat -c %a -- "$root") == 700 ]] || exit 1
operation=${1:-}
shift || exit 1
if [[ $operation == prepare ]]; then
    mktemp -d "$root/session.XXXXXXXXXX"
    exit
fi
session=${1:-}
shift || exit 1
[[ ${session#"$root"/} =~ ^session\.[A-Za-z0-9]+$ && $session == "$root"/session.* && -d $session && ! -L $session && -O $session ]] || exit 1
case "$operation" in
    serve)
        serial=${1:?Missing monitor serial}
        key=$(printf %s "$serial" | sha256sum)
        lock="$root/${key%% *}.lock"
        [[ ! -L "$lock" ]] || exit 1
        exec 9>"$lock"
        trap 'rm -f -- "$session/ready"; touch "$session/ended"' EXIT
        flock -n 9 || { printf 'Monitor is busy in another controller.\n' >&2; exit 75; }
        mkfifo "$session/request"
        exec 8<>"$session/request"
        touch "$session/ready"
        # A crashed/removed widget cannot leave the lock held indefinitely.
        while IFS=' ' read -r -t 45 -u 8 action code value extra; do
            case "$action" in
                close) exit 0 ;;
                read)
                    args=(getvcp E2 E3 60 --brief) ;;
                write)
                    [[ $code =~ ^(E2|E3|60)$ && $value =~ ^0x[0-9a-f]{4}$ && -z $extra ]] || exit 2
                    args=(--noverify --permit-unknown-feature setvcp "$code" "$value") ;;
                *) exit 2 ;;
            esac
            status=0
            timeout -k 2 20 /usr/bin/ddcutil --noconfig --sn "$serial" "${args[@]}" >"$session/output" 2>"$session/error" || status=$?
            printf '%s\n' "$status" >"$session/status"
            touch "$session/response"
        done
        ;;
    ready)
        for ((i=0; i<100; i++)); do
            [[ ! -f $session/ended ]] || { printf 'Monitor lock was not acquired.\n' >&2; exit 1; }
            [[ ! -f $session/ready ]] || exit 0
            sleep .05
        done
        printf 'Monitor transport did not start.\n' >&2; exit 1
        ;;
    exchange)
        [[ -f $session/ready && ! -f $session/ended ]] || exit 1
        rm -f -- "$session/response"
        printf '%s\n' "$*" >"$session/request"
        for ((i=0; i<500; i++)); do
            [[ ! -f $session/ended ]] || exit 1
            if [[ -f $session/response ]]; then
                cat "$session/output"
                cat "$session/error" >&2
                exit "$(cat "$session/status")"
            fi
            sleep .05
        done
        printf 'Monitor request timed out.\n' >&2; exit 1
        ;;
    close)
        if [[ -f $session/ready && ! -f $session/ended ]]; then
            printf 'close\n' >"$session/request"
            for ((i=0; i<100; i++)); do
                [[ ! -f $session/ended ]] || break
                sleep .05
            done
        fi
        # Never remove a live server's working files.
        [[ -f $session/ended ]] && rm -rf -- "$session"
        ;;
    *) exit 2 ;;
esac
