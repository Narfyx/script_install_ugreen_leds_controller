#!/bin/bash

# Variables
REPO_URL="https://github.com/miskcoo/ugreen_leds_controller.git"
INSTALL_DIR="/opt/ugreen_leds_controller"
KMOD_DIR="$INSTALL_DIR/kmod"
SCRIPTS_DIR="$INSTALL_DIR/scripts"
MODULE_NAME="led-ugreen"
MODULE_VERSION="0.1"
CONF_FILE="/etc/ugreen-leds.conf"
SERVICE_FILES="/etc/systemd/system"
KERNEL_VERSION=$(uname -r)

# Couleurs pour les logs
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

# Fonctions de logs
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Vérification des permissions root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root."
fi

# 1. Mise à jour et installation des dépendances
log_info "Mise à jour des paquets et installation des dépendances..."
apt update && apt install -y dkms g++ make libi2c-dev smartmontools || log_error "Erreur lors de l'installation des dépendances."

# 2. Vérification et installation des en-têtes du noyau
log_info "Vérification des en-têtes du noyau pour $KERNEL_VERSION..."
if [ ! -d "/lib/modules/$KERNEL_VERSION/build" ]; then
    log_info "Les en-têtes du noyau ne sont pas installés. Tentative d'installation..."
    apt install -y pve-headers-$KERNEL_VERSION || apt install -y pve-headers || {
        log_error "Impossible d'installer les en-têtes du noyau. Veuillez installer manuellement les en-têtes pour $KERNEL_VERSION."
    }
else
    log_success "Les en-têtes du noyau sont déjà installés."
fi

# 3. Clonage du dépôt
log_info "Clonage du dépôt GitHub..."
git clone "$REPO_URL" "$INSTALL_DIR" || log_error "Erreur lors du clonage du dépôt."

# 4. Compilation et installation du module du noyau
log_info "Compilation et installation du module du noyau..."
if [ -d "$KMOD_DIR" ]; then
    cd "$KMOD_DIR" || log_error "Impossible d'accéder au répertoire $KMOD_DIR."

    # Nettoyage du module s'il existe déjà
    if dkms status | grep -q "${MODULE_NAME}/${MODULE_VERSION}"; then
        log_info "Le module $MODULE_NAME version $MODULE_VERSION existe déjà. Nettoyage..."
        dkms remove -m $MODULE_NAME -v $MODULE_VERSION --all || log_error "Erreur lors de la suppression du module existant."
    fi

    # Méthode avec DKMS
    cp -r . /usr/src/${MODULE_NAME}-${MODULE_VERSION}
    dkms add -m $MODULE_NAME -v $MODULE_VERSION || log_error "Échec de dkms add."
    dkms build -m $MODULE_NAME -v $MODULE_VERSION || log_error "Échec de dkms build. Vérifiez que les en-têtes du noyau sont correctement installés."
    dkms install -m $MODULE_NAME -v $MODULE_VERSION || log_error "Échec de dkms install."

    # Chargement du module
    modprobe $MODULE_NAME || log_error "Impossible de charger le module $MODULE_NAME."
else
    log_error "Le dossier kmod est introuvable dans le dépôt."
fi


# 5. Copie des scripts et configuration
log_info "Copie des scripts et fichiers de configuration..."
if [ -d "$SCRIPTS_DIR" ]; then
    # Copier les scripts
    for script in ugreen-diskiomon ugreen-netdevmon ugreen-probe-leds; do
        chmod +x "$SCRIPTS_DIR/$script"
        cp "$SCRIPTS_DIR/$script" /usr/bin/ || log_error "Erreur lors de la copie de $script."
    done

    # Copier le fichier de configuration
    cp "$SCRIPTS_DIR/ugreen-leds.conf" "$CONF_FILE" || log_error "Erreur lors de la copie du fichier de configuration."

    # Copier les fichiers de service systemd
    cp "$SCRIPTS_DIR"/*.service "$SERVICE_FILES/" || log_error "Erreur lors de la copie des fichiers systemd."
    systemctl daemon-reload
else
    log_error "Le dossier scripts est introuvable."
fi

# 6. Activer et démarrer les services
log_info "Activation et démarrage des services..."
systemctl start ugreen-netdevmon@enp2s0 || log_error "Échec du démarrage du service ugreen-netdevmon."
systemctl start ugreen-diskiomon || log_error "Échec du démarrage du service ugreen-diskiomon."
systemctl enable ugreen-netdevmon@enp2s0
systemctl enable ugreen-diskiomon

# 7. Compilation optionnelle des outils
log_info "Compilation des outils optionnels..."
cd "$SCRIPTS_DIR" || log_error "Impossible d'accéder au répertoire $SCRIPTS_DIR."
g++ -std=c++17 -O2 blink-disk.cpp -o ugreen-blink-disk
cp ugreen-blink-disk /usr/bin || log_error "Erreur lors de la copie de ugreen-blink-disk."
g++ -std=c++17 -O2 check-standby.cpp -o ugreen-check-standby
cp ugreen-check-standby /usr/bin || log_error "Erreur lors de la copie de ugreen-check-standby."

# Fin
log_success "Installation complète ! Les LEDs sont prêtes à être configurées."
