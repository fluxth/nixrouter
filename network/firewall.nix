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
  # keep kernel config in sync with the firewall
  boot.kernel.sysctl."net.ipv4.ip_local_port_range" =
    "${constants.selfEphemeralPortStart} ${constants.selfEphemeralPortEnd}";

  # disable nixos default firewall, use raw netfilter instead
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;

    flushRuleset = true; # replace, not add
    ruleset = ''
      define wan_iface = "${constants.wanIface}"

      define transix_iface = "${constants.transixIface}"
      define transix_endpoints = ${constants.transixEndpointSet}

      define lan_iface = "${constants.lanIface}"
      define lan_ipv6_prefix = ${constants.lanIpv6Prefix}
      define lan_ipv4_prefix = ${constants.lanIpv4Prefix}

      define pppoe_iface = "${constants.pppoeIface}"
      define pppoe_ct_mark = ${constants.pppoeConntrackMark}

      define zone_wan_ifaces = { $wan_iface, $transix_iface, $pppoe_iface }
      define zone_lan_ifaces = { $lan_iface }

      define self_ephemeral_port_range = ${constants.selfEphemeralPortStart}-${constants.selfEphemeralPortEnd}

      # firewall rules are in external files in network/nftables directory

      table inet filter {
        include "${builtins.toFile "firewall-filter.nft" (builtins.readFile ./nftables/filter.nft)}"
      }

      table inet raw {
        include "${builtins.toFile "prefixes-ipv4-bogons.nft" (builtins.readFile ./nftables/prefixes/ipv4_bogons.nft)}"
        include "${builtins.toFile "prefixes-ipv4-private.nft" (builtins.readFile ./nftables/prefixes/ipv4_private.nft)}"
        include "${builtins.toFile "prefixes-ipv6-bogons.nft" (builtins.readFile ./nftables/prefixes/ipv6_bogons.nft)}"
        include "${builtins.toFile "prefixes-ipv6-linklocal.nft" (builtins.readFile ./nftables/prefixes/ipv6_linklocal.nft)}"

        include "${builtins.toFile "firewall-raw.nft" (builtins.readFile ./nftables/raw.nft)}"
      }

      table inet mangle {
        include "${builtins.toFile "firewall-mangle.nft" (builtins.readFile ./nftables/mangle.nft)}"
      }
    '';
  };
}
