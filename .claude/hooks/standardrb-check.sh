#!/usr/bin/env bash
# PostToolUse hook: run standardrb on the edited file and block the turn
# when violations remain so Claude must fix them before continuing.

set -u

payload="$(cat)"
file_path=$(printf '%s' "$payload" | jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

case "$file_path" in
  "$PWD"/*.rb | "$PWD"/*.gemspec | "$PWD"/Rakefile | "$PWD"/Gemfile) ;;
  *) exit 0 ;;
esac

output=$(bundle exec standardrb "$file_path" 2>&1)
if [ $? -ne 0 ]; then
  reason="standardrb violations in $file_path. Fix manually or run \`bundle exec rake standard:fix\`:

$output"
  jq -n --arg reason "$reason" '{decision:"block",reason:$reason}'
fi
exit 0
