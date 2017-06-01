
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
    env_reset
    create_dirs
    load_requirements
    determine_system_capabilites
    determine_term_capabilites

    permnote "Installing ${SOFIN_BUNDLE_NAME} to prefix: $(distn "${SOFIN_ROOT}")"

    compiler_setup && \
        build_sofin_natives && \
        install_sofin_files && \
        note "${SOFIN_BUNDLE_NAME} installed successfully with version: $(distn "${SOFIN_VERSION}")" && \
        echo "${SOFIN_VERSION}" > "${SOFIN_ROOT}/${SOFIN_NAME}${DEFAULT_INST_MARK_EXT}"

    for _bin in "s" "s-osver" "s-usec"; do
        test ! -L "${SOFIN_ROOT}/exports/${_bin}" && \
            run "${SOFIN_ROOT}/bin/${_bin} export ${_bin} ${SOFIN_BUNDLE_NAME}"
    done

    update_system_shell_env_files
    return 0
}


# No-Op one for installer:
update_defs () {
    debug "Skipping definitions update in installation process."
}


build_sofin_natives () {
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    compiler_setup
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "src/${_prov}.cc" ]; then
            debug "${SOFIN_BUNDLE_NAME}: Build: ${CXX_NAME} -o bin/${_prov} ${CFLAGS} src/${_prov}.cc"
            run "${CXX_NAME} ${DEFAULT_COMPILER_FLAGS} ${DEFAULT_LINKER_FLAGS} src/${_prov}.cc -o bin/${_prov}" && \
                permnote "  ${_okch} cc: src/${_prov}.cc"

            continue
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
    if [ -z "${SOFTWARE_DIR}" ] || [ -z "${SOFIN_ROOT}" ]; then
        exit 67
    fi
    ${MKDIR_BIN} -p "${SOFTWARE_DIR}" "${SERVICES_DIR}" "${SOFIN_ROOT}/bin" "${SOFIN_ROOT}/exports" "${SOFIN_ROOT}/share" || \
        try_sudo_installation

    env_pedantic
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "bin/${_prov}" ]; then
            run "${INSTALL_BIN} -v bin/${_prov} ${SOFIN_ROOT}/bin"
            run "${RM_BIN} -f bin/${_prov}"
        fi
    done && \
        permnote "  ${_okch} native utils"

    run "${CP_BIN} -vfR share/sofin/* ${SOFIN_ROOT}/share/" && \
        permnote "  ${_okch} facts and functions"

    run "${INSTALL_BIN} -v src/s.sh ${SOFIN_ROOT}/bin/s" && \
        permnote "  ${_okch} sofin launcher" && \
        permnote "Type: $(distn "s usage") for help." && \
        note "Read: $(distn "https://github.com/VerKnowSys/sofin") for more details." && \
            return 0
    return 1
}
