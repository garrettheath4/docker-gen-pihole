# docker-gen-pihole

Automatically updates local DNS records in Pi-hole based on running containers in Docker. This eliminates the need to manually create DNS records for Traefik-routed domains like `n8n.lan`.

## How It Works

1. **docker-gen** monitors the Docker socket for container start/stop events
2. When containers change, it uses `lan-hosts.tmpl` to generate a list of `.lan` domains from container labels
3. docker-gen then executes a notify command that runs `sync-pihole-dns.sh` inside the Pi-hole container
4. The script updates Pi-hole's `pihole.toml` configuration with:
   - An A record pointing `traefik.lan` to your Traefik IP
   - CNAME records pointing all other `.lan` domains to `traefik.lan`
5. Pi-hole reloads its DNS configuration to apply the changes

## Prerequisites

- Docker and Docker Compose
- Pi-hole v6+ (uses `pihole.toml` configuration)
- Traefik as your reverse proxy
- Containers with Traefik labels (or at minimum, not explicitly disabled with `traefik.enable=false`)

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | Extends `nginxproxy/docker-gen` with Docker CLI for running `docker exec` |
| `lan-hosts.tmpl` | Go template that extracts domain names from container labels |
| `sync-pihole-dns.sh` | Bash script that updates Pi-hole's TOML config with DNS records |
| `build_and_push_to_docker_hub.sh` | Helper script to build and publish the Docker image |

## Build

1. Edit `build_and_push_to_docker_hub.sh` and change the Docker Hub username if needed
2. Run the build script:
   ```bash
   ./build_and_push_to_docker_hub.sh
   ```

## Configuration

### Traefik IP Address

Edit `sync-pihole-dns.sh` and set `TRAEFIK_IP` to the IP address of your Traefik server on your local network:

```bash
TRAEFIK_IP="192.168.4.30"
```

This is typically the same IP as your Docker host if Traefik runs as a container.

### Domain Naming

The template extracts domain names using this priority:
1. `traefik.service.name` label if set
2. Container name as fallback

All domains are suffixed with `.lan`.

## Setup

### Directory Structure

Create the following directories on your Docker host:

```
/portainer/Files/AppData/Config/
├── PiHole/
│   ├── scripts/
│   │   └── sync-pihole-dns.sh    # Copy sync-pihole-dns.sh here
│   └── ...                        # Other Pi-hole data
└── docker-gen-pihole/
    ├── templates/
    │   └── lan-hosts.tmpl         # Copy lan-hosts.tmpl here
    └── docker-domains/
        └── domains.txt            # Generated automatically
```

### Portainer Stack

Deploy this as a Stack in Portainer: **Stacks** > **Add stack** > **Web editor**

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    volumes:
      - /portainer/Files/AppData/Config/PiHole/:/etc/pihole
      - /portainer/Files/AppData/Config/PiHole/DNS/:/etc/dnsmasq.d
      - /portainer/Files/AppData/Config/docker-gen-pihole/docker-domains/:/docker-domains:ro
    environment:
      TZ: ${TZ:-America/New_York}
      FTLCONF_webserver_api_password: ${PIHOLE_PASSWORD}
    # ... other pihole config (ports, networks, etc)

  docker-gen-pihole:
    image: garrettheath4/docker-gen-with-cli:latest
    container_name: docker-gen-pihole
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /portainer/Files/AppData/Config/docker-gen-pihole/templates/:/etc/docker-gen-pihole/templates:ro
      - /portainer/Files/AppData/Config/docker-gen-pihole/docker-domains/:/output
    command: >-
      -watch
      -notify "docker exec pihole /etc/pihole/scripts/sync-pihole-dns.sh"
      /etc/docker-gen-pihole/templates/lan-hosts.tmpl
      /output/domains.txt
    depends_on:
      - pihole
```

#### Stack Environment Variables

When deploying the stack, add these environment variables in Portainer:

| Variable | Description | Example |
|----------|-------------|---------|
| `TZ` | Timezone | `America/New_York` |
| `PIHOLE_PASSWORD` | Pi-hole web interface password | `your_secure_password` |

### Make the Script Executable

```bash
chmod +x /portainer/Files/AppData/Config/PiHole/scripts/sync-pihole-dns.sh
```

## Example

If you have the following containers running:

| Container | traefik.enable | traefik.service.name |
|-----------|----------------|----------------------|
| traefik   | true           | traefik              |
| n8n-ui    | (not set)      | n8n                  |
| portainer | true           | (not set)            |
| redis     | false          | -                    |

The generated DNS records would be:

- `traefik.lan` → A record → `192.168.4.30`
- `n8n.lan` → CNAME → `traefik.lan`
- `portainer.lan` → CNAME → `traefik.lan`

(redis is excluded because `traefik.enable=false`)

## Troubleshooting

### Check Generated Domains

```bash
cat /portainer/Files/AppData/Config/docker-gen-pihole/docker-domains/domains.txt
```

### Verify Pi-hole Configuration

```bash
docker exec pihole grep -A5 "hosts\|cnameRecords" /etc/pihole/pihole.toml
```

### Manually Trigger DNS Sync

```bash
docker exec pihole /etc/pihole/scripts/sync-pihole-dns.sh
```

### View docker-gen-pihole Logs

```bash
docker logs docker-gen-pihole
```

<!-- vim: set smarttab shiftround expandtab nosmartindent: -->
