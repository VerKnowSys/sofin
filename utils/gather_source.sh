# Synchronization through SSH Shell-API
gather-source () {
    if [ "${1}" = "" ]; then
        printf "Missing archive URL!\n"
        exit 1
    fi
    readonly fetch_bin="curl --progress-bar -C - -L -O"
    readonly default_port="60022"
    readonly user_name="sofin"
    readonly default_source_path="/Mirror/software/source"
    readonly default_host="software.verknowsys.com"
    readonly archive_name="$(basename "${1}")"

    command='awk "{print $4}"'
    if [ "$(uname)" = "Linux" ]; then
        export command='awk "{print $3}"'
    fi
    for mirror in $(host ${default_host} | $(${command})); do # XXX: 3 on linux, 4 on normal
        printf "Synchronizing ${archive_name} with ${mirror}\n"
        ssh -p ${default_port} "${user_name}@${mirror}" "cd ${default_source_path} && ${fetch_bin} '${1}'"
    done

    case "$(uname)" in
        Linux)
            sha1sum "${default_source_path}/${archive_name}"
            ;;

        FreeBSD)
            sha1 -q "${default_source_path}/${archive_name}"
            ;;

        *)
            shasum "${default_source_path}/${archive_name}"
            ;;
    esac
}

