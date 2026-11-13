rec {
  upstreamDelegatedPrefix = "2409:10:720:c200";
  upstreamDelegatedPrefixSize = "64"; # without hikari denwa, there is no /56 prefix delegation :(

  wanIface = "enp4s0"; # 2.5GbE port 1
  wanIpv6Prefix = "${upstreamDelegatedPrefix}::/${upstreamDelegatedPrefixSize}";

  transixIface = "wan4-dslite";
  transixMTU = "1460"; # ipv4 over ipv6
  transixEndpointSet = "{ 2404:8e00::feed:100, 2404:8e00::feed:101, 2404:8e00::feed:102 }"; # nft set, for firewall
  transixEndpoint = "2404:8e00::feed:101"; # the one to use

  pppoeIface = "wan4-pppoe";
  pppoeMTU = "1454"; # because NGN black magic tunneling thingy
  pppoeConntrackMark = "20";
  pppoeFirewallMark = "20";
  pppoeRouteTable = "20";

  lanIface = "br-lan";
  lanIpv6Prefix = wanIpv6Prefix; # proxy NDP from wan
  lanIpv6Host = "${upstreamDelegatedPrefix}::1";
  lanIpv6HostPrefix = "${lanIpv6Host}/${upstreamDelegatedPrefixSize}";
  lanIpv6UlaPrefix = "fd42:80c2:5fd6:1::/64";
  lanIpv6UlaHost = "fd42:80c2:5fd6:1::1";
  lanIpv6UlaHostPrefix = "${lanIpv6UlaHost}/64";
  lanIpv4Prefix = "172.24.1.0/24";
  lanIpv4Host = "172.24.1.254";
  lanIpv4HostPrefix = "${lanIpv4Host}/24";
  lanIfaceSlaves = [
    {
      # 2.5GbE port 2
      configName = "310-eth2";
      ifaceName = "enp5s0";
    }
    {
      # 2.5GbE port 3
      configName = "311-eth3";
      ifaceName = "enp6s0";
    }
    {
      # 2.5GbE port 4
      configName = "312-eth4";
      ifaceName = "enp7s0";
    }
    {
      # 2.5GbE port 5
      configName = "313-eth5";
      ifaceName = "enp8s0";
    }
    {
      # 10G SFP+ port 6
      configName = "314-sfp6";
      ifaceName = "eno1";
    }
    {
      # 10G SFP+ port 7
      configName = "315-sfp7";
      ifaceName = "eno2";
    }
    {
      # 10G SFP+ port 8
      configName = "316-sfp8";
      ifaceName = "eno3";
    }
    {
      # 10G SFP+ port 9
      configName = "317-sfp9";
      ifaceName = "eno4";
    }
  ];

  fastpathIfaces = "{ enp4s0, enp5s0, enp6s0, enp7s0, enp8s0, eno1, eno2, eno3, eno4 }"; # nft set, for firewall

  selfEphemeralPortStart = "32768";
  selfEphemeralPortEnd = "60999";
}
