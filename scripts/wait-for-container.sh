#!/bin/bash
# wait-for-container.sh - Wait for a Docker container to become healthy
#
# Usage: ./wait-for-container.sh CONTAINER_NAME [TIMEOUT]
#
# Arguments:
#   CONTAINER_NAME - The name of the Docker container to check
#   TIMEOUT - Maximum time to wait in seconds (default: 60)

set -e

# Parse arguments
CONTAINER_NAME=${1:?Container name is required}
TIMEOUT=${2:-60}

echo "Waiting for ${CONTAINER_NAME} to be healthy (timeout: ${TIMEOUT}s)"

# Set a timeout using SECONDS builtin variable
SECONDS=0

# Use the until loop as specified
until [ "$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null)" = "healthy" ]; do
  if [ $SECONDS -gt $TIMEOUT ]; then
    echo "Timeout reached after ${TIMEOUT}s. Container ${CONTAINER_NAME} is not healthy."
    exit 1
  fi

  echo "Waiting for ${CONTAINER_NAME} to be healthy... (${SECONDS}/${TIMEOUT}s)"
  sleep 1
done

echo "Container ${CONTAINER_NAME} is healthy! (took ${SECONDS}s)"
exit 0
