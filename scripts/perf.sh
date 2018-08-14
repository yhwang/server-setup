#!/bin/bash

deactivate() {
    PS1=${PS1//'{'"$PERF_ENV"'} '/}
    unset PERF_ENV
    unset DB_SERVERS
    unset INDEX_SERVERS
    unset JANUSGRAPH_SERVERS
    unset SERVER_LOGS
    unset SERVER_CONFS
    unset INJECTOR
    unset USER

    unset -f deactivate
    unset -f get_db_data
    unset -f start_nmon
    unset -f stop_nmon
    unset -f collect_nmon
    unset -f showSettings
}

get_db_data() {
    IFS=', ' read -r -a array <<< "$DB_SERVERS"
    for host in "${array[@]}"; do
        echo "collect db config and log files from $host"
        ssh "$USER"@"$host" "tar zcf /tmp/db-""${host}"".tgz $SERVER_CONFS $SERVER_LOGS"
        scp "$USER"@"$host":/tmp/db-"$host".tgz "$RESULTDIR"/
    done
}

#START nmon
start_nmon() {

    if [[ $# -ne 4 ]]; then
        echo "usage: start_nmon <server1[,server2...]> <dateStr> <interval> <count>"
        return
    fi

    SERVERS="$1"
    shift
    DATE="$1"
    shift
    AVG_INT="$1"
    shift
    COUNT="$1"
    shift

    IFS=', ' read -r -a array <<< "$SERVERS"
    for host in "${array[@]}"; do
        echo "start nmon on $host"
        ssh "$USER"@"$host" "if [ ! -d /tmp ]; then echo "directory /tmp does not exit. Creating..";mkdir -p /tmp;fi"
        ssh "$USER"@"$host" nmon -F /tmp/"${host}"."${DATE}".nmon -s "${AVG_INT}" -c "${COUNT}" -T -p -I 5
    done
}

stop_nmon() {

    if [[ $# -ne 1 ]]; then
        echo "usage: stop_nmon <server1[,server2...]>"
        return
    fi

    SERVERS="$1"
    shift

    IFS=', ' read -r -a array <<< "$SERVERS"
    for host in "${array[@]}"; do
        echo "stop nmon on $host"
        ssh "$USER"@"$host" "killall nmon" >/dev/null 2>&1
    done
}

collect_nmon() {

    if [[ $# -ne 2 ]]; then
        echo "usage: collect_nmon <server1[,server2...]> <dateStr>"
        return
    fi

    SERVERS="$1"
    shift
    DATE="$1"
    shift

    IFS=', ' read -r -a array <<< "$SERVERS"
    for host in "${array[@]}"; do
        echo "collect nmon on $host"
        scp "$USER"@"$host":/tmp/"${host}"."${DATE}".nmon "${RESULTDIR}"
    done
}

showSettings() {
    echo "USER:${USER}"
    echo "DB_SERVERS:${DB_SERVERS}"
    echo "INDEX_SERVERS:${INDEX_SERVERS}"
    echo "JANUSGRAPH_SERVERS:${JANUSGRAPH_SERVERS}"
    echo "INJECTOR:${INJECTOR}"
}

export -f get_db_data
export -f start_nmon
export -f stop_nmon
export -f collect_nmon
export -f showSettings

showSettings
