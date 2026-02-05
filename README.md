# LocalPasskey

A macOS passkey manager that stores credentials locally in the Secure Enclave.

![screenshot](https://github.com/malt03/local-passkey-manager/blob/main/readme/screenshot.png?raw=true)

## Motivation

Modern passkey solutions—whether Apple's iCloud Keychain or third-party password managers like 1Password, Bitwarden, and Dashlane—are designed around cloud synchronization. While this provides convenience, it turns your cloud account into a single point of failure for all your passkey-protected services.

### The Single Point of Failure Problem

Many service providers skip TOTP or other second-factor verification when users authenticate with passkeys, treating them as a strong single factor. This seems reasonable—passkeys are phishing-resistant and cryptographically secure.
However, when passkeys are synced to the cloud, this creates a dangerous single point of failure:

1. You enable 2FA on important services (GitHub, Google, etc.)
2. You register passkeys for these services, stored in iCloud Keychain
3. Service providers skip 2FA when you use passkeys
4. An attacker compromises your Apple account
5. **All your passkeys sync to the attacker's device**
6. The attacker now has access to all your services—bypassing the 2FA you carefully set up

The 2FA you configured becomes meaningless because passkeys are treated as sufficient authentication, and those passkeys are only as secure as your cloud account.

### Root Causes

The WebAuthn specification includes Backup Eligible (BE) and Backup State (BS) flags, allowing service providers to distinguish between synced and device-bound credentials. This enables risk-based authentication—for example, requiring additional verification for synced passkeys while trusting device-bound ones.
However, two problems prevent users from benefiting from this design:

1. **Service providers ignore these flags**: Most services treat all passkeys equally, skipping 2FA regardless of whether the credential is device-bound or synced to the cloud.
2. **No local-only option exists**: Neither Apple nor major password managers offer a way to create device-bound passkeys. Users are forced to accept cloud synchronization whether they want it or not.

### The Solution

LocalPasskey addresses the second problem. It stores private keys in the Secure Enclave—they cannot be extracted even with root privileges, and can only be used for signing after biometric verification. No iCloud sync, no cloud backup, no third-party servers. Even if your Apple account is compromised, your passkeys remain secure on your device.
This provides true two-factor authentication in a single step: physical possession of your device (something you have) and biometric verification (something you are).

### A Note to Apple

Ideally, this app wouldn't need to exist. Apple—the company that controls the entire platform, from Secure Enclave to the Passwords app—is in the best position to offer a local-only storage option. Yet they don't. Users who want device-bound passkeys have no choice but to rely on third-party solutions like this one. We hope Apple will eventually provide this option natively, making LocalPasskey obsolete.

### Further Reading

- [Device-Device-Bound vs. Synced Credentials: A Comparative Evaluation of Passkey Authentication](https://arxiv.org/html/2501.07380v1) - University of Oslo
- [Detecting Compromise of Passkey Storage on the Cloud](https://www.microsoft.com/en-us/research/video/detecting-compromise-of-passkey-storage-on-the-cloud/) - Microsoft Research
- [Your (Synced) Passkey is Weak](https://yourpasskeyisweak.com/) - DEFCON 33
- [How Attackers Bypass Synced Passkeys](https://thehackernews.com/2025/10/how-attackers-bypass-synced-passkeys.html) - The Hacker News

## Installation

### Build from Source (Recommended)

Trusting an individual developer to enhance your security is one of the most absurd things you can do. Please read the code, verify its safety, and build it yourself.

You don't need to read much. Just check [the key generation code](https://github.com/malt03/local-passkey-manager/blob/v1.0.0/CredentialProvider/Sources/Registration.swift#L70-L97) and confirm that keys are stored in a way that prevents extraction. Even if there are bugs or malicious code elsewhere, your private keys cannot be leaked as long as the Secure Enclave storage is configured correctly.

### Download from Releases

If you trust my word, you can download the dmg file from the [Releases](https://github.com/malt03/local-passkey-manager/releases) page.

## Setup

1. Open **System Settings** > **General** > **AutoFill & Passwords**
2. Enable **LocalPasskey** under "AutoFill from"

## Known Issues (Apple Platform Bugs)

Due to bugs in Apple's Credential Provider Extension implementation, LocalPasskey cannot accurately convey credential properties to relying parties. **These issues do not affect your security**—your private keys remain protected in the Secure Enclave—but service providers receive incorrect metadata about your credentials:

- **BE/BS flags are forced to 1**: Relying parties cannot distinguish device-bound credentials from cloud-synced ones. [Forum Thread](https://developer.apple.com/forums/thread/813844)
- **AAGUID is overwritten to zeros**: Relying parties cannot identify which passkey manager created a credential. [Forum Thread](https://developer.apple.com/forums/thread/814547)

Both issues have received no response from Apple. If you care about proper passkey implementation on macOS, please boost these threads.

## Build Environment

- macOS 26.2
- Xcode 26.2
