FROM alpine:3.20 AS tofu

ADD install-opentofu.sh /install-opentofu.sh
RUN chmod +x /install-opentofu.sh
RUN apk add gpg gpg-agent
RUN ./install-opentofu.sh --install-method standalone --install-path / --symlink-path -

FROM ubuntu:20.04

COPY --from=tofu /tofu /usr/local/bin/tofu
RUN apt-get update && apt-get install -y git zip curl python3 python3-pip

ENTRYPOINT ["/bin/sh"]
