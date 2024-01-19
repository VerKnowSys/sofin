#!/usr/bin/env sh

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
    . share/sofin/funs/datasets.fun
}


prepare_and_manage_origin () {
    if [ -n "${CAP_SYS_ZFS}" ]; then
        try "zfs set readonly=off '${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}'"

        # Create "root" Sofin dataset:
        try "zfs list '${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}'" \
            || try "zfs create -o mountpoint='${SOFTWARE_DIR}/${SOFIN_BUNDLE_NAME}' '${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}'"

        _any_snap="$(zfs list -H -r -t snapshot -o name "${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}" 2>/dev/null)"
        if [ -n "${_any_snap}" ]; then
            _snap_count="$(printf "%b\n" "${_any_snap}" | ${GREP_BIN} -c '' 2>/dev/null)"
            # NOTE: handle potential problem with huge amount of snapshots later on. Keep max of N most recent snapshots:
            if [ "${_snap_count}" -gt "${DEFAULT_ZFS_MAX_SNAPSHOT_COUNT}" ]; then
                debug "Old snapshots count: $(distd "${_snap_count}")"
                for _a_snap in $(to_iter "${_any_snap}"); do
                    try "zfs destroy '${_a_snap}'" \
                        && permnote "Destroyed the oldest $(distn "@${ORIGIN_ZFS_SNAP_NAME}") snapshot: $(distn "${_a_snap}")." \
                            && break # - we want to remove at least one snapshot
                done
            else
                debug "Old ${SOFIN_BUNDLE_NAME} snapshots count: $(distd "${_snap_count}")"
            fi

            _timestamp_now="$(date +%F-%H%M-%s 2>/dev/null)"
            try "zfs rename '${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}@${ORIGIN_ZFS_SNAP_NAME}' '@${ORIGIN_ZFS_SNAP_NAME}-${_timestamp_now}'" \
                && permnote "Renamed current @${ORIGIN_ZFS_SNAP_NAME} for ${SOFIN_BUNDLE_NAME} dataset."
        fi
    fi
}


commit_origin () {
    if [ -n "${CAP_SYS_ZFS}" ]; then
        run "zfs snapshot ${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}@${ORIGIN_ZFS_SNAP_NAME}" \
            && permnote "Created new $(distn "@${ORIGIN_ZFS_SNAP_NAME}") snapshot of bundle: $(distn "${SOFIN_BUNDLE_NAME}")."

        try "zfs set readonly=on ${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${SOFIN_BUNDLE_NAME}"
    fi
}


install_sofin () {
    load_requirements
    determine_system_capabilites
    set_software_root_writable
    create_sofin_dirs

    prepare_and_manage_origin

    permnote "Install $(distn "${SOFIN_BUNDLE_NAME}") to prefix: $(distn "${SOFIN_ROOT}")"
    compiler_setup \
        && build_sofin_natives \
            && install_sofin_files \
                && printf "%b\n" "${SOFIN_VERSION}" > "${SOFIN_ROOT}/${SOFIN_NAME}${DEFAULT_INST_MARK_EXT}"

    # _zsh="${DEFAULT_SHELL_EXPORTS}/zsh"
    # _zsh_maybe="$(which zsh)"
    # if [ -x "${_zsh_maybe}" ]; then
    #     _zsh="${_zsh_maybe}"
    # fi

    # ${SED_BIN} -i '' -e "s#/usr/bin/env sh#${_zsh}#" \
    #     "${SOFIN_ROOT}/bin/s" \
    #     "${SOFIN_ROOT}/share/loader" \
    #     >/dev/null 2>&1 \
    permnote "${SOFIN_BUNDLE_NAME} v$(distn "${SOFIN_VERSION}") was installed successfully!"

    commit_origin

    update_system_shell_env_files
    update_shell_vars
    set_software_root_readonly
    reload_shell
    permnote "Installation successful."
    return 0
}


# No-Op one for installer:
update_defs () {
    debug "Skipped definitions update in installation process."
}


