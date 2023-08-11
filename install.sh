#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

color() {
    case "$1" in
        RED) echo -en "\x1b[31m" ;;
        GREEN) echo -en "\x1b[32m" ;;
        YELLOW) echo -en "\x1b[33m" ;;
        BLUE) echo -en "\x1b[34m" ;;
        BOLD) echo -en "\x1b[1m" ;;
        DEFAULT) echo -en "\x1b[0m" ;;
    esac
}

confirm() {
    read -p "$(color BOLD)$* [Y/n]: $(color DEFAULT)" RESULT
    case RESULT in
        y*|Y*) ;;
        *) return 1 ;;
    esac
}

require-command() {
    for ARG; do
        echo -n "Check for $ARG... "
        if ! which "$ARG" 2>/dev/null; then
            echo "$(color YELLOW)missing$(color DEFAULT)"
            echo "$(color GREEN)Installing $ARG (may ask for root password)$(color DEFAULT)"
            sudo apt install "$ARG"
        fi
    done
}

require-command docker-compose

read -p "$(color BOLD)User to run the server as$(color DEFAULT) [$USER]: " FACTORIO_USER
read -p "$(color BOLD)Group to run the server as$(color DEFAULT) [$USER]: " FACTORIO_GROUP

[[ "$FACTORIO_USER" ]] || FACTORIO_USER="$USER"
[[ "$FACTORIO_GROUP" ]] || FACTORIO_GROUP="$GROUP"

echo -n "Check if $FACTORIO_USER can control docker... "
if ! id -nG "$FACTORIO_USER" | grep docker; then
    echo "$(color YELLOW)no$(color DEFAULT)"
    echo "$(color GREEN)Adding $FACTORIO_USER to group docker (may ask for root password)$(color DEFAULT)"
    sudo gpasswd --add "$FACTORIO_USER" docker
fi

preprocess() {
    sed -e "s/@@USER@@/$FACTORIO_USER/g" \
        -e "s/@@GROUP@@/$FACTORIO_GROUP/g" \
        -e "s|@@SCRIPT_DIR@@|$SCRIPT_DIR|g" \
        "$1"
}

echo "Setting up factorio server"
echo "* Creating factorio-server.service"
preprocess "$SCRIPT_DIR/factorio-server.service.in" > "$SCRIPT_DIR/factorio-server.service"
echo "* Installing systemd service (may ask for root password)"
sudo systemctl enable "$SCRIPT_DIR/factorio-server.service"
echo "* Starting the server (may ask for root password)"
sudo systemctl start factorio-server

confirm "Set up the data exporter for Grafana?" && WITH_GRAFANA=1 || WITH_GRAFANA=
if [[ "$WITH_GRAFANA" ]]; then
    echo "* Creating graftorio-exporter.service"
    preprocess "$SCRIPT_DIR/graftorio-exporter.service.in" > "$SCRIPT_DIR/graftorio-exporter.service"
    echo "* Installing systemd service (may ask for root password)"
    sudo systemctl enable "$SCRIPT_DIR/graftorio-exporter.service"
    echo "Starting the exporter (may ask for root password)"
    sudo systemctl start graftorio-exporter
fi

if crontab -l | grep factorio-server-update.sh; then
    echo "Auto-updater already in crontab"
elif confirm "Add auto-updater to crontab?"; then
    cat <(crontab -l) <(echo "0 4 * * * systemd-cat $SCRIPT_DIR/factorio-server-update.sh") > crontab -
    echo "crontab entry added"
fi

cat <<EOF
$(color GREEN)All done!$(color DEFAULT)

To restart server:

  sudo systemctl restart factorio-server

To check server logs:

  sudo journalctl -xeu factorio-server

EOF
if [[ "$WITH_GRAFANA" ]]; then
    cat <<EOF
To restart Grafana data provider:

  sudo systemctl restart graftorio-exporter

EOF
fi
