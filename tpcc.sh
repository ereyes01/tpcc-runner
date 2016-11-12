#!/bin/bash

set -e

# authenticate with sudo to get password prompts out of the way
sudo true

echo "Cleaning up old DB container"
sudo docker kill tpcc-db || true
sudo docker rm -v tpcc-db || true

echo "Starting MySQL container..."
sudo docker run --name tpcc-db -e MYSQL_ROOT_PASSWORD=tpcc-pw -e MYSQL_DATABASE=tpcc -d -P mysql:8

echo Waiting for DB to fully start up...
while ! sudo docker exec -i tpcc-db /usr/bin/mysql -h localhost -P 3306 -uroot -ptpcc-pw -D tpcc <<<$(echo "show databases;") >/dev/null; do
    sleep 30
done

echo "Creating tables / adding indexes..."
sudo docker run --rm gaishimo/tpcc-mysql sh -c 'cat create_table.sql add_fkey_idx.sql' | \
    sudo docker exec -i tpcc-db sh -c '/usr/bin/mysql -h localhost -P 3306 -uroot -ptpcc-pw -D tpcc'

echo "Loading test data"
sudo docker run -it --rm --link tpcc-db:mysql gaishimo/tpcc-mysql tpcc_load tpcc root 'tpcc-pw' 50

echo "Generating test container name..."
NAME="tpcc-run-"$(date | md5sum | awk '{print substr($1, 0, 4)}')

echo "Starting the test..."
sudo docker run -d --name $NAME --link tpcc-db:mysql gaishimo/tpcc-mysql tpcc_start -d tpcc -u root -p tpcc-pw -w 50 -c 10 -r $((20*60)) -l $((8*60*60))

cat <<EOF



The test has been started. It will take over 8 hours to run.

To view all of the output, including the result when it is finished:

  sudo docker logs $NAME

To view the lastest output printed in real time as the test is running:

  sudo docker logs -f --since 1m $NAME
EOF
