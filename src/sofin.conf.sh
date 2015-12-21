# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)
#
# global Sofin values:
if [ "${DEBUG}" = "" ]; then
    export DEBUG="false"
fi
if [ "${SOFIN_TRACE}" = "" ]; then
    export SOFIN_TRACE="false"
fi

# setting up definitions repository
readonly DEFAULT_REPOSITORY="https://verknowsys@bitbucket.org/verknowsys/sofin-definitions.git" # official sofin definitions repository
# REPOSITORY is set after determining CACHE_DIR (L300)
# and branch used
if [ "${BRANCH}" = "" ]; then
    export BRANCH="stable"
fi

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

readonly DEBUG
readonly SOFIN_TRACE

readonly SOFIN_HEADER="Sofin v${VERSION} (c) 2o11-2o15 verknowsys.com"
readonly SOFIN_PROFILE="/etc/profile_sofin"
readonly SOFIN_DISABLED_INDICATOR_FILE="${HOME}/.sofin-disabled"
readonly SOFTWARE_ROOT_DIR="/Software/"
readonly SOFTWARE_DIR="/Software/"
readonly CACHE_DIR="${HOME}/.cache/"
readonly BINBUILDS_CACHE_DIR="${CACHE_DIR}binbuilds/"
readonly DEFINITIONS_DIR="${CACHE_DIR}definitions/definitions/"
readonly LOG="${CACHE_DIR}logs/sofin"
readonly LISTS_DIR="${CACHE_DIR}definitions/lists/"
readonly DEFAULTS="${DEFINITIONS_DIR}defaults.def"
readonly BINBUILDS_CACHE_DIR
readonly LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
readonly MAIN_PORT="60022"
readonly MAIN_USER="sofin"
readonly MAIN_SOFTWARE_PREFIX="/Mirror"
readonly MAIN_SOFTWARE_ADDRESS="software.verknowsys.com"
readonly MAIN_SOURCE_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/source/"
readonly MAIN_BINARY_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/binary/"
readonly CCACHE_BIN_OPTIONAL="${SOFTWARE_ROOT_DIR}Ccache/exports/ccache"
readonly DEFAULT_ID_OPTIONS="-un"
readonly DEFAULT_MANPATH="/usr/share/man"
readonly DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
readonly DEFAULT_ARCHIVE_EXT=".txz"
readonly DEPENDENCIES_FILE=".dependencies"
readonly INSTALLED_MARK=".installed"
readonly LOG_LINES_AMOUNT=250

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
UNZIP_BIN="/usr/bin/unzip"
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
FETCH_BIN="/usr/bin/fetch -T 3 -a"
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
SCP_BIN="/usr/bin/scp"
HOST_BIN="/usr/bin/host"
DIG_BIN="/usr/bin/dig"
XARGS_BIN="/usr/bin/xargs"
SOFIN_BIN="/usr/bin/sofin"
SOFIN_VERSION_UTILITY_BIN="/usr/bin/sofin-version-utility"
SOFIN_MICROSECONDS_UTILITY_BIN="/usr/bin/sofin-microseconds"
SOFIN_LIBBUNDLE_BIN="/usr/bin/sofin-dylibbundler"
GIT_BIN="/Software/Git/exports/git"
SSH_BIN="/usr/bin/ssh"
DIFF_BIN="/usr/bin/diff"
IFCONFIG_BIN="/sbin/ifconfig"
INSTALL_BIN="/usr/bin/install"
MKFIFO_BIN="/usr/bin/mkfifo"
PS_BIN="/bin/ps"

OS_VERSION=10
if [ -x "${SOFIN_VERSION_UTILITY_BIN}" ]; then
    export OS_VERSION="$(echo $(${SOFIN_VERSION_UTILITY_BIN}) | ${AWK_BIN} '{ gsub(/\./, ""); print $1; }' )"
    export FULL_SYSTEM_VERSION="$(${SOFIN_VERSION_UTILITY_BIN})"
