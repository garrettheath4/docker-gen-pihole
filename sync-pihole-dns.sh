#!/usr/bin/env bash
# Host path: /portainer/Files/AppData/Config/PiHole/scripts/sync-pihole-dns.sh
# Pihole Container: /etc/pihole/scripts/sync-pihole-dns.sh

TRAEFIK_IP="192.168.4.30"
TOML_FILE="/etc/pihole/pihole.toml"
TEMP_FILE="/tmp/pihole.toml.tmp"
BACKUP_FILE="/etc/pihole/pihole.toml.bak"

# Create backup
cp "$TOML_FILE" "$BACKUP_FILE"

# Read all domains from docker-gen output
mapfile -t domains < /docker-domains/domains.txt

# Build arrays for TOML
hosts_array="["
cname_array="["
first_host=true
first_cname=true

for domain in "${domains[@]}"; do
  # Skip empty lines
  [[ -z "$domain" ]] && continue
  
  if [[ "$domain" == "traefik.lan" ]]; then
    # Add A record for traefik.lan
    [[ "$first_host" == false ]] && hosts_array+=", "
    hosts_array+="\"$TRAEFIK_IP $domain\""
    first_host=false
  else
    # Add CNAME record
    [[ "$first_cname" == false ]] && cname_array+=", "
    cname_array+="\"$domain,traefik.lan\""
    first_cname=false
  fi
done

hosts_array+="]"
cname_array+="]"

# Use awk to replace the arrays in the TOML file
awk -v hosts="$hosts_array" -v cnames="$cname_array" '
/^  hosts = \[/ {
    # Check if the array closes on the same line
    if ($0 ~ /\]/) {
        print "  hosts = " hosts " ### CHANGED, default = []"
    } else {
        print "  hosts = " hosts " ### CHANGED, default = []"
        # Skip until we find the closing bracket
        while (getline > 0 && !/^  \]/) { }
    }
    next
}
/^  cnameRecords = \[/ {
    # Check if the array closes on the same line
    if ($0 ~ /\]/) {
        print "  cnameRecords = " cnames
    } else {
        print "  cnameRecords = " cnames
        # Skip until we find the closing bracket
        while (getline > 0 && !/^  \]/) { }
    }
    next
}
{ print }
' "$TOML_FILE" > "$TEMP_FILE"

# Verify the temp file was created successfully
if [[ -s "$TEMP_FILE" ]]; then
  # Replace original file
  mv "$TEMP_FILE" "$TOML_FILE"
  # Reload DNS to apply changes
  pihole reloaddns
else
  echo "Error: Failed to generate new TOML file"
  # Restore from backup
  cp "$BACKUP_FILE" "$TOML_FILE"
  exit 1
fi
