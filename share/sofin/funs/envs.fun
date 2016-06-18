setup_sofin_compiler () {

    COMMON_FLAGS="-fPIC"
    COMMON_COMPILER_FLAGS="${COMMON_FLAGS} -w -fno-strict-overflow -fstack-protector-all"
    DEFAULT_LDFLAGS="${COMMON_FLAGS}"
    DEFAULT_COMPILER_FLAGS="${COMMON_COMPILER_FLAGS}"

    case "${SYSTEM_NAME}" in
        Minix)
            DEFAULT_COMPILER_FLAGS="-I/usr/pkg/include -fPIE"
            DEFAULT_LDFLAGS="-L/usr/pkg/lib -fPIE"
            ;;

        FreeBSD)
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
            debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "ccache")"
            CC="${CCACHE_BIN_OPTIONAL} ${CC}"
            CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
            CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
        fi
    fi

    if [ -z "${APP_NO_GOLDEN_LINKER}" ]; then # Golden linker enabled by default
        case "${SYSTEM_NAME}" in
            Minix)
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
        debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "gold-linker")"
    else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
        unset NM LD
        debug " $(distinct d "${ERROR_CHAR}") $(distinct d "gold-linker")"
    fi

    if [ -z "${APP_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "enable-new-dtags")"
        else
            debug " $(distinct d "${ERROR_CHAR}") $(distinct d "enable-new-dtags")"
        fi
    fi

    if [ -z "${APP_NO_FAST_MATH}" ]; then
        debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "fast-math")"
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    else
        debug " $(distinct d "${ERROR_CHAR}") $(distinct d "fast-math")"
    fi

    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${CC}")"
    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${CXX}")"
    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${CPP}")"
    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${CFLAGS}")"
    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${CXXFLAGS}")"
    debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${LDFLAGS}")"

    if [ -z "${NM}" ]; then
        debug " $(distinct d "${ERROR_CHAR}") $(distinct d "${NM}")"
    else
        debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${NM}")"
    fi

    if [ -z "${LD}" ]; then
        debug " $(distinct d "${ERROR_CHAR}") $(distinct d "${LD}")"
    else
        debug " $(distinct d "${SUCCESS_CHAR}") $(distinct d "${LD}")"
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


create_lock () {
    bundle_name="${1}"
    if [ -z "${bundle_name}" ]; then
        error "No bundle name specified to lock!"
    else
        debug "Acquring bundle lock for: $(distinct d ${bundle_name})"
    fi
    if [ -z "${SOFIN_PID}" ]; then
        SOFIN_PID="$$"
        debug "\$SOFIN_PID is empty! Assigned as current process pid: $(distinct d ${SOFIN_PID})"
    else
        debug "create_lock(): Pid of current Sofin session is: $(distinct d ${SOFIN_PID})"
    fi
    bundle="$(capitalize ${bundle_name})"
    ${MKDIR_BIN} -p ${LOCKS_DIR}
    ${PRINTF_BIN} "${SOFIN_PID}" > ${LOCKS_DIR}${bundle}${DEFAULT_LOCK_EXT}
    unset bundle bundle_name
}


acquire_lock_for () {
    bundles="$*"
    debug "Trying lock acquire for bundles: [$(distinct d ${bundles})]"
    for bundle in ${bundles}; do
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
                debug "Found lock file acquired by dead process. Acquring a new lock.."
                create_lock "${bundle}"
            fi
        else
            debug "No file lock for bundle: $(distinct d ${bundle})"
            create_lock "${bundle}"
        fi
    done
}


destroy_locks () {
    debug "Cleaning file locks that belong to pid: $(distinct d ${SOFIN_PID}).."
    for f in $(${FIND_BIN} ${LOCKS_DIR} -mindepth 1 -maxdepth 1 -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        if [ ! -f "${LOG}" ]; then
            LOG="/dev/null"
        fi
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
        ${KILL_BIN} -SIGUSR2 ${wishlist} 2>> ${LOG} && \
        note "All running $(distinct n $(${BASENAME_BIN} "${SHELL}" 2>/dev/null)) sessions: $(distinct n ${wishlist}) were reloaded successfully"
        unset wishlist pids pattern pid
    else
        write_info_about_shell_configuration
    fi
}
