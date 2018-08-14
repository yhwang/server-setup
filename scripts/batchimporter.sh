#!/bin/bash
pushd . > /dev/null
sDir=$(dirname "$0")
cd "${sDir}"
sDir=$(pwd -P)
popd > /dev/null

if [[ -z "$DB_SERVERS" || -z "$PERF_ENV" ]]; then
    echo "please active environment first. i.e. 'source env-scylla.sh'"
    exit 1
fi

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <DBSize> <JanusgraphConfig> <ResultDir> <RunType>"
  exit 1
fi

DATA_SET="$1"
CSVDIR="$sDir"/csv-data/"$DATA_SET"
shift

CONF="$1"
shift

RESULTDIR="$1"
shift

RUNTYPE="$1"
shift
RESULTDIR=$RESULTDIR/$RUNTYPE

if [[ ! -d $RESULTDIR ]]; then
 echo "Created $RESULTDIR result directory"
 mkdir -p "$RESULTDIR"
fi

SCHEMA="$CSVDIR"/schema.json
DATAMAPPER="$CSVDIR"/datamapper.json

NMONDATE=$(date +%y%m%d"_"%H%M%S)
AVG_INT=10
COUNT=8640
echo "$NMONDATE" > "$RESULTDIR"/nmon_datetmp.txt

stop_nmon "$DB_SERVERS"
stop_nmon "$INDEX_SERVERS"
stop_nmon "$JANUSGRAPH_SERVERS"

echo "Starting nmon on all nodes with average interval $AVG_INT and sample count $COUNT:"
start_nmon "$DB_SERVERS" "$NMONDATE" "$AVG_INT" "$COUNT"
start_nmon "$INDEX_SERVERS" "$NMONDATE" "$AVG_INT" "$COUNT"
start_nmon "$JANUSGRAPH_SERVERS" "$NMONDATE" "$AVG_INT" "$COUNT"

sleep 10

echo "Importing. To see the output, run tail -f $RESULTDIR/$DATA_SET.out"

# copy conf to injector
scp "$CONF" "$USER"@"$INJECTOR":/home/"$USER"/janusgraph.conf
ssh "$USER"@"$INJECTOR" "export JANUSGRAPH_HOME=/home/$USER/janusgraph; /home/$USER/janusgraph-utils/run.sh loadsch /home/$USER/janusgraph.conf $SCHEMA"
ssh "$USER"@"$INJECTOR" "export JANUSGRAPH_HOME=/home/$USER/janusgraph; /home/$USER/janusgraph-utils/run.sh import /home/$USER/janusgraph.conf $CSVDIR $SCHEMA $CSVDIR/datamapper.json skipSchema" 2>&1 | tee $RESULTDIR/$DATA_SET.out

sleep 10

stop_nmon "$DB_SERVERS"
stop_nmon "$INDEX_SERVERS"
stop_nmon "$JANUSGRAPH_SERVERS"

collect_nmon "$DB_SERVERS" "$NMONDATE"
collect_nmon "$INDEX_SERVERS" "$NMONDATE"
collect_nmon "$JANUSGRAPH_SERVERS" "$NMONDATE"

cp "$CSVDIR"/*.json "$RESULTDIR"/
cp "$CONF" "$RESULTDIR"/
 

get_db_data "$DB_SERVERS"

