rec {
  upstreamDelegatedTemplatePrefix = "2409:10:720:c200";
  upstreamDelegatedTemplatePrefixSize = "64"; # without hikari denwa, there is no /56 prefix delegation :(

  # yeah, in theory this should be owned by me but NTT is refusing to route it
  # so might as well use it to trick RFC6724 behavior until the IETF fixes ULA in their new draft
  # RANT: IETF was rightly worried that ULA would be used for NAPT like ipv4 but isps are so incompetent that we have to use it like that anyway
  ownedIpv6GuaTemplatePrefix = "2409:10:720:c2"; # this is /56
  ipv6UlaTemplatePrefix = "fd42:80c2:5fd6"; # this is /48

  wanIface = "enp4s0"; # 2.5GbE port 1
  wanIpv6Prefix = "${upstreamDelegatedTemplatePrefix}::/${upstreamDelegatedTemplatePrefixSize}";

  transixIface = "wan4-dslite";
  transixMTU = "1460"; # ipv4 over ipv6
  transixEndpointSet = "{ 2404:8e00::feed:100, 2404:8e00::feed:101, 2404:8e00::feed:102 }"; # nft set, for firewall
  transixEndpoint = "2404:8e00::feed:101"; # the one to use

  pppoeIface = "wan4-pppoe";
  pppoeMTU = "1454"; # because NGN black magic tunneling thingy
  pppoeConntrackMark = "20";
  pppoeFirewallMark = 20;
  pppoeRouteTable = "20";

  lanIface = "br-lan";
  lanIpv6Host = "${upstreamDelegatedTemplatePrefix}::1";
  lanIpv6HostPrefix = "${lanIpv6Host}/${upstreamDelegatedTemplatePrefixSize}";
  lanIpv6UlaPrefix = "${ipv6UlaTemplatePrefix}:1::/64";
  lanIpv6UlaHost = "${ipv6UlaTemplatePrefix}:1::1";
  lanIpv6UlaHostPrefix = "${lanIpv6UlaHost}/64";
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

  wg0Iface = "wg0";
  wg0Ipv6UlaTemplatePrefix = "${ipv6UlaTemplatePrefix}:f0";
  wg0Ipv6UlaHost = "${wg0Ipv6UlaTemplatePrefix}::1";
  wg0Ipv6UlaHostPrefix = "${wg0Ipv6UlaHost}/128";
  wg0Ipv4TemplatePrefix = "10.242.0";
  wg0Ipv4Host = "${wg0Ipv4TemplatePrefix}.1";
  wg0Ipv4HostPrefix = "${wg0Ipv4Host}/32";

  wg1Iface = "wg1";
  wg1Ipv6TemplatePrefix = "${ownedIpv6GuaTemplatePrefix}f1";
  wg1Ipv6Prefix = "${wg1Ipv6TemplatePrefix}::/64"; # for srcnat sadly
  wg1Ipv6Host = "${wg1Ipv6TemplatePrefix}::1";
  wg1Ipv6HostPrefix = "${wg1Ipv6Host}/128";
  wg1Ipv6UlaTemplatePrefix = "${ipv6UlaTemplatePrefix}:f1";
  wg1Ipv6UlaHost = "${wg1Ipv6UlaTemplatePrefix}::1";
  wg1Ipv6UlaHostPrefix = "${wg1Ipv6UlaHost}/128";
  wg1Ipv4TemplatePrefix = "172.25.1";
  wg1Ipv4Host = "${wg1Ipv4TemplatePrefix}.1";
  wg1Ipv4HostPrefix = "${wg1Ipv4Host}/32";

  fastpathIfaces = "{ enp4s0, enp5s0, enp6s0, enp7s0, enp8s0, eno1, eno2, eno3, eno4 }"; # nft set, for firewall

  selfEphemeralPortStart = "32768";
  selfEphemeralPortEnd = "60999";
}
