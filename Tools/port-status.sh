#!/bin/sh

set -eu

make_command=$1
portdir=$2
temporary=$(mktemp -d "${TMPDIR:-/tmp}/uports-port-status.XXXXXX")
trap 'rm -rf -- "$temporary"' EXIT HUP INT TERM

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
        > "$temporary/metadata"
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
    done < "$temporary/metadata"
    printf '%s' "$state"
}

# emit flavor: descriptive columns use actual selected port metadata.
emit() {
    state=$(metadata_status)
    version=$(sed -n 's/^display|version|//p' "$temporary/metadata")
    license=$(sed -n 's/^display|license|//p' "$temporary/metadata")
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$group" "$port" "$base" "$state" "$flag" "$suffix" \
        "$1" "$version" "$license"
}

while IFS='|' read -r group port base status flag suffix hint selected \
    environment mode version license
do
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
        continue
    fi
    probe ''
    choices=$(sed -n 's/^flavors|//p' "$temporary/metadata")
    default=$(sed -n 's/^default|//p' "$temporary/metadata")
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
done
