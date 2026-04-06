# Claude Code Leak — Security Scanner

<center>
<img src="img/title.png" alt="title" />
</center>

### [EN FRANCAIS ICI](README_fr.md)

## What Happened

On **March 31, 2026**, Anthropic accidentally shipped the entire source code of Claude Code
to the public npm registry. The cause was mundane: the Bun runtime generates source map
files (`.map`) by default, and someone forgot to exclude them in `.npmignore`. That single
omission bundled a `.map` file into version `2.1.88` of `@anthropic-ai/claude-code`, which
pointed to a zip archive on Anthropic's own Cloudflare R2 storage bucket — publicly
accessible. Security researcher Chaofan Shou spotted it within minutes.

The zip contained **512,000 lines of TypeScript across 1,906 files**: the full agentic
harness, internal feature flags, unreleased roadmap items, internal model codenames, and
system prompts. It was mirrored and forked across GitHub tens of thousands of times before
Anthropic could respond. Anthropic confirmed it was human error, not a targeted breach, and
that no customer data or credentials were exposed.

This was the **second such leak in 13 months** — a near-identical incident occurred in
February 2025.

---

## Why a Security Scan Is Required

The source code leak itself was embarrassing but not directly dangerous to end users.
**What makes this a security incident for developers** is what happened at the same time.

### Concurrent npm Supply Chain Attack

Between **00:21 and 03:29 UTC on March 31, 2026**, a separate, unrelated attack trojanized
the widely-used `axios` HTTP library on npm. Two malicious versions were published:

| Package | Malicious Version |
|---------|------------------|
| axios   | 1.14.1           |
| axios   | 0.30.4           |

Both versions included a hidden dependency called `plain-crypto-js` that contained a
**cross-platform Remote Access Trojan (RAT)**.

Any developer who ran `npm install` or updated Claude Code via npm during that 3-hour window
may have pulled in the trojanized axios. Because Claude Code was a high-profile npm package
actively being discussed that day, it became an effective lure.

### What the Malware Does

**Vidar Stealer** — An infostealer that exfiltrates:
- Saved browser passwords and cookies
- Credit card data stored in browsers
- Cryptocurrency wallet files
- 2FA authenticator databases
- FTP and SSH credentials
- Discord tokens

**GhostSocks** — A SOCKS5 backconnect proxy that turns the infected machine into
exit-node infrastructure, routing other attackers' traffic through your IP. Your machine
becomes a persistent tool for further attacks even after Vidar has finished its job.

### Secondary Threat: Malicious GitHub Repositories

Following the leak, threat actors published fake "leaked Claude Code source" repositories on
GitHub. These were disguised as working forks with "unlocked enterprise features" but
contained a Rust-based dropper (`ClaudeCode_x64.exe`) that deployed both Vidar and
GhostSocks. At least one of these repos reached **793 forks and 564 stars** before action
was taken.

**Do not clone or run any unofficial Claude Code fork from this period.**

---

## What to Do If You Are Compromised

If the scan finds `axios 1.14.1`, `axios 0.30.4`, or `plain-crypto-js` in any of your
lockfiles:

1. **Treat the machine as fully compromised** — do not attempt to clean in place
2. **Rotate all credentials immediately**: API keys, SSH keys, tokens, passwords, secrets
3. **Revoke and reissue** any cloud provider credentials (AWS, Azure, GCP, etc.)
4. **Notify your team** if the machine had access to shared infrastructure
5. **Consider a clean OS reinstall** — the RAT and proxy may persist across partial cleanup

---

## Switching to the Safe Installer

Anthropic has designated the native installer as the recommended method going forward.
It uses a standalone binary and does not rely on the npm dependency chain.

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

---

## Usage — Windows (PowerShell 7)

### Requirements
- PowerShell 7+
- Claude Code installed (optional — the script checks for it)

### Setup

Save [Test-ClaudeCodeSecurity.ps1](scripts/Test-ClaudeCodeSecurity.ps1) to a location of your choice.

### Run

```powershell
# Scan a specific projects folder
.\Test-ClaudeCodeSecurity.ps1 -ProjectsRoot "C:\Projects"

# Scan your entire user profile
.\Test-ClaudeCodeSecurity.ps1 -ProjectsRoot $HOME
```

### What It Checks

1. Whether Claude Code is installed and whether it was installed via npm
2. All `package-lock.json`, `yarn.lock`, and `bun.lockb` files under the given path
3. Each lockfile for `axios 1.14.1`, `axios 0.30.4`, and `plain-crypto-js`

### Output

- `[OK]` — clean
- `[WARN]` — attention recommended
- `[!!!]` — immediate action required

---

## Usage — Linux (Bash)

### Requirements

- Bash 4+ (standard on any modern Linux distribution)
- `find`, `grep` — present by default everywhere

### Setup

Save [check_claude_security.sh](scripts/check_claude_security.sh) to a location of your choice.


```bash
chmod +x check_claude_security.sh
```

### Run

```bash
# Scan a specific projects folder
./check_claude_security.sh /home/user/projects

# Scan your entire home directory
./check_claude_security.sh $HOME
```

### What It Checks

Same logic as the PowerShell version:

1. Whether `claude` is on `PATH` and whether it resolves to an npm-based install
2. All `package-lock.json`, `yarn.lock`, and `bun.lockb` files under the given path
3. Each lockfile for `axios 1.14.1`, `axios 0.30.4`, and `plain-crypto-js`

### Output

- `[OK]` — clean
- `[WARN]` — attention recommended
- `[!!!]` — immediate action required

---

## A Note on `bun.lockb`

Bun's lockfile is a binary format. Both scripts scan it using string matching against raw
file content, which catches plaintext strings embedded in the binary. This is a heuristic,
not a proper bun lockfile parser. For full coverage on bun projects, check `bun.lock` (the
text-format lockfile) if available alongside `bun.lockb`.

---

## References

- [The Hacker News — Claude Code supply chain attack](https://thehackernews.com/2026/04/claude-code-tleaked-via-npm-packaging.html)
- [The Register — Claude Code source exposed](https://www.theregister.com/2026/03/31/anthropic_claude_code_source_code/)
- [The Register — Trojanized fake leak repos](https://www.theregister.com/2026/04/02/trojanized_claude_code_leak_github/)
- [VentureBeat — Full breakdown](https://venturebeat.com/technology/claude-codes-source-code-appears-to-have-leaked-heres-what-we-know)
