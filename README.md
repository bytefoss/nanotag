# nanotag

A **nice!nano v2 (nRF52840)** Fast Pair locator tag that registers in **Google Find Hub**. It builds
and flashes onto a cheap nice!nano / Pro Micro board with the Adafruit **UF2 bootloader** — no J-Link
or external debugger needed.

## Setup at a glance

1. **Install the toolchain** (once) — nRF Connect SDK v3.2.0; see [Install the build tools](#install-the-build-tools-once).
2. **Add credentials** — `cp secrets.env.example secrets.env`, then fill in your Fast Pair model ID + key.
3. **Build** — `source env.sh && ./build.sh`  →  `build/nanotag.uf2`.
4. **Flash** — double-tap the board's RESET, copy the `.uf2` onto the `NICENANO` drive.

Each step is detailed below — starting with the one hard requirement.

## You must bring your own Fast Pair credentials

Google Fast Pair + Find Hub require a Google-registered **Fast Pair Model ID** and its matching
**anti-spoofing private key** (a 32-byte P-256 scalar), issued to device makers enrolled in Google's
Fast Pair program. **This repository contains no model ID and no key** — you supply your own at build
time, and doing so is subject to Google's Fast Pair program terms. Impersonating another product's
identity is out of scope for this project.

Keep those two values **out of the repo** — the build reads them from your environment (e.g. a
gitignored `secrets.env`), and never commit a built `.uf2`, since it embeds the key.

## Prerequisites

- A **nice!nano v2** (or Pro Micro nRF52840) with the Adafruit UF2 bootloader.
- **Build tools:** nRF Connect SDK **v3.2.0** + Zephyr SDK **0.17.4** — install below.
- Your **Fast Pair model ID + anti-spoofing key** (see above).

## Install the build tools (once)

**New here? Use Option A.** It works on macOS, Linux and Windows and installs the whole toolchain for
you. Option B is a manual alternative (macOS/Linux) you can wipe in one command — pick it only if you
prefer that. Both install into `~/ncs`, and `build.sh` works with either.

### Option A — nrfutil  *(recommended; macOS / Linux / Windows)*

| Your system | `<target>` |
|-------------|------------|
| macOS — Apple Silicon | `aarch64-apple-darwin` |
| macOS — Intel | `x86_64-apple-darwin` |
| Linux — x86_64 | `x86_64-unknown-linux-gnu` |
| Linux — ARM64 | `aarch64-unknown-linux-gnu` |
| Windows — x86_64 | `x86_64-pc-windows-msvc` (use `nrfutil.exe`) |

1. **Install nrfutil.** Download the binary for your `<target>` (table above) from
   `https://files.nordicsemi.com/ui/api/v1/download?repoKey=swtools&path=external/nrfutil/executables/<target>/nrfutil&isNativeBrowsing=false`.
   On macOS/Linux: `chmod +x nrfutil` and put it on your `PATH` (don't use sudo).
2. **Install the SDK + toolchain:**
   ```bash
   nrfutil install sdk-manager
   nrfutil sdk-manager install v3.2.0
   ```
3. **Each new terminal**, open a build shell:
   ```bash
   nrfutil sdk-manager toolchain launch --ncs-version v3.2.0 --shell
   source ~/ncs/v3.2.0/zephyr/zephyr-env.sh
   ```
   (Windows: `--terminal` instead of `--shell`, then `…\v3.2.0\zephyr\zephyr-env.cmd`.)
   With Option A, use this shell in place of `source env.sh` in the Build steps.

### Option B — manual install  *(alternative; macOS / Linux, what `env.sh` uses)*

| Your system | `<host>` |
|-------------|----------|
| macOS — Apple Silicon | `macos-aarch64` |
| macOS — Intel | `macos-x86_64` |
| Linux — x86_64 | `linux-x86_64` |
| Linux — ARM64 | `linux-aarch64` |

1. **Host tools:** `brew install cmake ninja dtc` (macOS) or
   `sudo apt install cmake ninja-build device-tree-compiler python3-venv git` (Debian/Ubuntu). Python 3.10+.
2. **West + SDK source:**
   ```bash
   python3 -m venv ~/ncs/.venv && ~/ncs/.venv/bin/pip install west
   cd ~/ncs && ~/ncs/.venv/bin/west init -m https://github.com/nrfconnect/sdk-nrf --mr v3.2.0 v3.2.0 \
     && cd v3.2.0 && ~/ncs/.venv/bin/west update --narrow -o=--depth=1
   ~/ncs/.venv/bin/pip install -r zephyr/scripts/requirements-base.txt \
     -r zephyr/scripts/requirements-build-test.txt -r nrf/scripts/requirements-build.txt
   ```
3. **Compiler (Zephyr SDK 0.17.4):** from the `zephyrproject-rtos/sdk-ng` **v0.17.4** GitHub release, unpack
   `zephyr-sdk-0.17.4_<host>_minimal.tar.xz` into `~/ncs/`, then `toolchain_<host>_arm-zephyr-eabi.tar.xz`
   into `~/ncs/zephyr-sdk-0.17.4/` (your `<host>` is in the table above). Verify both against the release
   `sha256.sum`.
4. **Each new terminal:** `source env.sh` (sets the venv + Zephyr SDK + `ZEPHYR_BASE`, which `make_uf2.py` needs).

**Uninstall:** Option A → `nrfutil sdk-manager uninstall v3.2.0`; Option B → `./cleanup-ncs.sh`.

## Build

**1. Add your credentials** (once) — copy the template and paste your values in (it's gitignored):

```bash
cp secrets.env.example secrets.env
# then edit secrets.env — set FP_MODEL_ID and FP_ANTI_SPOOFING_KEY
```

**2. Build:**

```bash
cd nanotag
source env.sh              # Option B. Option A: enter the nrfutil toolchain shell instead
./build.sh                 # -> build/nanotag.uf2
```

`build.sh` loads `secrets.env` (or your exported `FP_MODEL_ID` / `FP_ANTI_SPOOFING_KEY`), runs the
`west` build for the nice!nano UF2 target, and packs the `.uf2`. It refuses to build if the two
credentials aren't set. (`build.sh` / `env.sh` are bash — on **Windows**, use the nrfutil toolchain
shell and run the commands below directly.)

<details><summary>What build.sh runs (if you'd rather do it by hand)</summary>

```bash
west build -p always -b promicro_nrf52840/nrf52840/uf2 -d build nanotag -- \
  -DSB_CONFIG_BT_FAST_PAIR_MODEL_ID="$FP_MODEL_ID" \
  -DSB_CONFIG_BT_FAST_PAIR_ANTI_SPOOFING_PRIVATE_KEY="\"$FP_ANTI_SPOOFING_KEY\"" \
  -Dnanotag_CONFIG_BT_CTLR_TX_PWR_PLUS_8=y
python3 make_uf2.py
```
The inner quoting `"\"$FP_ANTI_SPOOFING_KEY\""` matters — Kconfig needs the embedded quotes.
`make_uf2.py` must run inside the build shell (it needs `ZEPHYR_BASE` and `intelhex`).
</details>

## Flash

Double-tap the nice!nano RESET button to enter the bootloader — it mounts as a USB drive named
`NICENANO`. Copy `build/nanotag.uf2` onto that drive; the board flashes and reboots into the app
automatically.

- **Windows / Linux:** drag `build/nanotag.uf2` onto the `NICENANO` drive, or `cp` it there.
- **macOS:** use `cp -X` so a `._` metadata file isn't written (it corrupts the copy):
  ```bash
  cp -X build/nanotag.uf2 /Volumes/NICENANO/
  ```

## Verify in Find Hub (Android)

With USB debugging on and `adb` installed:

```bash
adb shell dumpsys activity service com.google.android.gms/.nearby.discovery.service.DiscoveryService \
  | grep -iE 'ModelId|bonded|hasSpot|result='
# expect your model ID, then after pairing: bonded … hasSpot: true
```

The pairing half-sheet only appears when the tag is **very close** to the phone (Fast Pair range
gate), the device is **unpaired**, and Find Hub's offline-finding is enabled. On some phones (e.g.
MIUI) Google Play services also needs the "Display pop-up windows while running in the background"
permission, or no sheet shows.

---

Built on Nordic Semiconductor's `locator_tag` sample from nRF Connect SDK v3.2.0
([source](https://github.com/nrfconnect/sdk-nrf/tree/v3.2.0/samples/bluetooth/fast_pair/locator_tag)),
under `LicenseRef-Nordic-5-Clause`; the files added here use the same terms unless a `LICENSE` file
says otherwise. Not affiliated with or endorsed by Google or Nordic Semiconductor; "Fast Pair" and
"Find Hub" are trademarks of Google LLC.
