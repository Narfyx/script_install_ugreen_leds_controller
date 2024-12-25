#!/bin/bash

# Vérifie que le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root."
  exit 1
fi

echo "Disque -> Port SATA -> Marque -> Capacité (Go)"

# Parcours des disques physiques uniquement
for disk in /sys/class/block/sd*; do
  disk_name=$(basename "$disk") # Récupère le nom du disque, ex: sda

  # Vérifie si c'est un disque physique (pas de "partition" sous ce disque)
  if [ -d "/sys/class/block/$disk_name/device" ]; then
    # Trouve le lien ATA correspondant
    ata_link=$(readlink -f "$disk" | grep -o "ata[0-9]*")
    [ -z "$ata_link" ] && ata_link="Port SATA non détecté"

    # Récupère la marque/modèle du disque
    model=$(cat /sys/class/block/$disk_name/device/model 2>/dev/null || echo "Marque inconnue")

    # Récupère la capacité du disque en Go
    size=$(cat /sys/class/block/$disk_name/size 2>/dev/null || echo 0)
    capacity_gb=$((size * 512 / 1024 / 1024 / 1024))

    # Affiche les informations
    echo "$disk_name -> $ata_link -> $model -> ${capacity_gb} Go"
  fi
done
