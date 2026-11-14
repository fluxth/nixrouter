{
  config,
  lib,
  pkgs,
  ddns,
  sops-nix,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  # see network/interfaces.nix for network interface configuration
  services.pppd = {
    enable = true;
    peers = {
      bbexcite = {
        autostart = true;
        enable = true;
        config = ''
          plugin pppoe.so
          ${constants.wanIface}

          file ${config.sops.secrets."pppoe_credentials/bbexcite".path}

          persist
          noipdefault
          nodefaultroute
          noauth
          hide-password
          maxfail 0
          holdoff 10
          mtu ${constants.pppoeMTU}

          ifname ${constants.pppoeIface}
        '';
      };
    };
  };

  # default was 1m30s, too long since we don't depend on pppoe on ipoe side
  systemd.services."pppd-bbexcite".serviceConfig.TimeoutStartSec = "15s";

  environment.etc.ppp-up = {
    enable = true;
    target = "ppp/ip-up";
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.logger}/bin/logger "$1 is up"
      if [ $IFNAME = "${constants.pppoeIface}" ]; then
        ${pkgs.logger}/bin/logger "${constants.pppoeIface} online, adding default route"

        ${pkgs.iproute2}/bin/ip route add default dev ${constants.pppoeIface} table ${constants.pppoeRouteTable}
        ${pkgs.systemd}/bin/networkctl reconfigure ${constants.pppoeIface}
        ${ddns}/bin/ddns "$4" &
      fi
    '';
  };

  environment.etc.ppp-down = {
    enable = true;
    target = "ppp/ip-down";
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.logger}/bin/logger "$1 is down"
      if [ $IFNAME = "${constants.pppoeIface}" ]; then
        ${pkgs.logger}/bin/logger "${constants.pppoeIface} offline, removing default route"

        ${pkgs.iproute2}/bin/ip route del default dev ${constants.pppoeIface} table ${constants.pppoeRouteTable}
      fi
    '';
  };
}
