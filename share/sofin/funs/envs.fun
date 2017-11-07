env_reset () {
    # unset conflicting environment variables
    # dynamic linker:
    unset LD_PRELOAD LD_LIBRARY_PATH DYLD_LIBRARY_PATH

    # utils
    unset CC CXX CPP LD AR RANLIB NM AS LIBTOOL

    # flags
    unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

    # env, shell:
    unset LC_ALL LC_CTYPE LANGUAGE MAIL

    LANG="${DEFAULT_LOCALE}"
    export LANG
}


env_pedantic () {
    set -e
}


env_forgivable () {
    set +e
}


enable_sofin_env () {
    _envs="${*}"
    if [ -z "${_envs}" ]; then
        _envs="Doas Git Mc Vim Sofin Zsh"
    fi
    debug "Enabling Sofin env for: $(distd "${_envs}")"
    for _env in $(to_iter "${_envs}"); do
        ${GREP_BIN} -F "${_env}" "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" >/dev/null 2>&1 || \
            ${PRINTF_BIN} "%s\n" "${_env}" >> "${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
    done
    note "Enabled Sofin environment for bundles: $(distn "${_envs}")"
    update_shell_vars
    reload_shell
}


disable_sofin_env () {
    _envs="${*}"
    if [ -z "${_envs}" ]; then
        error "No bundles to disable were provided!"
    fi
    if [ "@" = "${_envs}" ]; then
        debug "Wiping out environment for @!"
        ${RM_BIN} -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
    else
        for _env in $(to_iter "${_envs}"); do
            ${SED_BIN} -i '' -e "/^.*${_env}.*$/ d" "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" 2>/dev/null
        done
        note "Disabled Sofin environment for bundles: $(distn "${_envs}")"
    fi
    update_shell_vars
    reload_shell
}


