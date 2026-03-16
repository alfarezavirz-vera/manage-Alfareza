#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m'

line() {
  printf "${BLUE}====================================================${NC}\n" >/dev/tty
}

info() {
  printf "${CYAN}[INFO]${NC} %s\n" "$1" >/dev/tty
}

ok() {
  printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >/dev/tty
}

warn() {
  printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >/dev/tty
}

fail() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >/dev/tty
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_pm2() {
  warn "PM2 tidak ditemukan. Mencoba install otomatis..."

  if has_cmd npm; then
    npm install -g pm2 >/dev/tty 2>/dev/tty || fail "PM2 gagal diinstall dengan npm."
  elif has_cmd bun; then
    bun install -g pm2 >/dev/tty 2>/dev/tty || fail "PM2 gagal diinstall dengan bun."
  else
    fail "npm dan bun tidak ditemukan. Install Node.js atau Bun dulu."
  fi

  has_cmd pm2 || fail "PM2 gagal diinstall."
  ok "PM2 berhasil diinstall."
}

ask_non_empty() {
  local prompt="$1"
  local val=""

  while true; do
    read -r -p "$prompt" val </dev/tty
    if [ -n "${val// }" ]; then
      printf "%s" "$val"
      return 0
    fi
    warn "Input tidak boleh kosong."
  done
}

ask_type() {
  local t=""

  printf "${WHITE}Pilih tipe aplikasi:${NC}\n" >/dev/tty
  printf "  ${CYAN}1)${NC} Bot\n" >/dev/tty
  printf "  ${CYAN}2)${NC} Website / API\n" >/dev/tty

  while true; do
    read -r -p "Choose (1/2): " t </dev/tty
    case "$t" in
      1|2)
        printf "%s" "$t"
        return 0
        ;;
      *)
        warn "Pilih 1 atau 2."
        ;;
    esac
  done
}

ask_runtime() {
  local r=""

  printf "${WHITE}Pilih runtime:${NC}\n" >/dev/tty
  printf "  ${CYAN}1)${NC} Node\n" >/dev/tty
  printf "  ${CYAN}2)${NC} Bun\n" >/dev/tty

  while true; do
    read -r -p "Choose (1/2): " r </dev/tty
    case "$r" in
      1)
        printf "%s" "node"
        return 0
        ;;
      2)
        printf "%s" "bun"
        return 0
        ;;
      *)
        warn "Pilih 1 atau 2."
        ;;
    esac
  done
}

ask_port() {
  local p=""

  while true; do
    read -r -p "Port (default 3000): " p </dev/tty
    p="${p:-3000}"

    if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
      printf "%s" "$p"
      return 0
    fi

    warn "Port harus angka 1 sampai 65535."
  done
}

ask_yes_no() {
  local prompt="$1"
  local ans=""

  while true; do
    read -r -p "$prompt" ans </dev/tty
    case "$ans" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) warn "Jawab y atau n." ;;
    esac
  done
}

ensure_runtime_installed() {
  local runtime="$1"

  if has_cmd "$runtime"; then
    ok "Runtime '$runtime' terdeteksi."
    return 0
  fi

  fail "Runtime '$runtime' tidak ditemukan. Install dulu sebelum lanjut."
}

generate_bot_config() {
  local app_name="$1"
  local script_path="$2"
  local runtime="$3"

  cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "$app_name",
      script: "$script_path",
      interpreter: "$runtime",
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
}

generate_website_config() {
  local app_name="$1"
  local script_path="$2"
  local port="$3"
  local runtime="$4"

  cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "$app_name",
      script: "$script_path",
      interpreter: "$runtime",
      exec_mode: "fork",
      instances: 1,
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      env: {
        NODE_ENV: "development",
        PORT: $port
      },
      env_production: {
        NODE_ENV: "production",
        PORT: $port
      }
    }
  ]
};
EOF
}

