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

namespace=$2

function push {
  RESPONSE=$(curl -Ss https://slack.com/api/chat.postMessage -d "token=${SLACK_TOKEN}&channel=${SLACK_CHANNEL}&text=${1}&as_user=true")
  echo $RESPONSE
}

diff="$(cat $1 | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' | egrep --colour=never '^(\+|-)' | grep 'image:' | grep -v selenium | sed 's/+/%2B/g')"

if [[ -z "${diff// }" ]]
then
  push "Deployment made to $namespace but no versions changed"
else
  push "Versions changed in $namespace:
$diff"
fi
