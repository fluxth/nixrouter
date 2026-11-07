# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "console=ttyS4,115200"
  ];

  # Disable the upstream getty module's automatic configuration for serial-getty@
  # This prevents conflicts with our custom configuration
  systemd.services."serial-getty@" = {
    enable = false;
  };

  # Configure our own serial-getty@ttyS4 service
  systemd.services."serial-getty@ttyS4" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    after = [ "systemd-user-sessions.service" ];
    wants = [ "systemd-user-sessions.service" ];
    serviceConfig = {
      Type = "idle";
      Restart = "always";
      Environment = "TERM=vt220";
      ExecStart = "${pkgs.util-linux}/bin/agetty --login-program ${pkgs.shadow}/bin/login --noclear --keep-baud ttyS4 115200,57600,38400,9600 vt220";
      UtmpIdentifier = "ttyS4";
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/ttyS4";
      TTYReset = "yes";
      TTYVHangup = "yes";
      IgnoreSIGPIPE = "no";
      SendSIGHUP = "yes";
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixrouter"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.supervisor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      git
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzo/1Jt86KbVV2gVFG27JqyxglPejOZrN/B6Eo/YDi5" # content of authorized_keys file
    ];
  };

  environment = {
    variables.EDITOR = "vim";
    systemPackages = with pkgs; [
      vim
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
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

