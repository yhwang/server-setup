#!bin/bash

echo "$PS1" | grep '{cassandra} ' -q

if [ "$?" != "0" ]; then
    PS1="{cassandra} $PS1"
    export PERF_ENV=cassandra
    export DB_SERVERS=1.1.1.1,2.2.2.2,3.3.3.3
    export INDEX_SERVERS=
    export JANUSGRAPH_SERVERS=4.4.4.4
    export INJECTOR=5.5.5.5
    export SERVER_LOGS=/var/log/cassandra
    export SERVER_CONFS=/etc/cassandra
    export USER=perf

    . perf.sh
fi


