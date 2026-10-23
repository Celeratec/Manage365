# eMudhra intermediate CA compromise (Oct 2026)

Public references:

- [Incident summary](https://emudhra.we-have-a-problem.com/)
- [Cisco Talos](https://blog.talosintelligence.com/compromised-intermediate-certificates/)
- [Ubuntu fixes](https://ubuntu.com/blog/emudhra-ca-compromise-fixes-available)

Eight eMudhra intermediate CAs had recoverable private keys. Browsers block them via OneCRL/CRLSets; many non-browser clients still trust them until the OS or bundled CA store is updated.

## Manage365 exposure (audit summary)

| Area | Result |
| --- | --- |
| Repo committed CA bundles / pinned TLS certs | None (Proxyman dev bundle is gitignored under `build/config/`) |
| Production `manage365.celeratec.cloud` | DigiCert / GeoTrust TLS RSA CA G1 (not eMudhra) |
| Azure default host `cippbefno.azurewebsites.net` | Microsoft TLS (not eMudhra) |
| Staging `manage36533arg.azurewebsites.net` | Microsoft TLS (not eMudhra) |
| Container image registry `ghcr.io` | Sectigo (not eMudhra) |
| Application runtime | .NET on distroless **Craft** (Azure Linux); no Go services in this repo |
| Docker build Node stage | `node:22.23.4-slim` (patched Node trust store) |

No owned TLS certificate in this stack chains to eMudhra or emSign. Reissue is not required for Manage365 hosts.

## Trust stores to keep current

| Component | Patched baseline (Oct 2026) | Notes |
| --- | --- | --- |
| Ubuntu `ca-certificates` | `20260816ubuntu0.<release>.1` | GitHub Actions `ubuntu-latest` |
| NSS (`libnss3`) | 3.131.1+ | Firefox/Chromium on Linux |
| Homebrew `ca-certificates` | 2026-10-20+ | Used by Homebrew `curl`, not macOS `/usr/bin/curl` |
| Python `certifi` | 2026.10.19+ | |
| Node.js | 22.23.4+, 24.22.1+, 26.12.1+ | Bundled roots in `tls.rootCertificates` |
| Go | 1.27.3+ or 1.26.10+ | CVE-2026-111943 |
| Java `cacerts` | OpenJDK CPU listed on incident site | **Manual** on servers that run Java TLS clients |
| Craft / Azure Linux runtime | Rebuild image after vendor base updates | Distroless; trust store comes from base image |

### macOS developer workstations

Apple distrusts the compromised intermediates for Safari/Keychain-backed TLS, but **Command Line Tools** (`/usr/bin/curl`, `git`, system `python3`) still read `/etc/ssl/cert.pem`, which may include **AAA Certificate Services** and **emSign ECC Root CA - G3** until Apple updates that file or you apply the [documented awk filter](https://emudhra.we-have-a-problem.com/) (backup first).

Homebrew Python `certifi` and Homebrew `curl --cacert $(brew --prefix)/etc/ca-certificates/cert.pem` behave correctly after upgrading `ca-certificates`.

If multiple Node installs exist (for example nvm **and** Homebrew), ensure the Node version on your `PATH` meets the patched baseline above.

## Verification

From the repo root:

```powershell
./scripts/security/Test-EmudhraTrustStores.ps1
```

Optional host list (production defaults included):

```powershell
./scripts/security/Test-EmudhraTrustStores.ps1 -Hosts manage365.celeratec.cloud,login.microsoftonline.com
```

**Expected:** probe URLs under `*.we-have-a-problem.com` should **fail** TLS verification. HTTP 200 from `/usr/bin/curl` on macOS indicates an outdated `/etc/ssl/cert.pem`.

## Remediation checklist (no production deploy without approval)

1. Upgrade OS and language runtimes on build agents and workstations.
2. Rebuild and publish a new `ghcr.io/celeratec/manage365` image only after base-image CA updates (if needed) and routine release approval.
3. Run `Test-EmudhraTrustStores.ps1` after changes; confirm Microsoft Graph and Manage365 health endpoints still connect.
4. Java: run vendor `cacerts` update or `dpkg-reconfigure ca-certificates-java` on Debian/Ubuntu hosts.
5. VPN clients, mobile devices, and embedded agents: follow vendor CA updates separately.

## TLS regressions after root removal

Removing Comodo AAA or emSign G3 cross-signs can break legacy sites that still chain through them. If a dependency fails TLS after patching, capture the issuer chain (`openssl s_client -showcerts`) and decide whether to allowlist that host or upgrade the remote service—not re-trust the compromised roots.
