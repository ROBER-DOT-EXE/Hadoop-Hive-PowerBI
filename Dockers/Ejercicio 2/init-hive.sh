#!/bin/bash
set -e

# Wait for MySQL to be ready
until nc -z -v -w30 mysql 3306
do
  echo "Waiting for MySQL database connection..."
  sleep 5
done

# Initialize schema
echo "Initializing Hive Metastore schema..."
$HIVE_HOME/bin/schematool -dbType mysql -initSchema --verbose

echo "Schema initialization completed"