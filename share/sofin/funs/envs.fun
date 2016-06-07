setup_sofin_compiler () {
    case $1 in
        GNU)
            BASE_COMPILER="/usr/bin"
            export CC="$(echo "${BASE_COMPILER}/gcc ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CXX="$(echo "${BASE_COMPILER}/g++ ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CPP="${BASE_COMPILER}/cpp"
            ;;

        CLANG)
            BASE_COMPILER="${SOFTWARE_DIR}Clang/exports"
            if [ ! -f "${BASE_COMPILER}/clang" ]; then
                export BASE_COMPILER="/usr/bin"
                if [ ! -x "${BASE_COMPILER}/clang" ]; then
                    setup_sofin_compiler GNU # fallback to gcc on system without any clang version
                    return
                fi
            fi
            export CC="$(echo "${BASE_COMPILER}/clang ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CXX="$(echo "${BASE_COMPILER}/clang++ ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CPP="${BASE_COMPILER}/clang-cpp"
            if [ ! -x "${CPP}" ]; then # fallback for systems with clang without standalone preprocessor binary:
                export CPP="${BASE_COMPILER}/clang -E"
            fi

            # Golden linker support:
            if [ -z "${APP_NO_GOLDEN_LINKER}" ]; then # Golden linker enabled by default
                case "${SYSTEM_NAME}" in
                    FreeBSD)
                        if [ -x "/usr/bin/ld.gold" -a -f "/usr/lib/LLVMgold.so" ]; then
                            CROSS_PLATFORM_COMPILER_FLAGS="-Wl,-fuse-ld=gold ${CROSS_PLATFORM_COMPILER_FLAGS}"
                            DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
                            export LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                            export NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
                        fi
                        ;;

                    Linux)
                        # Golden linker support without LLVM plugin:
                        if [ -x "/usr/bin/ld.gold" ]; then
                            CROSS_PLATFORM_COMPILER_FLAGS="-fPIC"
                            DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -fuse-ld=gold"
                            unset NM LD
                        fi
                        ;;
                esac
            else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
                debug "Removing explicit golden linker params.."
                CROSS_PLATFORM_COMPILER_FLAGS="-fPIC -fno-strict-overflow -fstack-protector-all"
                DEFAULT_LDFLAGS="-fPIC -fPIE"
                unset NM LD
            fi
            ;;
    esac
}


update_shell_vars () {
    # TODO: consider filtering debug messages to enable debug statements in early sofin code: | ${GREP_BIN} -v 'DEBUG:?'
    if [ "${USERNAME}" = "root" ]; then
        debug "Updating ${SOFIN_PROFILE} settings."
        ${PRINTF_BIN} "$(${SOFIN_BIN} getshellvars 2>/dev/null)" > "${SOFIN_PROFILE}" 2>/dev/null
    else
        debug "Updating ${HOME}/.profile settings."
        ${PRINTF_BIN} "$(${SOFIN_BIN} getshellvars ${USERNAME} 2>/dev/null)" > "${HOME}/.profile" 2>/dev/null
    fi
}


reload_zsh_shells () {
    if [ ! -z "${SHELL_PID}" ]; then
        pattern="zsh"
        if [ "${SYSTEM_NAME}" = "Darwin" ]; then
            pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
        fi
        pids=$(sofin_processes | ${EGREP_BIN} "${pattern}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)
        wishlist=""
        for pid in ${pids}; do
            wishlist="${wishlist}${pid} "
        done
        ${KILL_BIN} -SIGUSR2 ${wishlist} && \
        note "All running $(distinct n $(${BASENAME_BIN} "${SHELL}" 2>/dev/null)) sessions: $(distinct n ${wishlist}) were reloaded successfully"
        unset wishlist pids
    else
        write_info_about_shell_configuration
    fi
}
