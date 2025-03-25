#!/bin/bash

# Skript zur Anzeige externer IPs mit Proxy-Umgehung
# Version 2.0 - Proxy-resistent

# Funktion zur Proxy-umgehenden IP-Abfrage
get_ip_without_proxy() {
    local ip_type=$1
    local interface=$2
    local timeout=3
    local useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
    
    # Liste von Diensten (priorisierte Reihenfolge)
    local services=()
    if [ "$ip_type" == "4" ]; then
        services=(
            "http://api.ipify.org"                # Beliebtester Dienst
            "http://icanhazip.com"                # Einfacher Dienst
            "http://ifconfig.me/ip"               # Alternative
            "http://ident.me"                     # Minimalistisch
            "http://checkip.amazonaws.com"        # AWS-basiert
            "http://ipecho.net/plain"             # Langjähriger Dienst
            "http://whatismyip.akamai.com"        # Akamai-basiert
        )
    else
        services=(
            "http://api6.ipify.org"               # IPv6-Version
            "http://ipv6.icanhazip.com"           # IPv6-Alternative
            "http://v6.ident.me"                  # Minimalistisch IPv6
            "http://ipv6.ifconfig.me/ip"          # Alternative IPv6
        )
    fi

    # Spezielle curl-Optionen zur Proxy-Umgehung
    local curl_opts=(
        "--noproxy" "*"                           # Alle Proxys ignorieren
        "--interface" "$interface"                # Spezifische Schnittstelle
        "--connect-timeout" "$timeout"            # Timeout setzen
        "--max-time" "$((timeout+2))"             # Maximale Laufzeit
        "--silent"                                # Keine Statusmeldungen
        "--user-agent" "$useragent"               # User-Agent setzen
    )

    for service in "${services[@]}"; do
        echo -n "-> Versuche $service... " >&2
        if ip=$(curl "${curl_opts[@]}" "$service" 2>/dev/null | tr -d '\n'); then
            if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || 
               [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]]; then
                echo -e "\033[32mErfolg!\033[0m" >&2
                echo "$ip"
                return 0
            fi
        fi
        echo -e "\033[31mFehlgeschlagen\033[0m" >&2
    done
    
    echo "N/A (Alle Dienste versagt)"
    return 1
}

# Hauptprogramm
clear
echo -e "\n=== Externe IP-Adressen (Proxy-umgehend) ===\n"
echo -e "Datum: $(date)\n"

# Alle aktiven Schnittstellen finden
interfaces=($(ip -o link show | awk '$2 != "lo:" && $9 == "UP" {print substr($2, 1, length($2)-1)}'))

if [ ${#interfaces[@]} -eq 0 ]; then
    echo "Keine aktiven Netzwerkschnittstellen gefunden!"
    exit 1
fi

# Für jede Schnittstelle IPs abfragen
for intf in "${interfaces[@]}"; do
    echo -e "\n\033[1;34m[Schnittstelle: $intf]\033[0m"
    
    # Lokale IPs anzeigen
    echo -n "Lokale IPv4: "
    ipv4=$(ip -4 addr show dev "$intf" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "N/A")
    echo -e "\033[0;32m$ipv4\033[0m"
    
    echo -n "Lokale IPv6: "
    ipv6=$(ip -6 addr show dev "$intf" | grep -oP '(?<=inet6\s)[\da-f:]+' | head -n 1 || echo "N/A")
    echo -e "\033[0;32m$ipv6\033[0m"
    
    # Externe IPs abfragen (mit Proxy-Umgehung)
    echo -n "Externe IPv4: "
    ext4=$(get_ip_without_proxy 4 "$intf")
    echo -e "\033[0;33m$ext4\033[0m"
    
    echo -n "Externe IPv6: "
    ext6=$(get_ip_without_proxy 6 "$intf")
    echo -e "\033[0;33m$ext6\033[0m"
    
    # Verbindungstest
    echo -n "Internetverbindung: "
    if ping -I "$intf" -c 1 -W 1 8.8.8.8 &> /dev/null; then
        echo -e "\033[0;32mOK\033[0m"
    else
        echo -e "\033[0;31mFEHLER\033[0m"
    fi
done

echo -e "\n=== Skript beendet ===\n"
