#!/bin/bash

resource_group_name=""
storage_account_name=""
snapshot_name="backup-$(date +'%Y-%m-%d')"
backup_location="/home/ubuntu/mysql-${snapshot_name}.sql.gz"

# Settings for the Elasticsearch repository
elastic_repo_settings=$(
cat <<SETTINGS
{
  "type": "azure",
  "settings": {
    "container": "backups",
    "base_path": "elasticsearch",
    "client": "default"
  }
}
SETTINGS
)

# Settings for mysqldump
mysql_dump_settings=$(
cat <<MYSQLDUMP
[client]
host=dataguard-mysql
user=root
password=bloxtest
MYSQLDUMP
)

# Login from Analysis VM
az login --identity

# Get storage accounts access keys
storage_account_key=$(az storage account keys list --resource-group $resource_group_name --account-name $storage_account_name --query "[0].value" --output tsv)

# Check if backup container exists
container_exists=$(az storage container exists --name backups --account-key $storage_account_key --account-name $storage_account_name --query "exists")

if [ "$container_exists" == "false" ]; then
  echo "Backup container not found in storage account, creating..."
  az storage container create --name backups --account-key $storage_account_key --account-name $storage_account_name
else
  echo "Backup container found in storage account."
fi

# Will return 200 if repo exists, 404 if it doesn't
elastic_repo_check=$(/usr/bin/docker exec dataguard-sidecar /usr/bin/curl -s -o /dev/null -w "%{http_code}" dataguard-elasticsearch:9200/_snapshot/dataguard_repository)

# If repo not found, create it
if [[ $elastic_repo_check == 404 ]]; then
  echo "repo not found, attempting to create"
  /usr/bin/docker exec dataguard-sidecar /usr/bin/curl -XPUT dataguard-elasticsearch:9200/_snapshot/dataguard_repository -d"${elastic_repo_settings}" --header 'Content-Type: application/json'

  # Create symbolic link for java to interact with elasticsearch-keystore
  /usr/bin/docker exec dataguard-elasticsearch sh -c "mkdir -p /usr/share/elasticsearch/jdk/bin/"
  /usr/bin/docker exec dataguard-elasticsearch sh -c "ln -s /usr/bin/java /usr/share/elasticsearch/jdk/bin/java"

  # Add account (storage account name) and key (storage account access key)
  /usr/bin/docker exec dataguard-elasticsearch sh -c "echo $storage_account_name | /usr/share/elasticsearch/bin/elasticsearch-keystore add -f --stdin azure.client.default.account"
  /usr/bin/docker exec dataguard-elasticsearch sh -c "echo $storage_account_key | /usr/share/elasticsearch/bin/elasticsearch-keystore add -f --stdin azure.client.default.key"

  /usr/bin/docker restart dataguard-elasticsearch

  # Check if ES is back up, tries for up to 5 minutes
  RETRIES=0
  until $(curl --output /dev/null --silent --head --fail http://localhost:9200); do
    RETRIES=$((RETRIES+1))
    echo "Elasticsearch is still down, attempt $RETRIES"
    sleep 5
    if (( $RETRIES > 60 )); then
      echo "Elasticsearch didn't restart in time, giving up"
      exit 1
    fi
  done
fi

# Create the Elasticsearch snapshot
echo "Snapshotting Elasticsearch..."
/usr/bin/docker exec dataguard-sidecar /usr/bin/curl -XPOST dataguard-elasticsearch:9200/_snapshot/dataguard_repository/$snapshot_name

# Check if /appmount/.ssl/.my.cnf already exists
cnf_test=$(/usr/bin/docker exec dataguard-sidecar test -f /appmount/ssl/.my.cnf)$?

# if .my.cnf not found, populate it with defaults
if [[ $cnf_test != 0 ]]; then
  echo ".my.cnf settings not found, attempting to create"
  /usr/bin/docker exec -e mysql_dump_settings="$mysql_dump_settings" dataguard-sidecar bash -c '/bin/echo "$mysql_dump_settings" > /appmount/ssl/.my.cnf'
fi

# docker command to dump db (with date)
echo "dumping mysql data"
/usr/bin/docker exec dataguard-sidecar /usr/bin/mysqldump --defaults-file=/appmount/ssl/.my.cnf --column-statistics=0 --all-databases | /bin/gzip > ${backup_location}

az storage blob upload --account-name $storage_account_name --container-name backups --name "mysql-${snapshot_name}.sql.gz" --file $backup_location --auth-mode key --account-key $storage_account_key