fi
USERNAME="$(${ID_BIN} ${DEFAULT_ID_OPTIONS})"

TTY="false"
SUCCESS_CHAR="V"
WARN_CHAR="*"
NOTE_CHAR=">"
ERROR_CHAR="#"
NOTE_CHAR2="-"
if [ -t 1 ]; then
    TTY="true"
    SUCCESS_CHAR="√"
    WARN_CHAR="•"
    NOTE_CHAR="»"
    NOTE_CHAR2="→"
    ERROR_CHAR="✘"
fi
readonly TTY
readonly SUCCESS_CHAR
readonly WARN_CHAR
readonly NOTE_CHAR
readonly ERROR_CHAR


# common functions
# helpers

cecho () {
    if [ "${TTY}" = "true" ]; then # if it's terminal then use colors
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    else
        ${PRINTF_BIN} "${1}\n"
    fi
}


debug () {
    if [ "${DEBUG}" = "true" ]; then
        cecho "# $1" ${magenta} # NOTE: this "#" is required for debug mode to work properly with generation of ~/.profile and /etc/profile_sofin files!
    else
        cecho "# $1" ${magenta} >> ${LOG} 2>/dev/null
        # cecho " ~ $1" ${magenta} >> ${LOG}
    fi
}


warn () {
    cecho "$1" ${yellow}
}


note () {
    cecho "$1" ${green}
}


error () {
    cecho "${ERROR_CHAR} $1" ${red}
    exit 1
}


# System specific configuration
readonly SYSTEM_NAME="$(uname)"
readonly SYSTEM_ARCH="$(uname -m)"
DEFAULT_LDFLAGS="-fPIC -fPIE"
DEFAULT_COMPILER_FLAGS="-Os -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"

if [ ! -z "${DEBUGBUILD}" ]; then
    DEFAULT_COMPILER_FLAGS="-O0 -ggdb -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"
fi

