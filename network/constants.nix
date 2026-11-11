rec {
  upstreamDelegatedPrefix = "2409:10:720:c200";
  upstreamDelegatedPrefixSize = "64"; # without hikari denwa, there is no /56 prefix delegation :(

  wanIface = "enp4s0"; # 2.5GbE port 1
  wanIpv6Prefix = "${upstreamDelegatedPrefix}::/${upstreamDelegatedPrefixSize}";

  lanIface = "enp5s0"; # 2.5GbE port 2
  lanIpv6Prefix = wanIpv6Prefix; # proxy NDP from wan
  lanIpv6Host = "${upstreamDelegatedPrefix}::1";
  lanIpv6HostPrefix = "${lanIpv6Host}/${upstreamDelegatedPrefixSize}";
  lanIpv4Prefix = "172.24.100.0/24";
  lanIpv4Host = "172.24.100.254";
  lanIpv4HostPrefix = "${lanIpv4Host}/24";

  transixIface = "wan4-dslite";
  transixMTU = "1460"; # ipv4 over ipv6
  transixEndpointSet = "{ 2404:8e00::feed:100, 2404:8e00::feed:101, 2404:8e00::feed:102 }"; # nft set, for firewall
  transixEndpoint = "2404:8e00::feed:101"; # the one to use

  pppoeIface = "wan4-pppoe";
  pppoeMTU = "1454"; # because NGN black magic tunneling thingy
  pppoeConntrackMark = "20";
  pppoeFirewallMark = "20";
  pppoeRouteTable = "20";

  selfEphemeralPortStart = "32768";
  selfEphemeralPortEnd = "60999";
}
