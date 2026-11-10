{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;

      Macs = null;
      KexAlgorithms = [ "mlkem768x25519-sha256" ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
      ];
    };

    # unfortunately these don't exist in nix mapping yet
    extraConfig = ''
      HostKeyAlgorithms ssh-ed25519
      PubkeyAcceptedKeyTypes ssh-ed25519
    '';
  };
}
