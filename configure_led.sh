#!/bin/bash

# Couleurs pour les LED
COLOR_ORANGE="255 165 0"  # Orange pour <= 1Gbps
COLOR_WHITE="255 255 255" # Blanc pour > 1Gbps et <= 5Gbps
COLOR_BLUE="0 0 255"      # Bleu pour > 5Gbps

# Fonction pour définir la couleur de la LED
set_led_color() {
    local led="$1"
    local color="$2"
    echo "$color" > /sys/class/leds/$led/color || echo "Erreur : impossible de définir la couleur pour $led"
}

# Fonction pour configurer la LED pour le trafic réseau
configure_led_for_traffic() {
    local led="$1"
    local interface="$2"
    echo netdev > /sys/class/leds/$led/trigger
    echo "$interface" > /sys/class/leds/$led/device_name
    echo 1 > /sys/class/leds/$led/link
    echo 1 > /sys/class/leds/$led/tx
    echo 1 > /sys/class/leds/$led/rx
    echo 100 > /sys/class/leds/$led/interval
}

# Surveillance en boucle
previous_speed=""
while true; do
    interfaces=$(ls /sys/class/net | grep -E 'enp|eth')
    for interface in $interfaces; do
        state=$(cat /sys/class/net/$interface/operstate 2>/dev/null || echo "down")
        if [ "$state" = "up" ]; then
            speed=$(cat /sys/class/net/$interface/speed 2>/dev/null || echo 0)
            if [ "$speed" != "$previous_speed" ]; then
                echo "Interface : $interface (active) | Vitesse : $speed Mbps"

                # Définir la couleur selon la vitesse
                if [ "$speed" -le 1000 ]; then
                    color=$COLOR_ORANGE
                elif [ "$speed" -le 5000 ]; then
                    color=$COLOR_WHITE
                else
                    color=$COLOR_BLUE
                fi

                # Configuration de la LED
                led="netdev"
                set_led_color "$led" "$color"
                configure_led_for_traffic "$led" "$interface"
                echo "Couleur mise à jour : $color pour $interface à $speed Mbps"
                previous_speed="$speed"
            fi
        fi
    done
    sleep 5 # Vérifie toutes les 5 secondes
done

# Création du service systemd pour la persistance
SERVICE_NAME="configure_led"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

if [ ! -f "$SERVICE_PATH" ]; then
    echo "Création du service systemd pour rendre le script persistant..."

    cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Configurer les LEDs réseau en fonction de la vitesse et du trafic
After=network.target

[Service]
ExecStart=/bin/bash $(realpath "$0")
Restart=always
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Recharger systemd, activer et démarrer le service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.service"
    systemctl start "$SERVICE_NAME.service"
    systemctl status "$SERVICE_NAME.service"
    echo "Service $SERVICE_NAME créé et activé pour être persistant."
else
    echo "Service systemd $SERVICE_NAME existe déjà."
fi
