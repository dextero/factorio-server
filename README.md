# dextero's Factorio server setup

# Installation

* Adjust absolute paths in `*.service` files as needed
* Install the systemd services:

    sudo systemctl enable $PWD/factorio-server.service
    sudo systemctl start factorio-server

    # optional: exporter for grafana; requires graftorio2 mod
    # https://mods.factorio.com/mod/graftorio2
    sudo systemctl enable $PWD/graftorio-exporter.service
    sudo systemctl start graftorio-exporter

* Add a crontab entry for auto updater script, for example:

    0 4 * * * systemd-cat /home/dex/factorio-server-update.sh
