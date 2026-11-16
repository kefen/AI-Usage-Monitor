# User Guide

Codex Quota Sidebar by KEFEN. English / 简体中文 / 繁體中文 are available
from the upper-right language selector. Screenshots below are actual rendered
Windows UI using test fixtures, not real account data.

## 1. Download The Right Package

Open [Releases](https://github.com/kefen/codex-quota-sidebar/releases).
For Windows 10/11 x64, download the asset ending in
`Windows-0.12.3-x64-Setup.exe`, plus its SHA256 file if verifying integrity.
Chrome uses the separate `Chrome-0.3.1.zip`. Mac has experimental architecture-specific DMGs (see below).
The unsigned Windows executable may trigger an unknown-publisher warning.
Verify its origin; never disable security software to get around a detection.

## 2. Check The Environment

Install the official Microsoft Store Codex app, sign in, and confirm it can chat.
Run this tool's installer as your normal user, not as administrator.
Choose **Continue** after the environment check succeeds.

![Environment check](screenshots/setup-environment.png)

If Codex is missing, install/open the official app first. If an earlier meter is
running, use the offered graceful stop action, then retry. This stops the meter,
not Codex. Do not install a second copy merely to bypass a running-copy warning.

## 3. Choose The Installation Folder

Use **Browse** or the recommended location. For an upgrade, retain the detected
original folder to preserve settings. Having Codex and this tool on the same
drive is convenient but not required. Do not choose WindowsApps, the Codex
application directory, a protected system folder or a folder owned by another app.
Choose **Check and continue**.

![Installation folder with a sample path](screenshots/setup-location.png)

## 4. Choose Sidebar Items

Select quota, Token and optional subscription fields, then **Install**.
These choices can be changed later through **Sidebar content**.
Selecting renewal-date visibility alone does not create a renewal date.

![Sidebar display choices](screenshots/windows-install.png)

## 5. Connect To Codex

After installation, choose **Connect Codex**. Installation success is not
connection success. Review the local debugging permission before agreeing.
CDP access is broader than reading quota; do not enable it on an untrusted machine.

![Connection permission](screenshots/connection-consent.png)

If Codex is already running without the required local debugging interface,
the tool asks for a restart. Save your work first. Confirm only when ready;
canceling must not force Codex to close.

![Explicit restart confirmation](screenshots/restart-confirmation.png)

## 6. Read The Overview And Sidebar

**Connected** means the sidebar was attached. The overview displays available
quota windows and Token figures, with the daily data date and separate sync times.
Missing data is shown as unavailable rather than zero.

![Connected overview with sample data](screenshots/windows-status.png)

The narrow desktop rail shows selected items next to Codex navigation. Hover
for complete dates, exact values, freshness and provenance. The following image
demonstrates the actual component in a **test shell**, not the full Codex app.

![Actual sidebar component in a generated Codex-style workspace](screenshots/codex-sidebar-overview.png)

This generated demonstration shows placement and appearance with synthetic
data. It is not a live Codex screenshot and does not expose user conversations,
project names or account details. The narrow sidebar itself is rendered by
this project's actual component.

## 7. Settings And Daily Use

| Control | Result |
| --- | --- |
| Open Codex | Requests activation of the Codex window |
| Reconnect | Retries attachment; restart still requires confirmation |
| Sidebar content | Changes visible metrics; save to apply |
| Codex subscription record | Optional manual plan and renewal/expiry dates |
| Diagnostics and help | Explains troubleshooting, then exports sanitized diagnostics for manual submission |
| About project | Shows project details and a link to GitHub |
| Data and settings | Backs up/restores settings or clears local observation history |
| Window close button | Hides the panel while monitoring continues in the tray |
| Exit software | Stops the meter; leaves Codex open |

Subscription records are optional and local. You do not need to buy a membership
for this tool. Choose your actual Codex plan and purchase date, or manually enter
renewal/expiry. Estimated monthly/annual dates are not verified billing dates.
Free, enterprise and organization-managed plans may not have an individual renewal.
Skip the record when it does not apply. It never changes official subscription rights.

Saving keeps you on the same page. The button briefly shows success, then returns
to Save. While connected, sidebar settings apply automatically; no reconnect is
needed. Unsaved edits are confirmed before leaving a page. Official Codex controls
always take precedence: the sidebar scrolls when space is limited and collapses
only when space is severely constrained.

## macOS Experimental Installation

Choose `arm64` for Apple Silicon or `x86_64` for Intel. Open the DMG, drag
Codex Quota Sidebar into Applications, then open it. Keep the application there;
do not run from the mounted disk image. The first run creates its private payload
in `~/Library/Application Support/CodexSidebarMeter` and asks for connection consent.
The app is ad-hoc signed, not Developer ID signed or notarized. macOS may block it;
verify the repository and checksum before using System Settings > Privacy & Security
to approve it. Do not disable Gatekeeper or run blanket quarantine-removal commands.

Install the official Codex desktop client separately and sign in first. A supported
client must have bundle ID `com.openai.codex`, the verified OpenAI publisher, and a
bundled CLI. The official audited image now names it ChatGPT.app. The currently
audited image is ARM-only: the Intel companion needs a separately compatible Intel
official client. Its existence/availability is not guaranteed by this project.
If a running client lacks local debugging, save work and fully quit it before
reconnecting. Mac never silently terminates the official app. Real-account
connection acceptance remains pending on both Mac architectures.

The desktop language is saved and applied to sidebar labels. Settings backup and
restore do not contain authentication or connection permission, but do contain
manual subscription dates. Treat backups as private.

Quota refresh is approximately every minute; Token activity is read at startup
and hourly. Daily data may refer to yesterday or the most recent available date.
The date is always important. Calendar-week totals and quota-reset windows differ.

## 8. Browser Companion

1. Keep the Windows desktop monitor running and connected.
2. Extract the Chrome ZIP into a permanent folder.
3. Open `chrome://extensions`, enable Developer mode, then **Load unpacked**.
4. Select that folder and copy the extension ID.
5. From the desktop tool's installed directory, run the registration command
   in [browser setup](../browser/README.md), using that exact ID.
6. Click the extension toolbar button to open Chrome's side panel.

![Chrome side panel](screenshots/chrome-panel.png)

This reads local snapshots, not your browser's ChatGPT session or cookies.
Changing the unpacked folder may change the extension ID and require registration
again. The host now uses `org.kefen.codex_quota_sidebar`; upgrade the desktop and
extension together and follow [migration steps](../browser/README.md#upgrading-from-earlier-versions).

## Troubleshooting

| Symptom | Next step |
| --- | --- |
| Environment check fails | Verify official Codex opens under the same Windows account |
| Old version is running | Exit the old meter via its UI/tray, then retry installation |
| Installed but not connected | Select Connect Codex; review consent and restart prompt |
| E_RUNNING_WITHOUT_CDP | Save work, reconnect and explicitly approve a restart |
| Missing or stale Token values | Check the data date, account and hourly source refresh |
| Renewal date missing | Enable a valid subscription record as well as its sidebar visibility |
| Sidebar absent | Confirm Codex navigation is visible; reconnect; export diagnostics |
| Browser reports missing host | Register the exact extension ID under the same user |
| Browser data stale | Start the desktop monitor and confirm it is connected |

Do not post raw logs, credentials, chat screenshots or private paths in public
issues. Prefer the built-in diagnostic export. Update compatibility can change
when Codex changes its internal interface.

## Upgrade And Uninstall

Upgrade in the original installation directory. The installer checks ownership
and offers to stop its own running monitor; it does not force-close unrelated apps.
Unregister the browser helper first if used. Exit the meter, then run
`Uninstall.cmd` in the install directory. Personal settings and modified files
are retained. Stopping/uninstalling the meter does not close Codex's debug port:
fully quit Codex and reopen it from the official entry.
