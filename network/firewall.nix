{
  config,
  lib,
  pkgs,
  ...
}:

{
  # disable nixos default firewall, use raw netfilter instead
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;

    flushRuleset = true; # replace, not add
    ruleset = builtins.readFile ./firewall.nft;
  };
}
