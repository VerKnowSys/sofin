compiler_setup () {
    #XXX
    if [ "${1}" = "silent" ]; then
        debug () {
            ${LOGGER_BIN} "${DEFAULT_NAME}: $@"
        }
    fi
    debug "---------------- COMPILER FEATURES DUMP -----------------"
    debug "Listing compiler features for platform: $(distinct d "${SYSTEM_NAME}")"
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
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}debug-build")"
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}production-build")"
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O0 -ggdb"
    else
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}production-build")"
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}debug-build")"
        DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -O2"
    fi

    CFLAGS="$(echo "-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}" | eval ${CUT_TRAILING_SPACES_GUARD})"
    CXXFLAGS="$(echo "-I${PREFIX}/include ${DEF_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}" | eval ${CUT_TRAILING_SPACES_GUARD})"
    LDFLAGS="$(echo "-L${PREFIX}/lib ${DEF_LINKER_ARGS} ${DEFAULT_LDFLAGS}" | eval ${CUT_TRAILING_SPACES_GUARD})"

    # pick compiler in order:
    # 1. /usr/bin/clang
    # 2. /usr/bin/gcc
    default_c="${C_COMPILER_NAME}"
    default_cxx="${CXX_COMPILER_NAME}"
    default_cpp="${CPP_PREPROCESSOR_NAME}"
    BASE_COMPILER="${SOFTWARE_DIR}$(capitalize ${C_COMPILER_NAME})" # /Software/Clang
    if [ -x "${BASE_COMPILER}/bin/${default_c}" -a \
         -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}base-compiler: ${default_c}")"
    else # /usr/bin/clang
        BASE_COMPILER="/usr"
        if [ "${SYSTEM_NAME}" = "Minix" ]; then
            BASE_COMPILER="/usr/pkg"
        fi
        if [ -x "${BASE_COMPILER}/bin/${default_c}" -a \
             -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then
            debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}base-compiler: ${default_c}")"
        else
            if [ -x "${BASE_COMPILER}/bin/${C_COMPILER_NAME_ALT}" -a \
                 -x "${BASE_COMPILER}/bin/${CXX_COMPILER_NAME_ALT}" -a \
                 -x "${BASE_COMPILER}/bin/${CPP_PREPROCESSOR_NAME_ALT}" ]; then
                default_c="${C_COMPILER_NAME_ALT}"
                default_cxx="${CXX_COMPILER_NAME_ALT}"
                default_cpp="${CPP_PREPROCESSOR_NAME_ALT}"
                debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}base-compiler: ${default_c}")"
            else
                debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}base-compiler: ${default_c}")"
            fi
        fi
    fi

    CC="$(echo "${BASE_COMPILER}/bin/${default_c} ${DEF_COMPILER_ARGS}" | eval ${CUT_TRAILING_SPACES_GUARD})"
    if [ ! -x "${BASE_COMPILER}/bin/${default_c}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        error "Base C compiler: $(distinct e "${CC}") should be an executable!"
    fi

    CXX="$(echo "${BASE_COMPILER}/bin/${default_cxx} ${DEF_COMPILER_ARGS}" | eval ${CUT_TRAILING_SPACES_GUARD})"
    if [ ! -x "${BASE_COMPILER}/bin/${default_cxx}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        error "Base C++ compiler: $(distinct e "${CXX}") should be an executable!"
    fi

    CPP="$(echo "${BASE_COMPILER}/bin/${default_cpp}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    if [ ! -x "${BASE_COMPILER}/bin/${default_cpp}" ]; then # fallback for systems with clang without standalone preprocessor binary:
        CPP="${BASE_COMPILER}/bin/${default_c} -E"
    fi

    # -fPIC check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Cc]' >/dev/null 2>/dev/null && \
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}position-independent-code")" || \
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}position-independent-code")"

    # -fPIE check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Ee]' >/dev/null 2>/dev/null && \
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}position-independent-executable")" || \
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}position-independent-executable")"

    # -fstack-protector-all check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>/dev/null && \
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}stack-protector-all")" || \
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}stack-protector-all")"

    # -fno-strict-overflow check:
    echo "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>/dev/null && \
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}no-strict-overflow")" || \
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}no-strict-overflow")"

    if [ "${default_c}" = "${C_COMPILER_NAME}" ]; then
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}clang-compiler")"
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}gnu-c-compiler")"
    elif [ "${default_c}" = "${C_COMPILER_NAME_ALT}" ]; then
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}gnu-c-compiler")"
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}clang-compiler")"
    fi

    # Support for other definition options
    if [ -n "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
        warn "Support for GNU compiler was recently dropped, and is ignored since Sofin 1.0. Try using $(distinct e Gcc) instead?"
    fi

    # TODO: make a alternatives / or capability
    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then # check for CCACHE availability
            debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}ccache")"
            CC="${CCACHE_BIN_OPTIONAL} ${CC}"
            CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
            CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
        else
            debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}ccache")"
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
                    if [ "$?" != "0" ]; then
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
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}gold-linker")"
    else # Golden linker causes troubles with some build systems like Qt, so we give option to disable it
        unset NM LD
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}gold-linker")"
    fi

    if [ -z "${DEF_LINKER_NO_DTAGS}" ]; then
        if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
            CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
            debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}enable-new-dtags")"
        else
            debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}enable-new-dtags")"
        fi
    fi
    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        debug " $(distinct d "${ColorGreen}${SUCCESS_CHAR}") $(distinct d "${ColorGreen}fast-math")"
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    else
        debug " $(distinct d "${ColorYellow}${FAIL_CHAR}") $(distinct d "${ColorGray}fast-math")"
    fi
    debug "-------------- COMPILER FEATURES DUMP ENDS --------------"

    unset default_c default_cxx default_cpp

    export CFLAGS CXXFLAGS LDFLAGS LD NM CC CXX CPP
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
    for _dlf in $(${FIND_BIN} ${LOCKS_DIR} -mindepth 1 -maxdepth 1 -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        try "${GREP_BIN} ${SOFIN_PID} ${_dlf}" && \
            try "${RM_BIN} -f ${_dlf}" && \
                debug "Lock file removed: $(distinct d "${_dlf}")"
    done
    unset _dlf
}


