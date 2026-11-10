{ config, lib, pkgs, sops-nix, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./serial.nix
    ./network/interfaces.nix
    ./network/firewall.nix
    ./services/openssh.nix
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yml;
    defaultSopsFormat = "yaml";

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."pppoe_credentials/bbexcite" = { };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "console=ttyS4,115200" ]; # see serial.nix for more

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    "net.ipv4.conf.all.arp_filter" = 1;
    "net.ipv4.conf.default.arp_filter" = 1;

    "net.ipv6.conf.enp4s0.proxy_ndp" = 1;
    "net.ipv6.conf.enp5s0.proxy_ndp" = 1;

    # TODO: reverse path filtering
  };

  networking = {
    hostName = "nixrouter";
    nameservers = [ "::1" ];
  };

  # use dnsproxy instead
  services.resolved.enable = false;

  services.dnsproxy = {
    enable = true;

    settings = {
      upstream = [
        "quic://[2620:fe::fe]/dns-query"
        "quic://[2620:fe::9]/dns-query"
      ];

      dnssec = true;
    };
  };

  services.ndppd = {
    enable = true;

    proxies."enp4s0" = {
      router = false;

      rules."2409:10:720:c200::/64" = {
        method = "iface";
        interface = "enp5s0";
      };
    };
  };

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.supervisor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
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
