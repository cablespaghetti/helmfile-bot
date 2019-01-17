#!/bin/bash

while [[ "$#" > 1 ]]; do case $1 in
  --diff-file) diff_file="$2";;
  --slack-token) slack_token="$2";;
  --slack-channel) slack_channel="$2";;
  --namespace) namespace="$2";;
  --commit-url) commit_url="$2";;
    *) break;;
  esac; shift; shift
done

if [ -z "$diff_file" ] || [ -z "$slack_token" ] || [ -z "$slack_channel" ] || [ -z "$namespace" ]; then
  echo "Usage: $0 --diff-file <path to diff file> --slack-token <slack bot token> --slack-channel <slack channel name> --namespace <kubernetes namespace>"
  echo "  --diff-file (\$diff_file)          The path to the file containing helm-diff output"
  echo "  --slack-token (\$slack_token)      The Slack API Bot token to use"
  echo "  --slack-channel (\$slack_channel)  The name of the Slack channel to post to"
  echo "  --namespace (\$namespace)          The name of the Kubnernetes namespace"
  echo "  --commit-url (\$commit_url)        The URL prefix to use for commit links (Optional)"
  exit 1
fi

function push {
  response=$(curl -sS https://slack.com/api/chat.postMessage -d "token=${slack_token}&channel=${slack_channel}&text=${1}&as_user=true")
  echo $response
}

# Cat the file passed as the first positional argument
# Remove any colour codes from the text
# grep for lines beginning with + or - (disabling any shell aliases to avoid colour weirdness on some machines)
# grep for lines containing image:
# Hide the diff we get everytime for the test Pod for the Keycloak Chart
# Fix the fact + keeps getting URL encoded to a space
diff="$(cat $diff_file | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' | \grep -E '^(\+|-)' | \grep 'image:' | \grep -v selenium | sed 's/+/%2B/g')"

committer=$(git log -1 --pretty=format:'%an' 2>/dev/null) || true
if [ -z "$committer" ]
then
  committer_message=""
else
  committer_message="Commit made by $committer."
fi

commit=$(git rev-parse HEAD 2>/dev/null) || true
if [ -z "$commit" ]
then
  commit_message=""
else
  if [ -z "$commit_url" ]; then
    commit_message="_*$(echo $commit | cut -c-7)*_"
  else
    commit_message="_*<${commit_url}${commit}|$(echo $commit | cut -c-7)>*_"
  fi
fi

if [[ -z "${diff// }" ]]
then
  push "Deployment made to $namespace but no versions changed. $committer_message $commit_message"
else
  push "Versions changed in $namespace. $committer_message $commit_message
\`\`\`$diff\`\`\`"
fi
