#!/usr/bin/env bash

set -e

echo "=== PM2 Ecosystem Generator ==="
echo ""

echo "Select application type:"
echo "1) Bot"
echo "2) Website / API"
read -p "Choose (1/2): " TYPE

read -p "App name: " APP_NAME
read -p "Entry script (example: app.js / bot.js): " SCRIPT_PATH

PORT=""

if [ "$TYPE" == "2" ]; then
  read -p "Port (default 3000): " PORT
  PORT=${PORT:-3000}
fi

if [ "$TYPE" == "1" ]; then
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "$APP_NAME",
      script: "$SCRIPT_PATH",
      exec_mode: "fork",
      instances: 1,
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      env: {
        NODE_ENV: "development"
      },
      env_production: {
        NODE_ENV: "production"
      }
    }
  ]
};
EOF

APP_TYPE="Bot"

elif [ "$TYPE" == "2" ]; then
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "$APP_NAME",
      script: "$SCRIPT_PATH",
      exec_mode: "fork",
      instances: 1,
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      env: {
        NODE_ENV: "development",
        PORT: $PORT
      },
      env_production: {
        NODE_ENV: "production",
        PORT: $PORT
      }
    }
  ]
};
EOF

APP_TYPE="Website"

else
  echo "Invalid choice."
  exit 1
fi

echo ""
echo "ecosystem.config.js created!"
echo "Type: $APP_TYPE"
echo ""
echo "Start app with:"
echo "pm2 start ecosystem.config.js --env production"
