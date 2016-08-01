compiler_setup () {
    #XXX
    if [ "${1}" = "silent" ]; then
        debug () {
            ${LOGGER_BIN} "${DEFAULT_NAME}: ${@}"
        }
    fi
    debug "---------------- COMPILER FEATURES DUMP -----------------"
    debug "Listing compiler features for platform: $(distd "${SYSTEM_NAME}")"
    case "${SYSTEM_NAME}" in
        Minix)
            DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS} -I/usr/pkg/include -fPIE"
            DEFAULT_LDFLAGS="${COMMON_LDFLAGS} -L/usr/pkg/lib -fPIE"
            ;;

        FreeBSD)
            DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS} -fPIE"
            DEFAULT_LDFLAGS="${COMMON_LDFLAGS} -fPIE"
            ;;

        Darwin)
            DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS} -mmacosx-version-min=10.11 -arch=x86_64"
            DEFAULT_LDFLAGS="${COMMON_LDFLAGS}"
            ;;

        Linux)
            DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS} -mno-avx" # NOTE: Disable on Centos 5, XXX: old Xeons case :)
            DEFAULT_LDFLAGS="${COMMON_LDFLAGS}"
            ;;
    esac

    if [ "YES" = "${DEBUGBUILD}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "debug-build" ${ColorGreen})"
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "production-build" ${ColorGray})"
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O0 -ggdb"
    else
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "production-build" ${ColorGreen})"
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "debug-build" ${ColorGray})"
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O2"
    fi

    CFLAGS="$(${PRINTF_BIN} '%s\n' "-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    CXXFLAGS="$(${PRINTF_BIN} '%s\n' "-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    LDFLAGS="$(${PRINTF_BIN} '%s\n' "-L${PREFIX}/lib ${DEF_LINKER_ARGS} ${DEFAULT_LDFLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"

    # pick compiler in order:
    # 1. /usr/bin/clang
    # 2. /usr/bin/gcc
    default_c="${C_COMPILER_NAME}"
    default_cxx="${CXX_COMPILER_NAME}"
    default_cpp="${CPP_PREPROCESSOR_NAME}"
    BASE_COMPILER="${SOFTWARE_DIR}$(capitalize ${C_COMPILER_NAME})" # /Software/Clang
    if [ -x "${BASE_COMPILER}/bin/${default_c}" -a \
         -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "base-compiler: ${default_c}" ${ColorGreen})"
    else # /usr/bin/clang
        BASE_COMPILER="/usr"
        if [ "${SYSTEM_NAME}" = "Minix" ]; then
            BASE_COMPILER="/usr/pkg"
        fi
        if [ -x "${BASE_COMPILER}/bin/${default_c}" -a \
             -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then
            debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "base-compiler: ${default_c}" ${ColorGreen})"
        else
            if [ -x "${BASE_COMPILER}/bin/${C_COMPILER_NAME_ALT}" -a \
                 -x "${BASE_COMPILER}/bin/${CXX_COMPILER_NAME_ALT}" -a \
                 -x "${BASE_COMPILER}/bin/${CPP_PREPROCESSOR_NAME_ALT}" ]; then
                default_c="${C_COMPILER_NAME_ALT}"
                default_cxx="${CXX_COMPILER_NAME_ALT}"
                default_cpp="${CPP_PREPROCESSOR_NAME_ALT}"
                debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "base-compiler: ${default_c}" ${ColorGreen})"
            else
                debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "base-compiler: ${default_c}" ${ColorGray})"
            fi
        fi
    fi

    CC="$(${PRINTF_BIN} '%s\n' "${BASE_COMPILER}/bin/${default_c} ${DEF_COMPILER_ARGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    if [ ! -x "${BASE_COMPILER}/bin/${default_c}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        error "Base C compiler: $(diste "${CC}") should be an executable!"
    fi

    CXX="$(${PRINTF_BIN} '%s\n' "${BASE_COMPILER}/bin/${default_cxx} ${DEF_COMPILER_ARGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    if [ ! -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        error "Base C++ compiler: $(diste "${CXX}") should be an executable!"
    fi

    CPP="$(${PRINTF_BIN} '%s\n' "${BASE_COMPILER}/bin/${default_cpp}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    if [ ! -x "${BASE_COMPILER}/bin/${default_cpp}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        CPP="${BASE_COMPILER}/bin/${default_c} -E"
    fi

    # -fPIC check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Cc]' >/dev/null 2>/dev/null && \
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "position-independent-code" ${ColorGreen})" || \
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "position-independent-code" ${ColorGray})"

    # -fPIE check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Ee]' >/dev/null 2>/dev/null && \
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "position-independent-executable" ${ColorGreen})" || \
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "position-independent-executable" ${ColorGray})"

    # -fstack-protector-all check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>/dev/null && \
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "stack-protector-all" ${ColorGreen})" || \
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "stack-protector-all" ${ColorGray})"

    # -fno-strict-overflow check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>/dev/null && \
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "no-strict-overflow" ${ColorGreen})" || \
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "no-strict-overflow" ${ColorGray})"

    if [ "${default_c}" = "${C_COMPILER_NAME}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "clang-compiler" ${ColorGreen})"
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "gnu-c-compiler" ${ColorGray})"
    elif [ "${default_c}" = "${C_COMPILER_NAME_ALT}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "gnu-c-compiler" ${ColorGreen})"
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "clang-compiler" ${ColorGray})"
    fi

    # Support for other definition options
    if [ -n "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
        warn "Support for GNU compiler was recently dropped, and is ignored since Sofin 1.0. Try using $(diste Gcc) instead?"
    fi

    # TODO: make a alternatives / or capability
    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then # check for CCACHE availability
            debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "ccache" ${ColorGreen})"
            CC="${CCACHE_BIN_OPTIONAL} ${CC}"
            CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
            CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
        else
            debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "ccache" ${ColorGray})"
        fi
    fi

    if [ -z "${DEF_NO_GOLDEN_LINKER}" ]; then # Golden linker enabled by default
        case "${SYSTEM_NAME}" in
            Minix)
                if [ -x "${GOLD_BIN}" -a -f "/usr/lib/LLVMgold.so" ]; then
                    DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                    DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
                    CFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    CXXFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    LDFLAGS="-L${PREFIX}/lib ${DEF_LINKER_ARGS} ${DEFAULT_LDFLAGS}"
                    LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                    NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
                fi
                ;;

            FreeBSD|Minix)
                if [ -x "${GOLD_BIN}" -a -f "/usr/lib/LLVMgold.so" ]; then
                    DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                    DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
                    CFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    CXXFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    LDFLAGS="-L${PREFIX}/lib ${DEF_LINKER_ARGS} ${DEFAULT_LDFLAGS}"
                    LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                    NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
                fi
                ;;

            Linux)
                # Golden linker support without LLVM plugin:
                if [ -x "${GOLD_BIN}" ]; then
                    ${GREP_BIN} '7\.' /etc/debian_version >/dev/null 2>&1
                    if [ "${?}" != "0" ]; then
                        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                        DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -fuse-ld=gold"
                    else
                        DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS}"
                    fi
                    CFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    CXXFLAGS="-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    LDFLAGS="-L${PREFIX}/lib ${DEF_LINKER_ARGS} ${DEFAULT_LDFLAGS}"
                    unset NM LD
                fi
                ;;
        esac
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "gold-linker" ${ColorGreen})"
    else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
        unset NM LD
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "gold-linker" ${ColorGray})"
    fi

    if [ -z "${DEF_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "enable-new-dtags" ${ColorGreen})"
        else
            debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "enable-new-dtags" ${ColorGray})"
        fi
    fi
    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" ${ColorGreen}) $(distd "fast-math" ${ColorGreen})"
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    else
        debug " $(distd "${FAIL_CHAR}" ${ColorYellow}) $(distd "fast-math" ${ColorGray})"
    fi
    debug "-------------- COMPILER FEATURES DUMP ENDS --------------"

    unset default_c default_cxx default_cpp

    export CFLAGS CXXFLAGS LDFLAGS LD NM CC CXX CPP
}


