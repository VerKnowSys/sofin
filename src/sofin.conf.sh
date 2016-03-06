# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)
#

# Sofin version string:
readonly SOFIN_VERSION="0.98.8"

# setting up definitions repository
if [ -z "${BRANCH}" ]; then
    export BRANCH="stable"
fi
if [ -z "${REPOSITORY}" ]; then
    export REPOSITORY="https://verknowsys@bitbucket.org/verknowsys/sofin-definitions.git" # main sofin definitions repository
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

readonly SOFIN_HEADER="Sofin v${cyan}${SOFIN_VERSION} ${green}(c) 2o11-2o16 verknowsys.com"


distinct () {
    msg_type="${1}"
    shift
    content="$*"
    if [ -z "${msg_type}" ]; then
        error "No message type given as first param for: ${DISTINCT_COLOUR}distinct()${red}!"
    fi
    case ${msg_type} in
        n|note)
            printf "${DISTINCT_COLOUR}${content}${green}"
            ;;

        d|debug)
            printf "${DISTINCT_COLOUR}${content}${magenta}"
            ;;

        w|warn)
            printf "${DISTINCT_COLOUR}${content}${yellow}"
            ;;

        e|error)
            printf "${DISTINCT_COLOUR}${content}${red}"
            ;;

        *)
            printf "${msg_type}${content}${reset}"
            ;;
    esac
}
readonly SOFIN_PROFILE="/etc/profile_sofin"
readonly SOFIN_DISABLED_INDICATOR_FILE="${HOME}/.sofin-disabled"
readonly SERVICES_DIR="/Services/"
readonly SOFTWARE_DIR="/Software/"
readonly CACHE_DIR="${HOME}/.cache/"
readonly BINBUILDS_CACHE_DIR="${CACHE_DIR}binbuilds/"
readonly GIT_CACHE_DIR="${CACHE_DIR}git-cache/"
readonly DEFINITIONS_DIR="${CACHE_DIR}definitions/definitions/"
readonly LOGS_DIR="${CACHE_DIR}logs/"
readonly LOG="${LOGS_DIR}sofin"
readonly LISTS_DIR="${CACHE_DIR}definitions/lists/"
readonly DEFAULTS="${DEFINITIONS_DIR}defaults.def"
readonly LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
readonly MAIN_PORT="60022"
readonly MAIN_USER="sofin"
readonly MAIN_SOFTWARE_PREFIX="/Mirror"
readonly MAIN_SOFTWARE_ADDRESS="software.verknowsys.com"
readonly MAIN_SOURCE_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/source/"
readonly MAIN_BINARY_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/binary/"
readonly MAIN_COMMON_NAME="Common"
readonly CCACHE_BIN_OPTIONAL="${SOFTWARE_DIR}Ccache/exports/ccache"
readonly DEFAULT_ID_OPTIONS="-un"
readonly DEFAULT_MANPATH="/usr/share/man"
readonly DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
readonly DEFAULT_ARCHIVE_EXT=".txz"
readonly DEPENDENCIES_FILE=".dependencies"
readonly INSTALLED_MARK=".installed"
readonly LOG_LINES_AMOUNT=23
readonly LOG_LINES_AMOUNT_ON_ERR=37
readonly SERVICE_SNAPSHOT_POSTFIX="zfs-stream"
readonly PS_DEFAULT_OPTS="-axS"
readonly LESS_DEFAULT_OPTIONS="--hilite-search -K -N -M -R --follow-name -c"
readonly MOST_DEFAULT_OPTIONS="-c -s +s +u"

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
SOFIN_BIN="/usr/bin/s"
SOFIN_VERSION_UTILITY_BIN="/usr/bin/sofin-version-utility"
SOFIN_MICROSECONDS_UTILITY_BIN="/usr/bin/sofin-microseconds"
SOFIN_LIBBUNDLE_BIN="/usr/bin/sofin-dylibbundler"
ZSH_BIN="/Software/Zsh/exports/zsh"
GIT_BIN="/Software/Git/exports/git"
RSYNC_BIN="/Software/Rsync-static/exports/rsync"
MOST_BIN="/Software/Most/exports/most"
LESS_BIN="/usr/bin/less"
SYNC_BIN="/bin/sync"
SSH_BIN="/usr/bin/ssh"
DIFF_BIN="/usr/bin/diff"
IFCONFIG_BIN="/sbin/ifconfig"
INSTALL_BIN="/usr/bin/install"
MKFIFO_BIN="/usr/bin/mkfifo"
PS_BIN="/bin/ps"
DAEMON_BIN="/usr/bin/true"
STAT_BIN="/usr/bin/stat"
ZFS_BIN="/sbin/zfs"
XZ_BIN="/usr/bin/xz"
XZCAT_BIN="/usr/bin/xzcat"
SEQ_BIN="/usr/bin/seq"
CHFLAGS_BIN="/bin/chflags"
LOGGER_BIN="/usr/bin/logger"

