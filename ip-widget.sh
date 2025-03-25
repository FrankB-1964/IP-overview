#!/bin/bash

# Funktion zur Überprüfung der Internetverbindung
check_internet() {
    if ! ping -c 1 -W 1 8.8.8.8 &> /dev/null && ! ping6 -c 1 -W 1 2001:4860:4860::8888 &> /dev/null; then
        echo "Keine Internetverbindung gefunden."
        exit 1
    fi
}

# Funktion zum Abrufen der externen IP über verschiedene Dienste
get_external_ip() {
    local ip_type=$1
    local services=()
    
    if [ "$ip_type" == "4" ]; then
        services=(
            "https://api.ipify.org"
            "https://ipv4.icanhazip.com"
            "https://4.ident.me"
        )
    else
        services=(
            "https://api6.ipify.org"
            "https://ipv6.icanhazip.com"
            "https://6.ident.me"
        )
    fi

    for service in "${services[@]}"; do
        if ip=$(curl -${ip_type}s --connect-timeout 3 "$service" 2>/dev/null); then
            echo "$ip" | tr -d '\n'
            return 0
        fi
    done
    
    echo "N/A"
    return 1
}

# Funktion zum Ermitteln der aktiven Schnittstellen
get_active_interfaces() {
    ip -o link show | awk '$2 != "lo:" && $9 == "UP" {print substr($2, 1, length($2)-1)}'
}

# Hauptprogramm
clear
echo -e "\n=== Externe IP-Adressen aller Internet-Schnittstellen ===\n"

check_internet

active_interfaces=($(get_active_interfaces))

if [ ${#active_interfaces[@]} -eq 0 ]; then
    echo "Keine aktiven Netzwerkschnittstellen gefunden (ausgenommen lo)."
    exit 1
fi

for interface in "${active_interfaces[@]}"; do
    echo -e "\nSchnittstelle: \033[1;34m$interface\033[0m"
    
    # Temporäre Route über diese Schnittstelle erzwingen
    current_ipv4=$(ip -4 addr show dev $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    current_ipv6=$(ip -6 addr show dev $interface | grep -oP '(?<=inet6\s)[\da-f:]+' | head -n 1)
    
    echo -e "Lokale IPv4: \033[0;32m${current_ipv4:-N/A}\033[0m"
    echo -e "Lokale IPv6: \033[0;32m${current_ipv6:-N/A}\033[0m"
    
    # Externe IPs ermitteln
    echo -n "Externe IPv4: "
    EXT_IPV4=$(get_external_ip 4)
    echo -e "\033[0;33m$EXT_IPV4\033[0m"
    
    echo -n "Externe IPv6: "
    EXT_IPV6=$(get_external_ip 6)
    echo -e "\033[0;33m$EXT_IPV6\033[0m"
    
    # Traceroute-Info (optional)
    echo -n "Route IPv4: "
    traceroute -4 -w 1 -m 3 8.8.8.8 -i $interface 2>/dev/null | awk 'NR==2 {print $2}' || echo "N/A"
done

echo -e "\n=== Skript beendet ===\n"
