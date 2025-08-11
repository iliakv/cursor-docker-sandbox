# Cursor AppImage in Docker with Controlled File System Access

This setup runs the **Cursor** editor inside a Docker container with controlled read-only and read-write mounts, software OpenGL rendering, and D-Bus support.  
It is **config-driven**, so you only need to edit `config.sh` to adjust paths and options for each user or environment.

---

## 📂 Folder Structure
```
.
├── config.sh                         # Main configuration file (edit this only)
├── build.sh                          # Build the Docker image
├── start.sh                          # Start the container, apply mounts from config.sh
├── download_latest_cursor_AppImage.sh# Fetch the latest Cursor AppImage from official source
├── Dockerfile                        # Image definition
├── entry.sh                          # Entrypoint (root → user)
├── run_cursor.sh                     # Starts Cursor AppImage inside container
├── verify_fs.sh                      # Verifies RO/RW/exec permissions inside container
└── README.md                         # This file
```

---

## ⚙️ Configuration
Edit **`config.sh`** to set:
- **IMAGE_NAME** – Docker image tag.
- **APPIMAGE_HOST_DIR / APPIMAGE_FILENAME** – Where the Cursor AppImage lives on the host.
- **RO_BINDS** – Host → container mappings mounted **read-only**.
- **RW_BINDS** – Host → container mappings mounted **read-write**.
- **PERSIST_BASE** – Host directory for persistent config/cache.
- **CONTAINER_UID / CONTAINER_GID** – UID/GID inside container.
- **USE_X11** – Set `1` to use X11 forwarding.

Example:
```bash
RO_BINDS="
/mnt/share->/mnt/share
/home/ilia/cursor->/appimage
"

RW_BINDS="
/mnt/share/ilia->/mnt/share/ilia
"
```

---

## ⬇️ Download Latest Cursor AppImage
Before building, get the newest Cursor AppImage into your configured folder:
```bash
./download_latest_cursor_AppImage.sh
```
This will:
- Fetch the latest stable Cursor AppImage
- Save it to `${APPIMAGE_HOST_DIR}/${APPIMAGE_FILENAME}`

---

## 🔨 Build
Run:
```bash
./build.sh
```
This will:
- Create persistent directories (`$PERSIST_BASE/config`, `cache`, `cursor`)
- Build the Docker image with all dependencies installed

---

## 🚀 Start
Run:
```bash
./start.sh
```
This will:
1. Generate RO/RW mounts from `config.sh`
2. Mount them into the container
3. Run **verify_fs.sh** to confirm permissions
4. Launch Cursor AppImage

### Optional Flags
- **`--clean`**  
  Moves persistent directories to a `.bak-<timestamp>` backup before starting fresh.
  ```bash
  ./start.sh --clean
  ```
- **`--grant-acl`**  
  Grants container user (`CONTAINER_UID`) RWX permissions on host RW dirs **without changing ownership**. Requires `setfacl` on the host.
  ```bash
  ./start.sh --grant-acl
  ```

You can combine:
```bash
./start.sh --clean --grant-acl
```

---

## 🔍 Permission Verification
The container runs `verify_fs.sh` on startup:
- **RO** mounts → Write should fail
- **RW** mounts → Write/read/delete should succeed
- **Exec** check → Scripts in exec-enabled tmpfs should run
- Fails fast if any check doesn't match expectations

Example output:
```
== FS verify: RO must fail to write, RW must succeed; exec must succeed ==
RO check: /mnt/share ... OK (write blocked)
RO check: /home/ilia/cursor ... OK (write blocked)
RW check: /mnt/share/ilia ... OK (write succeeded)
Exec check: /tmpfs_exec ... OK (script executed)
```

---

## 🧹 Cleanup
This setup uses `--rm` in `docker run`, so the container is removed on exit.  
Persistent files remain in `${PERSIST_BASE}`.

To completely remove state:
```bash
rm -rf "${PERSIST_BASE}"
```

---

## 📌 Notes
- Requires Docker on host with X11 access (`xhost +local:docker` is run automatically when `USE_X11=1`)
- Host RW dirs must allow the container UID to write; use `--grant-acl` or adjust permissions manually
- You can easily change the AppImage path in `config.sh` without touching any other script
- Works with **software rendering**, no GPU passthrough required

---

**Tagline:**  
> Run Cursor in a secure, configurable Docker sandbox with controlled filesystem access and minimal host exposure.

