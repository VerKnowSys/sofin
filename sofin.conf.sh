# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)
# global Sofin settings:

DEBUG="false"
TRACE="false"
# DEVEL="true"

DEBIAN="$(test -e /etc/debian_version && echo true)"
GENTOO="$(test -e /etc/gentoo-release && echo true)"

ID_SVD="-un"
HEADER="Sofin v${VERSION} - © 2o12-2o13 - Versatile Knowledge Systems - VerKnowSys.com"
SCRIPT_NAME="/usr/bin/sofin.sh"
SCRIPT_ARGS="$*"
PRIVATE_METADATA_DIR="/Private/"
PRIVATE_METADATA_FILE="Metadata"
SOFTWARE_DIR="/Software/"
LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
HOME_DIR="/Users/"
HOME_APPS_DIR="Apps/"
CACHE_DIR="${SOFTWARE_DIR}.cache/"
LOG="${CACHE_DIR}install.log"
DEFINITIONS_DIR="${CACHE_DIR}definitions/"
LISTS_DIR="${CACHE_DIR}lists/"
DEFAULTS="${DEFINITIONS_DIR}defaults.def"
DEFINITION_SNAPSHOT_FILE="defs.tar.bz2"
DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
DEFAULT_LDFLAGS="-fPIC -fPIE"
DEFAULT_COMPILER_FLAGS="-Os -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"
DEFAULT_MANPATH="/usr/share/man:/usr/share/openssl/man"
SOFIN_PROFILE="/etc/profile_sofin"
DEPENDENCIES_FILE=".dependencies"
INSTALLED_MARK=".installed"
LOG_LINES_AMOUNT="150"

MAKE_OPTS="-j4"

# config binary requirements definitions
export XARGS_BIN="/usr/bin/xargs"
export PRINTF_BIN="/usr/bin/printf"
export KLDLOAD_BIN="/sbin/kldload"
export KILL_BIN="/bin/kill"
export PWD_BIN="/bin/pwd"
export MV_BIN="/bin/mv"
export CP_BIN="/bin/cp"
export LN_BIN="/bin/ln"
export WHICH_BIN="/usr/bin/which"
export TAIL_BIN="/usr/bin/tail"
export CUT_BIN="/usr/bin/cut"
export LS_BIN="/bin/ls"
export ID_BIN="/usr/bin/id"
export MKDIR_BIN="/bin/mkdir"
export MAKE_BIN="/usr/bin/make"
export TAR_BIN="/usr/bin/tar"
export CAT_BIN="/bin/cat"
export TR_BIN="/usr/bin/tr"
export TOUCH_BIN="/usr/bin/touch"
export RM_BIN="/bin/rm"
export DATE_BIN="/bin/date"
export PATCH_BIN="/usr/bin/patch"
export SED_BIN="/usr/bin/sed"
export CHOWN_BIN="/usr/sbin/chown"
export GREP_BIN="/usr/bin/grep"
export EGREP_BIN="/usr/bin/egrep"
export FETCH_BIN="/usr/bin/fetch"
export UNAME_BIN="/usr/bin/uname"
export FIND_BIN="/usr/bin/find"
export STRIP_BIN="/usr/bin/strip"
export BASENAME_BIN="/usr/bin/basename"
export DIRNAME_BIN="/usr/bin/dirname"
export SORT_BIN="/usr/bin/sort"
export WC_BIN="/usr/bin/wc"
export SHA_BIN="/sbin/sha1"
export AWK_BIN="/usr/bin/awk"
export SLEEP_BIN="/bin/sleep"
export SYSCTL_BIN="/sbin/sysctl"
export BC_BIN="/usr/bin/bc"
export HEAD_BIN="/usr/bin/head"
export SERVICE_BIN="/usr/sbin/service"
export TEST_BIN="/bin/test"
export CHMOD_BIN="/bin/chmod"

export USERNAME="$(${ID_BIN} ${ID_SVD})"
export SYSTEM_NAME="$(uname)"
export SYSTEM_ARCH="$(uname -p)"


# System specific configuration
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


DEFAULT_PAUSE_WHEN_LOCKED="30" # seconds
MAIN_SOURCE_REPOSITORY="http://software.verknowsys.com/source/"
MAIN_BINARY_REPOSITORY="http://software.verknowsys.com/binary/$(${UNAME_BIN})/common/"

CCACHE_BIN_OPTIONAL="${SOFTWARE_DIR}Ccache/exports/ccache"

# ANSI color definitions
red='\033[31;40m'
green='\033[32;40m'
yellow='\033[33;40m'
blue='\033[34;40m'
magenta='\033[35;40m'
cyan='\033[36;40m'
gray='\033[37;40m'
white='\033[38;40m'
reset='\033[0m'


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


# fallback
if [ ! -d "${HOME_DIR}" ]; then # fallback to FHS /home
    HOME_DIR="/home/"
else # if /Users/ exists, and it's not OSX, check for svd metadata
    CURRENT_USER_UID="$(${ID_BIN} -u)"
    if [ "${CURRENT_USER_UID}" != "0" ]; then
        if [ "$(${FIND_BIN} ${HOME_DIR} -depth 1 2>/dev/null | ${WC_BIN} -l | ${TR_BIN} -d ' ')" = "0" ]; then
            error "No user home dir found? Critial error. No entries in ${HOME_DIR}? Fix it and retry."
            exit 1
        fi
        USER_DIRNAME="$(${FIND_BIN} ${HOME_DIR} -depth 1 -uid "${CURRENT_USER_UID}" 2> /dev/null)" # get user dir by uid and ignore access errors

        # additional check for multiple dirs with same UID (illegal)
        USER_DIR_AMOUNT="$(echo "${USER_DIRNAME}" | ${WC_BIN} -l | ${TR_BIN} -d ' ')"
        debug "User dirs amount: ${USER_DIR_AMOUNT}"
        if [ "${USER_DIR_AMOUNT}" != "1" ]; then
            error "Found more than one user with same uid in ${HOME_DIR}! That's illegal. Fix it an retry."
            error "Conflicting users: $(echo "${USER_DIRNAME}" | ${TR_BIN} '\n' ' ')"
            exit 1
        fi
        debug "User dirname: ${USER_DIRNAME}"
        export USERNAME="$(${BASENAME_BIN} ${USER_DIRNAME})"
        METADATA_FILE="${HOME_DIR}${USERNAME}${PRIVATE_METADATA_DIR}${PRIVATE_METADATA_FILE}"
        if [ -f "${METADATA_FILE}" ]; then
            debug "ServeD System found. Username set to: ${USERNAME}. Home directory: ${HOME_DIR}${USERNAME}"
            debug "Loading user metdata from ${METADATA_FILE}"
            . "${METADATA_FILE}"
            export SVD_FULL_NAME="${SVD_FULL_NAME}"
            #
            # TODO: FIXME: 2013-03-19 15:34:07 - dmilith - fill metadata and define values of it...
            # ...
            #
        else
            debug "No metadata found in: ${METADATA_FILE} for user: ${USERNAME}. No additional user data accessible."
        fi
    fi
fi

