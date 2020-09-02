#!/bin/bash

#set -x

if [ $# -lt 1 ]; then
      echo "Usage: cicd_runner.sh <splunk_8_0_1>"
      exit 1
fi

version=$1
APP_ROOT="testing_app"
APPS_DIR="/opt/splunk/etc/apps"
USER="admin"
PASSWORD="newPassword"
REGISTRY="weberjas"
CI_PROJECT_DIR=${CI_PROJECT_DIR:-`pwd`}

echo "Running image: ${version}..."

# The Docker network allows the Splunk and testing containers to communicate
echo "Create a bridge network for the containers to communicate"
docker network create testingnet

# Create the Splunk container from the image but do not start it yet
echo "Starting splunk image $version:latest..."
#docker container create --name $version --hostname "idx-example.splunkcloud.com" --network testingnet $REGISTRY/$version:latest
echo "docker container create --rm --name $version --hostname 'idx-example.splunkcloud.com' --network testingnet $REGISTRY/$version:latest"
docker container create --rm --name $version --hostname "idx-example.splunkcloud.com" --network testingnet $REGISTRY/$version:latest

# Copy app and configuration into Splunk container
echo "Copying data into container..."
echo "docker cp $CI_PROJECT_DIR/$APP_ROOT $version:$APPS_DIR/"
docker cp $CI_PROJECT_DIR/$APP_ROOT $version:$APPS_DIR/
echo "docker cp $CI_PROJECT_DIR/output $version:/"
docker cp $CI_PROJECT_DIR/output $version:/

# Start Splunk container
echo "starting ${version}..."
docker start $version

# Wait for instance to be available
# Waiting for 2 and a half minutes.
loopCounter=30
mainReady=0
# forwarderReady=0
echo "Wait for Splunk to be available..."

while [[ $loopCounter != 0 && $mainReady != 1 ]]; do
  ((loopCounter--))
  health=`docker ps --filter "name=${version}" --format "{{.Status}}"`

# TODO document the container status
# health will be one of these values: 
  if [[ ! $health =~ "starting" ]]; then
    echo "container running, checking data status..."
    eventCount=`docker exec $version bash -c "SPLUNK_USERNAME=admin SPLUNK_PASSWORD=newPassword /opt/splunk/bin/splunk search 'index=main source=/output/access.log | stats count' -app testing_app"`
    # This count reflects the number of events which are read from the
    # test data file.
    if [[ $eventCount =~ "1559" ]]; then
      echo "Data full indexed!"
      mainReady=1
    fi
  fi

 # if the container is no longer running...
  if [[ $health == "" ]]; then
    echo "Health:\n${health}\n"
    echo "--------------------------------"
    docker ps -a
    echo "--------------------------------"
    docker inspect $version
    echo "--------------------------------"
    docker logs $version
    echo "--------------------------------"
    echo "Container is no longer running!"
    exit 1
  fi

  echo "loopCounter: ${loopCounter}"
  echo "mainReady: ${mainReady}"
  sleep 5
done

if [[ $mainReady != 1 ]]; then
  echo "Timeout waiting for data to be ingested into Splunk!"
  docker exec $version bash -c "ls -l /output"
  docker logs $version
  exit 1
fi

echo "Setting up test environment..."
# Prevent splunk from prompting for password reset
docker exec $version bash -c "touch /opt/splunk/etc/.ui_login"
# Run btool on the Splunk container
# TODO: Will this create a failure state if there is something wrong with btool or will it just report the error and move on?
docker exec $version bash -c "/opt/splunk/bin/splunk btool check --debug"

echo "-------------------------------------"

# Run saved searches
echo "Running Saved Searches..."

# TODO change saved search

echo "-------------------------------------"

echo "Executing Cypress test specs..."

docker container create --name cypress_runner \
  --network testingnet \
  -w /e2e \
  -e CYPRESS_baseUrl=http://$version:8000 \
  -e CYPRESS_base_api=https://$version:8089 \
  -e CYPRESS_headless=true \
  cypress/included:5.0.0

docker cp $CI_PROJECT_DIR/cicd/test/cypress cypress_runner:/e2e/cypress
docker cp $CI_PROJECT_DIR/cicd/test/cypress.json cypress_runner:/e2e/cypress.json
docker start -a cypress_runner || status=$?
docker cp cypress_runner:/e2e/cypress/videos $CI_PROJECT_DIR/cicd/test/cypress/videos
# clean up the network for local runs
docker stop $version
docker network rm testingnet
exit ${status:-0}
