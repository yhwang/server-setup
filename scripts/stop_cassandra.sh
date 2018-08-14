#!/bin/bash

IFS=', ' read -r -a array <<< "$DB_SERVERS"

for host in "${array[@]}"; do
    echo "stop and cleanup cassandra database on $host"
    ssh "$USER"@"$host" "sudo systemctl stop cassandra && sudo rm -rf /database/cassandra/data/* && sudo rm -rf /database/cassandra/commitlog/* && sudo rm -rf /database/cassandra/saved_caches/*"
done


