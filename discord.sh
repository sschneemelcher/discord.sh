#!/bin/sh

CONFIG_FILE="config.json"

# Set the Discord API endpoint and your bot's token
ENDPOINT=$(jq -r ".endpoint" "$CONFIG_FILE")
TOKEN=$(jq -r ".token" "$CONFIG_FILE")
GENERAL_CHANNEL_ID=$(jq -r ".generalChannelID" "$CONFIG_FILE")
WAITING_INTERVAL=$(jq -r ".waitingInterval" "$CONFIG_FILE")

# Send a message to a channel
send_message() {
  CHANNEL_ID="$1"
  MESSAGE="$2"
  curl -s -X POST "$ENDPOINT/channels/$CHANNEL_ID/messages" \
       -H "Authorization: Bot $TOKEN" \
       -H "Content-Type: application/json" \
       -d "{\"content\": \"$MESSAGE\"}" > /dev/null
}

# Main loop: check for new messages and respond
LATEST_MESSAGE_ID_FILE="latest-message-id.txt"
test -e "$LATEST_MESSAGE_ID_FILE" || touch "$LATEST_MESSAGE_ID_FILE"

while true; do
  # Read the ID of the latest message that has been processed
  LATEST_MESSAGE_ID=$(cat "$LATEST_MESSAGE_ID_FILE")

  # Retrieve the list of unread messages
  MESSAGES=$(curl -s -X GET "$ENDPOINT/channels/$GENERAL_CHANNEL_ID/messages?after=$LATEST_MESSAGE_ID" \
                  -H "Authorization: Bot $TOKEN" \
                  -H "Content-Type: application/json")

  # Iterate over the messages and respond to each one
  MESSAGES=$(echo "$MESSAGES" | jq -c '.[]')

  # If we have no new messages, wait an repoll (shell if is weird)
  if [ "$(echo MESSAGES | wc -l)" -gt 1 ]; then
    sleep "$WAITING_INTERVAL"
    continue
  fi

  echo "$MESSAGES" | while read -r MESSAGE; do
    # Parse the neccessary information for the reply
    MESSAGE_ID=$(echo "$MESSAGE" | jq -r '.id')

    # Update the ID of the latest message that has been processed
    if [ -n "$MESSAGE_ID" ]; then
      echo "$MESSAGE_ID" > "$LATEST_MESSAGE_ID_FILE"
    fi

    CONTENT=$(echo "$MESSAGE" | jq -r '.content')
    USER=$(echo "$MESSAGE" | jq -r '.author.username')
    CHANNEL_ID=$(echo "$MESSAGE" | jq -r '.channel_id')
    if [ "$CONTENT" = "!hello" ]; then
      send_message "$CHANNEL_ID" "Hello, $USER!"
    fi
  done

  # Wait sometime before polling again
  sleep "$WAITING_INTERVAL"
done
