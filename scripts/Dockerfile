
FROM alpine:3.23
ENV PROOT_VERSION=5.4.0
ENV LANG=fr_FR.UTF-8


RUN apk update && \
    apk add --no-cache \
        bash \
        jq \
        curl \
        ca-certificates \
        iproute2 \
        xz \
        shadow

# Installer PRoot
RUN ARCH=$(uname -m) && \
    mkdir -p /usr/local/bin && \
    proot_url="https://github.com/ysdragon/proot-static/releases/download/v${PROOT_VERSION}/proot-${ARCH}-static" && \
    curl -Ls "$proot_url" -o /usr/local/bin/proot && \
    chmod 755 /usr/local/bin/proot

# Créer l'utilisateur non-root
RUN adduser -D -h /home/container -s /bin/sh container

USER container
ENV USER=container
ENV HOME=/home/container

WORKDIR /home/container

# Copie des scripts
COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
COPY --chown=container:container ./install.sh /install.sh
COPY --chown=container:container ./helper.sh /helper.sh
COPY --chown=container:container ./run.sh /run.sh
COPY --chown=container:container ./common.sh /common.sh
COPY --chown=container:container ./checker.sh /checker.sh
COPY --chown=container:container ./install_vnc.sh /vnc_install.sh

RUN chmod +x /entrypoint.sh /install.sh /helper.sh /run.sh /common.sh /checker.sh /vnc_install.sh
CMD ["/bin/sh", "/entrypoint.sh"]