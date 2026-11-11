{
  config,
  lib,
  pkgs,
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
}
