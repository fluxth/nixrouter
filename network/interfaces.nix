{ config, lib, pkgs, sops-nix, ... }:

{
  # disable default dhcpcd and use systemd-networkd instead
  networking.useDHCP = false;
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;

    netdevs."15-dslite" = {
      netdevConfig = {
        Name = "wan4-dslite";
        Kind = "ip6tnl";
      };
      tunnelConfig = {
        Mode = "ipip6";
        Local = "slaac";
        Remote = "2404:8e00::feed:101";
        EncapsulationLimit = "none"; # otherwise the MTU drops to 1452
        DiscoverPathMTU = true;
      };
    };

    networks."10-backup" = {
      matchConfig.Name = "enp8s0"; # 2.5GbE port 5
      networkConfig = {
        DHCPServer = true;
      };
      dhcpServerConfig = {
        EmitRouter = false; # not router
        EmitDNS = false;
        PoolOffset = 100;
        PoolSize = 100;
      };
      address = [
        "192.168.1.1/24"
      ];
    };

    networks."20-wan6" = {
      matchConfig.Name = "enp4s0"; # 2.5GbE port 1
      networkConfig = {
        IPv6AcceptRA = "yes";
        IPv6Forwarding = true;
        IPv6LinkLocalAddressGenerationMode = "stable-privacy";
        IPv6PrivacyExtensions = true;
        Tunnel = "wan4-dslite";
      };
      ipv6AcceptRAConfig = {
        UseOnLinkPrefix = false;
        Token = "prefixstable";
      };
    };

    networks."25-wan4-dslite" = {
      matchConfig.Name = "wan4-dslite";
      linkConfig.MTUBytes = "1460";
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

    networks."26-wan4-pppoe" = {
      matchConfig.Name = "wan4-pppoe";
      linkConfig.MTUBytes = "1454";
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
          FirewallMark = "20";
          Table = "20";
        }
      ];
    };

    networks."30-lan" = {
      matchConfig.Name = "enp5s0"; # 2.5GbE port 2
      networkConfig = {
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPServer = true;
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
      address = [
        "2409:10:720:c200::1/64"
        "10.0.0.1/24"
      ];
      dhcpServerConfig = {
        EmitRouter = true;
        EmitDNS = true;
        PoolOffset = 100;
        PoolSize = 100;
        DNS = [
          "10.0.0.1"
        ];
      };
      ipv6SendRAConfig = {
        DNS = [ "2409:10:720:c200::1" ];
      };
      ipv6Prefixes = [
        {
          Prefix = "2409:10:720:c200::/64";
          OnLink = true;
          AddressAutoconfiguration = true;
        }
      ];
    };

    networks."90-labwan" = {
      matchConfig.Name = "enp7s0"; # 2.5GbE port 4
      networkConfig = {
        IPv6AcceptRA = "yes";
        DHCP = "yes";
      };
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
          enp4s0

          file ${config.sops.secrets."pppoe_credentials/bbexcite".path}

          persist
          noipdefault
          nodefaultroute
          noauth
          hide-password
          maxfail 0
          holdoff 10
          mtu 1454

          ifname wan4-pppoe
        '';
      };
    };
  };

  environment.etc.ppp-up = {
    enable = true;
    target = "ppp/ip-up";
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.logger}/bin/logger "$1 is up"
      if [ $IFNAME = "wan4-pppoe" ]; then
        ${pkgs.logger}/bin/logger "bbexcite pppoe online, adding default route"

        ${pkgs.iproute2}/bin/ip route add default dev wan4-pppoe table 20
        ${pkgs.systemd}/bin/networkctl reconfigure wan4-pppoe
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
      if [ $IFNAME = "wan4-pppoe" ]; then
        ${pkgs.logger}/bin/logger "bbexcite pppoe offline, removing default route"

        ${pkgs.iproute2}/bin/ip route del default dev wan4-pppoe table 20
      fi
    '';
  };
}
