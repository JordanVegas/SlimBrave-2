<div align="center">

# SlimBrave 2
<img src="https://github.com/user-attachments/assets/3e90a996-a74a-4ca1-bea6-0869275bab58" width="200" height="300">
</div>

---
SlimBrave 2 was created because the original creator of SlimBrave stopped responding. SlimBrave 2 presents an updated version of SlimBrave with Linux support and up to date policies.


## Brave Browser Debloater

SlimBrave is a powerful PowerShell script designed for Windows users to streamline their Brave Browser experience by toggling and configuring unwanted features. With SlimBrave, you can easily disable or enable various Brave functionalities, customize settings, and improve privacy.

### Features:

<details>
<summary> Click here to view </summary>

- **Disable Brave Rewards**  
   Brave's reward system.

- **Disable Brave Wallet**  
   Brave's Wallet feature for managing cryptocurrencies.

- **Disable Brave VPN**  
   Brave's VPN feature for "enhanced" privacy.

- **Disable Brave AI Chat**  
   Brave's integrated AI Chat feature.

- **Disable Password Manager**  
   Brave's built-in password manager for website login credentials.

- **Disable Tor**  
   Tor functionality for "anonymous" browsing.

- **Set DNS Over HTTPS Mode**  
   Set the DNS Over HTTPS mode (options include automatic or off) to ensure private browsing with secure DNS queries.

- **Disable Sync**  
   Sync functionality that synchronizes your data across devices.

- **Telemetry & Reporting Controls**  
   Disable metrics reporting, safe browsing reporting, and data collection.

- **Privacy & Security Options**  
   Manage autofill, WebRTC, QUIC protocol, and more.

- **Performance Optimization**  
   Disable background processes and unnecessary features.

- **Enable Do Not Track**  
   Forces Do Not Track header for all browsing.

- **Force Google SafeSearch**  
   Enforces SafeSearch across Google searches.

- **Disable Spellcheck**  
   Disables browser spellcheck functionality.

- **Disable Browser Sign-in**  
   Prevents browser account sign-in.

- **Disable Printing**  
   Disables web page printing capability.

- **Disable Incognito Mode**  
   Blocks private browsing/incognito mode.

- **Disable Default Browser Prompt**  
   Stops Brave from asking to be default browser.

- **Disable Developer Tools**  
   Blocks access to developer tools.

- **Always Open PDF Externally**  
   Forces PDFs to open in external applications.

- **Disable Brave Shields**  
   Turns off Brave's built-in Shields protection.
</details>

---

# How to Run

### Windows

Run the command below in PowerShell:

```ps1
iwr "https://raw.githubusercontent.com/JordanVegas/SlimBrave-2/main/SlimBrave.ps1" -OutFile "SlimBrave.ps1"; .\SlimBrave.ps1
```

---

### Linux (managed policies)

SlimBrave for Linux writes Brave managed policies to `/etc/brave/policies/managed/slimbrave.json`.

```bash
sudo ./SlimBrave.sh --import "./Presets/Maximum Privacy Preset.json"
```

Interactive setup (terminal):

```bash
sudo ./SlimBrave.sh --interactive
```

To export a PowerShell-compatible config from the current policy file:

```bash
sudo ./SlimBrave.sh --export "./SlimBraveSettings.json"
```

## DNS-over-HTTPS (DoH) modes

Brave accepts the following policy values for `DnsOverHttpsMode`:

- `off` — Disable DNS-over-HTTPS.
- `automatic` — Enable DoH with insecure fallback.
- `secure` — Enable DoH without insecure fallback.

To use a custom provider, set `DnsOverHttpsTemplates` to the provider URL (for example, `https://cloudflare-dns.com/dns-query` or `https://dns.quad9.net/dns-query`) alongside `DnsOverHttpsMode=secure`. On Linux, you can supply the same value via `DnsTemplates` in the SlimBrave JSON or pass `--doh-templates` when using `SlimBrave.sh`.

---

## Extras:

<details>
<summary> Presets </summary>


- **Maximum Privacy Preset**  
   - Telemetry: Blocks all reporting (metrics, safe browsing, URL collection, feedback).
   - Privacy: Disables autofill, password manager, sign-in, WebRTC leaks, QUIC, and forces Do Not Track.
   - Brave Features: Kills Rewards, Wallet, VPN, AI Chat, Tor, and Sync.
   - Performance: Disables background processes, recommendations, and bloat.
   - DNS: Uses plain DNS (no HTTPS) to prevent potential logging by DoH providers.
   - Best for: Paranoid users, journalists, activists, or anyone who wants Brave as private as possible.

- **Balanced Privacy Preset**  
   - Telemetry: Blocks all tracking but keeps basic safe browsing.
   - Privacy: Blocks third-party cookies, enables Do Not Track, but allows password manager and autofill for addresses.
   - Brave Features: Disables Rewards, Wallet, VPN, and AI features.
   - Performance: Turns off background services and ads.
   - DNS: Uses automatic DoH (lets Brave choose the fastest secure DNS).
   - Best for: Most users who want privacy but still need convenience features.

- **Performance Focused Preset**  
   - Telemetry: Only blocks metrics and feedback surveys (keeps some safe browsing).
   - Brave Features: Disables Rewards, Wallet, VPN, and AI to declutter the browser.
   - Performance: Kills background processes, shopping features, and promotions.
   - DNS: Automatic DoH for a balance of speed and security.
   - Best for: Users who want a faster, cleaner Brave without extreme privacy tweaks.

- **Developer Preset**  
   - Telemetry: Blocks all reporting.
   - Brave Features: Disables Rewards, Wallet, and VPN but keeps developer tools.
   - Performance: Turns off background services and ads.
   - DNS: Automatic DoH (default secure DNS).
   - Best for: Developers who need dev tools but still want telemetry and ads disabled.

- **Strict Parental Controls Preset**  
   - Privacy: Blocks incognito mode, forces Google SafeSearch, and disables sign-in.
   - Brave Features: Disables Rewards, Wallet, VPN, Tor, and dev tools.
   - DNS: Uses custom DoH (can be set to a family-friendly DNS like Cloudflare for Families).
   - Best for: Parents, schools, or workplaces that need restricted browsing.


</details>



<details>
<summary> Requirements </summary>

- Windows 10/11
- PowerShell
- Administrator privileges
</details>

<details>
<summary>Error "Running Scripts is Disabled on this System"</summary>

### Run this command in PowerShell:

```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```
</details>
<div align="center">
  
---

🌟 **Like this project? Give it a star!** 🌟  
💻  **Want to contribute? PRs are welcome!** 💻 

</div>

### Why SlimBrave Matters

In an era of increasingly bloated browsers, SlimBrave puts **you** back in control:
- 🚀 **Faster browsing** by removing unnecessary features
- 🛡️ **Enhanced privacy** through granular controls
- ⚙️ **Transparent customization** without hidden settings

---

### Future Roadmap
- [x] Add preset configurations (Privacy, Performance, etc.)
- [x] Create backup/restore functionality
- [ ] Add support for Linux/Mac (WIP)

---
<div align="center">
   
[![PayPal Donate](https://img.shields.io/badge/PayPal_Donate-s?style=for-the-badge&logo=paypal&logoColor=black)](https://paypal.me/AggelosMeta)

</div>

<div align="center">
  
Made with ❤️ and PowerShell  

</div>
