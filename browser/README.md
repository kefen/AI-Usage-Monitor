# Browser companion / KEFEN

Experimental Chrome MV3 side panel. Not a standalone account reader and not an
official OpenAI extension. The desktop monitor must be running and connected.
The CLI account can differ from both the browser and desktop accounts.

## Windows setup

## Upgrading From Earlier Versions

The current native-host name is `org.kefen.codex_quota_sidebar`.
The desktop tool and Chrome extension must use the same name.

1. Before upgrading, run the **previous installed version's** registration script
   with `-Remove` and your existing extension ID to unregister its previous host.
2. Upgrade Windows to 0.11.1-beta.1 and the extension to 0.2.1. Keep the extension
   directory/ID when possible. Do not mix the old extension with the new host.
3. Run the new `browser/Register-Windows.ps1` with the exact current extension ID.
4. Reload the extension and reopen its side panel.

If already upgraded without step 1, register the new host as in step 3.
The earlier registry entry is unused; its cleanup is separate from connecting
the new version. Do not delete unrelated native messaging registrations.
Mac source users similarly unregister using the previous registration script
before switching source versions. Mac remains unverified.

## First Installation On Windows

1. Install the matching desktop candidate. Start its monitor and confirm data.
2. Extract the Chrome ZIP into a permanent folder. Open `chrome://extensions`,
   enable Developer mode, choose Load unpacked, and select that folder.
3. Copy the extension ID from its details. In PowerShell, open the desktop
   tool's installed directory and run:

```powershell
./browser/Register-Windows.ps1 -ExtensionId YOUR_32_LETTER_EXTENSION_ID
```

4. Click the extension toolbar action to open Chrome's side panel.
   Registration allows only the exact extension ID. Moving the unpacked
   extension may change its ID, requiring explicit re-registration.

Before uninstalling, from the same directory:

```powershell
./browser/Register-Windows.ps1 -ExtensionId YOUR_32_LETTER_EXTENSION_ID -Remove
```

Registration changes only the current user's Chrome Native Messaging registry
entry. It is not performed silently by the installer. The native helper lives
outside the extension ZIP. Do not run registration as administrator.

## Mac source only

After desktop real-machine acceptance, the corresponding command from its
installation directory is `./runtime/node browser/Register-Mac.mjs EXTENSION_ID`;
append `--remove` to unregister. Not validated on macOS yet.

## Boundaries

- Only `sidePanel` and `nativeMessaging` permissions. No cookies, web host
  permissions, content scripts, external service or network listener.
- Helper accepts only a bounded `{ "op": "read" }` request and exact origin.
- Returns whitelisted numeric/date fields, never raw RPC/authentication data.
- Visible panels refresh at most once per minute; token source refreshes hourly.
- Stopped monitor or old snapshot is shown as unavailable, not zero.
- Chrome Web Store publication, signed extension identity, Edge and Safari are
  outside this candidate's verified scope. Unregister before desktop uninstall.
