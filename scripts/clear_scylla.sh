#!/bin/bash

IFS=', ' read -r -a array <<< "$DB_SERVERS"

for host in "${array[@]}"; do
    echo "stop and cleanup scylla database on $host"
    ssh "$USER"@"$host" "sudo systemctl stop scylla-server && sudo rm -rf /database/scylla/data/* && sudo rm -rf /database/scylla/commitlog/* && sudo rm -rf /database/scylla/saved_caches/*"
done

nonseednode=0
for host in "${array[@]}"; do
    case $nonseednode in
    0)
        nonseednode=1
        # Start the first node and use auto_bootstrap=false
        ssh "$USER"@"$host" "sudo grep -q 'auto_bootstrap' /etc/scylla/scylla.yaml ; if [[ \"\$?\" == \"0\" ]]; then sudo sed -E \"s/auto_bootstrap.*$/auto_bootstrap: false/\" -i.bak /etc/scylla/scylla.yaml; else sudo bash -c \"echo 'auto_bootstrap: false' >> /etc/scylla/scylla.yaml\"; fi"
        echo "starting scylla database on $host"
        ssh "$USER"@"$host" 'sudo systemctl start scylla-server'

        sed -E 's/^storage\.hostname=.*$/storage\.hostname='"$host"'/' /home/"$USER"/scripts/janusgraph-astyanax.properties > /tmp/scylla.properties
        echo "wait 60 seconds until the first node to be fully ready"
        sleep 60
        ;;
    1)
        echo "starting scylla database on $host"
        ssh "$USER"@"$host" 'sudo systemctl start scylla-server'
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
cd /home/"$USER"/janusgraph/; echo "JanusGraphFactory.open('/tmp/scylla.properties');" | bin/gremlin.sh
popd > /dev/null

echo "done"
