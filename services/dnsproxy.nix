{
  config,
  lib,
  pkgs,
  ...
}:

{
  # use dnsproxy instead
  services.resolved.enable = false;
  networking.nameservers = [ "::1" ];

  services.dnsproxy = {
    enable = true;

    settings = {
      upstream = [
        "quic://[2620:fe::fe]/dns-query"
        "quic://[2620:fe::9]/dns-query"
      ];

      dnssec = true;
    };
  };
}
