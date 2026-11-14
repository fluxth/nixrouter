{
  config,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
in
{
  systemd.network.netdevs."110-wg1" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = "wg1";
    };

    wireguardConfig = {
      ListenPort = 55241;
      RouteTable = "main";
      FirewallMark = 20;
      PrivateKeyFile = config.sops.secrets."wireguard/wg1/private_key".path;
    };

    wireguardPeers = [
      {
        # peer2
        PublicKey = "r8E4JE3Q5mrQnOROL4vSv7XvvsW5rbcklsUKhuDUfl0=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer2/preshared_key".path;
        AllowedIPs = [
          "2409:10:720:c2f1::2"
          "fd42:80c2:5fd6:f1::2"
          "172.25.1.2"
        ];
      }
      {
        # peer3
        PublicKey = "MBAuopZqP/12f2BMwwByitDK2/X7ysZ7CfGCGzHu7kM=";
        PresharedKeyFile = config.sops.secrets."wireguard/wg1/peer3/preshared_key".path;
        AllowedIPs = [
          "2409:10:720:c2f1::3"
          "fd42:80c2:5fd6:f1::3"
          "172.25.1.3"
        ];
      }
    ];
  };
}
