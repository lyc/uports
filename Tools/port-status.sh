#!/bin/sh

set -eu

make_command=$1
portdir=$2
jobs=${3:-4}
case "$jobs" in
    ""|*[!0-9]*|0)
        echo 'INFO_PORTS_JOBS must be a positive integer' >&2
        exit 1
        ;;
esac
temporary=$(mktemp -d "${TMPDIR:-/tmp}/uports-port-status.XXXXXX")
trap 'wait || :; rm -rf -- "$temporary"' EXIT
trap 'exit 1' HUP INT TERM

# probe flavor: empty selects the declared default, clearing inherited choice.
probe() {
    if [ -n "$1" ]; then
        selection="override FLAVOR := $1"
    else
        selection='override undefine FLAVOR'
    fi
    "$make_command" -s --no-print-directory -C "$base/$port" \
        PORTSDIR="$portdir" $clean_environment \
        --eval="$selection" uports-port-status-metadata \
        > "$metadata_file"
}

# port_path path: resolve relative artifacts against the actual port directory.
port_path() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *) printf '%s/%s/%s' "$base" "$port" "$1" ;;
    esac
}

# metadata_status: use the selected configuration's exact cookie paths.
metadata_status() {
    state=
    while IFS='|' read -r kind phase value
    do
        [ "$kind" = cookie ] || continue
        [ -f "$(port_path "$value")" ] || continue
        case "$phase" in
            extract) state=E ;;
            patch) state=P ;;
            configure) state=C ;;
            build) state=B ;;
            stage) state=S ;;
            package) state=K ;;
            install) state=I ;;
        esac
    done < "$metadata_file"
    printf '%s' "$state"
}

# emit flavor: descriptive columns use actual selected port metadata.
emit() {
    state=$(metadata_status)
    version=$(sed -n 's/^display|version|//p' "$metadata_file")
    license=$(sed -n 's/^display|license|//p' "$metadata_file")
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$group" "$port" "$base" "$state" "$flag" "$suffix" \
        "$1" "$version" "$license"
}

# process_row: collect one instance and its Flavors in private worker storage.
process_row() {
    clean_environment=
    for entry in $environment
    do
        case "$entry" in
            FLAVOR=*) ;;
            WRKDIR=*)
                mode=custom
                clean_environment="$clean_environment $entry"
                ;;
            *_COOKIE=*)
                clean_environment="$clean_environment $entry"
                if [ "$mode" = fast ]; then
                    mode=probe
                fi
                ;;
            TYPE_SUFFIX=*)
                hint="$base/$port/work${entry#TYPE_SUFFIX=}"
                clean_environment="$clean_environment $entry"
                ;;
            *) clean_environment="$clean_environment $entry" ;;
        esac
    done
    if [ "$mode" = fast ] && [ -z "$selected" ]; then
        status=
        for phase in extract patch configure build stage package install
        do
            for cookie in "$hint/$phase"._done.*
            do
                [ -f "$cookie" ] || continue
                case "$phase" in
                    extract) status=E ;;
                    patch) status=P ;;
                    configure) status=C ;;
                    build) status=B ;;
                    stage) status=S ;;
                    package) status=K ;;
                    install) status=I ;;
                esac
                break
            done
        done
        printf '%s|%s|%s|%s|%s|%s|-|%s|%s\n' \
            "$group" "$port" "$base" "$status" "$flag" "$suffix" \
            "$version" "$license"
        return
    fi
    probe ''
    choices=$(sed -n 's/^flavors|//p' "$metadata_file")
    default=$(sed -n 's/^default|//p' "$metadata_file")
    if [ -n "$choices" ]; then
        emit "$default"
    else
        emit '-'
    fi
    if [ -n "$selected" ]; then
        case " $choices " in
            *" $selected "*) ;;
            *)
                echo "Unknown project Flavor $selected for $port" >&2
                exit 1
                ;;
        esac
    fi
    for choice in $choices
    do
        [ "$choice" != "$default" ] || continue
        probe "$choice"
        emit "$choice"
    done
}

# wait_workers: drain the bounded batch before reusing its worker slots.
wait_workers() {
    for pid in $pids
    do
        if wait "$pid"; then
            :
        else
            failed=1
        fi
    done
    pids=
    active=0
}

rows=0
active=0
pids=
failed=0
while IFS='|' read -r group port base status flag suffix hint selected \
    environment mode version license
do
    rows=$((rows + 1))
    metadata_file="$temporary/$rows.metadata"
    process_row > "$temporary/$rows.rows" 2> "$temporary/$rows.errors" &
    pids="$pids $!"
    active=$((active + 1))
    if [ "$active" -ge "$jobs" ]; then
        wait_workers
        [ "$failed" -eq 0 ] || break
    fi
done
wait_workers

# Workers never write shared output; emit rows/errors in original input order.
row=1
while [ "$row" -le "$rows" ]
do
    cat "$temporary/$row.errors" >&2
    if [ "$failed" -eq 0 ]; then
        cat "$temporary/$row.rows"
    fi
    row=$((row + 1))
done
exit "$failed"
