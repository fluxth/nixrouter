{
  config,
  lib,
  pkgs,
  sops-nix,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  # disable default dhcpcd and use systemd-networkd instead
  networking.useDHCP = false;
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;

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

    networks."200-wan6" = {
      matchConfig.Name = constants.wanIface;
      networkConfig = {
        IPv6AcceptRA = "yes";
        IPv6Forwarding = true;
        IPv6LinkLocalAddressGenerationMode = "stable-privacy";
        IPv6PrivacyExtensions = true;
        Tunnel = constants.transixIface;
      };
      ipv6AcceptRAConfig = {
        UseOnLinkPrefix = false;
        Token = "prefixstable";
      };
    };

    networks."210-wan4-dslite" = {
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

    networks."220-wan4-pppoe" = {
      matchConfig.Name = constants.pppoeIface;
      linkConfig.MTUBytes = constants.pppoeMTU;
      linkConfig.RequiredForOnline = false;
      networkConfig = {
        IPv4Forwarding = false; # turn this on if want to use as a gateway for lan
        KeepConfiguration = true; # otherwise it clears ip that pppd set
        LinkLocalAddressing = "no";
        IPv6AcceptRA = false;
      };
      # default routes are configured in ppp hooks due to race
      routingPolicyRules = [
        {
          FirewallMark = constants.pppoeFirewallMark;
          Table = constants.pppoeRouteTable;
        }
      ];
    };

    networks."300-lan" = {
      matchConfig.Name = constants.lanIface;
      networkConfig = {
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPServer = true;
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
      address = [
        constants.lanIpv6HostPrefix
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
        DNS = [ constants.lanIpv6Host ];
      };
      ipv6Prefixes = [
        {
          Prefix = constants.wanIpv6Prefix;
          OnLink = true;
          AddressAutoconfiguration = true;
        }
      ];
    };
  };

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
