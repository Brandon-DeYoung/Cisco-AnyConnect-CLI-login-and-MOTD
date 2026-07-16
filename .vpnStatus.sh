#!/bin/bash

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
KEYCHAIN_USERNAME_SERVICE='cisco-secure-client-cli-helper-username'
KEYCHAIN_PASSWORD_SERVICE='cisco-secure-client-cli-helper-password'
KEYCHAIN_SERVER_SERVICE='cisco-secure-client-cli-helper-server'

usage() {
  cat <<'EOF'
Usage:
  vpn                    Prompt for username and password on every connection.
  vpn --setup-keychain   Store one VPN server, username, and password in Keychain.
  vpn --keychain         Retrieve the stored VPN server and credentials from Keychain.
EOF
}

setup_keychain() {
  read -r -p 'VPN server to store in Keychain: ' keychain_server
  read -r -p 'Username to store in Keychain: ' keychain_username
  if [[ -z "$keychain_server" || -z "$keychain_username" ]]; then
    echo -e "${RED}A VPN server and username are required.${NC}"
    exit 1
  fi

  # -T '' prevents automatic access by applications, including this script.
  security add-generic-password \
    -a "$keychain_username" \
    -s "$KEYCHAIN_SERVER_SERVICE" \
    -l 'Cisco Secure Client CLI Helper Server' \
    -T '' \
    -U \
    -w "$keychain_server"

  security add-generic-password \
    -a "$keychain_username" \
    -s "$KEYCHAIN_USERNAME_SERVICE" \
    -l 'Cisco Secure Client CLI Helper Username' \
    -T '' \
    -U \
    -w "$keychain_username"

  echo 'Enter the VPN password when prompted. Do not append the YubiKey code.'
  security add-generic-password \
    -a "$keychain_username" \
    -s "$KEYCHAIN_PASSWORD_SERVICE" \
    -l 'Cisco Secure Client CLI Helper Password' \
    -T '' \
    -U \
    -w

  echo -e "${GREEN}Credentials saved to Keychain. Connect with: vpn --keychain${NC}"
}

if [[ "$OSTYPE" != darwin* ]]; then
  echo -e "${RED}This script supports macOS only.${NC}"
  exit 1
fi

use_keychain=false
setup_keychain_requested=false

for argument in "$@"; do
  case "$argument" in
    --setup-keychain)
      setup_keychain_requested=true
      ;;
    --keychain)
      use_keychain=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if "$setup_keychain_requested"; then
  setup_keychain
  exit 0
fi

if [[ -x /opt/cisco/secureclient/bin/vpn ]]; then
  VPN_BIN=/opt/cisco/secureclient/bin/vpn
else
  echo -e "${RED}Cisco Secure Client CLI was not found.${NC}"
  exit 1
fi

vpn_state() {
  "$VPN_BIN" status 2>&1 | tr -d '\r' | awk '/state: (Connected|Disconnected)/ { state = $0 } END { print state }'
}

status=$(vpn_state)

if [[ $status == *'state: Disconnected'* ]]; then
  if "$use_keychain"; then
    if ! vpn_host=$(security find-generic-password -s "$KEYCHAIN_SERVER_SERVICE" -w); then
      echo -e "${RED}Could not retrieve the VPN server from Keychain.${NC}"
      exit 1
    fi
    if ! vpn_username=$(security find-generic-password -s "$KEYCHAIN_USERNAME_SERVICE" -w); then
      echo -e "${RED}Could not retrieve the VPN username from Keychain.${NC}"
      exit 1
    fi
    if ! vpn_password=$(security find-generic-password -s "$KEYCHAIN_PASSWORD_SERVICE" -w); then
      echo -e "${RED}Could not retrieve the VPN password from Keychain.${NC}"
      exit 1
    fi
  else
    read -r -p 'VPN server: ' vpn_host
    read -r -p 'Username: ' vpn_username
    read -r -s -p 'Password: ' vpn_password
    echo
  fi

  read -r -s -p 'YubiKey code: ' yubi_code
  echo

  if [[ -z "$vpn_host" || -z "$vpn_username" || -z "$vpn_password" || -z "$yubi_code" ]]; then
    echo -e "${RED}VPN server, username, password, and YubiKey code are required.${NC}"
    exit 1
  fi

  echo -e "\n${GREEN}Connecting to ${vpn_host}...${NC}\n"
  # The final response accepts VPN banners that use a y/n acknowledgement.
  printf '%s\n%s%s\ny\n' "$vpn_username" "$vpn_password" "$yubi_code" | "$VPN_BIN" -s connect "$vpn_host"
  unset vpn_password yubi_code

  if [[ $(vpn_state) == *'state: Connected'* ]]; then
    echo -e "${GREEN}Connected to VPN.${NC}\n"
  else
    echo -e "${RED}VPN did not connect.${NC}\n"
    exit 1
  fi
elif [[ $status == *'state: Connected'* ]]; then
  echo -e "${GREEN}VPN is connected.${NC}"
  read -r -p 'Disconnect? (y/n) ' input

  if [[ "$input" == y ]]; then
    "$VPN_BIN" disconnect
    if [[ $(vpn_state) == *'state: Disconnected'* ]]; then
      echo -e "${RED}Disconnected from VPN.${NC}\n"
    else
      echo -e "${RED}VPN did not disconnect.${NC}\n"
      exit 1
    fi
  fi
else
  echo -e "${RED}Could not determine VPN state.${NC}"
  exit 1
fi
