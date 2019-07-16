# Build stage
FROM golang:1.12-stretch as build-env

RUN mkdir -p /go/src/github.com/gluster/gluster-prometheus/

WORKDIR /go/src/github.com/gluster/gluster-prometheus/

RUN set -ex && \
export DEBIAN_FRONTEND=noninteractive; \
if ! timeout -k 12s -s TERM 10s apt-get update; then \
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list && \
apt-get update; \
fi && \
apt-get -q update && apt-get install -y --no-install-recommends bash curl make git

COPY . .

RUN scripts/install-reqs.sh
RUN PREFIX=/app make
RUN PREFIX=/app make install

# Create small image for running
FROM debian:stretch-slim

ARG GLUSTER_VERSION=6

# Install gluster cli for gluster-exporter
RUN set -ex && \
export DEBIAN_FRONTEND=noninteractive; \
if ! timeout -k 12s -s TERM 10s apt-get update; then \
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list && \
apt-get update; \
fi && \
apt-get -q update && apt-get install -y --no-install-recommends gnupg curl apt-transport-https && \
        apt-get install -y --no-install-recommends ca-certificates && \
        DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"') && \
        DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+') && \
        DEBARCH=$(dpkg --print-architecture) && \
        curl -sSL http://download.gluster.org/pub/gluster/glusterfs/${GLUSTER_VERSION}/rsa.pub | apt-key add - && \
        echo deb https://download.gluster.org/pub/gluster/glusterfs/${GLUSTER_VERSION}/LATEST/Debian/${DEBID}/${DEBARCH}/apt ${DEBVER} main > /etc/apt/sources.list.d/gluster.list && \
        apt-get -q update && apt-get install -y --no-install-recommends glusterfs-server && apt-get clean all && \
        apt-get clean && rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY --from=build-env /app /app/

ENTRYPOINT ["/app/sbin/gluster-exporter"]
