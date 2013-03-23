# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)
#
# global Sofin values:
if [ "${DEBUG}" = "" ]; then
    export DEBUG="false"
fi
if [ "${TRACE}" = "" ]; then
    export TRACE="false"
fi
readonly DEBUG
readonly TRACE
readonly DEBIAN="$(test -e /etc/debian_version && echo true)"
readonly GENTOO="$(test -e /etc/gentoo-release && echo true)"
readonly ID_SVD="-un"
readonly HEADER="Sofin v${VERSION} - © 2o12-2o13 - Versatile Knowledge Systems - VerKnowSys.com"
readonly SCRIPT_NAME="/usr/bin/sofin.sh"
readonly SCRIPT_ARGS="$*"
readonly PRIVATE_METADATA_DIR="/Private/"
readonly PRIVATE_METADATA_FILE="Metadata"
readonly HOME_APPS_DIR="Apps/"
readonly DEFINITION_SNAPSHOT_FILE="defs.tar.bz2"
readonly DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
readonly DEFAULT_MANPATH="/usr/share/man:/usr/share/openssl/man"
readonly SOFIN_PROFILE="/etc/profile_sofin"
readonly DEPENDENCIES_FILE=".dependencies"
readonly INSTALLED_MARK=".installed"
readonly LOG_LINES_AMOUNT="250"

# utils software from POSIX base system variables:
PRINTF_BIN="/usr/bin/printf"
KLDLOAD_BIN="/sbin/kldload"
KILL_BIN="/bin/kill"
PWD_BIN="/bin/pwd"
MV_BIN="/bin/mv"
CP_BIN="/bin/cp"
LN_BIN="/bin/ln"
WHICH_BIN="/usr/bin/which"
TAIL_BIN="/usr/bin/tail"
CUT_BIN="/usr/bin/cut"
LS_BIN="/bin/ls"
ID_BIN="/usr/bin/id"
MKDIR_BIN="/bin/mkdir"
MAKE_BIN="/usr/bin/make"
TAR_BIN="/usr/bin/tar"
CAT_BIN="/bin/cat"
TR_BIN="/usr/bin/tr"
TOUCH_BIN="/usr/bin/touch"
RM_BIN="/bin/rm"
DATE_BIN="/bin/date"
PATCH_BIN="/usr/bin/patch"
SED_BIN="/usr/bin/sed"
CHOWN_BIN="/usr/sbin/chown"
GREP_BIN="/usr/bin/grep"
EGREP_BIN="/usr/bin/egrep"
FETCH_BIN="/usr/bin/fetch"
UNAME_BIN="/usr/bin/uname"
FIND_BIN="/usr/bin/find"
STRIP_BIN="/usr/bin/strip"
BASENAME_BIN="/usr/bin/basename"
DIRNAME_BIN="/usr/bin/dirname"
SORT_BIN="/usr/bin/sort"
WC_BIN="/usr/bin/wc"
SHA_BIN="/sbin/sha1"
AWK_BIN="/usr/bin/awk"
SLEEP_BIN="/bin/sleep"
SYSCTL_BIN="/sbin/sysctl"
BC_BIN="/usr/bin/bc"
HEAD_BIN="/usr/bin/head"
SERVICE_BIN="/usr/sbin/service"
TEST_BIN="/bin/test"
CHMOD_BIN="/bin/chmod"
XARGS_BIN="/usr/bin/xargs"

# probably the most crucial value in whole code. by design immutable
USERNAME="$(${ID_BIN} ${ID_SVD})"

# common functions
# helpers

cecho () {
    if [ -t 1 ]; then # if it's terminal then use colors
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    else
        ${PRINTF_BIN} "${1}\n"
    fi
}


debug () {
    if [ "${DEBUG}" = "true" ]; then
        cecho "# $1" ${magenta} # NOTE: this "#" is required for debug mode to work properly with generation of ~/.profile and /etc/profile_sofin files!
    # else
        # cecho " ~ $1" ${magenta} >> ${LOG}
    fi
}


warn () {
    cecho " • $1" ${yellow}
}


note () {
    cecho " » $1" ${green}
}


