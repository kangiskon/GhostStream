# GhostStream Privacy Policy — DRAFT, NOT FOR PUBLICATION

**[REPLACE BEFORE PUBLICATION: Legal developer or company name]**  
**[REPLACE BEFORE PUBLICATION: Contact email / support address]**  
**[REPLACE BEFORE PUBLICATION: Effective date]**  
**Applies to:** GhostStream for iPhone, iPad and Apple TV.

> **Owner review required.** This draft reflects observable first-party behavior in the supplied Xcode source, not a verified audit of third-party VLCKit binaries, Apple platform services, provider practices, production traffic, or any service the developer operates separately. Confirm the statements and replace bracketed fields before publishing. Do not submit this draft with placeholders as an active privacy policy.

## What GhostStream does

GhostStream is a media player for streaming sources you choose and configure. The app itself does not include television channels, movies, series, playlists, streaming subscriptions or provider accounts. You should connect only to sources for which you have authorization.

## Information used on your device

When you add a source, the app keeps source names, connection addresses, provider usernames and other playlist/source settings in local app preferences. Provider passwords entered for compatible provider logins are stored in Apple's device Keychain rather than plaintext app preferences; older app builds may have stored them in preferences and are migrated when loaded. Some M3U URLs and provider URLs may themselves contain access tokens or credentials, so treat those URLs as sensitive.

The app also stores local preferences, selected sources, favorites and movie/episode resume positions. To speed up browsing, it caches portions of the provider's channel/movie/series metadata and may cache images. Metadata caches are associated with the saved source and include a seven-day freshness check; they can remain on the device until replaced, cleared, or the app is deleted.

## Connections to streaming providers and third parties

GhostStream contacts the provider or playlist server that you enter to retrieve content and stream media. Those requests necessarily expose connection details such as your IP address to the receiving server and may transmit the provider credentials, token-bearing URLs, playlist requests, channel IDs, or media requests needed to deliver the content. Your provider independently determines how it logs, retains, and uses that data; consult its privacy policy.

Some sources use HTTP rather than HTTPS. On those connections, transmitted requests or account details may be exposed in transit. Use HTTPS-capable sources where possible. The app uses AVPlayer and includes MobileVLCKit/TVVLCKit for media compatibility. **[REPLACE BEFORE PUBLICATION: insert independently verified statement about the bundled VLCKit version's network activity, telemetry and any third-party services.]**

**[REPLACE BEFORE PUBLICATION: describe any developer-operated website/API, support form, server logs, crash analytics, advertising, account system or other collection outside the reviewed app source; if none, confirm and remove this instruction.]**

## Why this information is used

Locally saved source settings allow the app to reconnect; favorites and resume positions retain choices you make; cached metadata improves loading. Provider credentials and stream URLs are used to connect to the services you configure and play their media. **[REPLACE BEFORE PUBLICATION: list any additional collection and purpose found in the production/SDK audit.]**

## Tracking, advertising and disclosure

The reviewed first-party source contains no advertising/analytics integration and does not intentionally use data for cross-app tracking. This does not establish the practices of external streaming providers or the bundled third-party framework binaries. **[REPLACE BEFORE PUBLICATION: confirm actual third-party SDK practices and any developer-operated services before stating a definitive no-tracking/no-collection claim.]**

## Retention, choices and deletion

You can remove an individual source from Saved Sources; this removes its saved provider password from the Keychain and its source-specific library metadata cache. Other local items, such as favorites or playback-resume history, may remain until the app's stored data is cleared. Disconnecting a source does not delete it. To clear ordinary on-device app preferences and caches, delete the app from your device; for the best chance of clearing Keychain credentials as well, first remove the saved sources within GhostStream. Uninstalling an app does not always delete every Keychain item. Deleting local information does not delete accounts or provider-side records; request those directly from the relevant provider.

**[REPLACE BEFORE PUBLICATION: confirm whether the developer runs any accounts/service and supply its actual deletion/contact procedure and retention periods, including support email records if applicable.]**

## Security

The application stores supported provider passwords in Apple Keychain and uses local file protection for its provider metadata snapshot. Security for transfers to third-party providers depends on the provider endpoint and whether it supports HTTPS. No software or network connection can be guaranteed completely secure.

## Children, changes and contact

**[REPLACE BEFORE PUBLICATION: confirm age targeting, child-related processing, jurisdiction-specific notices, how policy changes are announced, a working contact email and the legal entity.]**

For privacy questions contact **[REPLACE BEFORE PUBLICATION: working privacy contact]**.
