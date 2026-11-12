{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  constants = import ../network/constants.nix;
in
{
  services.ndppd = {
    enable = true;

    proxies."${constants.wanIface}" = {
      router = false;

      rules."${constants.wanIpv6Prefix}" = {
        method = "iface";
        interface = constants.lanIface;
      };
    };
  };

  # declare ndppd needs to start after networkd setup these interfaces
  systemd.services.ndppd = {
    bindsTo = [
      "sys-subsystem-net-devices-${constants.wanIface}.device"
      "sys-subsystem-net-devices-${utils.escapeSystemdPath constants.lanIface}.device"
    ];
    after = [
      "sys-subsystem-net-devices-${constants.wanIface}.device"
      "sys-subsystem-net-devices-${utils.escapeSystemdPath constants.lanIface}.device"
      "systemd-networkd.service"
    ];
  };
}
