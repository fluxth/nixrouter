{
  pkgs,
  lib,
  ...
}:

let
  bogons = pkgs.writeShellScriptBin "bogons" ''
    set -euo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.python3
        pkgs.nftables
        pkgs.coreutils
      ]
    }

    step="starting"
    on_exit() {
      status=$?
      if [ "$status" -ne 0 ]; then
        echo "<3>bogons: update FAILED during $step (exit $status), nothing was applied" >&2
      fi
    }
    trap on_exit EXIT

    out="''${RUNTIME_DIRECTORY:?run this through the bogons service}"

    step="fetch and render"
    python3 ${../scripts/update_bogons.py} --output-dir "$out"

    # flush is needed or else it will be additively merged to the old one
    cat > "$out/swap.nft" <<EOF
    flush set inet raw ipv4_bogons
    flush set inet raw ipv6_bogons

    table inet raw {
      include "$out/ipv4_bogons.nft"
      include "$out/ipv6_bogons.nft"
    }
    EOF

    step="nft dry run"
    nft --check --file "$out/swap.nft"

    step="nft apply"
    nft --file "$out/swap.nft"

    step="done"
  '';
in
{
  systemd.services.bogons = {
    description = "Refresh nftables bogon sets";
    wants = [ "network-online.target" ];
    after = [
      "nftables.service"
      "network-online.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${bogons}/bin/bogons";

      TimeoutStartSec = "5min";

      # /run/bogons holds the rendered set files so they can be audited,
      # it is a tmpfs so it is cleared on reboot
      RuntimeDirectory = "bogons";
      RuntimeDirectoryPreserve = "yes";

      DynamicUser = true;
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
        "AF_UNIX"
      ];
    };
  };

  systemd.timers.bogons = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnCalendar = "00/4:56:00 UTC";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };
  };
}
