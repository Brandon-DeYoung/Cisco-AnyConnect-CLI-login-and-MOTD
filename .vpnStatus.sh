#!/bin/bash

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [[ "$OSTYPE" != darwin* ]]; then
  echo -e "${RED}This script supports macOS only.${NC}"
  exit 1
fi

if [[ -x /opt/cisco/secureclient/bin/vpn ]]; then
  VPN_BIN=/opt/cisco/secureclient/bin/vpn
elif [[ -x /opt/cisco/anyconnect/bin/vpn ]]; then
  VPN_BIN=/opt/cisco/anyconnect/bin/vpn
else
  echo -e "${RED}Cisco Secure Client/AnyConnect CLI was not found.${NC}"
  exit 1
fi

vpn_state() {
  "$VPN_BIN" status 2>&1 | tr -d '\r' | awk '/state: (Connected|Disconnected)/ { state = $0 } END { print state }'
}

status=$(vpn_state)

if [[ $status == *'state: Disconnected'* ]]; then
  read -r -p 'VPN server: ' vpn_host
  read -r -p 'Username: ' vpn_username
  read -r -s -p 'Password: ' vpn_password
  echo
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
