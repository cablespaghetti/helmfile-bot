#!/bin/bash
if [ -z "$SLACK_TOKEN" ]
then
  echo "\$SLACK_TOKEN is not set"
  exit 1
fi

if [ -z "$SLACK_CHANNEL" ]
then
  echo "\$SLACK_CHANNEL is not set"
  exit 1
fi

function push {
  RESPONSE=$(curl -sS https://slack.com/api/chat.postMessage --data "token=$SLACK_TOKEN&channel=$SLACK_CHANNEL&text=$1&as_user=true&mrkdwn=true") 
  echo $RESPONSE
}

push "I'm a test message"

