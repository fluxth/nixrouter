{
  config,
  pkgs,
  lib,
  ...
}:

let
  ttl = 60;
  iface = "wan4-pppoe";

  credsFile = config.sops.secrets."ddns/aws_credentials".path;
  envFile = config.sops.secrets."ddns/envfile".path;

  ddns = pkgs.writeShellScriptBin "ddns" ''
    set -u
    PATH=${
      lib.makeBinPath [
        pkgs.awscli2
        pkgs.coreutils
        pkgs.util-linux
        pkgs.iproute2
        pkgs.jq
      ]
    }
    export AWS_DEFAULT_REGION=us-east-1

    die() {
      logger -t ddns "$*"
      echo "ddns: $*" >&2
      exit 1
    }

    [ -r "${envFile}" ] || die "env file ${envFile} missing or unreadable"
    set -a
    . "${envFile}"
    set +a

    [ -n "''${DDNS_ZONE_ID:-}" ] || die "DDNS_ZONE_ID not set in ${envFile}"
    [ -n "''${DDNS_RECORD:-}" ]  || die "DDNS_RECORD not set in ${envFile}"

    [ -r "${credsFile}" ] || die "AWS credentials file ${credsFile} missing or unreadable"
    export AWS_SHARED_CREDENTIALS_FILE=${credsFile}

    # lock this script's own (read-only) file, so no writable lock path is needed.
    exec 9<"$0"
    flock -w 180 9 || die "could not get lock within 180s"

    # ip comes from pppd ($1 = its $4) when called from the hook,
    # otherwise from the interface when called from the timer.
    # note that ipv6 is not supported since it's not from pppoe in my use case.
    addr="''${1:-}"
    is_hook=0
    if [ -n "$addr" ]; then
      is_hook=1
    else
      addr=$(ip -j -4 addr show dev ${iface} 2>/dev/null | jq -r '[.[].addr_info[] | select(.family == "inet" and .scope == "global") | .local][0] // empty')
      is_hook=0
    fi

    case "$addr" in
      "" | *[!0-9.]*)
        logger -t ddns "no usable IPv4 address on ${iface}, skipping"
        exit 0
      ;;
    esac

    batch=$(mktemp) || die "mktemp failed"
    trap 'rm -f "$batch"' EXIT
    cat > "$batch" <<EOF
    {
      "Comment": "ddns",
      "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "$DDNS_RECORD",
          "Type": "A",
          "TTL": ${toString ttl},
          "ResourceRecords": [{ "Value": "$addr" }]
        }
      }]
    }
    EOF

    for i in 1 2 3 4 5; do
      if out=$(aws route53 change-resource-record-sets --hosted-zone-id "$DDNS_ZONE_ID" --change-batch "file://$batch" 2>&1); then
        if [ "$is_hook" -eq 1 ]; then
          logger -t ddns "UPSERT $DDNS_RECORD -> $addr: $out"
        fi

        exit 0
      fi

      logger -t ddns "attempt $i failed: $out"
      sleep 10
    done

    exit 1
  '';
in
{
  # export the script to be called inside pppd hook
  _module.args.ddns = ddns;

  systemd.services.ddns = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ddns}/bin/ddns";
    };
  };

  systemd.timers.ddns = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "10min";
    };
  };
}