create_lock () {
    _bundle_name="${1}"
    if [ -z "${_bundle_name}" ]; then
        error "No bundle name specified to lock!"
    else
        debug "Acquring bundle lock for: $(distd "${_bundle_name}")"
    fi
    SOFIN_PID="${SOFIN_PID:-$$}"
    debug "Pid of current Sofin session: $(distd "${SOFIN_PID}")"
    _bundle="$(capitalize "${_bundle_name}")"
    ${MKDIR_BIN} -p ${LOCKS_DIR} 2>/dev/null
    ${PRINTF_BIN} '%s\n' "${SOFIN_PID}" > "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}"
    unset _bundle _bundle_name
}


acquire_lock_for () {
    _bundles=${*}
    debug "Trying lock acquire for bundles: [$(distd "${_bundles}")]"
    for _bundle in ${_bundles}; do
        if [ -f "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" ]; then
            _lock_pid="$(${CAT_BIN} "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" 2>/dev/null)"
            _lock_ppid="$(${PGREP_BIN} -P${_lock_pid} 2>/dev/null)"
            debug "Lock pid: $(distd "${_lock_pid}"), Sofin pid: $(distd "${SOFIN_PID}"), _lock_ppid: $(distd "${_lock_ppid}")"
            try "${KILL_BIN} -0 ${_lock_pid}"
            if [ "${?}" = "0" ]; then # NOTE: process is alive
                if [ "${_lock_pid}" = "${SOFIN_PID}" -o \
                     "${_lock_ppid}" = "${SOFIN_PID}" ]; then
                    debug "Dealing with own process or it's fork, process may continue.."
                elif [ "${_lock_pid}" = "${SOFIN_PID}" -a \
                       -z "${_lock_ppid}" ]; then
                    debug "Dealing with no fork, process may continue.."
                else
                    error "Bundle: $(diste "${_bundle}") is locked due to background job pid: $(diste "${_lock_pid}")"
                fi
            else # NOTE: process is dead
                debug "Found lock file acquired by dead process. Acquring a new lock.."
                create_lock "${_bundle}"
            fi
        else
            debug "No file lock for _bundle: $(distd "${_bundle}")"
            create_lock "${_bundle}"
        fi
    done
    unset _bundle _bundles _lock_pid _lock_ppid
}