OS_VERSION=10
if [ -x "${SOFIN_VERSION_UTILITY_BIN}" ]; then
    export OS_VERSION="$(echo $(${SOFIN_VERSION_UTILITY_BIN} 2>/dev/null) | ${AWK_BIN} '{ gsub(/\./, ""); print $1; }' 2>/dev/null)"
    export FULL_SYSTEM_VERSION="$(${SOFIN_VERSION_UTILITY_BIN} 2>/dev/null)"
fi
USERNAME="$(${ID_BIN} ${DEFAULT_ID_OPTIONS} 2>/dev/null)"

TTY="NO"
SUCCESS_CHAR="V"
WARN_CHAR="*"
NOTE_CHAR=">"
ERROR_CHAR="#"
NOTE_CHAR2="-"
if [ -t 1 ]; then
    TTY="YES"
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
readonly SEPARATOR="_________________________________________________________"

umask 027 # default, and should be global. New files created with chmod: 750 by default.


# common functions
# helpers

cecho () {
    if [ "${TTY}" = "YES" ]; then # if it's terminal then use colors
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    else
        ${PRINTF_BIN} "${1}\n"
    fi
}


debug () {
    if [ -z "${DEBUG}" ]; then
        aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
        if [ ! -z "${aname}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}-${aname}" 2>&1
        elif [ -z "${aname}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}" 2>&1
        elif [ ! -d "${LOGS_DIR}" ]; then
            ${LOGGER_BIN} "# ${cyan} $1"
        fi
    else
        cecho "# $1" ${magenta} # NOTE: this "#" is required for debug mode to work properly with generation of ~/.profile and /etc/profile_sofin files!
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
export DEFAULT_ZPOOL="zroot"
export DEFAULT_LDFLAGS="-fPIC -fPIE"
export readonly SYSTEM_NAME="$(uname -s 2>/dev/null)"
export readonly SYSTEM_ARCH="$(uname -m 2>/dev/null)"
export readonly COMMON_SAFE_CC_FLAGS="-ffast-math -fno-strict-overflow -fstack-protector-all"

export CROSS_PLATFORM_COMPILER_FLAGS="-fPIC ${COMMON_SAFE_CC_FLAGS}"
if [ -z "${DEBUGBUILD}" ]; then
    export DEFAULT_COMPILER_FLAGS="-O2 -fPIE ${CROSS_PLATFORM_COMPILER_FLAGS}"
else
    export DEFAULT_COMPILER_FLAGS="-O0 -ggdb ${CROSS_PLATFORM_COMPILER_FLAGS}"
fi

case "${SYSTEM_NAME}" in

    FreeBSD)
        # Golden linker support:
        if [ -x "/usr/bin/ld.gold" -a -f "/usr/lib/LLVMgold.so" ]; then
            export CROSS_PLATFORM_COMPILER_FLAGS="-Wl,-fuse-ld=gold ${CROSS_PLATFORM_COMPILER_FLAGS}"
            export DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
        fi

        # Defaults:
        readonly FREEBSD_MINIMUM_VERSION="91"
        export CPUS="$(${SYSCTL_BIN} kern.smp.cpus 2>/dev/null | ${AWK_BIN} '{printf $2;}' 2>/dev/null)"
        export CURL_BIN="/usr/bin/fetch -T 3 -o -"
        export MAKE_OPTS="-j${CPUS}"
        if [ ${OS_VERSION} -lt ${FREEBSD_MINIMUM_VERSION} ]; then
            export USE_BINBUILD=NO
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
        export PFCTL_BIN="/sbin/pfctl"
        export DIALOG_BIN="/usr/bin/dialog"
        export DAEMON_BIN="/usr/sbin/daemon"

        # XXX: disable ssl verification of https://github.com which fails on FreeBSD by default.
        if [ -x "${GIT_BIN}" ]; then
            ${GIT_BIN} config --global http.sslVerify false
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN} 2>/dev/null)-$(${SOFIN_MICROSECONDS_UTILITY_BIN} 2>/dev/null)" | ${SHA_BIN} 2>/dev/null)"
        ;;

    Darwin)
        # OSX specific configuration
        readonly DARWIN_MINIMUM_VERSION="124"
        export GIT_BIN="/usr/bin/git"
        export CURL_BIN="/usr/bin/curl"
        export FETCH_BIN="/usr/bin/curl --connect-timeout 3 -O"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export DEFAULT_LDFLAGS="-fPIC" # -arch x86_64 fPIE isn't well supported on OSX, but it's not production anyway
        export DEFAULT_COMPILER_FLAGS="-w -O2 -fPIC ${COMMON_SAFE_CC_FLAGS}"
        if [ ! -z "${DEBUGBUILD}" ]; then
            export DEFAULT_COMPILER_FLAGS="-O0 -g -fPIC ${COMMON_SAFE_CC_FLAGS}"
        fi
        export SHA_BIN="/usr/bin/shasum"
        export SYSCTL_BIN="/usr/sbin/sysctl"
        export KLDLOAD_BIN="/sbin/kextload"
        export ZFS_BIN="/usr/bin/true"
        export RSYNC_BIN="/usr/bin/rsync"
        export CPUS=$(${SYSCTL_BIN} machdep.cpu.thread_count 2>/dev/null | ${AWK_BIN} '{printf $2;}' 2>/dev/null)
        export MAKE_OPTS="-j${CPUS}"
        export DEFAULT_ZPOOL="Projects"
        export XZ_BIN="/Software/Xz/exports/xz"
        export XZCAT_BIN="/bin/cat"
        unset SERVICE_BIN # not necessary

        if [ ${OS_VERSION} -lt ${DARWIN_MINIMUM_VERSION} ]; then
            export USE_BINBUILD=NO
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN} 2>/dev/null)-$(${SOFIN_MICROSECONDS_UTILITY_BIN} 2>/dev/null)" | ${SHA_BIN} 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
        ;;

    Linux)
        # only Debian 6 is supported a.t.m.
        readonly GLIBC_MINIMUM_VERSION="211"
        export CHFLAGS_BIN="/usr/bin/chattr"
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
        export DEFAULT_LDFLAGS="-fPIC"
        export DEFAULT_COMPILER_FLAGS="-w -O2 -fPIC -mno-avx -fno-strict-overflow -fstack-protector-all"
        if [ ! -z "${DEBUGBUILD}" ]; then
            export DEFAULT_COMPILER_FLAGS="-O0 -fPIC -mno-avx -ggdb -fno-strict-overflow -fstack-protector-all"
        fi
        # Golden linker support without LLVM plugin:
        if [ -x "/usr/bin/ld.gold" ]; then
            export CROSS_PLATFORM_COMPILER_FLAGS="-Wl,-fuse-ld=gold ${CROSS_PLATFORM_COMPILER_FLAGS}"
            export DEFAULT_COMPILER_FLAGS="${DEFAULT_COMPILER_FLAGS} -Wl,-fuse-ld=gold"
            export DEFAULT_LDFLAGS="${DEFAULT_LDFLAGS} -Wl,-fuse-ld=gold"
        fi
        export TEST_BIN="/usr/bin/test"
        export NPROC_BIN="/usr/bin/nproc"
        export CPUS="$(${NPROC_BIN} 2>/dev/null)"
        export MAKE_OPTS="-j${CPUS}"
        export AWK_BIN="/usr/bin/awk"
        export ZFS_BIN="/usr/sbin/zfs"
        export RSYNC_BIN="/Software/Rsync/exports/rsync"
        if [ ${OS_VERSION} -lt ${GLIBC_MINIMUM_VERSION} ]; then
            export USE_BINBUILD=NO
        fi
        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN} 2>/dev/null)-$(${SOFIN_MICROSECONDS_UTILITY_BIN} 2>/dev/null)" | ${SHA_BIN} 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
        ;;

