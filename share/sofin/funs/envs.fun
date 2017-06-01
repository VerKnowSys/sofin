env_reset () {
    # unset conflicting environment variables
    # dynamic linker:
    unset LD_PRELOAD LD_LIBRARY_PATH DYLD_LIBRARY_PATH

    # utils
    unset CC CXX CPP LD AR RANLIB NM AS

    # flags
    unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

    # NOTE: By default environment should treat non-ASCII characters as literals.
    #       It's often required for test suites:

    # NOTE: should be considered legacy?
    # LANG=C
    # LC_ALL=C
    # LC_CTYPE=C
}


env_pedantic () {
    set -e
}


env_forgivable () {
    set +e
}


enable_sofin_env () {
    try "${RM_BIN} -f ${SOFIN_ENV_DISABLED_INDICATOR_FILE}" && \
        update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Enabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Enabled Sofin environment. Reloading shell"
        reload_zsh_shells
    fi
}


disable_sofin_env () {
    try "${TOUCH_BIN} ${SOFIN_ENV_DISABLED_INDICATOR_FILE}" && \
        update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Disabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Disabled Sofin environment. Reloading shell"
        reload_zsh_shells
    fi
}


set_c_and_cxx_flags () {
    _flagz="${@}"
    CFLAGS="$(${PRINTF_BIN} '%s\n' "-I${PREFIX}/include ${_flagz} ${DEFAULT_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    CXXFLAGS="$(${PRINTF_BIN} '%s\n' "-I${PREFIX}/include ${_flagz} ${DEFAULT_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    LDFLAGS="$(${PRINTF_BIN} '%s\n' "-L${PREFIX}/lib ${DEFAULT_LINKER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    unset _flagz
}


dump_compiler_setup () {
    debug "---------------- COMPILER FEATURES DUMP -----------------"
    debug "Listing compiler features for platform: $(distd "${SYSTEM_NAME}")"
    if [ "YES" = "${DEBUGBUILD}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "debug-build" "${ColorGreen}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "production-build" "${ColorGray}")"
    else
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "production-build" "${ColorGreen}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "debug-build" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "ccache" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "ccache" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_SAFE_STACK}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "safe-stack" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "safe-stack" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_LTO}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "link-time-optimization" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "link-time-optimization" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "llvm-lld-linker" "${ColorGreen}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "gnu-gold-linker" "${ColorGray}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "system-linker" "${ColorGray}")"
    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] && [ -n "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "llvm-lld-linker" "${ColorGray}")"
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "gnu-gold-linker" "${ColorGreen}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "system-linker" "${ColorGray}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "llvm-lld-linker" "${ColorGray}")"
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "gnu-gold-linker" "${ColorGray}")"
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "system-linker" "${ColorGreen}")"
    fi

    # -fPIC check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Cc]' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "position-independent-code" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "position-independent-code" "${ColorGray}")")

    # -fPIE check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Ee]' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "position-independent-executable" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "position-independent-executable" "${ColorGray}")")

    # -fstack-protector-all check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "stack-protector-all" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "stack-protector-all" "${ColorGray}")")

    # -fstack-protector-strong check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-strong' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "stack-protector-strong" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "stack-protector-strong" "${ColorGray}")")

    # -fno-strict-overflow check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "no-strict-overflow" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "no-strict-overflow" "${ColorGray}")")

    # -ftrapv check:
    # NOTE: Signed integer overflow raises the signal SIGILL instead of SIGABRT/SIGSEGV:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'ftrapv' >/dev/null 2>/dev/null && ( \
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "trap-signed-integer-overflow" "${ColorGreen}")" || \
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "trap-signed-integer-overflow" "${ColorGray}")")

    if [ -z "${DEF_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "enable-new-dtags" "${ColorGreen}")"
        else
            debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "enable-new-dtags" "${ColorGray}")"
        fi
    fi

    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "fast-math" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "fast-math" "${ColorGray}")"
    fi
    debug "-------------- COMPILER FEATURES DUMP ENDS --------------"
}


dump_system_capabilities () {
    debug "---------------- SYSTEM CAPABILITIES DUMP ---------------"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -i 'CAP_SYS_' 2>/dev/null | while IFS= read -r _envv
    do
        if [ -n "${_envv}" ]; then
            debug "$(distd "${_envv}")"
        fi
    done
    debug "------------- SYSTEM CAPABILITIES DUMP ENDS -------------"
    unset _envv
}


