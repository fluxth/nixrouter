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

    useDHCP = false;
    useNetworkd = true;

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

  systemd.network = {
    enable = true;

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

    networks."20-wan" = {
      matchConfig.Name = "enp4s0"; # 2.5GbE port 1
      networkConfig = {
        IPv6AcceptRA = "yes";
        IPv6Forwarding = true;
      };
      ipv6AcceptRAConfig = {
        UseOnLinkPrefix = false;
      };
    };

    networks."30-lan" = {
      matchConfig.Name = "enp5s0"; # 2.5GbE port 2
      networkConfig = {
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        IPv6Forwarding = true;
      };
      address = [
        "2409:10:720:c200::1/64"
      ];
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

  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    tables.firewall = {
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority 0; policy drop;

          iifname "lo" accept

          ct state { established, related } accept
          ct state invalid counter drop

          meta l4proto { icmp, ipv6-icmp } counter accept
          tcp dport 22 accept

          counter
        }

        chain forward {
          type filter hook forward priority 0; policy drop;

          ct state { established, related } accept
          ct state invalid counter drop

          iifname "enp5s0" counter accept

          counter
        }

        chain output {
          type filter hook output priority 0; policy accept;
        }
      '';
    };

    tables.raw = {
      family = "inet";
      content = ''
        chain prerouting {
          type filter hook prerouting priority raw; policy accept;
          iifname "lo" notrack
        }

        chain output {
          type filter hook output priority raw; policy accept;
          oifname "lo" notrack
        }
      '';
    };
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

