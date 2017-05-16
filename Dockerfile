# Taken from play-with-docker

ARG VERSION=17.05.0-ce-dind
FROM docker:${VERSION}

RUN apk add --no-cache git tmux py2-pip apache2-utils vim build-base gettext-dev curl bash-completion bash util-linux jq

ENV COMPOSE_VERSION=1.12.0
ENV MACHINE_VERSION=v0.10.0
# Install Compose and Machine
RUN pip install docker-compose==${COMPOSE_VERSION}
RUN curl -L https://github.com/docker/machine/releases/download/${MACHINE_VERSION}/docker-machine-Linux-x86_64 \
    -o /usr/bin/docker-machine && chmod +x /usr/bin/docker-machine

# Compile and install httping
# (used in orchestration workshop, and very useful anyway)
RUN mkdir -p /opt && cd /opt && \
    curl https://www.vanheusden.com/httping/httping-2.5.tgz | \
    tar -zxf- && cd httping-2.5 && \
    ./configure && make install LDFLAGS=-lintl && \
    rm -rf httping-2.5

# Add bash completion
RUN mkdir /etc/bash_completion.d && curl https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker -o /etc/bash_completion.d/docker

# Replace modprobe with a no-op to get rid of spurious warnings
# (note: we can't just symlink to /bin/true because it might be busybox)
RUN rm /sbin/modprobe && echo '#!/bin/true' >/sbin/modprobe && chmod +x /sbin/modprobe

# Install a nice vimrc file and prompt (by soulshake)
COPY ["docker-prompt","/usr/local/bin/"]
COPY [".vimrc",".profile", ".inputrc", ".gitconfig", "./root/"]
COPY ["motd", "/etc/motd"]
COPY ["daemon.json", "/etc/docker/"]

ARG docker_storage_driver=overlay2

ENV DOCKER_STORAGE_DRIVER=$docker_storage_driver

# Move to our home
WORKDIR /root

# Remove IPv6 alias for localhost and start docker in the background ...
CMD cat /etc/hosts >/etc/hosts.bak && \
    sed 's/^::1.*//' /etc/hosts.bak > /etc/hosts && \
    sed -i "s/\DOCKER_STORAGE_DRIVER/$DOCKER_STORAGE_DRIVER/" /etc/docker/daemon.json && \
    sed -i "s/\PWD_IP_ADDRESS/$PWD_IP_ADDRESS/" /etc/docker/daemon.json && \
    umount /var/lib/docker && mount -t securityfs none /sys/kernel/security && \
    dockerd &>/docker.log & \
    while true ; do script -q -c "/bin/bash -l" /dev/null ; done
# ... and then put a shell in the foreground, restarting it if it exits
