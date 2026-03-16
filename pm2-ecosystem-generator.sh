bash <<'EOF'
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
  printf "${BLUE}====================================================${NC}\n"
}

info() {
  printf "${CYAN}[INFO]${NC} %s\n" "$1"
}

ok() {
  printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

warn() {
  printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

fail() {
  printf "${RED}[ERROR]${NC} %s\n" "$1"
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

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
