setup_sofin_compiler () {

    COMMON_FLAGS="-fPIC"
    COMMON_COMPILER_FLAGS="${COMMON_FLAGS} -w -fno-strict-overflow -fstack-protector-all"
    DEFAULT_LDFLAGS="${COMMON_FLAGS}"
    DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS}"

    case "${SYSTEM_NAME}" in
        FreeBSD|Minix)
            DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -fPIE"
            DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -fPIE"
            ;;

        Linux)
            DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -mno-avx" # XXX: old Xeons case :)
            ;;
    esac

    if [ "YES" = "${DEBUGBUILD}" ]; then
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O0 -ggdb"
    else
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O2"
    fi

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
                BASE_COMPILER="/usr/bin"
                if [ "${SYSTEM_NAME}" = "Minix" ]; then
                    BASE_COMPILER="/usr/pkg/bin"
                fi
                if [ ! -x "${BASE_COMPILER}/clang" ]; then
                    setup_sofin_compiler GNU # fallback to gcc on system without any clang version
                    return
                fi
            fi
            CC="$(echo "${BASE_COMPILER}/clang ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            CXX="$(echo "${BASE_COMPILER}/clang++ ${APP_COMPILER_ARGS}" | ${SED_BIN} 's/ *$//' 2>/dev/null)"
            CPP="${BASE_COMPILER}/clang-cpp"
            if [ ! -x "${CPP}" ]; then # fallback for systems with clang without standalone preprocessor binary:
                CPP="${BASE_COMPILER}/clang -E"
            fi
            ;;
    esac

    # Support for other definition options
    if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
        error "Support for GNU compiler was recently dropped. Try using $(distinct e Gcc) instead)?"
    fi

    if [ -z "${APP_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then # check for CCACHE availability
            CC="${CCACHE_BIN_OPTIONAL} ${CC}"
            CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
            CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
        fi
    fi

    if [ -z "${APP_NO_GOLDEN_LINKER}" ]; then # Golden linker enabled by default
        case "${SYSTEM_NAME}" in
            FreeBSD|Minix)
                if [ -x "${GOLD_BIN}" -a -f "/usr/lib/LLVMgold.so" ]; then
                    DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                    DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
                    CFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    CXXFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS}"
                    LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                    NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
                fi
                ;;

            Linux)
                # Golden linker support without LLVM plugin:
                if [ -x "${GOLD_BIN}" ]; then
                    ${GREP_BIN} '7\.' /etc/debian_version >/dev/null 2>&1
                    if [ "$?" != "0" ]; then
                        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
                        DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -fuse-ld=gold"
                    else
                        DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS}"
                    fi
                    CFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    CXXFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                    LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS}"
                    unset NM LD
                fi
                ;;
        esac
    else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
        debug "Not using golden linker"
        unset NM LD
    fi

    if [ -z "${APP_LINKER_NO_DTAGS}" ]; then
        debug "Using dtags linker information"
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        fi
    fi

    if [ -z "${APP_NO_FAST_MATH}" ]; then
        debug "Enabling 'fast-math' compiler option"
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    fi

    export CFLAGS
    export CXXFLAGS
    export LDFLAGS
    export LD
    export NM
    export CC
    export CXX
    export CPP
}


acquire_lock_for () {
    bundles="$*"
    debug "Acquring lock for bundles: [$(distinct d ${bundles})]"
    for bundle in ${bundles}; do
        create_lock () {
            debug "Creating bundle lock file for: $(distinct d ${bundle})"
            echo "${SOFIN_PID}" > ${LOCKS_DIR}${bundle}${DEFAULT_LOCK_EXT}
        }
        if [ -f "${LOCKS_DIR}${bundle}${DEFAULT_LOCK_EXT}" ]; then
            lock_pid="$(${CAT_BIN} ${LOCKS_DIR}${bundle}${DEFAULT_LOCK_EXT} 2>/dev/null)"
            lock_parent_pid="$(${PGREP_BIN} -P${lock_pid} 2>/dev/null)"
            debug "Lock pid: $(distinct d ${lock_pid}), Sofin pid: $(distinct d ${SOFIN_PID}), lock_parent_pid: $(distinct d ${lock_parent_pid})"
            ${KILL_BIN} -0 "${lock_pid}" >/dev/null 2>/dev/null
            if [ "$?" = "0" ]; then # NOTE: process is alive
                if [ "${lock_pid}" = "${SOFIN_PID}" -o \
                     "${lock_parent_pid}" = "${SOFIN_PID}" ]; then
                    debug "Dealing with own process or it's fork, process may continue.."
                elif [ "${lock_pid}" = "${SOFIN_PID}" -a \
                       -z "${lock_parent_pid}" ]; then
                    debug "Dealing with no fork, process may continue.."
                else
                    error "Bundle: $(distinct e ${bundle}) is locked due to background job pid: $(distinct e "${lock_pid}")"
                fi
            else # NOTE: process is dead
                debug "Lock was acquired by some process but it's now dead. Acquring a new lock.."
                create_lock
            fi
        else
            debug "No file lock for bundle: $(distinct d ${bundle})"
            create_lock
        fi
    done
}


destroy_locks () {
    debug "Cleaning file locks that belong to pid: $(distinct d ${SOFIN_PID}).."
    for f in $(${FIND_BIN} ${LOCKS_DIR} -mindepth 1 -maxdepth 1 -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        ${GREP_BIN} "${SOFIN_PID}" "${f}" >> ${LOG} 2>> ${LOG}
        if [ "$?" = "0" ]; then
            debug "Removing lock file: $(distinct d ${f})"
            ${RM_BIN} -fv "${f}" >> ${LOG} 2>> ${LOG}
        fi
    done
}


update_shell_vars () {
    get_shell_vars > ${SOFIN_PROFILE}
}


reload_zsh_shells () {
    if [ ! -z "${SHELL_PID}" ]; then
        pattern="zsh"
        if [ "${SYSTEM_NAME}" = "Darwin" ]; then
            pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
        fi
        pids=$(processes_all | ${EGREP_BIN} "${pattern}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)
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