error () {
    cecho " # $1" ${red}
}


# System specific configuration
readonly SYSTEM_NAME="$(uname)"
readonly SYSTEM_ARCH="$(uname -p)"

case "${SYSTEM_NAME}" in

    FreeBSD)
        # Default
        cpus="$(${SYSCTL_BIN} -a | ${GREP_BIN} kern.smp.cpus: | ${AWK_BIN} '{printf $2}')"
        export CURL_BIN="/usr/bin/fetch -o -"
        export MAKE_OPTS="-j${cpus}"
        ;;

    Darwin)
        # OSX specific configuration
        export CURL_BIN="/usr/bin/curl"
        export FETCH_BIN="/usr/bin/curl -O"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export DEFAULT_LDFLAGS="-fPIC -arch x86_64" # fPIE isn't well supported on OSX, but it's not production anyway
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all -arch x86_64"
        export SHA_BIN="/usr/bin/shasum"
        export SYSCTL_BIN="/usr/sbin/sysctl"
        export KLDLOAD_BIN="/sbin/kextload"
        cpus=$(${SYSCTL_BIN} -a | ${GREP_BIN} cpu.core_count: | ${AWK_BIN} '{printf $2}')
        export MAKE_OPTS="-j${cpus}"
        unset SERVICE_BIN # not necessary
        ;;

    Linux)
        export CURL_BIN="/usr/bin/wget -qO -"
        export FETCH_BIN="/usr/bin/wget -N"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export UNAME_BIN="/bin/uname"
        export KLDLOAD_BIN="/sbin/modprobe"
        export SHA_BIN="/usr/bin/shasum"
        export SED_BIN="/bin/sed"
        export TAR_BIN="/bin/tar"
        export GREP_BIN="/bin/grep"
        export EGREP_BIN="/bin/egrep"
        export BC_BIN="/usr/bin/bc"
        export CHOWN_BIN="/bin/chown"
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all"
        export DEFAULT_LDFLAGS="-fPIC "
        export TEST_BIN="/usr/bin/test"
        if [ "${DEBIAN}" = "true" ]; then # we're dealing with debian or ubuntu.
            export AWK_BIN="/usr/bin/awk"
            export SHA_BIN="/usr/bin/sha1sum"
        else
            export AWK_BIN="/usr/bin/awk -c"
        fi
        if [ "${GENTOO}" = "true" ]; then # Gentoo Linux
            export SERVICE_BIN="/sbin/rc-service"
        fi
        ;;

esac


SOFTWARE_DIR="/Software/"
CACHE_DIR="${SOFTWARE_DIR}.cache/"
DEFINITIONS_DIR="${CACHE_DIR}definitions/"
HOME_DIR="/Users/"
LOG="${CACHE_DIR}install.log"
LISTS_DIR="${CACHE_DIR}lists/"
DEFAULTS="${DEFINITIONS_DIR}defaults.def"


# fallback for FHS users for standard BSD/Linux
if [ ! -d "${HOME_DIR}" ]; then # fallback to FHS /home
    HOME_DIR="/home/"
