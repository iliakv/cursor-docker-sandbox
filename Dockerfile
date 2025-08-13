FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# 1) Base tools + enable 'universe' early so later installs (fuse-overlayfs) work
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gosu software-properties-common \
  && add-apt-repository -y universe \
  && rm -rf /var/lib/apt/lists/*

# 2) Electron/GTK/X11 deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      xauth x11-utils xdg-utils \
      libgtk-3-0 libasound2 libnss3 libxss1 libxtst6 libatk-bridge2.0-0 \
      libx11-xcb1 libxkbcommon0 libcanberra-gtk-module libcanberra-gtk3-module \
      libdbus-glib-1-2 libxcb-render0 libxcb-shm0 \
  && rm -rf /var/lib/apt/lists/*

# 3) D-Bus
RUN apt-get update && apt-get install -y --no-install-recommends \
      dbus dbus-x11 \
  && rm -rf /var/lib/apt/lists/*

# 4) Software GL (Mesa)
RUN apt-get update && apt-get install -y --no-install-recommends \
      mesa-utils libgl1 libglx-mesa0 libgl1-mesa-dri libegl1 libgbm1 libgles2 \
  && rm -rf /var/lib/apt/lists/*

# 5) Firefox (non-snap) from Mozilla PPA + CLI text browsers for xdg-open fallbacks
RUN add-apt-repository -y ppa:mozillateam/ppa \
  && printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501\n' \
       > /etc/apt/preferences.d/mozilla-firefox \
  && apt-get update && apt-get install -y --no-install-recommends \
       firefox links2 elinks lynx w3m \
  && ln -sf /usr/bin/firefox /usr/local/bin/firefox \
  && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 200 \
  && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/firefox 200 \
  && rm -rf /var/lib/apt/lists/*

# 6) AppImage / FUSE + fuse-overlayfs (needs 'universe')
RUN apt-get update && apt-get install -y --no-install-recommends \
      libfuse2 fuse-overlayfs \
  && rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y --no-install-recommends \
    libpci3 libpciaccess0 \
 && rm -rf /var/lib/apt/lists/ 
 
# 7) Unprivileged user and workspace
RUN useradd -m -u 1000 -s /bin/bash cursoruser
WORKDIR /home/cursoruser

# 8) Scripts late for better layer reuse
COPY entry.sh /entry.sh
COPY verify_fs.sh /home/cursoruser/verify_fs.sh
COPY run_cursor.sh /home/cursoruser/run_cursor.sh
RUN chmod +x /entry.sh /home/cursoruser/verify_fs.sh /home/cursoruser/run_cursor.sh \
  && chmod a+rx /home/cursoruser /home/cursoruser/run_cursor.sh \
  && chown -R 1000:1000 /home/cursoruser

# 9) Make Firefox the default for tools that read env
ENV BROWSER=/usr/bin/firefox

ENTRYPOINT ["/entry.sh"]

