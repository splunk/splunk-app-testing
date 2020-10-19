#!/bin/bash
#set -x

if [ $# -lt 2 ]; then
      echo "Usage: cicd_runner.sh [Splunk Image] [Cypress Image]"
      echo "Image: "
      echo "    registry/image:tag"
      exit 1
fi

MAX_WAIT_SECONDS=120
version=$1
cypress_image=$2
container="splunk"
APP_ROOT="testing_app"
APPS_DIR="/opt/splunk/etc/apps"
USER="admin"
PASSWORD="newPassword"
CI_PROJECT_DIR=${CI_PROJECT_DIR:-`pwd`}

SPLUNK_HOME="/opt/splunk"
SPLUNK_ETC="/opt/splunk/etc"
SPLUNK_START_ARGS="--accept-license"
SPLUNK_ENABLE_LISTEN="9997"
SPLUNK_ADD="tcp 1514"
SPLUNK_PASSWORD="newPassword"
SPLUNK_HOSTNAME="idx-example.splunkcloud.com"

mkdir -p build

echo "Running image: ${version}..."

# The Docker network allows the Splunk and testing containers to communicate
echo "Create a bridge network for the containers to communicate"
docker network create testingnet

# Create and start the Splunk container
echo "Starting splunk image ${version} as ${container}..."
docker run -d \
      --name $container \
      --network testingnet \
      --hostname "$SPLUNK_HOSTNAME" \
      --env SPLUNK_HOME="$SPLUNK_HOME" \
      --env SPLUNK_ETC="$SPLUNK_ETC" \
      --env SPLUNK_START_ARGS="$SPLUNK_START_ARGS" \
      --env SPLUNK_ENABLE_LISTEN="$SPLUNK_ENABLE_LISTEN" \
      --env SPLUNK_ADD="$SPLUNK_ADD" \
      --env SPLUNK_PASSWORD="$SPLUNK_PASSWORD" \
      --user root \
      -p 8000:8000 \
      -p 8089:8089 \
      $version

echo "Copying data into container..."
docker exec $container bash -c "mkdir -p -m 777 /opt/splunk/etc/apps"
docker cp $CI_PROJECT_DIR/cicd/config/passwd $container:$SPLUNK_ETC/passwd
# Copy in the sample app
docker cp $CI_PROJECT_DIR/$APP_ROOT $container:$APPS_DIR/$APP_ROOT
# Copy in the generated data
docker cp $CI_PROJECT_DIR/output $container:/
# Prevent splunk from prompting for password reset
docker exec $container bash -c "touch /opt/splunk/etc/.ui_login"

# Wait for instance to be available
# Waiting for 2 and a half minutes.
loopCounter=0
health="starting"

# check to see if container has a health check and if so, wait for it to be healthy
while [[ $loopCounter -lt $MAX_WAIT_SECONDS && $health =~ "starting" ]]; do
  health=`docker ps --filter "name=${container}" --format "{{.Status}}"`
  echo -ne "\rWaiting for Splunk to be available...$((MAX_WAIT_SECONDS - loopCounter))   "
  ((loopCounter++))
  sleep 1
done

# validate container is running
health=`docker ps --filter "name=${container}" --format "{{.Status}}"`

# if there was a problem, print some debugging information
if [[ $health == "" ]]; then
  echo "Health:\n${health}\n" &> Errors.txt
  echo "--------------------------------" &> Errors.txt
  docker ps -a &> Errors.txt
  echo "--------------------------------" &> Errors.txt
  docker inspect $container &> Errors.txt
  echo "--------------------------------" &> Errors.txt
  docker logs $container &> Errors.txt
  echo "--------------------------------" &> Errors.txt
  echo "Container is no longer running!"
  echo "See Errors.txt for more information."
  exit 1
else
  echo -e "\n\033[0;32m\xE2\x9C\x94\033[0m Splunk Available!"
fi

# if the container is healthy, or it's an old container without a health check, use the saved search to validate data is loaded
loopCounter=0
splunkReady=0
while [[ $loopCounter -lt $MAX_WAIT_SECONDS && $splunkReady -lt 1 ]]; do

  echo -ne "container running, checking indexed data count...$((MAX_WAIT_SECONDS - loopCounter))   \r"
  eventCount=`docker exec $container bash -c "SPLUNK_USERNAME=admin SPLUNK_PASSWORD=newPassword /opt/splunk/bin/splunk search 'index=main source=/output/access.log | stats count' -app testing_app"`
  if [[ $eventCount =~ "1559" ]]; then
    echo -e "\n\033[0;32m\xE2\x9C\x94\033[0m Data full indexed!"
    splunkReady=1
  fi
  ((loopCounter+=5))
  sleep 5
done

# timeout error message if the data was not fully indexed
if [[ $splunkReady != 1 ]]; then
  echo "Timeout waiting for data to be ingested into Splunk!"
  echo "See build/Errors.txt for more information."
  docker exec $container bash -c "ls -l /output" &> build/Errors.txt
  docker logs $container &> Errors.txt
  exit 1
fi

echo "Setting up test environment..."

# Run btool on the Splunk container
echo -n "Running btool checks..."
docker exec $container bash -c "/opt/splunk/bin/splunk btool check --debug" &> build/btool_output.txt

if [ $? -eq 0 ]
then
    echo -e "\033[0;32m\xE2\x9C\x94\033[0m"
  else
    echo "Failed!"
    echo "See build/btool_output.txt for more information"
fi

echo "Executing Cypress test specs..."

# Create Cypress container but do not start it yet
docker container create --name cypress_runner \
  --network testingnet \
  -w /e2e \
  -e CYPRESS_baseUrl=http://$container:8000 \
  -e CYPRESS_base_api=https://$container:8089 \
  -e CYPRESS_headless=true \
  $cypress_image

# Copy in configuration and tests
docker cp cicd/test/cypress cypress_runner:/e2e/cypress
docker cp cicd/test/cypress.json cypress_runner:/e2e/cypress.json

# Start Cypress container, which runs the tests
docker start -a cypress_runner || status=$?

# Copy out the test results (Cypress videos)
docker cp cypress_runner:/e2e/cypress/videos $CI_PROJECT_DIR/cicd/test/cypress/videos

# clean up from the run
docker stop $container || true
docker container rm $container || true
docker container rm cypress_runner || true
docker network rm testingnet || true
exit ${status:-0}