else # if /Users/ exists, and it's not OSX, check for svd metadata
    readonly CURRENT_USER_UID="$(${ID_BIN} -u)"
    if [ "${CURRENT_USER_UID}" != "0" ]; then
        if [ "$(${FIND_BIN} ${HOME_DIR} -maxdepth 1 2>/dev/null | ${WC_BIN} -l | ${TR_BIN} -d ' ')" = "0" ]; then
            error "No user home dir found? Critial error. No entries in ${HOME_DIR}? Fix it and retry."
            exit 1
        fi
        readonly USER_DIRNAME="$(${FIND_BIN} ${HOME_DIR} -maxdepth 1 -uid "${CURRENT_USER_UID}" 2> /dev/null)" # get user dir by uid and ignore access errors

        # additional check for multiple dirs with same UID (illegal)
        readonly USER_DIR_AMOUNT="$(echo "${USER_DIRNAME}" | ${WC_BIN} -l | ${TR_BIN} -d ' ')"
        debug "User dirs amount: ${USER_DIR_AMOUNT}"
        if [ "${USER_DIR_AMOUNT}" != "1" ]; then
            error "Found more than one user with same uid in ${HOME_DIR}! That's illegal. Fix it an retry."
            error "Conflicting users: $(echo "${USER_DIRNAME}" | ${TR_BIN} '\n' ' ')"
            exit 1
        fi
        debug "User dirname: ${USER_DIRNAME}"
        export USERNAME="$(${BASENAME_BIN} ${USER_DIRNAME})"
        readonly METADATA_FILE="${HOME_DIR}${USERNAME}${PRIVATE_METADATA_DIR}${PRIVATE_METADATA_FILE}"
        if [ -f "${METADATA_FILE}" ]; then
            debug "ServeD System found. Username set to: ${USERNAME}. Home directory: ${HOME_DIR}${USERNAME}"
            debug "Loading user metdata from ${METADATA_FILE}"
            . "${METADATA_FILE}"
            readonly export SVD_FULL_NAME="${SVD_FULL_NAME}"
            #
            # TODO: FIXME: 2013-03-19 15:34:07 - dmilith - fill metadata and define values of it...
            # ...
            #
        else
            debug "No metadata found in: ${METADATA_FILE} for user: ${USERNAME}. No additional user data accessible."
        fi
    fi
fi


if [ "${USERNAME}" != "root" ]; then
    export SOFTWARE_DIR="${HOME_DIR}${USERNAME}/${HOME_APPS_DIR}"
    export LOG="${HOME_DIR}${USERNAME}/install.log"
    export CACHE_DIR="${HOME_DIR}${USERNAME}/.cache/"
    export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
    export LISTS_DIR="${CACHE_DIR}lists/"
    export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
fi
readonly SOFTWARE_DIR
readonly LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
readonly LOG
readonly CACHE_DIR
readonly DEFINITIONS_DIR
readonly LISTS_DIR
readonly DEFAULTS
readonly USERNAME


# mutable state for compiler
DEFAULT_LDFLAGS="-fPIC -fPIE"
DEFAULT_COMPILER_FLAGS="-Os -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"
MAKE_OPTS="-j5"

# more values
readonly DEFAULT_PAUSE_WHEN_LOCKED="30" # seconds
readonly MAIN_SOURCE_REPOSITORY="http://software.verknowsys.com/source/"
readonly MAIN_BINARY_REPOSITORY="http://software.verknowsys.com/binary/$(${UNAME_BIN})/common/"
readonly CCACHE_BIN_OPTIONAL="${SOFTWARE_DIR}Ccache/exports/ccache"

# ANSI color definitions
readonly red='\033[31;40m'
readonly green='\033[32;40m'
readonly yellow='\033[33;40m'
readonly blue='\033[34;40m'
readonly magenta='\033[35;40m'
readonly cyan='\033[36;40m'
readonly gray='\033[37;40m'
readonly white='\033[38;40m'
readonly reset='\033[0m'


check_command_result () {
    if [ -z "$1" ]; then
        error "No param given for check_command_result()!"
        exit 1
    fi
    if [ "$1" = "0" ]; then
        debug "CORRECT"
    else
        error
        error "FAILURE. Run $(${BASENAME_BIN} ${SCRIPT_NAME}) log to see what went wrong."
        exit 1
    fi
}


check_root () {
    if [ ! "${USERNAME}" = "root" ]; then
        error "This command should be run as root."
        exit 1
    fi
}


check_os () {
    case "${SYSTEM_NAME}" in
        FreeBSD)
            ;;

        Darwin)
            ;;

        Linux)
            ;;

        *)
            error "Currently only FreeBSD, Darwin and Linux hosts are supported."
            exit
            ;;

    esac
}


# validate environment availability or crash
validate_env () {
    env | ${GREP_BIN} '_BIN=/' | while IFS= read -r envvar
    do
        var_value="$(${PRINTF_BIN} "${envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1}')"
        if [ ! -x "${var_value}" ]; then
            error "Required binary is unavailable: ${envvar}"
            exit 1
        fi
    done || exit 1
}
