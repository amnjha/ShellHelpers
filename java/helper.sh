# Always have clean start. 
# **Nothing is better than Unknown**
# @author: amanjha22@gmail.com

unset JAVA_HOME
unset JAVA_JMX
unset JAVA_GC_TUNE
unset JAVA_FILE_ENC
unset JAVA_HEAP_MEM
unset JAVA_PGEN_MEM
unset JAVA_OPTS

# usage: log <MSG>
function log () {
    local MSG
    MSG="$(date '+[%d.%m.%Y %H.%M.%S %Z]')[${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}] $*"

    echo "$MSG"

    [[ -f "$CRMS_SCRIPTS_LOG" && -w "$CRMS_SCRIPTS_LOG" ]] && echo "$MSG" >> "$CRMS_SCRIPTS_LOG"

    return 0
}

# Usage: abort <MSG>
function abort () {
    log "$*"

    if [[ $RB_SCRIPT_DEBUG == 1 ]]; then
        log "----------------------------------------"
        local frame=0
        local funcn
        while funcn="$(caller $frame)"; do
            log "trace: $funcn"
            ((frame++));
        done
        log "----------------------------------------"
    fi

    log "Exiting..."
log "=========================================="
    exit 1
}

# usage: abort_on_failure <msg>
function abort_on_failure () {
    local returnCode="$?"

    [[ "$returnCode" != "0" ]] && abort "Error: ${1:-"Process failed, Error code: '$returnCode'"}"
}

# usage: abort_on_empty <var> <msg>
function abort_on_empty () {
    [[ "x$1" = "x" ]] && abort "Error: ${2:-"Missing/Empty '$1'"}"
}

# usage: abort_on_not_rw <path> <msg>
function abort_on_not_rw () {
    [[ ! -r "$1" || ! -w "$1" ]] && abort "Error: ${2:-"Not readable/writable '$1'"}"
}

# usage: abort_on_not_exec <path> <msg>
function abort_on_not_exec () {
    [[ ! -x "$1" ]] && abort "Error: ${2:-"Not executable '$1'"}"
}

# usage: abort_on_not_dir <path> <msg>
function abort_on_not_dir () {
    [[ ! -d "$1" ]] && abort "Error: ${2:-"Not directory '$1'"}"
}

# usage: abort_on_invalid_ip <ip-string>
function abort_on_invalid_ip () {
    if [[ ! "$1" =~ ([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5]) ]]; then
        abort "Error: ${2:-"Invalid IPv4 address '$1'"}"
    fi
}

# usage: abort_on_invalid_int <ip-string>
function abort_on_invalid_int () {
    [[ ! "$1" =~ ^[0-9]+$ ]] && abort "Error: ${2:-"Invalid number '$1'"}"
}

# usage: abort_on_malformed_url <url-string>
function abort_on_malformed_url(){
    regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    if [[ ! $1 =~ $regex ]]; then
        abort "Error: ${2:-"Malformed URL '$1'"}"
    fi
}

