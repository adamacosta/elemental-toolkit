FROM registry.suse.com/bci/bci-base:16.0 AS builder

COPY SCCcredentials /etc/zypp/credentials.d/SCCcredentials

ARG ELEMENTAL_REPO=https://download.opensuse.org/repositories/isv:/Rancher:/Elemental:/Maintenance:/6.2/standard/isv:Rancher:Elemental:Maintenance:6.2.repo
ARG IMAGE_REPO=local/elemental-minimal
ARG IMAGE_TAG=latest

# Beware curl and zypper will not work without ca-certificates-mozilla because it, rather
# than base ca-certificates, installs the certs for p11-kit
RUN mkdir /osimage && \
    rpmdb --initdb --root /osimage && \
    zypper addrepo "$ELEMENTAL_REPO" && \
    zypper --gpg-auto-import-keys --installroot /osimage in --no-recommends -y \
    bash \
    bind-utils \
    ca-certificates \
    ca-certificates-mozilla \
    coreutils \
    curl \
    dracut \
    elemental-toolkit \
    filesystem \
    findutils \
    gawk \
    grep \
    grub2 \
    grub2-i386-pc \
    grub2-x86_64-efi \
    iproute2 \
    iputils \
    kernel-default \
    kernel-firmware-all \
    man \
    man-pages \
    netcat-openbsd \
    NetworkManager \
    openssh \
    openssl \
    sed \
    shim \
    sudo \
    systemd \
    tar \
    vim-small \
    zypper

# Setup elemental-release used for versioning/upgrade. The
# values here should reflect the tag of the image being built
# Also used by elemental-populate-labels
RUN echo IMAGE_REPO=\"${IMAGE_REPO}\"          >> /osimage/etc/os-release && \
    echo IMAGE_TAG=\"${IMAGE_TAG}\"            >> /osimage/etc/os-release && \
    echo IMAGE=\"${IMAGE_REPO}:${IMAGE_TAG}\"  >> /osimage/etc/os-release && \
    echo TIMESTAMP="$(date +'%Y%m%d%H%M%S')"   >> /osimage/etc/os-release && \
    echo GRUB_ENTRY_NAME=\"Elemental Minimal\" >> /osimage/etc/os-release

RUN cp -arv /etc/zypp/repos.d/* /osimage/etc/zypp/repos.d/

FROM scratch AS osimage

COPY --from=builder /osimage /

# Finish setup and cleanup
RUN update-ca-certificates && \
    systemd-sysusers && \
    systemctl enable NetworkManager.service && \
    systemctl enable sshd.service && \
    zypper clean --all && \
    elemental init --force