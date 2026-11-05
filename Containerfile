# ==============================================================================
# Microsoft Surface Book 2 - Fedora Silverblue 40 (Atomic Desktop)
# Specialized OCI Image with linux-surface kernel, LibreWolf & 65W Power Mitigations
# ==============================================================================

FROM ghcr.io/ublue-os/silverblue-nvidia:40

ARG SURFACE_RELEASEVER=40

LABEL maintainer="kalmix" \
      org.opencontainers.image.title="surface-book2-silverblue" \
      org.opencontainers.image.description="Fedora Silverblue 40 with linux-surface kernel, LibreWolf, Deskflow and 65W USB-C mitigations for Surface Book 2" \
      org.opencontainers.image.version="40"

# 1. Clean up broken repos, import official GPG Keys and Setup Repositories
RUN rm -f /etc/yum.repos.d/*negativo*.repo 2>/dev/null || true && \
    curl -fsSL https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
        -o /etc/pki/rpm-gpg/RPM-GPG-KEY-surface && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-surface && \
    curl -fsSL https://repo.librewolf.net/pubkey.gpg \
        -o /etc/pki/rpm-gpg/RPM-GPG-KEY-librewolf && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-librewolf && \
    curl -fsSL https://pkg.surfacelinux.com/fedora/linux-surface.repo \
        -o /etc/yum.repos.d/linux-surface.repo && \
    sed -i "s/\$releasever/${SURFACE_RELEASEVER}/g" /etc/yum.repos.d/linux-surface.repo && \
    curl -fsSL https://repo.librewolf.net/librewolf.repo \
        -o /etc/yum.repos.d/librewolf.repo

# 2. Swap standard Fedora kernel with official linux-surface kernel and install hardware daemons + LibreWolf + DNF stack
RUN (rpm-ostree override remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra libwacom libwacom-data \
        --install kernel-surface \
        --install kernel-surface-devel \
        --install iptsd \
        --install libwacom-surface \
        --install libwacom-surface-data \
        --install surface-dtx-daemon \
        --install surface-secureboot \
        --install msr-tools \
        --install librewolf \
        --install python3-pip \
        --install git \
        --install dnf \
        --install dnf-plugins-core 2>/dev/null) \
    || ( \
        rpm -e --nodeps $(rpm -qa | grep -E '^kernel-(core|modules|modules-core|modules-extra)?$') libwacom libwacom-data 2>/dev/null || true && \
        dnf5 install -y --allowerasing \
            dnf \
            dnf-plugins-core \
            kernel-surface \
            kernel-surface-devel \
            iptsd \
            libwacom-surface \
            libwacom-surface-data \
            surface-dtx-daemon \
            surface-secureboot \
            msr-tools \
            librewolf \
            python3-pip \
            git \
    )

# 2.1 Guarantee /usr/bin/dnf is executable and valid for bootc-image-builder
RUN if [ ! -e /usr/bin/dnf ] && [ -e /usr/bin/dnf5 ]; then ln -sf /usr/bin/dnf5 /usr/bin/dnf; fi && \
    which dnf && (dnf --version || dnf5 --version)

# 3. Copy Hardware Configurations, Scripts, Systemd Units and Kernel Arguments
COPY config/throttled.conf /etc/throttled.conf
COPY config/surface-power.conf /etc/surface-power.conf
COPY config/modprobe-nvidia-power.conf /etc/modprobe.d/nvidia-power.conf
COPY config/surface-dtx.conf /etc/surface-dtx/surface-dtx-daemon.conf
COPY scripts/surface-nvidia-power-limit.sh /usr/local/bin/surface-nvidia-power-limit.sh
COPY scripts/disable-bd-prochot.sh /usr/local/bin/disable-bd-prochot.sh
COPY scripts/surface-firstboot.sh /usr/local/bin/surface-firstboot.sh
COPY scripts/setup-surface-kernel.sh /tmp/setup-surface-kernel.sh
COPY systemd/throttled.service /etc/systemd/system/throttled.service
COPY systemd/surface-nvidia-power-limit.service /etc/systemd/system/surface-nvidia-power-limit.service
COPY systemd/surface-bdprochot-fallback.service /etc/systemd/system/surface-bdprochot-fallback.service
COPY systemd/surface-firstboot.service /etc/systemd/system/surface-firstboot.service
COPY bootc/kargs.d/50-surface.toml /usr/lib/bootc/kargs.d/50-surface.toml

# 4. Set Execution Permissions and Execute Setup Script
RUN chmod +x /usr/local/bin/surface-nvidia-power-limit.sh \
             /usr/local/bin/disable-bd-prochot.sh \
             /usr/local/bin/surface-firstboot.sh \
             /tmp/setup-surface-kernel.sh && \
    /bin/bash /tmp/setup-surface-kernel.sh && \
    rm -f /tmp/setup-surface-kernel.sh

# 5. Clean package managers and temporary files
RUN (dnf clean all 2>/dev/null || true) && \
    (dnf5 clean all 2>/dev/null || true) && \
    rm -rf /tmp/* /var/tmp/*
