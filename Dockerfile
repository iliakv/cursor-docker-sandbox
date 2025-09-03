# syntax=docker/dockerfile:1.7

FROM ubuntu:22.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=0 PIP_DEFAULT_TIMEOUT=60
ENV PIP_CACHE_DIR=/opt/pip-cache
ENV PATH=/home/workspace/.local/bin:$PATH
ENV BROWSER=/usr/bin/firefox
ENV PORT=8000

# -------------------------------------------------------------------
# APT mirrors normalization
# -------------------------------------------------------------------
RUN sed -i 's|http://mirrors.edge.kernel.org/ubuntu/|http://archive.ubuntu.com/ubuntu/|g' /etc/apt/sources.list \
 && sed -i 's|http://mirrors.edge.kernel.org/ubuntu/|http://security.ubuntu.com/ubuntu/|g' /etc/apt/sources.list \
 && sed -i 's|http://mirrors.kernel.org/|http://archive.ubuntu.com/|g' /etc/apt/sources.list

# -------------------------------------------------------------------
# Base tools and enable universe
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gosu software-properties-common uuid-runtime git \
      pkg-config build-essential lsof sudo \
 && add-apt-repository -y universe \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Electron, GTK, X11
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xauth x11-utils xdg-utils \
      libgtk-3-0 libasound2 libnss3 libxss1 libxtst6 libatk-bridge2.0-0 \
      libx11-xcb1 libxkbcommon0 libcanberra-gtk-module libcanberra-gtk3-module \
      libdbus-glib-1-2 libxcb-render0 libxcb-shm0 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# D-Bus
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends dbus dbus-x11 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Software GL, Mesa
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      mesa-utils libgl1 libglx-mesa0 libgl1-mesa-dri libegl1 libgbm1 libgles2 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Firefox from Mozilla PPA
# -------------------------------------------------------------------
RUN add-apt-repository -y ppa:mozillateam/ppa \
 && printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501\n' > /etc/apt/preferences.d/mozilla-firefox \
 && apt-get update \
 && apt-get install -y --no-install-recommends firefox links2 elinks lynx w3m \
 && ln -sf /usr/bin/firefox /usr/local/bin/firefox \
 && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 200 \
 && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/firefox 200 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Python 3.10 toolchain
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-pip python3-dev pipx \
 && rm -rf /var/lib/apt/lists/* \
 && update-alternatives --install /usr/bin/python python /usr/bin/python3 2 \
 && update-alternatives --set python /usr/bin/python3 \
 && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2 \
 && update-alternatives --set pip /usr/bin/pip3

# -------------------------------------------------------------------
# Native libraries for data science and DB bindings
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libffi-dev libssl-dev \
      libxml2-dev libxslt1-dev zlib1g-dev \
      libjpeg-turbo8-dev libpng-dev \
      libpq-dev default-libmysqlclient-dev libpqxx-dev \
      libpoco-dev libleveldb-dev libhdf5-dev \
      libnuma1 libnuma-dev hwloc liblzo2-dev \
      libboost-all-dev protobuf-compiler \
      libpci3 libpciaccess0 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# AppImage, FUSE
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends libfuse2 fuse-overlayfs \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Pip cache and tooling upgrade
# -------------------------------------------------------------------
RUN mkdir -p "${PIP_CACHE_DIR}" && chmod 1777 "${PIP_CACHE_DIR}" \
 && python -m pip install -U pip setuptools wheel packaging

# -------------------------------------------------------------------
# Python packages, wheels-only pass
# -------------------------------------------------------------------
RUN pip install --no-cache-dir --only-binary :all: \
      tabulate sortedcontainers matplotlib \
      catboost numpy pandas Cython decorator defusedxml dogpile.cache entrypoints \
      filelock scikit-learn scipy seaborn torch torch-optimizer torchvision tornado \
      tqdm xgboost xlrd lightgbm psycopg2-binary psutil lxml beartype einops \
      polygon-api-client exchange_calendars holidays openturns h5py \
      uvicorn[standard] watchfiles

# -------------------------------------------------------------------
# Node.js 20.x installation
# -------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g npm@latest

# -------------------------------------------------------------------
# Python packages, source-allowed pass
# -------------------------------------------------------------------
RUN pip install --no-cache-dir \
      prodict interval bs4 py_vollib

# -------------------------------------------------------------------
# SSH client for agent forwarding (added last for faster rebuilds)
# -------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-client \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# User workspace (user will be created at runtime with actual username)
# -------------------------------------------------------------------
RUN mkdir -p /home/workspace
WORKDIR /home/workspace

# -------------------------------------------------------------------
# Passwordless sudo configuration (will be set up dynamically at runtime)
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# App scripts
# -------------------------------------------------------------------
COPY entry.sh /entry.sh
COPY verify_fs.sh /home/workspace/verify_fs.sh
COPY run_cursor.sh /home/workspace/run_cursor.sh
RUN chmod +x /entry.sh /home/workspace/verify_fs.sh /home/workspace/run_cursor.sh \
 && chmod a+rx /home/workspace /home/workspace/run_cursor.sh \
 && chmod 1777 /home/workspace

# -------------------------------------------------------------------
# Port metadata, expose both Cursor IDE and VeloQuant Trading Monitor ports
# -------------------------------------------------------------------
EXPOSE 8000
EXPOSE 8001
EXPOSE 3000

ENTRYPOINT ["/entry.sh"]