esac


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
        error "Command failure: '$*'. Run ${cyan}$(${BASENAME_BIN} ${SOFIN_BIN} 2>/dev/null) log your-def${red}, to see what went wrong"
        exit 1


os_tripple () {
    ${PRINTF_BIN} "${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
}


def_error () {
    if [ -z "${2}" ]; then
        error "Failed action for: $(distinct e $1). Report it if necessary on: $(distinct e "${DEFAULT_ISSUE_REPORT_SITE}") or fix definition please!"
    else
        error "${2}. Report it if necessary on: $(distinct e "${DEFAULT_ISSUE_REPORT_SITE}") or fix definition please!"
    fi
}


file_checksum () {
    name="$1"
    if [ -z "${name}" ]; then
        error "Empty file name given for function: $(distinct e "file_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Darwin|Linux)
            ${PRINTF_BIN} "$(${SHA_BIN} "${name}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
            ;;

        FreeBSD)
            ${PRINTF_BIN} "$(${SHA_BIN} -q "${name}" 2>/dev/null)"
            ;;
    esac
}


fill () {
    _char="${1}"
    if [ -z "${_char}" ]; then
        _char="${SEPARATOR_CHAR}"
    fi
    _times=${2}
    if [ -z "${_times}" ]; then
        _times=80
    fi
    _buf=""
    for i in $(${SEQ_BIN} 1 ${_times} 2>/dev/null); do
        _buf="${_buf}${_char}"
    done
    ${PRINTF_BIN} "${_buf}"
    unset _times _buf
}


sofin_processes () {
    ${PS_BIN} ${PS_DEFAULT_OPTS} 2>/dev/null | ${EGREP_BIN} -v "(grep|$$)" 2>/dev/null
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
    env | ${GREP_BIN} '_BIN=/' 2>/dev/null | while IFS= read -r envvar
    do
        var_value="$(${PRINTF_BIN} "${envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1;}' 2>/dev/null)"
        if [ ! -x "${var_value}" ]; then
            error "Required binary is unavailable: ${cyan}${envvar}"
            exit 1
        fi
    done || exit 1
}
