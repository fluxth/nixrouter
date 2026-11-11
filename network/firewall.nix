{
  config,
  lib,
  pkgs,
  ...
}:

let
  constants = import ./constants.nix;
  firewallRuleset = builtins.readFile ./firewall.nft;
in
{
  # disable nixos default firewall, use raw netfilter instead
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;

    flushRuleset = true; # replace, not add
    ruleset = ''
      define transix_iface = "${constants.transixIface}"
      define transix_endpoints = ${constants.transixEndpointSet}

      define wan_iface = "${constants.wanIface}"
      define lan_iface = "${constants.lanIface}"
      define lan_ipv6_prefix = ${constants.lanIpv6Prefix}
      define lan_ipv4_prefix = ${constants.lanIpv4Prefix}

      define pppoe_iface = "${constants.pppoeIface}"
      define pppoe_ct_mark = ${constants.pppoeConntrackMark}

      # firewall rules are in external file firewall.nft
      ${firewallRuleset}
    '';
  };
}
