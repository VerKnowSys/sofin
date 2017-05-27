
load_requirements () {
    # load base facts
    . share/sofin/facts/core.fact
    . share/sofin/facts/paths.fact

    # these two loaded only for colorful output:
    . share/sofin/facts/system.fact
    . share/sofin/facts/terminal.fact
    . share/sofin/facts/sofin.fact

    # load functions
    . share/sofin/funs/core.fun
    . share/sofin/funs/commons.fun
    . share/sofin/funs/envs.fun
    . share/sofin/funs/internals.fun
    . share/sofin/funs/cleaners.fun
    . share/sofin/funs/caches.fun
}


install_sofin () {
    export CAP_SYS_PRODUCTION=YES
    export PREFIX="${PREFIX:-/Software/Sofin}"
    permnote "Installing Software Installer with version: $(distn "${SOFIN_VERSION}")"
    compiler_setup && \
        build_sofin_natives && \
            install_sofin_files && \
                note "Installation successful for: $(distn "${SOFIN_VERSION}")" && \
                echo "${SOFIN_VERSION}" > "${PREFIX}/${DEFAULT_NAME}${DEFAULT_INST_MARK_EXT}"
    update_system_shell_env_files

    permnote "Post install. Exporting default Sofin binaries…"
    try "${PREFIX}/bin/s export s Sofin"
    try "${PREFIX}/bin/s export s-osver Sofin"
    try "${PREFIX}/bin/s export s-usec Sofin"
    return 0
}


# No-Op one for installer:
update_defs () {
    debug "Skipping definitions update in installation process."
}


build_sofin_natives () {
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    compiler_setup
    _harden_flags="${COMMON_FLAGS} ${HARDEN_CFLAGS} ${HARDEN_OFLOW_CFLAGS} ${HARDEN_SAFE_STACK_FLAGS} ${HARDEN_CMACROS} ${HARDEN_CFLAGS_PRODUCTION} ${HARDEN_LDFLAGS_PRODUCTION}"
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "./src/${_prov}.cc" ]; then
            debug "Sofin: Build: ${CXX_NAME} -o bin/${_prov} ${_harden_flags} src/${_prov}.cc"
            ${CXX_NAME} -o "bin/${_prov}" \
                ${_harden_flags} "src/${_prov}.cc" && \
                permnote "  ${_okch} src/${_prov}.cc" && \
                continue

            return 1
        fi
    done
}


try_sudo_installation () {
    _cmds="sudo ${MKDIR_BIN} -vp ${SOFTWARE_DIR} ${SERVICES_DIR} && sudo ${CHOWN_BIN} -R ${USER} ${SOFTWARE_DIR} ${SERVICES_DIR}"
    note "Please provide password for commands: $(distn "${_cmds}")"
    eval "${_cmds}" || \
        exit 66
    unset _cmds
}


install_sofin_files () {
    if [ -z "${SOFTWARE_DIR}" ] || [ -z "${PREFIX}" ]; then
        exit 67
    fi
    ${MKDIR_BIN} -p "${SOFTWARE_DIR}" "${SERVICES_DIR}" "${PREFIX}/bin" "${PREFIX}/exports" "${PREFIX}/share" || \
        try_sudo_installation

    set -e
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    permnote "Installing to prefix: $(distn "${PREFIX}")"
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "bin/${_prov}" ]; then
            run "${INSTALL_BIN} -v bin/${_prov} ${PREFIX}/bin"
            run "${RM_BIN} -f bin/${_prov}"
        fi
    done && \
        permnote "  ${_okch} native utils"

    run "${CP_BIN} -vfR share/sofin/* ${PREFIX}/share/" && \
        permnote "  ${_okch} facts and functions"

    run "${INSTALL_BIN} -v src/s.sh ${PREFIX}/bin/s" && \
        permnote "  ${_okch} sofin launcher" && \
        permnote "Type: $(distn "s usage") for help." && \
        note "Read: $(distn "https://github.com/VerKnowSys/sofin") for more details." && \
            return 0
    return 1
}