set_c_and_cxx_flags () {
    _flagz="${*}"
    CFLAGS="$(${PRINTF_BIN} '%s\n' "${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    CXXFLAGS="$(${PRINTF_BIN} '%s\n' "${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    LDFLAGS="$(${PRINTF_BIN} '%s\n' "${DEFAULT_LINKER_FLAGS} -L${PREFIX}/lib ${DEF_LINKER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    unset _flagz
    export CFLAGS CXXFLAGS LDFLAGS
}


dump_compiler_setup () {
    debug "Listing compiler features for platform: $(distd "${SYSTEM_NAME}"):"
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

    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "ssp-buffer-override" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "ssp-buffer-override" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "fortify-source" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "fortify-source" "${ColorGray}")"
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
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "enable-new-dtags" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "enable-new-dtags" "${ColorGray}")"
    fi

    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        debug " $(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "fast-math" "${ColorGreen}")"
    else
        debug " $(distd "${FAIL_CHAR}" "${ColorYellow}") $(distd "fast-math" "${ColorGray}")"
    fi
    debug "Compiler features dump eof"
}


dump_system_capabilities () {
    # NOTE: make sure that this is not the way with IFS instead of echoing on tr in for loops;
    debug "System capabilities dump:"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -i 'CAP_SYS_' 2>/dev/null | while IFS= read -r _envv
    do
        if [ -n "${_envv}" ]; then
            debug "$(distd "${_envv}")"
        fi
    done
    debug "System capabilities dump eof"
    unset _envv
}


compiler_setup () {
    # TODO: linker pick should be implemented via "capabilities"!

    # if [ -n "${DEBUGBUILD}" ]; then
    #     debug "DEBUGBUILD defined! Appending compiler flags with: $(distd "-O0 -ggdb")"
    #     DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O0 -ggdb"
    # else
    #     DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O2"
    # fi

    _default_c="${CC_NAME}"
    _default_cxx="${CXX_NAME}"
    _default_cpp="${CPP_NAME}"

    # NOTE: Darwin case: no clang-cpp but clang -E as preprocesor there:
    if [ ! -x "${PREFIX}/bin/${_default_cpp}" ]; then
        _default_cpp="${_default_c} -E"
    fi
    CC="${_default_c}"
    CXX="${_default_cxx}"
    CPP="${_default_cpp}"
    unset _default_c _default_cxx _default_cpp

    # TODO: make a alternatives / or capability
    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN}" ]; then
            CC="${CCACHE_BIN} /usr/bin/${CC}"
            CXX="${CCACHE_BIN} /usr/bin/${CXX}"
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
        #
        # NOTE: possible values for LLVM (LLD) linker emulation values (-m XYZ):
        #
        #       aarch64     =>          aarch64elf
        #       amd64       =>          elf_x86_64_fbsd
        #       arm         =>          armelf_fbsd
        #       armeb       =>          armelf_fbsd
        #       armv6       =>          armelf_fbsd
        #       i386        =>          elf_i386_fbsd
        #       mips        =>          elf32btsmip_fbsd
        #       mips64      =>          elf64btsmip_fbsd
        #       mipsel      =>          elf32ltsmip_fbsd
        #       mips64el    =>          elf64ltsmip_fbsd
        #       mipsn32     =>          elf32btsmipn32_fbsd
        #       powerpc     =>          elf32ppc_fbsd
        #       powerpc64   =>          elf64ppc_fbsd
        #       riscv       =>          elf64riscv
        #       sparc64     =>          elf64_sparc_fbsd
        #

        _compiler_use_linker_flags="-fuse-ld=lld"
        LD="ld.lld -m elf_x86_64_fbsd"

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

    unset DEFAULT_LINKER_FLAGS CMACROS
    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ]; then
        CMACROS="${HARDEN_CMACROS}"
    fi
    case "${SYSTEM_NAME}" in
        FreeBSD)
            DEFAULT_COMPILER_FLAGS="${HARDEN_CFLAGS} ${HARDEN_CFLAGS_PRODUCTION} ${CMACROS}"
            DEFAULT_LINKER_FLAGS="${HARDEN_LDFLAGS_PRODUCTION}"
            ;;

        Darwin)
            DEFAULT_COMPILER_FLAGS="${HARDEN_CFLAGS} ${CMACROS}"
            ;;

        Linux|Minix)
            DEFAULT_COMPILER_FLAGS="${HARDEN_CFLAGS} ${CMACROS}"
            ;;
    esac

    # CFLAGS, CXXFLAGS setup:
    set_c_and_cxx_flags "${_compiler_use_linker_flags}"

    if [ -z "${DEF_LINKER_NO_DTAGS}" ]; then
        CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
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
        # LDFLAGS="${LDFLAGS} ${LTO_CFLAGS}"
    fi

    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        CFLAGS="${CFLAGS} ${SSP_BUFFER_OVERRIDE}"
        CXXFLAGS="${CXXFLAGS} ${SSP_BUFFER_OVERRIDE}"
    fi

    # If DEF_LINKER_FLAGS is set on definition side, append it's content to LDFLAGS:
    # if [ -n "${DEF_LINKER_FLAGS}" ]; then
    #     LDFLAGS="${LDFLAGS} ${DEF_LINKER_FLAGS}"
    # fi
    # if [ -n "${DEF_COMPILER_FLAGS}" ]; then
    #     CFLAGS="${CFLAGS} ${DEF_COMPILER_FLAGS}"
    #     CXXFLAGS="${CXXFLAGS} ${DEF_COMPILER_FLAGS}"
    # fi

    # NOTE: some definitions fails on missing values for these:
    AR="${AR:-ar}"
    AS="${AS:-as}"
    NM="${NM:-nm}"
    LD="${LD:-ld}"
    CC="${CC:-cc}"
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
    debug "Pid of current Sofin session: $(distd "${SOFIN_PID}")"
    _bundle="$(capitalize "${_bundle_name}")"
    try "${MKDIR_BIN} -p ${LOCKS_DIR} 2>/dev/null"
    ${PRINTF_BIN} '%s\n' "${SOFIN_PID}" > "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}"
    unset _bundle _bundle_name
}


