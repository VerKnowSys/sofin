# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)
# global Sofin settings:

DEBUG="false"
TRACE="false"
# DEVEL="true"

DEBIAN="$(test -e /etc/debian_version && echo true)"

ID_SVD="-u" # NOTE: use "-un" for standard FreeBSD systems with users defined in /etc/passwd
HEADER="Sofin v${VERSION} - © 2o12-2o13 - Versatile Knowledge Systems - VerKnowSys.com"
SCRIPT_NAME="/usr/bin/sofin.sh"
SCRIPT_ARGS="$*"
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
export FETCH_BIN="/usr/bin/fetch"
export UNAME_BIN="/usr/bin/uname"
export FIND_BIN="/usr/bin/find"
export STRIP_BIN="/usr/bin/strip"
export BASENAME_BIN="/usr/bin/basename"
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

SYSTEM_NAME="$(uname)"
SYSTEM_ARCH="$(uname -p)"

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
        export BC_BIN="/usr/bin/bc"
        export CHOWN_BIN="/bin/chown"
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all"
        export DEFAULT_LDFLAGS="-fPIC "
        if [ "${DEBIAN}" = "true" ]; then # we're dealing with debian or ubuntu.
            export AWK_BIN="/usr/bin/awk"
            export SHA_BIN="/usr/bin/sha1sum"
        else
            export AWK_BIN="/usr/bin/awk -c"
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
    if [ "${DEBIAN}" = "true" ]; then
        ${PRINTF_BIN} "${1}\n"
    else
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    fi
}


debug () {
    if [ "${DEBUG}" = "true" ]; then
        cecho " ~ $1" ${magenta}
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
    if [ ! "$(${ID_BIN} -u)" = "0" ]; then
        error "This command should be run as root."
        exit
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
            error "Unavailable binary required by ${SCRIPT_NAME}: ${envvar}"
            exit 1
        fi
    done
}
