# Cursor AppImage in Docker with Controlled File System Access

Run the **Cursor** editor inside a Docker container with controlled read only and read write mounts, software OpenGL, and D-Bus. The setup is **config driven**, edit `config.sh` only.

---

## 📂 Folder Structure

```
.
├── config.sh                          # Main configuration file
├── build.sh                           # Build the Docker image
├── start.sh                           # Start the container, apply mounts from config.sh
├── download_latest_cursor_AppImage.sh # Fetch the latest Cursor AppImage
├── Dockerfile                         # Image definition
├── entry.sh                           # Entrypoint, root to runtime uid
├── run_cursor.sh                      # Launches the Cursor AppImage
├── verify_fs.sh                       # Verifies RO, RW, exec permissions
└── README.md                          # This file
```

---

## ✅ Requirements

* Docker installed on the host
* X11 available on the host
  Local desktop, `DISPLAY=":0"`
  SSH with X forwarding, `ssh -Y`, `DISPLAY="localhost:N.0"`
* Cursor AppImage present at `${APPIMAGE_HOST_DIR}/${APPIMAGE_FILENAME}`
  Fetch via `./download_latest_cursor_AppImage.sh`

---

## ⚙️ Configuration

Edit **`config.sh`** and review:

* `IMAGE_NAME`
* `APPIMAGE_HOST_DIR`, `APPIMAGE_FILENAME`, `APPIMAGE_CONTAINER_DIR`
* `RO_BINDS` list of `host->container` read only paths
* `RW_BINDS` list of `host->container` read write paths
* `PERSIST_BASE` for `.config`, `.cache`, `.cursor`, `.mozilla`
* `CONTAINER_UID`, `CONTAINER_GID` default `1000,1000`
* `USE_X11` set to `1` to enable X11
* `SHM_SIZE` default `1g`

Example:

```bash
RO_BINDS="
/mnt/share->/mnt/share
${APPIMAGE_HOST_DIR}->/appimage
"
RW_BINDS="
/home/${USER}/monitor_cursor->/home/${USER}/monitor_cursor
"
```

Notes:

* `config.sh` in this repo resolves the current user automatically and supports `/home/vault/users/<user>` layouts.
* If you must elevate, prefer `sudo -E` so `DISPLAY` and `XAUTHORITY` are preserved.

---

## ⬇️ Download Latest Cursor AppImage

```bash
./download_latest_cursor_AppImage.sh
```

Saves to `${APPIMAGE_HOST_DIR}/${APPIMAGE_FILENAME}`.

---

## 🔨 Build

```bash
./build.sh
```

Creates `${PERSIST_BASE}/{config,cache,cursor,mozilla}` and builds the image with X11, Mesa software GL, D-Bus, Firefox, FUSE.

---

## 🚀 Start, recommended flags for NFS and SSH

Most reliable command on corporate and NFS setups:

```bash
./start.sh --as-owner --userns-host
```

What these flags do:

* `--as-owner` runs the app as the owner uid,gid of the first RW bind, matching host permissions
* `--userns-host` disables user namespace remapping so the kernel sees the same uid,gid over NFS

Other useful flags:

* `--clean` rotate `${PERSIST_BASE}` dirs to `.bak-<timestamp>`
* `--grant-acl` apply `setfacl` for `CONTAINER_UID` on RW host dirs if the filesystem supports ACLs

Examples:

```bash
./start.sh
./start.sh --as-owner --userns-host
./start.sh --clean --as-owner --userns-host
```

SSH X forwarding tips:

* Run from the same shell where `echo $DISPLAY` prints `localhost:N.0`
* Avoid plain `sudo`; if needed use `sudo -E ./start.sh` to preserve `DISPLAY` and `XAUTHORITY`

---

## 🔍 What happens on start

1. `start.sh` parses bind lists, sets up X11, passes your `DISPLAY`
2. `verify_fs.sh` confirms RO cannot be written, RW can be written, and an exec tmpfs works
3. `run_cursor.sh` starts a session D-Bus and launches the AppImage with software GL

Example output:

```
== FS verify ==
-- RO checks --
RO: /appimage ... OK
-- RW checks --
RW: /home/you/monitor_cursor ... OK
-- EXEC check -- OK
Launching Cursor AppImage with system+session D-Bus and software GL...
```

---

## 🧹 Cleanup

Containers run with `--rm` and are removed on exit.
To erase persisted state:

```bash
rm -rf "${PERSIST_BASE}"
```

---

## 🔧 Troubleshooting

**X11 connection rejected, or platform failed to initialize**
Ensure `DISPLAY=localhost:N.0` and run from the same SSH session. Avoid plain `sudo`; use `sudo -E`.

**On NFS, RW path says permission denied**
Use `./start.sh --as-owner --userns-host` so the kernel sees the same uid,gid as on the host.

**Firefox shows “profile cannot be loaded”**
`.mozilla` is persisted and mounted. After `--clean`, the first run recreates it. If an old unreadable profile exists, remove `${PERSIST_BASE}/mozilla`.

**Corporate proxy blocks login or re‑signs TLS**
Export your proxy on the host so Firefox inside inherits it:

```bash
export HTTPS_PROXY=http://proxy.example.com:3128
export HTTP_PROXY=http://proxy.example.com:3128
export NO_PROXY=localhost,127.0.0.1,::1
./start.sh --as-owner --userns-host
```

If TLS interception errors appear, place your corporate root CA PEM into `${PERSIST_BASE}/certs` and follow certificate import notes in `entry.sh`.

**Firefox prints `glxtest: libpci missing`**
Benign with software GL; the Dockerfile installs `libpci3` and `libpciaccess0` to silence it.

---

## 📌 Notes

* Software rendering only, no GPU passthrough required
* Firefox is installed and registered as default browser, `xdg-open` uses it
* X11 over SSH requires valid `DISPLAY` and `XAUTHORITY` in your shell

---

**Tagline**
Run Cursor in a secure, configurable Docker sandbox, controlled filesystem access, predictable auth and rendering paths.

