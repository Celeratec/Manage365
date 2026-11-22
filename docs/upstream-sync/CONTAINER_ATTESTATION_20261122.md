# Container attestation / trust — 2026-11-22

Selective CIPP intake on `clint/upstream-container-attestation`. Fork-only; never PR CyberDrain/CIPP.

**Base:** `main` (independent of auth #86 / TGS #88).

| SHA | Change | Status |
|-----|--------|--------|
| `3dca57955` | Pin container actions + attest build provenance (dev/nightly/release) | **Adapt** — Manage365 already pins actions; add id-token/attestations + attest step to `release-container.yml` / `preview-container.yml` only (no CIPP `dev-container` / `nightly-container` workflows here) |
| `d985563c9` | Attest preview container provenance | **Adapt** — same preview workflow |
| `38db661f9` | Verify Sigstore attestation before auto-update (CIPPSharp + Test-CIPPContainerAttestation + UI) | Planned |
| `eb42820af` | Verify channel image attestation always | Planned |
| `6defe6933` | Verify attestation on manual update check | Planned |
| `b50961f43` | Pin verified channel image digests + shared helpers | Planned |
| `1853aa854` | Label channel trust level in UI | Planned |

## Adapt notes

- Do not add CIPP-only `dev-container.yml` / `nightly-container.yml` unless product asks; attestation identity for those tags still documents CIPP paths in `Test-CIPPContainerAttestation`.
- Expected repo identity is derived from the GHCR image path (`owner/repo`), so Celeratec/Manage365 images verify against themselves.
- Rebuild `CIPPSharp.dll` after adding `SigstoreVerify.cs` (do not check in a stale binary mismatch).
- Docs: port `verifying-container-images.md` under Manage365 user-docs; keep Manage365 branding where pages already diverge.
- Baseline stays **11.2.1**.

## Verify

- OpenAPI regen if endpoints change.
- Pester: SigstoreVerify, Test-CIPPContainerAttestation, container update/attestation suites.
- Vitest: `CippContainerManagement.test.jsx`.
- Aikido on first-party changes.
