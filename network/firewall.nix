{
  config,
  lib,
  pkgs,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  # keep kernel config in sync with the firewall
  boot.kernel.sysctl."net.ipv4.ip_local_port_range" =
    "${constants.selfEphemeralPortStart} ${constants.selfEphemeralPortEnd}";

  # disable nixos default firewall, use raw netfilter instead
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;

    # HACK: when checking rules at build time, interfaces don't exist
    # https://discourse.nixos.org/t/nftables-could-not-process-rule-no-such-file-or-directory/33031
    preCheckRuleset = "sed 's/devices = {.*}/devices = { lo }/' -i ruleset.conf";

    flushRuleset = true; # replace, not add
    ruleset = ''
      define wan_iface = "${constants.wanIface}"

      define transix_iface = "${constants.transixIface}"
      define transix_endpoints = ${constants.transixEndpointSet}

      define lan_iface = "${constants.lanIface}"

      define pppoe_iface = "${constants.pppoeIface}"
      define pppoe_ct_mark = ${constants.pppoeConntrackMark}

      define wg1_ipv6_prefix = ${constants.wg1Ipv6Prefix}

      define zone_wan_ifaces = { $wan_iface, $transix_iface, $pppoe_iface }
      define zone_lan_ifaces = { $lan_iface }
      define zone_wg0_ifaces = "${constants.wg0Iface}"
      define zone_wg1_ifaces = "${constants.wg1Iface}"

      define self_ephemeral_port_range = ${constants.selfEphemeralPortStart}-${constants.selfEphemeralPortEnd}

      # firewall rules are in external files in network/nftables directory

      table inet filter {
        # flowtable needs to be here for the preCheckRuleset hack above to work
        flowtable fastpath {
          hook ingress priority filter
          devices = ${constants.fastpathIfaces}
        }

        include "${./nftables/filter_prerouting.nft}"
        include "${./nftables/filter_input.nft}"
        include "${./nftables/filter_forward.nft}"
        include "${./nftables/filter_output.nft}"
      }

      table inet raw {
        include "${./nftables/prefixes/ipv4_bogons.nft}"
        include "${./nftables/prefixes/ipv4_private.nft}"
        include "${./nftables/prefixes/ipv6_bogons.nft}"
        include "${./nftables/prefixes/ipv6_linklocal.nft}"

        include "${./nftables/raw.nft}"
      }

      table inet mangle {
        include "${./nftables/mangle.nft}"
      }

      table inet srcnat {
        include "${./nftables/srcnat.nft}"
      }
    '';
  };
}
