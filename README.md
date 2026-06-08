# Junior Backend Exercise — dasel v3.3.1

Package `dasel` v3.3.1 with Melange, build a container image with apko, and fix CVE-2026-33320.

**Prerequisites:** Docker. All build steps run inside containers — no local melange/apko install needed. Run all commands from the repo root on linux/amd64 (or Docker Desktop with linux/amd64 emulation).

---

## Build & Test

**Step 0 — Generate signing key (one-time)**
```bash
docker run --rm -v "/${PWD}":/work cgr.dev/chainguard/melange keygen
```

**Step 1 — Build the package**
```bash
docker run --privileged --rm -v "/${PWD}":/work cgr.dev/chainguard/melange build melange/dasel.yaml --arch amd64 --signing-key melange.rsa
```
Output: `packages/x86_64/dasel-3.3.1-r1.apk`

**Step 2 — Test the package**
```bash
docker run --privileged --rm -v "/${PWD}":/work cgr.dev/chainguard/melange test melange/dasel.yaml --arch amd64 --repository-append //work/packages --keyring-append //work/melange.rsa.pub
```

**Step 3 — Build the image**
```bash
docker run --rm -v "/${PWD}":/work cgr.dev/chainguard/apko build apko/dasel.yaml dasel-image:latest dasel-image.tar --arch amd64 -k melange.rsa.pub
```
Output: `dasel-image.tar`. The `@local ./packages` repository in `apko/dasel.yaml` makes apko install the APK you built in Step 1. `-k` lets apko trust the Melange signing key. apko appends the arch to the tag, so the loaded image is `dasel-image:latest-amd64`.

**Step 4 — Load the image**
```bash
docker load --input dasel-image.tar
```

**Step 5 — Run image tests**
```bash
bash tests/test.sh
```
Four tests: binary present and runnable, JSON query via stdin, architecture is amd64, CVE-2026-33320 patch rejects a YAML alias bomb.

---

## CVE-2026-33320

`melange/CVE-2026-33320.patch` adds two guards to `parsing/yaml/yaml_reader.go`:
- `maxExpansionDepth = 32` — rejects alias chains deeper than 32 levels
- `maxExpansionBudget = 100` — rejects documents with more than 100 total alias resolutions

Both return a non-zero exit code with a message containing `yaml expansion`. Test 4 in `tests/test.sh` verifies this.

---

## Submission Note

Commands run: `melange keygen` → `melange build` → `melange test` → `apko build` → `docker load` → `tests/test.sh`

All steps passed on linux/amd64.

**What I'd improve with more time:**
- Parameterize the image tag and tarball name in `test.sh`
