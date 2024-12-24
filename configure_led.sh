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

# Détection des interfaces réseau
interfaces=$(ls /sys/class/net | grep -E 'enp|eth')

for interface in $interfaces; do
    # Vérification de l'état de l'interface
    state=$(cat /sys/class/net/$interface/operstate)
    if [ "$state" = "up" ]; then
        echo "Interface détectée : $interface (active)"
        # Vérification de la vitesse du lien
        speed=$(cat /sys/class/net/$interface/speed 2>/dev/null || echo 0)
        echo "Vitesse du lien : $speed Mbps"

        # Définition de la couleur de la LED selon la vitesse
        if [ "$speed" -le 1000 ]; then
            color=$COLOR_ORANGE
        elif [ "$speed" -le 5000 ]; then
            color=$COLOR_WHITE
        else
            color=$COLOR_BLUE
        fi

        # Configuration de la LED correspondante
        led="netdev" # Nom de la LED associée
        set_led_color "$led" "$color"
        configure_led_for_traffic "$led" "$interface"
        echo "Configuration terminée pour $interface avec la LED $led et la couleur $color"
        break # Arrêter après avoir configuré la première interface active
    fi
done

if [ -z "$interface" ]; then
    echo "Aucune interface réseau active détectée."
fi