compiler_setup () {
    # TODO: linker pick should be implemented via "capabilities"!
    case "${SYSTEM_NAME}" in
        FreeBSD|Minix)
            DEFAULT_LINKER_FLAGS="${COMMON_LDFLAGS} ${DEF_SYSTEM_SPECIFIC_LDFLAGS}"
            ;;

        Darwin)
            # NOTE: Default flags can contains linker setup options:
            DEFAULT_COMPILER_FLAGS="${COMMON_FLAGS} ${HARDEN_CFLAGS} ${HARDEN_CMACROS}"
            DEFAULT_LINKER_FLAGS="${COMMON_LDFLAGS} ${DEF_SYSTEM_SPECIFIC_LDFLAGS}"

            # XQuartz support to make things easier:
            # if [ -d "/opt/X11/lib" -a \
            #      -d "/opt/X11/include" ]; then
            #      debug "XQuartz /opt prefix detected. Appending to compiler environment.."
            #      DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -I/opt/X11/include"
            #      DEFAULT_LINKER_FLAGS="${DEFAULT_LINKER_FLAGS} -L/opt/X11/lib"
            # fi

            # NOTE: So if Lld is installed, and both /Software/Lld/exports/ld and
            #       /usr/bin/ld are same files => We use LLVM lld linker by default:
            LLD_ORIGIN="/Software/Lld/exports/lld"
            if [ -x "${LLD_ORIGIN}" ]; then
                LLD_BIN="${LLD_BIN:-${LLD_ORIGIN}}"
            fi
            if [ "$(file_checksum "${LD_BIN}")" = "$(file_checksum "${LLD_BIN}")" ]; then
                debug "Checksum matches origin: Default system linker is overriden with LLVM-linker!"
                unset LLD_BIN
                CAP_SYS_LLVM_LD=YES
            else
                unset LLD_BIN CAP_SYS_LLVM_LD
                debug "Falling to system linker for Darwin!"
            fi
            ;;

        Linux)
            DEFAULT_LINKER_FLAGS="${COMMON_LDFLAGS} ${DEF_SYSTEM_SPECIFIC_LDFLAGS}"
            ;;
    esac

    if [ -n "${DEBUGBUILD}" ]; then
        debug "DEBUGBUILD defined! Appending compiler flags with: $(distd "-O0 -ggdb")"
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O0 -ggdb"
    else
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O2"
    fi

    # pick compiler in order:
    # 1. /usr/bin/clang
    # 2. /usr/bin/gcc
    _default_c="${CC_NAME}"
    _default_cxx="${CXX_NAME}"
    _default_cpp="${CPP_NAME}"
    if [ "YES" = "${DEF_USE_ALT_COMPILER}" ]; then
        _default_c="${CC_NAME_ALT}"
        _default_cxx="${CXX_NAME_ALT}"
        _default_cpp="${CPP_NAME_ALT}"
    fi
    # NOTE: Darwin case: no clang-cpp but clang -E as preprocesor there:
    if [ ! -x "${PREFIX}/bin/${_default_cpp}" ]; then
        _default_cpp="${_default_c} -E"
    fi
    CC="$(${PRINTF_BIN} '%s\n' "${_default_c} ${DEF_SYSTEM_SPECIFIC_CFLAGS} ${DEF_COMPILER_ARGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    CXX="$(${PRINTF_BIN} '%s\n' "${_default_cxx} ${DEF_SYSTEM_SPECIFIC_CXXFLAGS} ${DEF_COMPILER_ARGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    CPP="$(${PRINTF_BIN} '%s\n' "${_default_cpp} ${DEF_COMPILER_ARGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    unset _default_c _default_cxx _default_cpp

    # TODO: make a alternatives / or capability
    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then
            if [ "YES" = "${DEF_USE_ALT_COMPILER}" ]; then
                if [ -d "${PREFIX}/bin" ]; then
                    CC="${CCACHE_BIN_OPTIONAL} ${PREFIX}/bin/${CC}"
                    CXX="${CCACHE_BIN_OPTIONAL} ${PREFIX}/bin/${CXX}"
                else
                    CC="${CCACHE_BIN_OPTIONAL} ${CC}"
                    CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
                fi
            else
                CC="${CCACHE_BIN_OPTIONAL} /usr/bin/${CC}"
                CXX="${CCACHE_BIN_OPTIONAL} /usr/bin/${CXX}"
            fi
        else
            CC="/usr/bin/${CC}"
            CXX="/usr/bin/${CXX}"
        fi
    fi

    # NOTE: Default Linker pick order:
    # 1. LLVM Linker (ld.lld)
    # 2. Gold Linker (ld.gold)
    # 3. Legacy Linker (ld)
    unset _compiler_use_linker_flags
    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        # Support of default: LLVM linker:
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then
            _llvm_pfx="/Software/Lld"
            if [ -x "${_llvm_pfx}/bin/llvm-config" ]; then
                _compiler_use_linker_flags="-fuse-ld=lld"
                RANLIB="${_llvm_pfx}/bin/llvm-ranlib"
                NM="${_llvm_pfx}/bin/llvm-nm"
                AR="${_llvm_pfx}/bin/llvm-ar"
                AS="${_llvm_pfx}/bin/llvm-as"
                debug "LLVM-LD linker configured."
                unset STRIP
            else
                debug "Failed to get LLVM-host-target hint from llvm-config. Got: '$(distd "${_llvm_target}")'"
                unset RANLIB STRIP AS NM AR
                if [ -x "${LD_BIN}.lld" ]; then
                    LD="${LD_BIN}.lld"
                else
                    # Fallback:
                    LD="${LD_BIN}"
                fi
            fi
            LD="${LD_BIN}.lld"
            unset _llvm_pfx _llvm_target

        else
            # NOTE: on Darwin hosts it's the same linker binry but skipping options when DEF_NO_LLVM_LINKER is defined
            LD="${LD_BIN} -arch ${DEFAULT_DARWIN_SYS_ARCH:-x86_64} -sdk_version ${DEFAULT_DARWIN_SDK_VERSION:-10.11}"
        fi

    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] && \
         [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then

        # Golden linker support:
        case "${SYSTEM_NAME}" in
            FreeBSD|Minix)
                _llvm_pfx="/Software/Gold"
                _llvm_target="$(${_llvm_pfx}/bin/llvm-config --host-target 2>/dev/null || :)"
                if [ -n "${_llvm_target}" ] && \
                   [ -d "${_llvm_pfx}/${_llvm_target}" ]; then
                    _compiler_use_linker_flags="-fuse-ld=gold"
                    LD="${LD_BIN}.gold --plugin ${GOLD_SO}"
                    RANLIB="${_llvm_pfx}/${_llvm_target}/bin/ranlib --plugin ${GOLD_SO}"
                    NM="${_llvm_pfx}/${_llvm_target}/bin/nm --plugin ${GOLD_SO}"
                    AR="${_llvm_pfx}/${_llvm_target}/bin/ar"
                    AS="${_llvm_pfx}/${_llvm_target}/bin/as"
                    STRIP="${_llvm_pfx}/${_llvm_target}/bin/strip"
                    debug "GNU-GOLD-LD linker configured."
                else
                    debug "Failed to get LLVM-host-target hint from llvm-config. Got: '$(distd "${_llvm_target}")'"
                    unset NM AR AS RANLIB STRIP
                    if [ -x "${GOLD_SO}" ] && \
                       [ -x "${LD_BIN}.gold" ]; then
                        LD="${LD_BIN}.gold --plugin ${GOLD_SO}"
                    else
                        # Fallback:
                        LD="${LD_BIN}"
                    fi
                fi
                unset _llvm_pfx _llvm_target
                ;;

            Darwin)
                unset NM AR AS RANLIB LD STRIP
                ;;

            Linux)
                unset NM AR AS RANLIB LD STRIP
                RANLIB="${RANLIB_BIN}"
                ;;
        esac
    else
        # NOTE: fallback with reset to system defaults - usually regular linker:
        unset NM AR AS RANLIB LD
    fi

    # CFLAGS, CXXFLAGS setup:
    set_c_and_cxx_flags "${_compiler_use_linker_flags}"

    if [ -z "${DEF_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        fi
    fi
    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    fi

    if [ -z "${DEF_NO_TRAP_INT_OVERFLOW}" ]; then
        CFLAGS="${CFLAGS} ${HARDEN_OFLOW_CFLAGS}"
        CXXFLAGS="${CXXFLAGS} ${HARDEN_OFLOW_CFLAGS}"
    fi

    if [ -z "${DEF_NO_SAFE_STACK}" ]; then
        CFLAGS="${CFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
        CXXFLAGS="${CXXFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
        LDFLAGS="${LDFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
    fi

    if [ -z "${DEF_NO_LTO}" ]; then
        CFLAGS="${CFLAGS} ${LTO_CFLAGS}"
        CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}"
    fi

    # If DEF_LINKER_ARGS is set on definition side, append it's content to LDFLAGS:
    if [ -n "${DEF_LINKER_ARGS}" ]; then
        LDFLAGS="${LDFLAGS} ${DEF_LINKER_ARGS}"
    fi

    # NOTE: some definitions fails on missing values for these:
    AR="${AR:-ar}"
    AS="${AS:-as}"
    NM="${NM:-nm}"
    CC="${CC:-cc}"
    LD="${LD:-ld}"
    CXX="${CXX:-c++}"
    CPP="${CPP:-cpp}"
    RANLIB="${RANLIB:-ranlib}"

    # export definitions critical to compiler environment:
    export CFLAGS CXXFLAGS LDFLAGS LD AR AS NM CC CXX CPP RANLIB
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
    ${MKDIR_BIN} -p "${LOCKS_DIR}" 2>/dev/null
    ${PRINTF_BIN} '%s\n' "${SOFIN_PID}" > "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}"
    unset _bundle _bundle_name
}


