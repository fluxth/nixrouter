{
  config,
  lib,
  pkgs,
  ...
}:

{
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
}
