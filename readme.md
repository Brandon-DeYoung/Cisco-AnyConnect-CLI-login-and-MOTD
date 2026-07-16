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
sed -i '' '/^[[:space:]]*alias[[:space:]]\+vpn=/d; $a\
alias vpn='\''~/.vpnStatus.sh'\''
' ~/.zshrc && source ~/.zshrc
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

Enter the VPN server and YubiKey code when prompted. macOS may ask for permission to retrieve each Keychain entry.

After saving credentials, make Keychain mode the default with this command:

```zsh
sed -i '' '/^[[:space:]]*alias[[:space:]]\+vpn=/d; $a\
alias vpn='\''~/.vpnStatus.sh --keychain'\''
' ~/.zshrc && source ~/.zshrc
```

Now run `vpn` to retrieve the stored username and password from Keychain. You will still enter the VPN server and YubiKey code when prompted.

- Choose **Allow Once** to require approval every time the helper retrieves a stored value. This is the recommended setting for a shared, managed, or higher-risk Mac.
- Choose **Always Allow** only at your own risk on a trusted personal Mac. It removes the repeated Keychain prompt for this helper, but an attacker or malicious process running as your macOS user could potentially invoke the trusted Keychain access path without asking again. The YubiKey code is still required for each VPN connection.
- To revoke a previous **Always Allow** choice completely, delete this helper's stored Keychain items and run `vpn --setup-keychain` again if needed:

  ```bash
  security delete-generic-password -s 'cisco-secure-client-cli-helper-username'
  security delete-generic-password -s 'cisco-secure-client-cli-helper-password'
  ```

  These commands delete the helper's two VPN entries from your macOS login Keychain. They do not delete the login Keychain itself or any unrelated passwords.

## Security

- Do not add passwords, YubiKey codes, server names, usernames, or other private details to this repository.
- The script does not write credentials to disk. Keychain mode stores credentials in the local login Keychain; prompt mode stores them only in memory. Both modes clear the password and YubiKey variables after the connection command.
- Avoid shell history entries that include secrets.

## Limitations

- macOS only. The client paths and behavior are specific to Cisco's macOS client.
- Browser-based/SAML authentication is not supported by the Cisco CLI. Use the Cisco Secure Client app for that flow.
