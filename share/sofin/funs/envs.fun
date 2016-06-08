setup_sofin_compiler () {
    # export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/libexec:/usr/lib:/lib"
    CFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
    CXXFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
    LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS}"

    debug "Setting up default system compiler"
    case $1 in
        GNU)
            BASE_COMPILER="/usr/bin"
            export CC="$(echo "${BASE_COMPILER}/gcc ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CXX="$(echo "${BASE_COMPILER}/g++ ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            export CPP="${BASE_COMPILER}/cpp"
            ;;

        *)
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
            ;;
    esac

    # Support for other definition options
    if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
        error "   ${WARN_CHAR} GNU compiler support was dropped. Try using $(distinct e Gcc) instead)"
    fi

    if [ ! -z "${APP_NO_FAST_MATH}" ]; then
        debug "Trying to disable fast math option"
        CROSS_PLATFORM_COMPILER_FLAGS="$(echo "${CROSS_PLATFORM_COMPILER_FLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
        DEFAULT_COMPILER_FLAGS="$(echo "${DEFAULT_COMPILER_FLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
        CFLAGS="$(echo "${CFLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
        CXXFLAGS="$(echo "${CXXFLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
    fi

    if [ ! -z "${APP_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then # check for CCACHE availability
            export CC="${CCACHE_BIN_OPTIONAL} ${CC}"
            export CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
            export CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
        fi
    fi

    if [ -z "${APP_NO_GOLDEN_LINKER}" ]; then # Golden linker enabled by default
        case "${SYSTEM_NAME}" in
            FreeBSD)
                if [ -x "/usr/bin/ld.gold" -a -f "/usr/lib/LLVMgold.so" ]; then
                    DEFAULT_COMPILER_FLAGS="-Wl,-fuse-ld=gold ${CROSS_PLATFORM_COMPILER_FLAGS}"
                    DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
                    export LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                    export NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
                fi
                ;;

            Linux)
                # Golden linker support without LLVM plugin:
                if [ -x "/usr/bin/ld.gold" ]; then
                    CROSS_PLATFORM_COMPILER_FLAGS="-fPIC"
                    ${GREP_BIN} '7\.' /etc/debian_version >/dev/null 2>&1
                    if [ "$?" != "0" ]; then
                        DEFAULT_LDFLAGS="${CROSS_PLATFORM_COMPILER_FLAGS} -fuse-ld=gold"
                        DEFAULT_COMPILER_FLAGS="${CROSS_PLATFORM_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                    else
                        DEFAULT_LDFLAGS="${CROSS_PLATFORM_COMPILER_FLAGS}"
                    fi
                    LDFLAGS="${DEFAULT_LDFLAGS}"
                    unset NM LD
                fi
                ;;
        esac
    else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
        debug "Not using golden linker"
        DEFAULT_COMPILER_FLAGS="-fPIC -fno-strict-overflow -fstack-protector-all"
        DEFAULT_LDFLAGS="-fPIC"
        unset NM LD
    fi

    if [ -z "${APP_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        fi
    fi

    export CFLAGS
    export CXXFLAGS
    export LDFLAGS
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
