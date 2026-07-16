# Cisco Secure Client CLI Helper for macOS

A small **macOS-only** Bash helper for Cisco Secure Client VPNs that authenticate with a username, password, and appended YubiKey one-time code.

By default it prompts for credentials on each connection. Users can optionally store one username and password in their local macOS Keychain.

## Requirements

- macOS
- Cisco Secure Client, including its command-line client
- A VPN profile that accepts username, password plus YubiKey code, and a `y` response to any login banner

## Install

Clone the repository, then copy the helper to your home directory:

```bash
cp .vpnStatus.sh ~/.vpnStatus.sh
chmod 700 ~/.vpnStatus.sh
printf "alias vpn='~/.vpnStatus.sh'\n" >> ~/.zshrc
source ~/.zshrc
```

For Bash, replace `.zshrc` with `.bashrc`.

## Connect or disconnect

Run:

```bash
vpn
```

When disconnected, enter your VPN server, username, password, and YubiKey code. The script appends the YubiKey code to the password only in memory before sending the login responses to Cisco Secure Client.

When connected, the command offers to disconnect.

## Optional macOS Keychain storage

To store one VPN username and password in the local login Keychain, run:

```bash
vpn --setup-keychain
```

Enter the base password only; do not append the YubiKey code. The script creates separate Keychain entries for the username and password, without granting automatic application access.

Connect with the stored credentials:

```bash
vpn --keychain
```

Enter the VPN server and YubiKey code when prompted. macOS may ask for permission to retrieve each Keychain entry. Choose **Allow Once** to avoid permanently granting the script access.

## Security

- Do not add passwords, YubiKey codes, server names, usernames, or other private details to this repository.
- The script does not write credentials to disk. Keychain mode stores credentials in the local login Keychain; prompt mode stores them only in memory. Both modes clear the password and YubiKey variables after the connection command.
- Avoid shell history entries that include secrets.

## Limitations

- macOS only. The client paths and behavior are specific to Cisco's macOS client.
- Browser-based/SAML authentication is not supported by the Cisco CLI. Use the Cisco Secure Client app for that flow.
