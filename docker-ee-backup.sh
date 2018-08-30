#!/bin/bash

startup() {
    echo ""
    echo "----------- Docker EE Backup Tool -----------"
    echo ""

    # Timeout required to allow user to cancel backup
    echo "Starting UCP & DTR backup in 10 seconds. Press CTRL+C to cancel."
    sleep 10

    #Time is set so that both DTR and UCP backups have same timestamp
    TIME="$(date +%F-%R)"

    UCP_VERSION=$(docker inspect ucp-controller | jq -r '.[].Config.Labels."com.docker.ucp.version"')
    
    # Create an environment variable with the user security token
    AUTHTOKEN=$(curl -sk -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" "https://${UCP_URL}/auth/login" | jq -r '.auth_token')
    
    # Download the client certificate bundle
    curl -f -k -H "Authorization: Bearer $AUTHTOKEN" "https://${UCP_URL}/api/clientbundle" -o ucp-bundle-${TIME}-${USERNAME}.zip

    unzip -oq -d /ucp-bundle ucp-bundle-${TIME}-${USERNAME}.zip

    cd /ucp-bundle && source env.sh && cd ${OLDPWD}

    DTR_VERSION=$(docker ps | grep dtr-rethink | awk '{print $2}' | awk -F: '{print $2}' | head -n 1)

    DTR_REPLICA=$(docker ps | grep dtr-rethink | awk '{print $NF}' | awk -F- '{print $NF}' | head -n 1)

    unset DOCKER_TLS_VERIFY
    unset DOCKER_CERT_PATH
    unset DOCKER_HOST
}

dtrBackup() {
    # Timeout required to allow UCP to come backup. UCP was restarted in previous step.
    echo ""
    echo "Starting DTR backup. DTR will continue running during the backup."

    # Health checking DTR replica before backup
    if [ "$(curl -k -s "https://${DTR_URL}/health" | jq ".Healthy")" != "true" ]; then
        echo "DTR Replica ${DTR_URL} returned bad health. Exiting backup script."
        exit 1
    fi
    echo "DTR health is OK"

    DTR_BACKUP_NAME="backup-${TIME}-dtr-${DTR_VERSION}.tar"

    echo "DTR backup starting ..."
    echo ""
    echo ""
    docker run -i --rm docker/dtr:"${DTR_VERSION}" backup \
      --debug \
      --ucp-username "${USERNAME}" \
      --ucp-password "${PASSWORD}" \
      --ucp-insecure-tls \
      --existing-replica-id "${DTR_REPLICA}" \
      --ucp-url "https://${UCP_URL}" > "${DTR_BACKUP_NAME}"

    if [ ! -s "${DTR_BACKUP_NAME}" ]; then
        echo "DTR backup was unsucessful. Run DTR backup manually."
        exit 1
    fi

    echo "DTR backup complete and saved as ${DTR_BACKUP_NAME}"
    echo ""
}

ucpBackup() {
    echo "UCP controller ${UCP_URL} will temporarily shut down but a UCP cluster in HA mode will remain up."
    sleep 20

    # Health checking for this UCP controller before backup
    if [ "$(curl -k -s https://${UCP_URL}/_ping)" != "OK" ]; then
        echo "UCP Controller ${UCP_URL} returned bad health. Exiting backup script."
        exit 1
    fi
    echo "UCP health is OK"

    UCP_BACKUP_NAME="backup-${TIME}-ucp-${UCP_VERSION}.tar"

    UCP_ID="$(docker run --rm -i --name ucp -v /var/run/docker.sock:/var/run/docker.sock docker/ucp:"${UCP_VERSION}" id 2> /dev/null)"

    echo "UCP backup starting ..."
    echo ""

    docker run --rm -i --name ucp \
        --log-driver none \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "docker/ucp:${UCP_VERSION}" backup \
        --id "${UCP_ID}" \
        --debug > "${UCP_BACKUP_NAME}"

    if [ ! -s "${UCP_BACKUP_NAME}" ]; then
        echo "UCP backup was unsucessful. Run UCP backup manually."
        exit 1
    fi

    echo "UCP backup complete and saved as ${UCP_BACKUP_NAME}"
}

cleanup() {
    rm "ucp-bundle-${TIME}-${USERNAME}.zip"
}

#Entrypoint for program
startup
dtrBackup
ucpBackup
cleanup
echo "UCP and DTR backups are complete. Remember to test the backups with a UCP & DTR restore from time to time."
