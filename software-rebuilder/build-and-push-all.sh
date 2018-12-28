#!/usr/bin/env zsh


SOFIN_ROOT="${SOFIN_ROOT:-/Software/Sofin}"
. "${SOFIN_ROOT}/share/loader"

# if [ "FreeBSD" = "${SYSTEM_NAME}" ]; then
#     try "${CHMOD_BIN} 600 ~/.ssh/id_rsa"
#     . /var/ServeD-OS/setup-buildhost
#     setup_buildhost
# fi

# ${TEST_BIN} -f /.build-host && export DEVEL=YES
# ${TEST_BIN} ! -x /Software/Ccache/bin/ccache || ${SOFIN_BIN} i Ccache
# USE_NO_UTILS=YES s d Pkgconf Make Cmake Bison Zip

note "Checking remote machine connection (shouldn't take more than a second).."
run "${SSH_BIN} sofin@git.verknowsys.com uname -a"

set +e

unset USE_NO_TEST

_working_state_file="/tmp/software.list.processing"
if [ ! -f "${_working_state_file}" ]; then
    permnote "Creating new work-state file: $(distn "${_working_state_file}")"
    run "${CP_BIN} -v software.list ${_working_state_file}"
fi

for _software in $(${CAT_BIN} ${_working_state_file} 2>/dev/null); do
    if [ "${_software}" = "------" ]; then
        permnote "All tasks finished!"
        exit
    fi
    permnote "________________________________"

    _indicator="/Software/${_software}/$(lowercase "${_software}")${DEFAULT_INST_MARK_EXT}"
    if [ -d "/Software/${_software}" ] && [ -f "${_indicator}" ]; then
        warn "Found already prebuilt version of software: $(distw "${_software}"). Leaving untouched with version: $(distw "$(${CAT_BIN} "${_indicator}" 2>/dev/null)")"
        ${SED_BIN} -i '' -e "/${_software}/d" ${_working_state_file}
    else
        destroy_software_and_datadirs () {
            try "${SOFIN_BIN} rm ${_software}"
            try "${ZFS_BIN} destroy -fr ${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${_software}"
            try "${ZFS_BIN} destroy -fr ${DEFAULT_ZPOOL}${SERVICES_DIR}/root/${_software}"
            try "${RM_BIN} -rf ${HOME}/.sofin/file-cache/$(capitalize "${_software}")* '${SOFTWARE_DIR}/${_software}' '${SERVICES_DIR}/${_software}'"
        }
        remove_from_list_and_destroy () {
            try "${SED_BIN} -i '' -e \"/${_software}/d\" ${_working_state_file}"
            destroy_software_and_datadirs
        }

        permnote "Removing software: $(distn "${_software}")"
        try "${SOFIN_BIN} rm ${_software}"

        permnote "Deploying software: $(distn "${_software}")"
        destroy_software_and_datadirs
        # USE_NO_UTILS=YES
        ${SOFIN_BIN} deploy ${_software}
        remove_from_list_and_destroy

    fi
    permnote "--------------------------------"
done
