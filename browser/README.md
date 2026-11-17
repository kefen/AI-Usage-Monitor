# Browser companion / KEFEN

Experimental Chrome MV3 side panel. Not a standalone account reader and not an
official OpenAI extension. The desktop monitor must be running and connected.
The CLI account can differ from both the browser and desktop accounts.

Version 0.4.1 follows the approved V3 design. The panel displays the same eleven
choices saved in the desktop companion; it does not keep a competing set of
checkboxes. Selected missing values keep their slots and explain their status.
To change choices, open the desktop companion's Display choices page. Quota bars
and a roomy Token table remain readable at narrow side-panel widths. Three
languages are available; update checks sit left of the language selector.

## Windows setup

## Upgrading From Earlier Versions

The current native-host name is `org.kefen.codex_quota_sidebar`.
The desktop tool and Chrome extension must use the same name.

1. Before upgrading, run the **previous installed version's** registration script
   with `-Remove` and your existing extension ID to unregister its previous host.
2. Upgrade Windows to 0.13.1 and the extension to 0.4.1. Keep the extension
   directory/ID when possible. Do not mix the old extension with the new host.
3. Run the new `browser/Register-Windows.ps1` with the exact current extension ID.
4. Reload the extension and reopen its side panel.

If already upgraded without step 1, register the new host as in step 3.
The earlier registry entry is unused; its cleanup is separate from connecting
the new version. Do not delete unrelated native messaging registrations.
Mac source users similarly unregister using the previous registration script
before switching source versions. Mac real-profile browser registration remains unverified.

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

## macOS Experimental Native Host

After launching the DMG-installed companion, open Terminal in
`~/Library/Application Support/CodexSidebarMeter` and run
`./runtime/node browser/Register-Mac.mjs EXTENSION_ID`;
append `--remove` to unregister. Real-profile registration acceptance on Mac
is still pending; confirm desktop connection before registering.

## Boundaries

- Only `sidePanel` and `nativeMessaging` permissions. No cookies, web host
  permissions or content scripts. Update checks contact the fixed repository's GitHub API; no account data is sent and no network listener is added.
- Helper accepts only a bounded `{ "op": "read" }` request and exact origin.
- Returns whitelisted numeric/date fields, never raw RPC/authentication data.
- Visible panels refresh at most once per minute; token source refreshes hourly.
- Stopped monitor or old snapshot is shown as unavailable, not zero.
- Chrome Web Store publication, signed extension identity, Edge and Safari are
  outside this candidate's verified scope. Unregister before desktop uninstall.
