FROM nginxproxy/docker-gen

# Install docker CLI
RUN apk add --no-cache docker-cli

ENTRYPOINT ["/usr/local/bin/docker-gen"]