update_shell_vars () {
    get_shell_vars > ${SOFIN_PROFILE}
}


reload_zsh_shells () {
    if [ -n "${SHELL_PID}" ]; then
        _shell_pattern="zsh"
        if [ "Darwin" = "${SYSTEM_NAME}" ]; then
            _shell_pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
        fi
        _shellshort="$(${BASENAME_BIN} "${SHELL}" 2>/dev/null)"
        _wishlist=""
        _pids=$(processes_all | ${EGREP_BIN} "${_shell_pattern}" 2>/dev/null | eval "${FIRST_ARG_GUARD}")
        for _pid in ${_pids}; do
            if [ -z "${_wishlist}" ]; then
                _wishlist="${_pid}"
            else
                ${KILL_BIN} -0 "${_pid}" >/dev/null 2>&1
                if [ "$?" = "0" ]; then
                    debug "Found alive pid: $(distinct d ${_pid}) in background."
                    _wishlist="${_wishlist} ${_pid}"
                fi
            fi
        done
        ${KILL_BIN} -SIGUSR2 ${_wishlist} >> ${LOG} 2>> ${LOG} && \
            note "Reload signal sent to $(distinct n "${_shellshort}") pids: $(distinct n ${_wishlist})"
    else
        write_info_about_shell_configuration
    fi
    unset _wishlist _pids _shell_pattern _pid _shellshort
}


update_env_files () {
    update_shell_vars
    _default_envs="/etc/profile /etc/zshenv /etc/bashrc"
    for _env_file in ${_default_envs}; do
        if [ -f "${_env_file}" ]; then
            debug "Processing existing env file: $(distinct d "${_env_file}")"
            ${GREP_BIN} -R "SHELL_PID=" "${_env_file}" >/dev/null 2>&1
            if [ "$?" = "0" ]; then
                continue
            else
                ${PRINTF_BIN} "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                    debug "Environment block appended to file: $(distinct d "${_env_file}")"

            fi
        else
            ${PRINTF_BIN} "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" && \
                debug "Environment block written to file: $(distinct d "${_env_file}")"
        fi
    done
    unset _default_envs _env_file
}
