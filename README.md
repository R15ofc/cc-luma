# Luma Browser

Luma is the browser and in-game internet layer for the RIG platform.

Repositories:

- RIG core: `R15ofc/cc-rig`
- DockOS: `R15ofc/cc-dock`
- Luma Browser: `R15ofc/cc-luma`

## Install

From DockOS:

```lua
dock store install luma
```

Direct install:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua luma-installer.lua
luma-installer.lua
```

## Commands

```lua
luma
luma open luma://home
luma search packages
luma gateway set http://192.168.31.21:9000
```

## CC Server PC

Use this on a CC PC with a modem if you want a separate Luma page server:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua luma-installer.lua
luma-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc
luma-server startup install
luma-server
```

The startup hook runs `/startup/luma-server.lua` after reboot.

## Internet Gateway

Use this on a real PC/Mac/Linux host when Luma should fetch normal HTTP/HTTPS pages through one allowed local address:

```sh
mkdir -p ~/cc-luma-gateway
cd ~/cc-luma-gateway
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-luma/main/server/luma-gateway.py
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-luma/main/server/startup-luma-gateway.sh
chmod +x luma-gateway.py startup-luma-gateway.sh
./startup-luma-gateway.sh
```

Then on the CC computer:

```lua
luma gateway set http://192.168.31.21:9000
```
