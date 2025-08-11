FROM ubuntu:22.04

# 1) Base tools
RUN apt-get update && apt-get install -y \
    ca-certificates curl gnupg gosu software-properties-common \
 && apt-get clean

# 2) Electron/GTK deps
RUN apt-get update && apt-get install -y \
    libgtk-3-0 libasound2 libnss3 libxss1 libxtst6 libatk-bridge2.0-0 \
    libx11-xcb1 libxkbcommon0 x11-utils xdg-utils \
    libcanberra-gtk-module libcanberra-gtk3-module \
 && apt-get clean

# 3) D-Bus (system + X helpers)
RUN apt-get update && apt-get install -y \
    dbus dbus-x11 \
 && apt-get clean

# 4) Software GL libs (ANGLE expects these)
RUN apt-get update && apt-get install -y \
    mesa-utils libgl1 libglx-mesa0 libgl1-mesa-dri \
    libegl1 libgbm1 libgles2 \
    libxcb-render0 libxcb-shm0 \
 && apt-get clean

# 5) Firefox from Mozilla PPA (non-snap) + CLI fallbacks to satisfy xdg-open
RUN add-apt-repository -y ppa:mozillateam/ppa \
 && printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501\n' \
      > /etc/apt/preferences.d/mozilla-firefox \
 && apt-get update && apt-get install -y --no-install-recommends \
    firefox links2 elinks lynx w3m \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 6) AppImage / FUSE
RUN apt-get update && apt-get install -y \
    fuse libfuse2 \
 && apt-get clean

# Unprivileged user
RUN useradd -m -u 1000 -s /bin/bash cursoruser
WORKDIR /home/cursoruser

# Scripts
COPY entry.sh /entry.sh
COPY verify_fs.sh /home/cursoruser/verify_fs.sh
COPY run_cursor.sh /home/cursoruser/run_cursor.sh
RUN chmod +x /entry.sh /home/cursoruser/run_cursor.sh /home/cursoruser/verify_fs.sh \
 && chown cursoruser:cursoruser /home/cursoruser/run_cursor.sh /home/cursoruser/verify_fs.sh

ENTRYPOINT ["/entry.sh"]
