# docker-gen-dns

Automatically updates local DNS records in Pi-hole based on running containers in Docker so that you do not need to
manually create DNS records for Traefik CNAME domains like `n8n.lan` to work.

## Build

1.  Change the Docker Hub username in `./build_and_push_to_docker_hub.sh`.
1.  Run the `./build_and_push_to_docker_hub.sh` script to build the Docker image and deploy it to Docker Hub.
1.  Edit the `TRAEFIK_IP` value in `sync-pihole-dns.sh` to the IP address of your Traefik server on your local (home)
    network. Note that this will likely be the same IP address as your Docker server if you are running Traefik as a
    Docker container.

## Setup

Your Docker setup should look something like this:

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    volumes:
      - /portainer/Files/AppData/Config/PiHole/:/etc/pihole
      - /portainer/Files/AppData/Config/PiHole/DNS/:/etc/dnsmasq.d
      - /portainer/Files/AppData/Config/docker-gen/docker-domains/:/docker-domains:ro
    environment:
      TZ: 'America/New_York'
      WEBPASSWORD: 'your_password'
    # ... other pihole config (ports, networks, etc)

  docker-gen:
    image: docker-gen-with-cli
    container_name: docker-gen-dns
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /portainer/Files/AppData/Config/docker-gen/templates/:/etc/docker-gen/templates:ro
      - /portainer/Files/AppData/Config/docker-gen/docker-domains/:/output
    command: -watch -notify "docker exec pihole /etc/pihole/scripts/sync-pihole-dns.sh" /etc/docker-gen/templates/lan-hosts.tmpl /output/domains.txt
    depends_on:
      - pihole
```



<!-- vim: set textwidth=120 smarttab shiftround expandtab nosmartindent: -->