acquire_lock_for () {
    _bundles="${@}"
    debug "Trying lock acquire for bundles: [$(distd "${_bundles}")]"
    for _bundle in $(echo "${_bundles}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
        if [ -f "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" ]; then
            _lock_pid="$(${CAT_BIN} "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" 2>/dev/null)"
            _lock_ppid="$(${PGREP_BIN} -P "${_lock_pid}" 2>/dev/null)"
            debug "Lock pid: $(distd "${_lock_pid}"), Sofin pid: $(distd "${SOFIN_PID}"), _lock_ppid: $(distd "${_lock_ppid}")"
            try "${KILL_BIN} -0 ${_lock_pid}"
            if [ "${?}" = "0" ]; then # NOTE: process is alive
                if [ "${_lock_pid}" = "${SOFIN_PID}" ] || \
                   [ "${_lock_ppid}" = "${SOFIN_PID}" ]; then
                    debug "Dealing with own process or it's fork, process may continue.."
                elif [ "${_lock_pid}" = "${SOFIN_PID}" ] && \
                     [ -z "${_lock_ppid}" ]; then
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
    _pid="${SOFIN_PID}"
    env_forgivable
    for _dlf in $(${FIND_BIN} "${LOCKS_DIR%/}" -mindepth 1 -maxdepth 1 -name "*${_pattern}*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        try "${EGREP_BIN} '^${_pid}$' ${_dlf}" && \
            try "${RM_BIN} -f ${_dlf}" && \
                debug "Removed currently owned pid lock: $(distd "${_dlf}")"

        _possiblepid="$(${CAT_BIN} "${_dlf}" 2>/dev/null)"
        if [ -n "${_possiblepid}" ]; then
            try "${KILL_BIN} -0 ${_possiblepid}"
            if [ "${?}" != "0" ]; then
                try "${RM_BIN} -f ${_dlf}" && \
                    debug "Pid: $(distd "${_pid}") appears to be already dead. Removed lock file: $(distd "${_dlf}")"
            else
                debug "Pid: $(distd "${_pid}") is alive. Leaving lock untouched."
            fi
        fi
    done && \
        debug "Finished locks cleanup using pattern: $(distd "${_pattern:-''}") that belong to pid: $(distd "${_pid}")"
    unset _dlf _pid _possiblepid _pattern
}


update_shell_vars () {
    env_forgivable
    if [ -f "${SOFIN_PROFILE}" ]; then
        debug "Generating shell environment and writing to: $(distd "${SOFIN_PROFILE}")"
        get_shell_vars > "${SOFIN_PROFILE}"
    else
        debug "Empty profile file: $(distd "${SOFIN_PROFILE}")! No-Op!"
    fi
}


reload_zsh_shells () {
    env_forgivable
    _shell_pattern="zsh"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        _shell_pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
    elif [ "FreeBSD" = "${SYSTEM_NAME}" ]; then
        _shell_pattern="\ -zsh \(zsh\)"
    fi
    unset _wishlist
    _shellshort="${SHELL##*/}" # basename
    _pids=$(processes_all | ${EGREP_BIN} -i "${_shell_pattern}" 2>/dev/null | ${CUT_BIN} -f1 -d' ' 2>/dev/null)
    debug "Shell inspect: $(distd "${_shellshort}"), pattern: $(distd "${_shell_pattern}"), PIDS: $(distd "$(${PRINTF_BIN} "${_pids}" | eval "${NEWLINES_TO_SPACES_GUARD}")")"
    for _pid in $(echo "${_pids}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
        if [ -z "${_wishlist}" ]; then
            _wishlist="${_pid}"
        else
            _wishlist="${_wishlist} ${_pid}"
        fi
    done
    if [ -n "${_wishlist}" ]; then
        try "${KILL_BIN} -SIGUSR2 ${SOFIN_PID} ${_wishlist}" && \
            debug "Reload signal sent to $(distd "${_shellshort}") pids: $(distd "${SOFIN_PID} + ${_wishlist}")"
    fi
    unset _wishlist _pid _pids _shell_pattern _shellshort
}


update_system_shell_env_files () {
    env_forgivable
    for _env_file in ${HOME}/.profile ${HOME}/.zshenv ${HOME}/.bashrc; do
        if [ -f "${_env_file}" ]; then
            ${EGREP_BIN} "SHELL_PID=" "${_env_file}" >/dev/null 2>&1
            if [ "${?}" = "0" ]; then
                continue
            else
                ${PRINTF_BIN} '\n\n%s\n' "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                    debug "Environment block appended to file: $(distd "${_env_file}")"

            fi
        else
            ${PRINTF_BIN} '\n\n%s\n' "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                debug "Environment block written to file: $(distd "${_env_file}")"
        fi
    done
    update_shell_vars
    unset _default_envs _env_file
}
