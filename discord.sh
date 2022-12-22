#!/bin/sh

CONFIG_FILE="./config.sh"

# shellcheck source=./config.sh
. $CONFIG_FILE

# Send a message to a channel
send_message() {
  channel_id_to_send="$1"
  message_to_send="$2"
  curl -s -X POST "$ENDPOINT/channels/$channel_id_to_send/messages" \
       -H "Authorization: Bot $TOKEN" \
       -H "Content-Type: application/json" \
       -d "{\"content\": \"$message_to_send\"}" > /dev/null
}

# TODO add features to logging
bot_log() {
  printf "[log] %s\n" "$1"
}

# difference between timestamp and now in ms
ms_difference() {
  from_timestamp="$1"
  parsed_timestamp_unix=$(date -d "$(date -d "$from_timestamp" +"%Y-%m-%dT%T.%N%z")" +"%s%N")
  current_time_unix=$(date -d "$(date +"%Y-%m-%dT%T.%N%z")" +"%s%N")
  printf "%s" "$(((current_time_unix - parsed_timestamp_unix) / 1000000))"
}

# Retrieve the last message of the channel
messages=$(curl -s -X GET "$ENDPOINT/channels/$GENERAL_CHANNEL_ID/messages?limit=1" \
                -H "Authorization: Bot $TOKEN" \
                -H "Content-Type: application/json" | tr '\n' ' ')

# Parse the message id
latest_message_id=$(printf "%s" "$messages" | jq -r '.[0].id')

# Main loop: check for new messages and respond
while true; do
  # Retrieve the list of unread messages
  messages=$(curl -s -X GET "$ENDPOINT/channels/$GENERAL_CHANNEL_ID/messages?after=$latest_message_id" \
                  -H "Authorization: Bot $TOKEN" \
                  -H "Content-Type: application/json")

  messages=$(printf "%s" "$messages" | tr '\n' ' ')
  n_messages=$(printf "%s" "$messages" | jq -c "length")

  # If we have no new messages, wait an repoll
  if [ "$n_messages" -lt 1 ]; then
    sleep "$WAITING_INTERVAL"
    continue
  fi

  # We are using a for loop here so we do not have to worry about running
  # stuff in a subshell which we would if we were to use `while read`
  for i in $(seq 0 $((n_messages - 1))); do
    message=$(printf "%s" "$messages" | jq -c ".[$i]")
    message_id=$(printf "%s" "$message" | jq -r '.id')

    # The messages do not neccessarily in order, so we need
    # to make sure we set LATEST_message_ID to the highest id of the batch
    if [ "$message_id" -gt "$latest_message_id" ]; then
      latest_message_id="$message_id"
    fi

    # Parse the message content
    content=$(printf "%s" "$message" | jq -r '.content')
    channel_id=$(printf "%s" "$message" | jq -r '.channel_id')

    # Check for commands at the beginning of content
    case $content in
      "!hello"*)
        user=$(printf "%s" "$message" | jq -r '.author.username')
        bot_message="Hello, $user!"
        send_message "$channel_id" "$bot_message"
      ;;

      "!ping"*)
        timestamp=$(printf "%s" "$message" | jq -r '.timestamp')
        difference_ms=$(ms_difference "$timestamp")
        bot_message="pong! [$difference_ms ms]"
        send_message "$channel_id" "$bot_message"
      ;;

      *) # Default
        # We unset this here, so that we do not log something when reading
        # our own messages from the channel
        bot_message=""
      ;;
    esac

    if [ -n "$LOGGING" ] && [ -n "$bot_message" ]; then
      bot_log "$bot_message"
    fi

  done

  # Wait sometime before polling again
  sleep "$WAITING_INTERVAL"
done