build_sofin_natives () {
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    compiler_setup
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "src/${_prov}.cc" ]; then
            debug "${SOFIN_BUNDLE_NAME}: Build: ${CXX_NAME} -o bin/${_prov} ${CFLAGS} src/${_prov}.cc"
            _compiler="${CXX}"
            if [ -x "${CCACHE_BIN}" ]; then
                _compiler="${CCACHE_BIN} ${CXX}"
            fi
            run "${_compiler} ${CXX14_CXXFLAGS} ${HARDEN_CFLAGS} \
                  ${DEFAULT_LINKER_FLAGS} \
                    src/${_prov}.cc \
                        -o bin/${_prov}" \
                            && permnote "  ${_okch} cc: src/${_prov}.cc"

            continue
        fi
    done
}


try_sudo_installation () {
    _cmds="sudo ${MKDIR_BIN} -vp ${SOFTWARE_DIR} ${SERVICES_DIR} && sudo ${CHOWN_BIN} -R ${USER} ${SOFTWARE_DIR} ${SERVICES_DIR}"
    permnote "Please provide password for commands: $(distn "${_cmds}")"
    eval "${_cmds}" \
        || exit 66
    unset _cmds
}


install_sofin_files () {
    if [ -z "${SOFTWARE_DIR}" ] \
    || [ -z "${SOFIN_ROOT}" ]; then
        exit 67
    fi

    ${MKDIR_BIN} -p "${SOFTWARE_DIR}" "${SERVICES_DIR}" "${SOFIN_ROOT}/bin" "${SOFIN_ROOT}/exports" "${SOFIN_ROOT}/share" \
        || try_sudo_installation

    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "bin/${_prov}" ]; then
            run "${INSTALL_BIN} bin/${_prov} ${SOFIN_ROOT}/bin"
            run "${RM_BIN} -f bin/${_prov}"
        fi
    done \
        && permnote "  ${_okch} native utils"

    run "${CP_BIN} -fR share/sofin/* ${SOFIN_ROOT}/share/" \
        && permnote "  ${_okch} facts and functions"

    run "${INSTALL_BIN} -m 755 src/s.sh ${SOFIN_ROOT}/bin/s" \
        && permnote "  ${_okch} sofin launcher"

    permnote "Read: $(distn "https://github.com/VerKnowSys/sofin") for more details."
    permnote "Type: $(distn "s usage") for quick help."
    return 0
}


set_software_root_readonly () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _sofin_processes="$(processes_all_sofin)"
        if [ -z "${_sofin_processes}" ]; then
        if [ "YES" = "${CAP_SYS_JAILED}" ]; then
            ${ZFS_BIN} set readonly=on "${DEFAULT_ZPOOL}/Software/${HOST}" >/dev/null 2>&1 \
                && debug "Ok(jailed): set readonly=on '${DEFAULT_ZPOOL}/Software/${HOST}'"
        else
            ${ZFS_BIN} set readonly=on "${DEFAULT_ZPOOL}/Software/${USER}" >/dev/null 2>&1 \
                && debug "Ok(unjailed): set readonly=on '${DEFAULT_ZPOOL}/Software/${USER}'"
        fi
    else
        warn "Other Sofin instances found in background, management of Software datasets skipped."
    fi
        unset _sofin_processes
    fi
}


set_software_root_writable () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ "YES" = "${CAP_SYS_JAILED}" ]; then
            ${ZFS_BIN} set readonly=off "${DEFAULT_ZPOOL}/Software/${HOST}" >/dev/null 2>&1 \
                && debug "Ok(jailed): set readonly=off '${DEFAULT_ZPOOL}/Software/${HOST}'"
        else
            ${ZFS_BIN} set readonly=off "${DEFAULT_ZPOOL}/Software/${USER}" >/dev/null 2>&1 \
                && debug "Ok(unjailed): set readonly=off '${DEFAULT_ZPOOL}/Software/${USER}'"
        fi
    fi
}
