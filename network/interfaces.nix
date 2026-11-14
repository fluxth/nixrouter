{
  config,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  # disable default dhcpcd and use systemd-networkd instead
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # NOTE: in a perfect world the forwarding,proxy_ndp ones would be set per
  # interface by networkd and these wouldn't be needed, but we are in a meat
  # world where we have to proxy ndp and ndppd requires these to be set.
  # Reference: https://docs.kernel.org/networking/ip-sysctl.html
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    "net.ipv4.conf.all.arp_filter" = true;
    "net.ipv4.conf.default.arp_filter" = true;

    "net.ipv6.conf.enp4s0.proxy_ndp" = true;
    "net.ipv6.conf.enp5s0.proxy_ndp" = true;
  };

  systemd.network = {
    enable = true;

    netdevs."100-br-lan" = {
      netdevConfig = {
        Name = constants.lanIface;
        Kind = "bridge";
      };
    };

    netdevs."100-wan4-dslite" = {
      netdevConfig = {
        Name = constants.transixIface;
        Kind = "ip6tnl";
      };
      tunnelConfig = {
        Mode = "ipip6";
        Local = "slaac";
        Remote = constants.transixEndpoint;
        EncapsulationLimit = "none"; # otherwise the MTU drops by 8 bytes (1460 to 1452)
        DiscoverPathMTU = true;
      };
    };

    networks = lib.mkMerge [
      {
        "200-wan6" = {
          matchConfig.Name = constants.wanIface;
          networkConfig = {
            IPv6Forwarding = true;
            IPv6ProxyNDP = true;

            IPv6AcceptRA = true;
            IPv6LinkLocalAddressGenerationMode = "stable-privacy";
            IPv6PrivacyExtensions = true;
            Tunnel = constants.transixIface;
          };
          ipv6AcceptRAConfig = {
            UseOnLinkPrefix = false;
            Token = "prefixstable";
          };
        };
      }
      {
        "210-wan4-dslite" = {
          matchConfig.Name = constants.transixIface;
          linkConfig.MTUBytes = constants.transixMTU;
          networkConfig = {
            IPv4Forwarding = true;
          };
          address = [ "192.0.0.2" ];
          routes = [
            {
              Destination = "0.0.0.0/0";
            }
          ];
        };
      }
      {
        # see network/pppoe.nix for more
        "220-wan4-pppoe" = {
          matchConfig.Name = constants.pppoeIface;
          linkConfig.MTUBytes = constants.pppoeMTU;
          linkConfig.RequiredForOnline = false;
          networkConfig = {
            IPv4Forwarding = false; # turn this on if want to use as a gateway for lan

            KeepConfiguration = true; # otherwise it clears ip that pppd set
            LinkLocalAddressing = "no";
            IPv6AcceptRA = false;
          };
          linkConfig = {
            Multicast = false; # it is basically an ipv4-only point to point link here, do not do this if it has ipv6
          };
          # default routes are configured in ppp hooks due to race
          routingPolicyRules = [
            {
              FirewallMark = constants.pppoeFirewallMark;
              Table = constants.pppoeRouteTable;
            }
          ];
        };
      }
      {
        "300-br-lan" = {
          matchConfig.Name = constants.lanIface;
          networkConfig = {
            IPv6Forwarding = true;
            IPv4Forwarding = true;
            IPv6ProxyNDP = true;

            IPv6SendRA = true;
            IPv6AcceptRA = false;
            DHCPServer = true;

            ConfigureWithoutCarrier = true;
          };
          address = [
            constants.lanIpv6HostPrefix
            constants.lanIpv6UlaHostPrefix
            constants.lanIpv4HostPrefix
          ];
          dhcpServerConfig = {
            EmitRouter = true;
            EmitDNS = true;
            PoolOffset = 0;
            PoolSize = 200;
            DNS = [ constants.lanIpv4Host ];
          };
          ipv6SendRAConfig = {
            DNS = [
              constants.lanIpv6Host
              constants.lanIpv6UlaHost
            ];
          };
          ipv6Prefixes = [
            {
              Prefix = constants.wanIpv6Prefix;
              OnLink = false; # proxied NDP
              AddressAutoconfiguration = true;
            }
            {
              Prefix = constants.lanIpv6UlaPrefix;
              OnLink = true;
              AddressAutoconfiguration = true;
            }
          ];
        };
      }
      # configure lan bridge slave interfaces
      (builtins.listToAttrs (
        map (
          item:
          lib.nameValuePair item.configName {
            matchConfig.Name = item.ifaceName;
            networkConfig = {
              Bridge = constants.lanIface;
              ConfigureWithoutCarrier = true;
            };
            linkConfig = {
              RequiredForOnline = "no";
            };
          }
        ) constants.lanIfaceSlaves
      ))
      {
        "400-wg1" = {
          matchConfig.Name = "wg1";
          linkConfig.MTUBytes = 1394;
          address = [
            "2409:10:720:c2f1::1/128"
            "fd42:80c2:5fd6:f1::1/128"
            "172.25.1.1/32"
          ];
        };
      }
    ];
  };
}