destroy_locks () {
    _pattern="${1}"
    _pid="${SOFIN_PID:-$$}"
    debug "Cleaning file locks matching pattern: $(distd "${_pattern}") that belong to pid: $(distd "${_pid}").."
    for _dlf in $(${FIND_BIN} ${LOCKS_DIR} -mindepth 1 -maxdepth 1 -name "*${_pattern}*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        try "${GREP_BIN} ${_pid} ${_dlf}" && \
            try "${RM_BIN} -f ${_dlf}" && \
                debug "Lock file removed: $(distd "${_dlf}")"
    done
    unset _dlf _pid
}


update_shell_vars () {
    if [ -n "${SOFIN_PROFILE}" ]; then
        debug "Generating shell environment and writing to: $(distd "${SOFIN_PROFILE}")"
        get_shell_vars > "${SOFIN_PROFILE}"
    else
        debug "Empty profile file: $(distd "${SOFIN_PROFILE}")! No-Op!"
    fi
}


reload_zsh_shells () {
    _shell_pattern="zsh"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        _shell_pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
    fi
    unset _wishlist
    _shellshort="$(${BASENAME_BIN} "${SHELL}" 2>/dev/null)"
    _pids=$(processes_all | ${EGREP_BIN} "${_shell_pattern}" 2>/dev/null | eval "${FIRST_ARG_GUARD}")
    # debug "Shell inspect: $(distd "${_shellshort}"), pattern: $(distd "${_shell_pattern}"), PIDS: $(distd "$(${PRINTF_BIN} "${_pids}" | eval "${NEWLINES_TO_SPACES_GUARD}")")"
    for _pid in ${_pids}; do
        if [ -z "${_wishlist}" ]; then
            _wishlist="${_pid}"
        else
            _wishlist="${_wishlist} ${_pid}"
        fi
    done
    if [ -n "${_wishlist}" ]; then
        try "${KILL_BIN} -SIGUSR2 ${_wishlist} 2>/dev/null" && \
            debug "Reload signal sent to $(distd "${_shellshort}") pids: $(distd "${_wishlist}")"
    fi
    unset _wishlist _pid _pids _shell_pattern _shellshort
}


update_env_files () {
    _default_envs="/etc/profile /etc/zshenv /etc/bashrc"
    for _env_file in ${_default_envs}; do
        if [ -f "${_env_file}" ]; then
            debug "Processing existing env file: $(distd "${_env_file}")"
            ${EGREP_BIN} "SHELL_PID=" "${_env_file}" >/dev/null 2>&1
            if [ "${?}" = "0" ]; then
                continue
            else
                ${PRINTF_BIN} '%s\n' "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                    debug "Environment block appended to file: $(distd "${_env_file}")"

            fi
        else
            ${PRINTF_BIN} '%s\n' "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                debug "Environment block written to file: $(distd "${_env_file}")"
        fi
    done
    update_shell_vars
    unset _default_envs _env_file
}