acquire_lock_for () {
    _bundles="${*}"
    for _bundle in $(to_iter "${_bundles}"); do
        debug "Acquiring lock for bundle: [$(distd "${_bundle}")]"
        if [ -f "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" ]; then
            _lock_pid="$(${CAT_BIN} "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" 2>/dev/null)"
            if [ -n "${_lock_pid}" ]; then
                debug "Lock pid: $(distd "${_lock_pid}"). Sofin pid: $(distd "${SOFIN_PID}"), Sofin PPID: $(distd "${PPID}")"
                try "${KILL_BIN} -0 ${_lock_pid} 2>/dev/null"
                if [ "${?}" = "0" ]; then # NOTE: process is alive
                    if [ "${_lock_pid}" = "${SOFIN_PID}" ] \
                    || [ "${PPID}" = "${SOFIN_PID}" ]; then
                        debug "Dealing with own process or it's fork, process may continue.."
                    elif [ "${_lock_pid}" = "${SOFIN_PID}" ] && \
                         [ -z "${PPID}" ]; then
                        debug "Dealing with no fork, process may continue.."
                    else
                        error "Bundle: $(diste "${_bundle}") is locked due to background job pid: $(diste "${_lock_pid}")"
                    fi
                else # NOTE: process is dead
                    debug "Found lock file acquired by dead process. Acquring a new lock.."
                    create_lock "${_bundle}"
                fi
            else
                debug "Lock pid: $(distd "none"), Sofin pid: $(distd "${SOFIN_PID}")"
            fi
        else
            debug "No file lock for bundle: $(distd "${_bundle}")"
            create_lock "${_bundle}"
        fi
    done
    unset _bundle _bundles _lock_pid
}


destroy_dead_locks () {
    _pattern="${1}"
    test -z "${_pattern}" && return 0

    _pid="${SOFIN_PID}"
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
    print_shell_vars > "${SOFIN_PROFILE}"
    print_local_env_vars >> "${SOFIN_PROFILE}"
}


reload_shell () {
    # NOTE: PPID contains pid of parent shell of Sofin
    if [ -n "${PPID}" ]; then
        try "${KILL_BIN} -SIGUSR2 ${PPID}" && \
            debug "Reload signal sent to parent pid: $(distd "${PPID}")"
    else
        debug "Skipped reload_shell() for no $(distd PPID)"
    fi
}


update_system_shell_env_files () {
    for _env_file in "${HOME}/.zshenv" "${HOME}/.bashrc"; do
        if [ -f "${_env_file}" ]; then
            ${GREP_BIN} -F 'Sofin launcher function' "${_env_file}" >/dev/null 2>&1
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
    unset _default_envs _env_file
}


set_normal_security () {
    debug "Setting security sysctls to normal. No background Sofin jobs found!"
    run "${SYSCTL_BIN} hardening.pax.segvguard.status=1 hardening.pax.mprotect.status=2 hardening.pax.pageexec.status=2 hardening.pax.disallow_map32bit.status=1 hardening.pax.aslr.status=3"
}


security_set_normal () {
    if [ -n "${CAP_SYS_HARDENED}" ]; then
        if [ -n "${CAP_SYS_PRODUCTION}" ]; then
            debug "Leaving security setting intact on production host."
        else
            _sp="$(processes_all_sofin)"
            if [ -z "${_sp}" ]; then
                debug "No Sofin processes in background! Setting normal security"
                set_normal_security
            else
                debug "Security sysctls untouched, Background Sofin jobs are still around!"
            fi
        fi
    fi
}


security_set_build () {
    if [ -n "${CAP_SYS_HARDENED}" ]; then
        if [ -z "${CAP_SYS_PRODUCTION}" ]; then
            debug "Setting security sysctls to build (lower)"
            run "${SYSCTL_BIN} hardening.pax.segvguard.status=0 hardening.pax.mprotect.status=0 hardening.pax.pageexec.status=0 hardening.pax.disallow_map32bit.status=0 hardening.pax.aslr.status=0"
        fi
    fi
}
