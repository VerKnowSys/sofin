# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)
# global Sofin settings:

DEBUG="false"
VERBOSE="false"
# DEVEL="true"

ID_SVD="-u" # NOTE: use "-un" for standard FreeBSD systems with users defined in /etc/passwd
HEADER="Sofin v${VERSION} - © 2o12 - Versatile Knowledge Systems - VerKnowSys.com"
SCRIPT_NAME="$0"
SCRIPT_ARGS="$*"
SOFTWARE_DIR="/Software/"
JDK6_32="${SOFTWARE_DIR}Openjdk6-i386"
JDK6_64="${SOFTWARE_DIR}Openjdk6-amd64"
JDK7_32="${SOFTWARE_DIR}Openjdk7-i386"
JDK7_64="${SOFTWARE_DIR}Openjdk7-amd64"
LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
HOME_DIR="/Users/"
HOME_APPS_DIR="Apps/"
CACHE_DIR="${SOFTWARE_DIR}.cache/"
LOG="${CACHE_DIR}install.log"
DEFINITIONS_DIR="${CACHE_DIR}definitions/"
LISTS_DIR="${CACHE_DIR}lists/"
DEFAULTS="${DEFINITIONS_DIR}defaults.def"
DEFINITION_SNAPSHOT_FILE="defs.tar.gz"
DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
DEFAULT_LDFLAGS="-fPIC -fPIE"
DEFAULT_COMPILER_FLAGS="-Os -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"
DEFAULT_MANPATH="/usr/share/man:/usr/share/openssl/man"
SOFIN_PROFILE="/etc/profile_sofin"
DEPENDENCIES_FILE=".dependencies"
INSTALLED_MARK=".installed"
LOG_LINES_AMOUNT="150"
MAKE_OPTS=""

# config binary requirements definitions
XARGS_BIN="/usr/bin/xargs"
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
FETCH_BIN="/usr/bin/fetch"
UNAME_BIN="/usr/bin/uname"
FIND_BIN="/usr/bin/find"
STRIP_BIN="/usr/bin/strip"
BASENAME_BIN="/usr/bin/basename"
SORT_BIN="/usr/bin/sort"
WC_BIN="/usr/bin/wc"
SHA_BIN="/sbin/sha1"
AWK_BIN="/usr/bin/awk"
SLEEP_BIN="/bin/sleep"
LOCKFILE_BIN="/usr/bin/lockfile"


SYSTEM_NAME="$(uname)"


# System specific configuration
case "${SYSTEM_NAME}" in

    FreeBSD)
        # Default
        ;;

    Darwin)
        # OSX specific configuration
        export FETCH_BIN="/usr/bin/curl -O"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export DEFAULT_LDFLAGS="-fPIC -arch x86_64" # fPIE isn't well supported on OSX, but it's not production anyway
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all -arch x86_64"
        export SHA_BIN="/usr/bin/shasum"
        ;;

    Linux)
        export FETCH_BIN="/usr/bin/curl -O"
        export UNAME_BIN="/bin/uname"
        export SHA_BIN="/usr/bin/shasum"
        export SED_BIN="/bin/sed"
        export TAR_BIN="/bin/tar"
        export LOCKFILE_BIN="true"
        ;;


esac


DEFAULT_PAUSE_WHEN_LOCKED="30" # seconds
MAIN_SOURCE_REPOSITORY="http://software.verknowsys.com/source/"
MAIN_BINARY_REPOSITORY="http://software.verknowsys.com/binary/$(${UNAME_BIN})/common/"

CCACHE_BIN="${SOFTWARE_DIR}/Ccache/exports/ccache"

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
    ${PRINTF_BIN} "${2}${1}${reset}\n"
}


debug () {
    if [ "${DEBUG}" = "true" ]; then
        cecho " ~ $1" ${magenta}
    # else
        # cecho " ~ $1" ${magenta} >> ${LOG}
    fi
}


warn () {
    cecho " ! $1" ${yellow}
}


note () {
    cecho " * $1" ${green}
}


error () {
    cecho " # $1" ${red}
}


check_command_result () {
    if [ -z "$1" ]; then
        error "No param given for check_command_result()!"
        exit_locked 1
    fi
    if [ "$1" = "0" ]; then
        debug "CORRECT"
    else
        error
        error "FAILURE. Run $(${BASENAME_BIN} ${SCRIPT_NAME}) log to see what went wrong."
        exit_locked 1
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
            # note "Running on FreeBSD host"
            ;;

        Darwin)
            # note "Running on OSX/Darwin host"
            ;;

        Linux)
            ;;

        *)
            error "Currently only FreeBSD and Darwin hosts are supported."
            exit
            ;;

    esac
}

