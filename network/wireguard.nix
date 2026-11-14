{
  config,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  systemd.network.netdevs."110-wg0" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = constants.wg0Iface;
    };

    wireguardConfig = {
      ListenPort = 55240;
      RouteTable = "main";
      FirewallMark = constants.pppoeFirewallMark; # ipv4 return traffic needs to go out pppoe path
      PrivateKeyFile = config.sops.secrets."wireguard/wg0/private_key".path;
    };

    wireguardPeers = [
      {
        # peer2
        PublicKey = "EMPRA0Y/9PTn10CSZvXbGvg08ryxiohO98HIM+kKTWw=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg0/peer2/preshared_key".path;
        AllowedIPs = [
          "${constants.wg0Ipv6UlaTemplatePrefix}::2"
          "${constants.wg0Ipv4TemplatePrefix}.2"
        ];
      }
      {
        # peer3
        PublicKey = "fvClwt/f8GBRp+ps3677Y0e+or3/62q04DLVb3NQ5FI=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg0/peer3/preshared_key".path;
        AllowedIPs = [
          "${constants.wg0Ipv6UlaTemplatePrefix}::3"
          "${constants.wg0Ipv4TemplatePrefix}.3"
        ];
      }
      {
        # peer4
        PublicKey = "2Vw2S3XvXil0xx/tXdsFy1Qw59oVvF+0hPlMbEjGehE=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg0/peer4/preshared_key".path;
        AllowedIPs = [
          "${constants.wg0Ipv6UlaTemplatePrefix}::4"
          "${constants.wg0Ipv4TemplatePrefix}.4"
        ];
      }
      {
        # peer5
        PublicKey = "cVTpXdzHZ74cDf8XGsu2XZAgtPxvpN+KidO6Nf2OjhE=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg0/peer5/preshared_key".path;
        AllowedIPs = [
          "${constants.wg0Ipv6UlaTemplatePrefix}::5"
          "${constants.wg0Ipv4TemplatePrefix}.5"
        ];
      }
      {
        # peer6
        PublicKey = "l/Z2s+Q1g9hIOOM+QW0FsXmVYCnbNGR0vza2TJAS33I=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg0/peer6/preshared_key".path;
        AllowedIPs = [
          "${constants.wg0Ipv6UlaTemplatePrefix}::6"
          "${constants.wg0Ipv4TemplatePrefix}.6"
        ];
      }
    ];
  };

  systemd.network.netdevs."111-wg1" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = constants.wg1Iface;
    };

    wireguardConfig = {
      ListenPort = 55241;
      RouteTable = "main";
      FirewallMark = constants.pppoeFirewallMark; # ipv4 return traffic needs to go out pppoe path
      PrivateKeyFile = config.sops.secrets."wireguard/wg1/private_key".path;
    };

    wireguardPeers = [
      {
        # peer2
        PublicKey = "r8E4JE3Q5mrQnOROL4vSv7XvvsW5rbcklsUKhuDUfl0=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer2/preshared_key".path;
        AllowedIPs = [
          "${constants.wg1Ipv6TemplatePrefix}::2"
          "${constants.wg1Ipv6UlaTemplatePrefix}::2"
          "${constants.wg1Ipv4TemplatePrefix}.2"
        ];
      }
      {
        # peer3
        PublicKey = "MBAuopZqP/12f2BMwwByitDK2/X7ysZ7CfGCGzHu7kM=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer3/preshared_key".path;
        AllowedIPs = [
          "${constants.wg1Ipv6TemplatePrefix}::3"
          "${constants.wg1Ipv6UlaTemplatePrefix}::3"
          "${constants.wg1Ipv4TemplatePrefix}.3"
        ];
      }
      # TODO: peer4
      {
        # peer5
        PublicKey = "FW8jkvupbneKe5FJWWSh/SJP5hiInaHWth/muyoJGAY=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer5/preshared_key".path;
        AllowedIPs = [
          "${constants.wg1Ipv6TemplatePrefix}::5"
          "${constants.wg1Ipv6UlaTemplatePrefix}::5"
          "${constants.wg1Ipv4TemplatePrefix}.5"
        ];
      }
      {
        # peer6
        PublicKey = "DmuwPW9NEUgXIlOXgHDj5jpW08cB7H9fSG8+6bOn6QY=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer6/preshared_key".path;
        AllowedIPs = [
          "${constants.wg1Ipv6TemplatePrefix}::6"
          "${constants.wg1Ipv6UlaTemplatePrefix}::6"
          "${constants.wg1Ipv4TemplatePrefix}.6"
        ];
      }
    ];
  };
}
