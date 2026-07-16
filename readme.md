# Cisco Secure Client CLI helper for macOS

A small **macOS-only** Bash helper for Cisco Secure Client or Cisco AnyConnect VPNs that authenticate with a username, password, and appended YubiKey one-time code.

It prompts for credentials on each connection and never stores them in the repository or in a credential file.

## Requirements

- macOS
- Cisco Secure Client or Cisco AnyConnect, including its command-line client
- A VPN profile that accepts username, password plus YubiKey code, and a `y` response to any login banner

## Install

Clone the repository, then copy the scripts to your home directory:

```bash
cp .vpnStatus.sh ~/.vpnStatus.sh
cp .motd.sh ~/.motd.sh
chmod 700 ~/.vpnStatus.sh ~/.motd.sh
printf "alias vpn='~/.vpnStatus.sh'\n~/.motd.sh\n" >> ~/.zshrc
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

## Security

- Do not add passwords, YubiKey codes, server names, usernames, or other private details to this repository.
- The script does not write credentials to disk. It clears the password and YubiKey variables after the connection command.
- Avoid shell history entries that include secrets.
- For stronger at-rest protection, adapt the script to retrieve secrets from macOS Keychain rather than creating a plaintext credential file.

## Limitations

- macOS only. The client paths and behavior are specific to Cisco's macOS client.
- Browser-based/SAML authentication is not supported by the Cisco CLI. Use the Cisco Secure Client app for that flow.