case "${SYSTEM_NAME}" in

    FreeBSD)
        # Default
        readonly FREEBSD_MINIMUM_VERSION="91"
        export CPUS="$(${SYSCTL_BIN} kern.smp.cpus | ${AWK_BIN} '{printf $2}')"
        export CURL_BIN="/usr/bin/fetch -T 3 -o -"
        export MAKE_OPTS="-j${CPUS}"
        if [ ${OS_VERSION} -lt ${FREEBSD_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi

        if [ ${OS_VERSION} -gt 93 ]; then
            export DIG_BIN="/usr/bin/drill"
        fi
        export JAIL_BIN="/usr/sbin/jail"
        export JEXEC_BIN="/usr/sbin/jexec"
        export JLS_BIN="/usr/sbin/jls"
        export TRUSS_BIN="/usr/bin/truss"
        export MOUNT_BIN="/sbin/mount"
        export UMOUNT_BIN="/sbin/umount"
        export ROUTE_BIN="/sbin/route"
        export MOUNT_NULLFS="/sbin/mount_nullfs"
        export RCTL_BIN="/usr/bin/rctl"
        export CHSH_BIN="/usr/bin/chsh"
        export PW_BIN="/usr/sbin/pw"
        export CAP_MKDB_BIN="/usr/bin/cap_mkdb"
        export ZPOOL_BIN="/sbin/zpool"
        export ZFS_BIN="/sbin/zfs"
        export PFCTL_BIN="/sbin/pfctl"
        export DIALOG_BIN="/usr/bin/dialog"

        # XXX: disable ssl verification of https://github.com which fails on FreeBSD by default.
        if [ -x "${GIT_BIN}" ]; then
            ${GIT_BIN} config --global http.sslVerify false
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN})"
        ;;

    Darwin)
        # OSX specific configuration
        readonly DARWIN_MINIMUM_VERSION="124"
        export GIT_BIN="/usr/bin/git"
        export CURL_BIN="/usr/bin/curl"
        export FETCH_BIN="/usr/bin/curl --connect-timeout 3 -O"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export DEFAULT_LDFLAGS="-fPIC" # -arch x86_64 fPIE isn't well supported on OSX, but it's not production anyway
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all" # -arch x86_64
        if [ ! -z "${DEBUGBUILD}" ]; then
            export DEFAULT_COMPILER_FLAGS="-O0 -g -fPIC -fno-strict-overflow -fstack-protector-all"
        fi
        export SHA_BIN="/usr/bin/shasum"
        export SYSCTL_BIN="/usr/sbin/sysctl"
        export KLDLOAD_BIN="/sbin/kextload"
        export CPUS=$(${SYSCTL_BIN} machdep.cpu.thread_count | ${AWK_BIN} '{printf $2}')
        export MAKE_OPTS="-j${CPUS}"
        unset SERVICE_BIN # not necessary

        if [ ${OS_VERSION} -lt ${DARWIN_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN} | ${AWK_BIN} '{print $1}')"
        ;;

    Linux)
        # only Debian 6 is supported a.t.m.
        readonly GLIBC_MINIMUM_VERSION="211"
        export CURL_BIN="/usr/bin/wget -qO -"
        export FETCH_BIN="/usr/bin/wget -N --no-check-certificate"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export UNAME_BIN="/bin/uname"
        export KLDLOAD_BIN="/sbin/modprobe"
        export SHA_BIN="/usr/bin/sha1sum"
        export SED_BIN="/bin/sed"
        export TAR_BIN="/bin/tar"
        export GREP_BIN="/bin/grep"
        export EGREP_BIN="/bin/egrep"
        export BC_BIN="/usr/bin/bc"
        export CHOWN_BIN="/bin/chown"
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all"
        if [ ! -z "${DEBUGBUILD}" ]; then
            export DEFAULT_COMPILER_FLAGS="-O0 -ggdb -fPIC -fno-strict-overflow -fstack-protector-all"
        fi
        export DEFAULT_LDFLAGS="-fPIC "
        export TEST_BIN="/usr/bin/test"
        export NPROC_BIN="/usr/bin/nproc"
        export CPUS="$(${NPROC_BIN})"
        export MAKE_OPTS="-j${CPUS}"
        export AWK_BIN="/usr/bin/awk"
        if [ ${OS_VERSION} -lt ${GLIBC_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi
        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN} | ${AWK_BIN} '{print $1}')"
        ;;

esac

if [ ! -d "${CACHE_DIR}/logs" ]; then
    ${MKDIR_BIN} -p ${CACHE_DIR}/logs
fi

# last repository cache setup:
export REPOSITORY_CACHE_FILE="${CACHE_DIR}.last_repository.pos"
if [ "${REPOSITORY}" = "" ]; then # :this value is given by user as shell param
    ${MKDIR_BIN} -p "${CACHE_DIR}"
    if [ -f "${REPOSITORY_CACHE_FILE}" ]; then
        export REPOSITORY="$(${CAT_BIN} ${REPOSITORY_CACHE_FILE})"
    else
        ${PRINTF_BIN} "${DEFAULT_REPOSITORY}\n" > ${REPOSITORY_CACHE_FILE}
        export REPOSITORY="${DEFAULT_REPOSITORY}"
    fi
fi


check_command_result () {
    if [ -z "$1" ]; then
        error "No param given for check_command_result()!"
        exit 1
    fi
    if [ "$1" = "0" ]; then
        shift
        debug "Command successful: '$*'"
    else
        shift
        error "Command failure: '$*'. Run $(${BASENAME_BIN} ${SOFIN_BIN}) log to see what went wrong."
        exit 1
    fi
}


check_root () {
    if [ "$(id -u)" != "0" ]; then
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
            error "Currently only FreeBSD, Darwin and Debian hosts are supported."
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
