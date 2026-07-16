#!/bin/bash

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
KEYCHAIN_USERNAME_SERVICE='cisco-secure-client-cli-helper-username'
KEYCHAIN_PASSWORD_SERVICE='cisco-secure-client-cli-helper-password'

usage() {
  cat <<'EOF'
Usage:
  vpn                    Prompt for username and password on every connection.
  vpn --setup-keychain   Store one username and password in the macOS Keychain.
  vpn --keychain         Retrieve the stored username and password from Keychain.
EOF
}

setup_keychain() {
  read -r -p 'Username to store in Keychain: ' keychain_username
  if [[ -z "$keychain_username" ]]; then
    echo -e "${RED}A username is required.${NC}"
    exit 1
  fi

  # -T '' prevents automatic access by applications, including this script.
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
case "${1:-}" in
  --setup-keychain)
    setup_keychain
    exit 0
    ;;
  --keychain)
    use_keychain=true
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  '')
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

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
  read -r -p 'VPN server: ' vpn_host

  if "$use_keychain"; then
    if ! vpn_username=$(security find-generic-password -s "$KEYCHAIN_USERNAME_SERVICE" -w); then
      echo -e "${RED}Could not retrieve the VPN username from Keychain.${NC}"
      exit 1
    fi
    if ! vpn_password=$(security find-generic-password -s "$KEYCHAIN_PASSWORD_SERVICE" -w); then
      echo -e "${RED}Could not retrieve the VPN password from Keychain.${NC}"
      exit 1
    fi
  else
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
