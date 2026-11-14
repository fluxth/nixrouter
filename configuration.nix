{
  config,
  lib,
  pkgs,
  sops-nix,
  ...
}:

let
  sopsNetworkdOwner = {
    owner = "root";
    group = "systemd-network";
    mode = "0440";
  };
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  imports = [
    ./serial.nix
    ./network/interfaces.nix
    ./network/firewall.nix
    ./network/pppoe.nix
    ./network/wireguard.nix
    ./services/openssh.nix
    ./services/dnsproxy.nix
    ./services/ndppd.nix
    ./services/ddns.nix
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yml;
    defaultSopsFormat = "yaml";

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."pppoe_credentials/bbexcite" = { };
    secrets."ddns/aws_credentials" = { };
    secrets."ddns/envfile" = { };
    secrets."wireguard/wg1/private_key" = sopsNetworkdOwner;
    secrets."wireguard/wg1/peer2/preshared_key" = sopsNetworkdOwner;
    secrets."wireguard/wg1/peer3/preshared_key" = sopsNetworkdOwner;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "console=ttyS4,115200" ]; # see serial.nix for more

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixrouter";

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";

  security.sudo.wheelNeedsPassword = false;
  users.users.supervisor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      git
      dig
      htop
      sops
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzo/1Jt86KbVV2gVFG27JqyxglPejOZrN/B6Eo/YDi5" # content of authorized_keys file
    ];
  };

  environment = {
    variables.EDITOR = "vim";
    systemPackages = with pkgs; [
      vim
      tcpdump
      conntrack-tools
    ];
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
