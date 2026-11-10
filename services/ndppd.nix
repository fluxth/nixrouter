{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.ndppd = {
    enable = true;

    proxies."enp4s0" = {
      router = false;

      rules."2409:10:720:c200::/64" = {
        method = "iface";
        interface = "enp5s0";
      };
    };
  };
}
