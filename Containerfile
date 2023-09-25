ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR}:-main"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-${BASE_IMAGE_NAME}${IMAGE_FLAVOR}}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-38}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS surface
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-38}"

# Store a copy of files so we not have to polute
# every image with image specific files.
COPY system_files/ /tmp/
# Copy shared files between all images.
COPY system_files/shared /
COPY surface-install.sh /tmp/surface-install.sh
COPY surface-packages.json /tmp/surface-packages.json

# Add Linux Surface repo
RUN wget https://pkg.surfacelinux.com/fedora/linux-surface.repo -P /etc/yum.repos.d

# Install Surface kernel
RUN wget https://github.com/linux-surface/linux-surface/releases/download/silverblue-20201215-1/kernel-20201215-1.x86_64.rpm -O \
    /tmp/surface-kernel.rpm && \
    rpm-ostree cliwrap install-to-root / && \
    rpm-ostree override replace /tmp/surface-kernel.rpm \
        --remove kernel-core \
        --remove kernel-devel-matched \
        --remove kernel-modules \
        --remove kernel-modules-extra \
        --remove libwacom \
        --remove libwacom-data \
        --install kernel-surface \
        --install kernel-surface-devel-matched \
        --install iptsd \
        --install libwacom-surface \
        --install libwacom-surface-data

# Install akmods
COPY --from=ghcr.io/ublue-os/akmods:surface-${FEDORA_MAJOR_VERSION} /rpms /tmp/akmods-rpms
# Only run if FEDORA_MAJOR_VERSION is not 39
RUN if [ ${FEDORA_MAJOR_VERSION} -lt 39 ]; then \
    rpm-ostree install \
        kernel-tools \
        /tmp/akmods-rpms/kmods/*xpadneo*.rpm \
        /tmp/akmods-rpms/kmods/*xpad-noone*.rpm \
        /tmp/akmods-rpms/kmods/*xone*.rpm \
        /tmp/akmods-rpms/kmods/*openrazer*.rpm \
        /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
        /tmp/akmods-rpms/kmods/*wl*.rpm; \
fi

# Setup specific files and commands for Silverblue
RUN if grep -q "silverblue" <<< "${BASE_IMAGE_NAME}"; then \
    rsync -rvK /tmp/silverblue/ / && \    
    systemctl enable dconf-update \
; fi

# Setup things which are the same for every image
RUN /tmp/surface-install.sh && \
    systemctl enable tlp && \
    systemctl enable fprintd && \
    rm -rf /tmp/* /var/* && \    
    ostree container commit && \
    mkdir -p /var/tmp && chmod -R 1777 /tmp /var/tmp