main() {
  local type=""
  local runtime=""
  local app_name=""
  local script_path=""
  local port=""
  local app_type=""

  line
  printf "${WHITE}        PM2 Ecosystem Generator${NC}\n" >/dev/tty
  printf "${MAGENTA}              by XeraFinzz${NC}\n" >/dev/tty
  line

  info "Memeriksa PM2..."
  if has_cmd pm2; then
    ok "PM2 sudah terinstall."
  else
    install_pm2
  fi

  type="$(ask_type)"
  runtime="$(ask_runtime)"
  ensure_runtime_installed "$runtime"

  app_name="$(ask_non_empty 'App name: ')"
  script_path="$(ask_non_empty 'Entry script (example: app.js / bot.js / server.js / index.ts): ')"

  if [ ! -f "$script_path" ]; then
    warn "File '$script_path' tidak ditemukan di folder ini."
    if ! ask_yes_no "Tetap lanjut? (y/n): "; then
      fail "Dibatalkan."
    fi
  fi

  if [ "$type" = "1" ]; then
    app_type="Bot"
    generate_bot_config "$app_name" "$script_path" "$runtime"
  else
    app_type="Website / API"
    port="$(ask_port)"
    generate_website_config "$app_name" "$script_path" "$port" "$runtime"
  fi

  ok "ecosystem.config.js berhasil dibuat."
  info "Menjalankan PM2..."

  if pm2 describe "$app_name" >/dev/null 2>&1; then
    warn "App '$app_name' sudah ada di PM2."
    if ask_yes_no "Restart app yang ada? (y/n): "; then
      pm2 restart "$app_name" >/dev/tty 2>/dev/tty || fail "Gagal restart app."
      ok "App berhasil direstart."
    else
      fail "Dibatalkan supaya tidak bentrok."
    fi
  else
    pm2 start ecosystem.config.js --env production >/dev/tty 2>/dev/tty || fail "Gagal menjalankan app dengan PM2."
    ok "App berhasil dijalankan."
  fi

  pm2 save >/dev/tty 2>/dev/tty || fail "Gagal menyimpan konfigurasi PM2."

  line
  ok "Selesai."
  info "Type     : $app_type"
  info "Runtime  : $runtime"
  info "App Name : $app_name"
  info "Script   : $script_path"
  if [ -n "$port" ]; then
    info "Port     : $port"
  fi
  line

  printf "${WHITE}Perintah berguna:${NC}\n" >/dev/tty
  printf "pm2 status\n" >/dev/tty
  printf "pm2 logs %s\n" "$app_name" >/dev/tty
  printf "pm2 restart %s\n" "$app_name" >/dev/tty
  printf "pm2 stop %s\n" "$app_name" >/dev/tty
  printf "pm2 delete %s\n" "$app_name" >/dev/tty
}

main "$@"
install_pm2() {
  warn "PM2 tidak ditemukan. Mencoba install otomatis..."
  has_cmd npm || fail "npm tidak ditemukan. Install Node.js + npm dulu."
  npm install -g pm2
  has_cmd pm2 || fail "PM2 gagal diinstall."
  ok "PM2 berhasil diinstall."
}

ask_non_empty() {
  local prompt="$1"
  local val=""
  while true; do
    read -r -p "$prompt" val
    [ -n "${val// }" ] && { printf "%s" "$val"; return; }
    warn "Input tidak boleh kosong."
  done
}

ask_type() {
  local t=""
  printf "${WHITE}Pilih tipe aplikasi:${NC}\n"
  printf "  ${CYAN}1)${NC} Bot\n"
  printf "  ${CYAN}2)${NC} Website / API\n"
  while true; do
    read -r -p "Choose (1/2): " t
    case "$t" in
      1|2) printf "%s" "$t"; return ;;
      *) warn "Pilih 1 atau 2." ;;
    esac
  done
}

ask_port() {
  local p=""
  while true; do
    read -r -p "Port (default 3000): " p
    p="${p:-3000}"
    if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
      printf "%s" "$p"
      return
    fi
    warn "Port harus angka 1 sampai 65535."
  done
}

line
printf "${WHITE}        PM2 Ecosystem Generator${NC}\n"
printf "${MAGENTA}              by XeraFinzz${NC}\n"
line

info "Memeriksa PM2..."
if has_cmd pm2; then
  ok "PM2 sudah terinstall."
else
  install_pm2
fi

TYPE="$(ask_type)"
APP_NAME="$(ask_non_empty 'App name: ')"
SCRIPT_PATH="$(ask_non_empty 'Entry script (example: app.js / bot.js / server.js): ')"

if [ ! -f "$SCRIPT_PATH" ]; then
  warn "File '$SCRIPT_PATH' tidak ditemukan di folder ini."
  read -r -p "Tetap lanjut? (y/n): " CONTINUE_ANYWAY
  case "$CONTINUE_ANYWAY" in
    y|Y) ;;
    *) fail "Dibatalkan." ;;
  esac
fi

if [ "$TYPE" = "1" ]; then
  APP_TYPE="Bot"

  cat > ecosystem.config.js <<EOC
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
EOC

else
  APP_TYPE="Website / API"
  PORT="$(ask_port)"

  cat > ecosystem.config.js <<EOC
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
EOC
fi

ok "ecosystem.config.js berhasil dibuat."
info "Menjalankan PM2..."
pm2 start ecosystem.config.js --env production
pm2 save

line
ok "Aplikasi berhasil dijalankan dengan PM2."
info "Type     : $APP_TYPE"
info "App Name : $APP_NAME"
info "Script   : $SCRIPT_PATH"
if [ "${PORT:-}" != "" ]; then
  info "Port     : $PORT"
fi
line

printf "${WHITE}Perintah berguna:${NC}\n"
printf "pm2 status\n"
printf "pm2 logs $APP_NAME\n"
printf "pm2 restart $APP_NAME\n"
printf "pm2 stop $APP_NAME\n"
EOF