# usage: abort_on_invalid_java <version>
function abort_on_invalid_java () {
    abort_on_not_dir "$JAVA_HOME" "Java Home not set"

    abort_on_not_exec "$JAVA_HOME/bin/java" "Invalid Java found: '$JAVA_HOME/bin/java'"

    local javaVersion
    javaVersion=$("$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')

    [[ $javaVersion != $1* ]] && abort "Java version not matched: '$javaVersion', required '$1'"
}

# usage: read_property_file <filepath> [<key-prefix>]; read property file and set variable in environment.
function read_property_file () {
    local PROP_REGEX="^[[:blank:]]*([a-zA-Z0-9_]+)[[:blank:]]*=[[:blank:]]*(.+[[:graph:]])[[:blank:]]*$"

    abort_on_not_rw "$1" "Can't read source properties file: '$1'"

    dos2unix "$1" > /dev/null 2>&1 || abort "Can't dos2unix on file '$1'"

    if [[ "x$2" != "x" ]]; then
        local _PREFIX_="$2"
    else
        local _PREFIX_=""
    fi

    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        if [[ "$LINE" =~ $PROP_REGEX ]]; then
            eval "${_PREFIX_}${BASH_REMATCH[1]}='${BASH_REMATCH[2]}'"
        fi
    done < "$1"

    return 0
}

# usage: read_props <filepath> [<key-prefix>];   
# Changes . seperated keys to _ seperated, the previous function fails to read . separated values as you cannot export . separtated values on *nix
function read_property_file_containing_dots(){
    local PROP_REGEX="^[[:blank:]]*([a-zA-Z0-9_.]+)[[:blank:]]*=[[:blank:]]*(.+[[:graph:]])[[:blank:]]*$"

    abort_on_not_rw "$1" "Can't read source properties file: '$1'"

    dos2unix "$1" > /dev/null 2>&1 || abort "Can't dos2unix on file '$1'"

    if [[ "x$2" != "x" ]]; then
        local _PREFIX_="$2"
    else
        local _PREFIX_=""
    fi

    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        if [[ "$LINE" =~ $PROP_REGEX ]]; then
            key=$(echo ${BASH_REMATCH[1]} | tr '.' '_')
            eval "${_PREFIX_}$key='${BASH_REMATCH[2]}'"
        fi
    done < "$1"

    return 0
}

# usage: copy_properties <src-file> <dst-file> <skip-keys>
function copy_properties () {
    local "SRC=$1"
    local "DST=$2"
    local "SKIP=$3"

    abort_on_not_rw "$SRC" "Can't read properties file: '$SRC'"
    abort_on_not_rw "$DST" "Can't read properties file: '$DST'"

    dos2unix "$SRC" "$DST" > /dev/null 2>&1 || abort "Can't dos2unix on file '$SRC' or '$DST'"

    local PROP_REGEX="^[[:blank:]]*([a-zA-Z0-9_]+)[[:blank:]]*=[[:blank:]]*(.+[[:graph:]])[[:blank:]]*$"
    local PROP_REGEX_IGNORE_VALUE="^[[:blank:]]*([a-zA-Z0-9_]+)[[:blank:]]*=.*$"

    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        if [[ "$LINE" =~ $PROP_REGEX ]]; then
            local "src_${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
        fi
    done < "$SRC"

    if [[ -f "${DST}_" ]]; then
        rm -rf "${DST}_" || abort "Can't remove '${DST}_'"
    fi

    touch "${DST}_" || abort "Can't create '${DST}_'"

    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        if [[ "$LINE" =~ $PROP_REGEX_IGNORE_VALUE && $SKIP != *"${BASH_REMATCH[1]}"* ]]; then
            local KEY="src_${BASH_REMATCH[1]}"
            if [[ "x${!KEY}" != "x" ]]; then
                echo "${BASH_REMATCH[1]} = ${!KEY}" >> "${DST}_"
                continue
            fi
        fi
        echo "$LINE" >> "${DST}_"
    done < "$DST"

    mv -f "${DST}_" "$DST" || abort "Can't move '${DST}_' to '${DST}'"

    return 0
}

# usage: start_process <base-dir> <cmdline> <logfile>
function start_process () {
    local BASEDIR="$1"
    local CMDLINE="$2"
    local LOGFILE="$3"

    abort_on_empty "$CMDLINE" "Start process, Empty CMDLINE"
    abort_on_not_dir "$BASEDIR" "Start process, Invalid BASEDIR: '$BASEDIR'"

    local PID_FILE="$BASEDIR/pid"

    if [[ -f "$PID_FILE" ]]; then
        PID="$(cat "$PID_FILE")"

        if [[ "x$PID" != "x" ]]; then
            if ps -p "$PID" >/dev/null 2>&1; then
                log "Previous process is still running with PID '$PID', Start aborted"
                ps -f -p "$PID"
                exit 1
            fi
        fi

        log "Removing PID file '$PID_FILE'"

        rm -rf "$PID_FILE" || abort "Failed to remove PID file: '$PID_FILE'"
    fi

    local PREVDIR="$PWD"

    cd "$BASEDIR" || abort "Failed to CD into '$BASEDIR', Current directory: '$PWD'"

    touch "$LOGFILE" || abort "Failed to create new '$LOGFILE'"

    eval "$CMDLINE" >> "$LOGFILE" 2>&1 "&" || abort "Process '$CMDLINE' failed to start"

    echo $! > "$PID_FILE"

    log "Process started with PID: '$(cat "$PID_FILE")'"

    cd "$PREVDIR" || abort "Failed to CD into '$PREVDIR', Current directory: '$PWD'"

    return 0
}

# usage: stop_process <base-dir> [<wait-time>]
function stop_process () {
    local BASEDIR="$1"
    local WAITSEC="$2"

    abort_on_not_dir "$BASEDIR" "Start process, Invalid BASEDIR: '$BASEDIR'"

    [[ "x$WAITSEC" = "x" ]] && WAITSEC=20

    local PID_FILE="$BASEDIR/pid"

    if [[ -f "$PID_FILE" ]]; then
        local PID
        PID="$(cat "$PID_FILE")"

        if [[ "x$PID" != "x" ]]; then
            if ps -p "$PID" >/dev/null 2>&1; then
                kill -SIGTERM "$PID" >/dev/null 2>&1

                for (( counter = 0; counter < WAITSEC; counter++ )); do
                    if ps -p "$PID" >/dev/null 2>&1; then
                        sleep 1
                        echo "Waiting ${counter} seconds.."
                    else
                        break
                    fi
                done

                if ps -p "$PID" >/dev/null 2>&1; then
                    log "Waited ${WAITSEC}s for process '$PID' to finish but its still running, abort.."
                    exit 1
                fi
            else
                log "Process not found with PID '$PID': '$PID_FILE'"
            fi
        else
            log "Missing PID: '$PID_FILE'"
        fi

        log "Removing PID file '$PID_FILE'"

        rm -rf "$PID_FILE" || abort "Failed to remove PID file: '$PID_FILE'"
    else
        log "PID file not found: $PID_FILE"
    fi

    return 0
}

# Usage: start_java <jar-file> <appln-options> <base-dir> <log-file> <jmx-host> <jmx-port>
function start_java () {
    local jarFile="$1"
    local applnOptions="$2"
    local baseDir="$3"
    local logFile="$4"
    local jmxHost="$5"
    local jmxPort="$6"

    abort_on_empty "$jarFile" "Jar file path not provided"

    [[ "x$baseDir" = "x" ]] && baseDir="$PWD"
    [[ "x$logFile" = "x" ]] && logFile="$baseDir/out.log"

    # java path
    local runJava="$JAVA_HOME/bin/java"

    # create new temp directory every time
    local javaTempDir="$baseDir/temp"
    if [[ -e "$javaTempDir" ]]; then
        rm -rf "$javaTempDir" || abort "Failed to delete java.io.tmpdir: '$javaTempDir'"
    fi
    mkdir -p "$javaTempDir" || abort "Failed to create java.io.tmpdir: '$javaTempDir'"

    local javaJmxOptions=""
    if [[ "x$jmxPort" != "x" && "x$jmxHost" != "x" ]]; then
        javaJmxOptions="-Dcom.sun.management.jmxremote \
                -Djava.rmi.server.hostname=${jmxHost} \
                -Dcom.sun.management.jmxremote.port=${jmxPort} \
                -Dcom.sun.management.jmxremote.rmi.port=${jmxPort} \
                -Dcom.sun.management.jmxremote.local.only=false \
                -Dcom.sun.management.jmxremote.authenticate=false \
                -Dcom.sun.management.jmxremote.ssl=false"
    elif [[ "x$JAVA_JMX" != "x" ]]; then
        javaJmxOptions="$JAVA_JMX"
    fi

    local javaGCTune=""
    if [[ "x$JAVA_GC_TUNE" != "x" ]]; then
        javaGCTune="$JAVA_GC_TUNE"
    else
        javaGCTune="-XX:+UseConcMarkSweepGC \
            -XX:+CMSClassUnloadingEnabled -XX:+UseCMSInitiatingOccupancyOnly \
            -XX:CMSInitiatingOccupancyFraction=75 -XX:+ScavengeBeforeFullGC \
            -XX:+CMSScavengeBeforeRemark"
    fi

    local javaFileEnc="UTF-8"
    if [[ "x$JAVA_FILE_ENC" != "x" ]]; then
        javaFileEnc="$JAVA_FILE_ENC"
    fi

    local javaHeapMem="2g"
    if [[ "x$JAVA_HEAP_MEM" != "x" ]]; then
        javaHeapMem="$JAVA_HEAP_MEM"
    fi

    local javaPGenMem="256m"
    if [[ "x$JAVA_PGEN_MEM" != "x" ]]; then
        javaPGenMem="$JAVA_PGEN_MEM"
    fi

    local javaTimeZone="IST"
    if [[ "x$JAVA_TIMEZONE" != "x" ]]; then
        javaTimeZone="$JAVA_TIMEZONE"
    fi

    local javaOptions="$JAVA_OPTS $javaGCTune $javaJmxOptions -Dfile.encoding=$javaFileEnc \
        -Xms$javaHeapMem -Xmx$javaHeapMem \
        -XX:PermSize=$javaPGenMem -XX:MaxPermSize=$javaPGenMem \
        -Djava.io.tmpdir=\"$javaTempDir\" -Duser.timezone=\"$javaTimeZone\""

    local cmdLine="\"$runJava\" $javaOptions -jar \"$jarFile\" $applnOptions"

    start_process "$baseDir" "$cmdLine" "$logFile"

    return 0
}

# usage: wait_for_http_server <HOST> <PORT> <WAIT-TIME>
function wait_for_http_server () {
    local aHost="$1"
    local aPort="$2"
    local waitTime="$3"

    for (( currentTime = 0; currentTime < waitTime; currentTime++ )); do
        if timeout 1 bash -c "cat < /dev/null 2>/dev/null >/dev/tcp/${aHost}/${aPort}"; then
            break
        fi

        sleep 1
        echo "Waiting ${currentTime} seconds for server at ${aHost}:${aPort} to start.."
    done

    if timeout 1 bash -c "cat < /dev/null 2>/dev/null >/dev/tcp/${aHost}/${aPort}"; then
        log "Server started at ${aHost}:${aPort}"
    else
        abort "Server not detected at ${aHost}:${aPort} after ${waitTime} seconds"
    fi

    return 0
}

# usage: get_current_machine_ip ; read machine_ip and set variable in environment
function get_current_machine_ip(){
    export machine_ip="$(hostname -I)"
}

# usage: get_property_value <property-name> <property-file-path>
function get_property_value(){
    prop_value=`sed '/^\#/d' $2 | grep $1  | tail -n 1 | cut -d "=" -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`
    echo $prop_value
}

# usage: replace_value_for_key <key> <value> <file-path>
function replace_value_by_key(){
    awk -v pat="^$1=" -v value="$1=$2" '{ if ($0 ~ pat) print value; else print $0; }' $3 > $3.tmp
    mv $3.tmp $3
}

# usage: replace_value_by_placeholder <place-holder> <value> <file-path>
function replace_value_by_placeholder(){
    sed -i 's|'$1'|'$2'|g' $3
}

function remove_prefix_suffix(){
    string=$1
    prefix=$2
    suffix=$3
    value=${string#$prefix}
    value=${value%$suffix}
    echo -n "$value"
}

#usage: trim <variable>
function trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}
