#!/bin/sh
set -e

cd /app
bundle exec rails db:prepare

if ! bundle exec rails runner "exit(User.exists? ? 0 : 1)"; then
  bundle exec rails db:seed
fi

exec bundle exec rails server -b 0.0.0.0 -p 3000
