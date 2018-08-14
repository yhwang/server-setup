#!/bin/bash

IFS=', ' read -r -a array <<< "$DB_SERVERS"

for host in "${array[@]}"; do
    echo "stop and cleanup cassandra database on $host"
    ssh "$USER"@"$host" "sudo systemctl stop cassandra && sudo rm -rf /database/cassandra/data/* && sudo rm -rf /database/cassandra/commitlog/* && sudo rm -rf /database/cassandra/saved_caches/*"
done

nonseednode=0
for host in "${array[@]}"; do
    case $nonseednode in
    0)
        nonseednode=1
        # Start the first node and use auto_bootstrap=false
        ssh "$USER"@"$host" "sudo grep -q 'auto_bootstrap' /etc/cassandra/cassandra.yaml ; if [[ \"\$?\" == \"0\" ]]; then sudo sed -E \"s/auto_bootstrap.*$/auto_bootstrap: false/\" -i.bak /etc/cassandra/cassandra.yaml; else sudo bash -c \"echo 'auto_bootstrap: false' >> /etc/cassandra/cassandra.yaml\"; fi"
        echo "starting cassandra database on $host"
        ssh "$USER"@"$host" "sudo systemctl start cassandra"

        sed -E 's/^storage\.hostname=.*$/storage\.hostname='"$host"'/' /home/"$USER"/scripts/janusgraph-cql.properties > /tmp/cassandra.properties
        echo "wait 60 seconds until the first node to be fully ready"
        sleep 60
        ;;
    1)
        echo "starting cassandra database on $host"
        ssh "$USER"@"$host" "sudo systemctl start cassandra"
        ;;
    esac

done

if [[ ${#array[@]} -gt 1 ]]; then
    nonseednum=$((${#array[@]} - 1))
    waittime=$((45*nonseednum))
    echo "wait $waittime seconds for node join"
    sleep $waittime
fi

# Use gremlin console to connect to the database and create the schema and tables
pushd . > /dev/null
cd /home/"$USER"/janusgraph/; echo "JanusGraphFactory.open('/tmp/cassandra.properties');" | bin/gremlin.sh
popd > /dev/null

echo "done"
