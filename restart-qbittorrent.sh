#!/bin/bash

# Script that restarts qbittorent docker container, when gluetun disconnects and reconnects
# otherwise, qbitorrent looses connection

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

is_gluetun_running() {
  docker ps --filter "name=$GLUETUN_CONTAINER_NAME" --filter "status=running" --format '{{.Names}}' | grep -w "$GLUETUN_CONTAINER_NAME" > /dev/null 2>&1
}

wait_for_gluetun() {
  log_message "Waiting for the '$GLUETUN_CONTAINER_NAME' container to start..."
  until is_gluetun_running; do
    sleep 60
  done
  log_message "$GLUETUN_CONTAINER_NAME container is running."
}

while true; do
  wait_for_gluetun

  # Check if environment variables are set
  if [ -z "$GLUETUN_CONTAINER_NAME" ] || [ -z "$QBITTORRENT_CONTAINER_NAME" ]; then
    # check gluetun container name set
    if [ -z "$GLUETUN_CONTAINER_NAME" ]; then
      log_message "Environment variable GLUETUN_CONTAINER_NAME is not set. Run 'export GLUETUN_CONTAINER_NAME=gluetun' to set it."
    fi
    # check qbittorrent container name set
    if [ -z "$QBITTORRENT_CONTAINER_NAME" ]; then
      log_message "Environment variable QBITTORRENT_CONTAINER_NAME is not set. Run 'export QBITTORRENT_CONTAINER_NAME=qbittorrent' to set it."
    fi
    exit 1
  fi

  log_message "Listening to '$GLUETUN_CONTAINER_NAME' logs..."
  docker logs -f -n 0 $GLUETUN_CONTAINER_NAME | while read line; do
      # Check if the line contains "ip getter"
      # Gluetun logs "ip getter" after it successfuly restarts/reconnects - that's when we want to
      # restart qbittorrent
      if [[ "$line" == *"ip getter"* ]]; then
          log_message "Detected 'ip getter' event. Restarting '$QBITTORRENT_CONTAINER_NAME' container..."

          if docker restart $QBITTORRENT_CONTAINER_NAME -t 120; then
              log_message "$QBITTORRENT_CONTAINER_NAME container restarted successfully."
          else
              log_message "Failed to restart $QBITTORRENT_CONTAINER_NAME container."
          fi
      fi
  done
  if [ $? -ne 0 ]; then
    log_message "$GLUETUN_CONTAINER_NAME container has stopped or an error occurred."
  fi

  log_message "Restarting log monitoring..."
  sleep 2
done