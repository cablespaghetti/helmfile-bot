#!/bin/bash

while [ "$1" != "" ]; do case $1 in
  --diff-file) shift; diff_file="$1";;
  --slack-token) shift; slack_token="$1";;
  --slack-channel) shift; slack_channel="$1";;
  --namespace) shift; namespace="$1";;
  --commit-url) shift; commit_url="$1";;
  --dry-run) dry_run=1;;
    *) break;;
  esac; shift
done

if [ -z "$diff_file" ] || [ -z "$slack_token" ] || [ -z "$slack_channel" ] || [ -z "$namespace" ]; then
  echo "Usage: $0 --diff-file <path to diff file> --slack-token <slack bot token> --slack-channel <slack channel name> --namespace <kubernetes namespace>"
  echo "  --diff-file (\$diff_file)          The path to the file containing helm-diff output"
  echo "  --slack-token (\$slack_token)      The Slack API Bot token to use"
  echo "  --slack-channel (\$slack_channel)  The name of the Slack channel to post to"
  echo "  --namespace (\$namespace)          The name of the Kubnernetes namespace"
  echo "  --commit-url (\$commit_url)        The URL prefix to use for commit links (Optional)"
  echo "  --dry-run (\$dry_run)              If set then echo instead of sending to the API (Optional)"
  exit 1
fi

function push {
  if [ "$dry_run" = "1" ]; then
    echo "$1"
  else
    response=$(curl -sS https://slack.com/api/chat.postMessage -d "token=${slack_token}&channel=${slack_channel}&text=${1}&as_user=true")
    echo $response
  fi
}

# Cat the file passed as the first positional argument
# Remove any colour codes from the text
# grep for lines beginning with + or - (disabling any shell aliases to avoid colour weirdness on some machines)
# grep for lines containing image:
# Hide the diff we get everytime for the test Pod for the Keycloak Chart
# Fix the fact + keeps getting URL encoded to a space
diff="$(cat $diff_file | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' | \grep -E '^(\+|-)' | \grep 'image:' | \grep -v selenium)"

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
  diff_message=""
  while read -r added_line; do
    if [[ $added_line == +* ]]; then
      added_image_name=$(echo $added_line | cut -d':' -f2 | cut -d'/' -f2 | awk '$1=$1')
      added_image_tag=$(echo $added_line | cut -d':' -f3 | awk '$1==$1')
      if [ -z "$added_image_tag" ]; then
        added_image_tag="latest"
      fi

      match=0
      while read -r removed_line; do
        if [[ $removed_line == -* ]]; then
          removed_image_name=$(echo $removed_line | cut -d':' -f2 | cut -d'/' -f2 | awk '$1=$1')
          removed_image_tag=$(echo $removed_line | cut -d':' -f3 | awk '$1==$1')
          if [ -z "$removed_image_tag" ]; then
            removed_image_tag="latest"
          fi

          if [ "$added_image_name" == "$removed_image_name" ]; then
            diff_message="$diff_message$removed_image_name - $removed_image_tag -> $added_image_tag"$'\n'
            match=1
            break
          fi
        fi
      done <<< "$diff"
      if [ $match = "0" ]; then
        diff_message="$diff_message$added_image_name - $added_image_tag (new image)"$'\n'
      fi
    fi
  done <<< "$diff"

  while read -r removed_line; do
    if [[ $removed_line == -* ]]; then
      removed_image_name=$(echo $removed_line | cut -d':' -f2 | cut -d'/' -f2 | awk '$1=$1')
      removed_image_tag=$(echo $removed_line | cut -d':' -f3 | awk '$1==$1')
      if [ -z "$removed_image_tag" ]; then
        removed_image_tag="latest"
      fi

      match=0
      while read -r added_line; do
        if [[ $added_line == +* ]]; then
          added_image_name=$(echo $added_line | cut -d':' -f2 | cut -d'/' -f2 | awk '$1=$1')
          added_image_tag=$(echo $added_line | cut -d':' -f3 | awk '$1==$1')
          if [ -z "$added_image_tag" ]; then
            added_image_tag="latest"
          fi

          if [ "$added_image_name" == "$removed_image_name" ]; then
            match=1
            break
          fi
        fi
      done <<< "$diff"
      if [ $match = "0" ]; then
        diff_message="$diff_message$removed_image_name - $removed_image_tag (removed image)"$'\n'
      fi
    fi
  done <<< "$diff"

  push "Versions changed in $namespace. $committer_message $commit_message
\`\`\`$diff_message\`\`\`"
fi
