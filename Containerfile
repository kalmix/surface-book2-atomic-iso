# ==============================================================================
# Microsoft Surface Book 2 - Fedora Silverblue 40 (Atomic Desktop)
# Specialized OCI Image with linux-surface kernel & Dead Battery Mitigations
# ==============================================================================

FROM ghcr.io/ublue-os/silverblue-nvidia:40

ARG SURFACE_RELEASEVER=40

LABEL maintainer="kalmix" \
      org.opencontainers.image.title="surface-book2-silverblue" \
      org.opencontainers.image.description="Fedora Silverblue 40 with linux-surface kernel and hardware mitigations for Surface Book 2" \
      org.opencontainers.image.version="40"

# 1. Import official Linux Surface GPG Key and Setup Repositories
RUN curl -fsSL https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
        -o /etc/pki/rpm-gpg/RPM-GPG-KEY-surface && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-surface && \
    curl -fsSL https://pkg.surfacelinux.com/fedora/linux-surface.repo \
        -o /etc/yum.repos.d/linux-surface.repo && \
    sed -i "s/\$releasever/${SURFACE_RELEASEVER}/g" /etc/yum.repos.d/linux-surface.repo && \
    curl -fsSL https://copr.fedorainfracloud.org/coprs/abn/throttled/repo/fedora-${SURFACE_RELEASEVER}/abn-throttled-fedora-${SURFACE_RELEASEVER}.repo \
        -o /etc/yum.repos.d/abn-throttled.repo

# 2. Swap standard Fedora kernel with official linux-surface kernel and install hardware daemons
# Uses rpm-ostree override when available, with a dnf5/rpm fallback
RUN (rpm-ostree override remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra libwacom libwacom-data \
        --install kernel-surface \
        --install kernel-surface-devel \
        --install kernel-surface-default-watchdog \
        --install iptsd \
        --install libwacom-surface \
        --install libwacom-surface-data \
        --install surface-dtx-daemon \
        --install surface-secureboot \
        --install throttled \
        --install msr-tools 2>/dev/null) \
    || ( \
        rpm -e --nodeps $(rpm -qa | grep -E '^kernel-(core|modules|modules-core|modules-extra)?$') libwacom libwacom-data 2>/dev/null || true && \
        dnf5 install -y --allowerasing \
            kernel-surface \
            kernel-surface-devel \
            kernel-surface-default-watchdog \
            iptsd \
            libwacom-surface \
            libwacom-surface-data \
            surface-dtx-daemon \
            surface-secureboot \
            throttled \
            msr-tools \
    )

# 3. Copy Hardware Configurations, Scripts, Systemd Units and Kernel Arguments
COPY config/throttled.conf /etc/throttled.conf
COPY config/surface-dtx.conf /etc/surface-dtx/surface-dtx-daemon.conf
COPY scripts/surface-nvidia-power-limit.sh /usr/local/bin/surface-nvidia-power-limit.sh
COPY scripts/disable-bd-prochot.sh /usr/local/bin/disable-bd-prochot.sh
COPY scripts/setup-surface-kernel.sh /tmp/setup-surface-kernel.sh
COPY systemd/surface-nvidia-power-limit.service /etc/systemd/system/surface-nvidia-power-limit.service
COPY systemd/surface-bdprochot-fallback.service /etc/systemd/system/surface-bdprochot-fallback.service
COPY bootc/kargs.d/50-surface.toml /usr/lib/bootc/kargs.d/50-surface.toml

# 4. Set Execution Permissions and Execute Setup Script
RUN chmod +x /usr/local/bin/surface-nvidia-power-limit.sh \
             /usr/local/bin/disable-bd-prochot.sh \
             /tmp/setup-surface-kernel.sh && \
    /bin/bash /tmp/setup-surface-kernel.sh && \
    rm -f /tmp/setup-surface-kernel.sh

# 5. Clean package managers and temporary files
RUN (dnf5 clean all 2>/dev/null || true) && \
    rm -rf /var/cache/* /tmp/* /var/tmp/*
