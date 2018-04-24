#!/usr/bin/env zsh


SOFIN_ROOT="${SOFIN_ROOT:-/Software/Sofin}"
. "${SOFIN_ROOT}/share/loader"

# if [ "FreeBSD" = "${SYSTEM_NAME}" ]; then
#     try "${CHMOD_BIN} 600 ~/.ssh/id_rsa"
#     . /var/ServeD-OS/setup-buildhost
#     setup_buildhost
# fi

# ${TEST_BIN} -f /.build-host && export DEVEL=YES
${TEST_BIN} ! -x /Software/Ccache/bin/ccache || ${SOFIN_BIN} i Ccache

# NO_UTILS=YES s d Pkgconf Make Cmake Bison Zip

note "Checking remote machine connection (shouldn't take more than a second).."
run "${SSH_BIN} sofin@git.verknowsys.com uname -a"

set +e

unset USE_NO_TEST

_working_state_file="/var/software.list.processing"
if [ ! -f "${_working_state_file}" ]; then
    permnote "Creating new work-state file: $(distn "${_working_state_file}")"
    run "${CP_BIN} -v software.list ${_working_state_file}"
fi

for software in $(${CAT_BIN} ${_working_state_file} 2>/dev/null); do
    if [ "${software}" = "------" ]; then
        note "All tasks finished!"
        exit
    fi
    permnote "________________________________"

    _indicator="/Software/${software}/$(lowercase "${software}")${DEFAULT_INST_MARK_EXT}"
    if [ -d "/Software/${software}" ] && [ -f "${_indicator}" ]; then
        warn "Found already prebuilt version of software: $(distw "${software}"). Leaving untouched with version: $(distw "$(${CAT_BIN} "${_indicator}" 2>/dev/null)")"
        ${SED_BIN} -i '' -e "/${software}/d" ${_working_state_file}
    else
        remove_from_list_and_destroy () {
            try "${SED_BIN} -i '' -e \"/${software}/d\" ${_working_state_file}"
            try "${SOFIN_BIN} rm ${software}"
        }

        note "Removing software: $(distn "${software}")"
        try "${SOFIN_BIN} rm ${software}"

        note "Deploying software: $(distn "${software}")"
        NO_UTILS=YES ${SOFIN_BIN} deploy ${software} \
            && remove_from_list_and_destroy

    fi
    permnote "--------------------------------"
done
