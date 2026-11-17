#!/usr/bin/env python3

import os
import asyncio
import urllib.request
import ipaddress
from pathlib import Path
import tempfile
import shutil
from ipaddress import IPv4Address, IPv6Address, ip_network
from datetime import datetime, timezone

from typing import Iterator


ASSERT_EXCLUDED_IPV4 = [
    IPv4Address("9.9.9.9"),
    IPv4Address("149.112.112.112"),
]


ASSERT_EXCLUDED_IPV6 = [
    IPv6Address("2620:fe::fe"),  # 2620:fe::9 is in the same /48 as this one
    IPv6Address("2404:8e00::feed:100"),  # other endpoints are in the same /48
]


def fetch_bogon_list(url: str) -> Iterator[str]:
    assert_excluded = None

    with urllib.request.urlopen(url) as response:
        for binary_line in response:
            line = binary_line.decode().strip()

            if len(line) == 0:
                continue

            if line[0] == "#":
                if line.startswith("# last updated"):
                    yield line

                continue

            # verify it actually is a prefix, raises ValueError if not
            network = ip_network(line)
            if assert_excluded is None:
                match network.version:
                    case 4:
                        assert_excluded = ASSERT_EXCLUDED_IPV4
                    case 6:
                        assert_excluded = ASSERT_EXCLUDED_IPV6

            for excluded in assert_excluded:
                if excluded in network:
                    raise RuntimeError(
                        f"fatal: excluded network found in bogon: {excluded}"
                    )

            yield line


HEADER = """\
set {set_name} {{
  type {set_type}
  flags interval, constant
  auto-merge

  elements = {{
"""

FOOTER = """\
  }
}
"""


def process_bogon_file(url: str, dest: Path, set_name: str, set_type: str) -> int:
    count = 0
    comments = []

    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as tmp:
        tmp.write(HEADER.format(set_name=set_name, set_type=set_type))

        for line in fetch_bogon_list(url):
            if line[0] == "#":
                if line.startswith("# last updated"):
                    unix_timestamp = float(
                        line.lstrip("# last updated ").split(" ", maxsplit=1)[0]
                    )
                    timestamp = (
                        datetime.fromtimestamp(
                            timestamp=unix_timestamp, tz=timezone.utc
                        )
                        .isoformat()
                        .replace("+00:00", "Z")
                    )
                    comments.append(f"# last updated: {timestamp}")
                    continue

                comments.append(line)
                continue

            tmp.write(f"    {line},\n")
            count += 1

        tmp.write(FOOTER)
        tmp.write(f"# prefix count: {count}\n")
        tmp.write("\n".join(comments))
        tmp.write("\n")

        tmp.flush()

        if count > 0:
            shutil.copyfile(tmp.name, dest)
        else:
            raise RuntimeError(f"fatal: got 0 prefixes from {set_name}")

    return count


def fetch_ipv4_bogons():
    print("fetching ipv4 bogons")
    url = "https://team-cymru.org/Services/Bogons/fullbogons-ipv4.txt"
    dest = Path(__file__).parent.parent / "network/nftables/prefixes/ipv4_bogons.nft"
    count = process_bogon_file(url, dest, "ipv4_bogons", "ipv4_addr")
    print(f"got {count} prefixes")


def fetch_ipv6_bogons():
    print("fetching ipv6 bogons")
    url = "https://team-cymru.org/Services/Bogons/fullbogons-ipv6.txt"
    dest = Path(__file__).parent.parent / "network/nftables/prefixes/ipv6_bogons.nft"
    count = process_bogon_file(url, dest, "ipv6_bogons", "ipv6_addr")
    print(f"got {count} prefixes")


if __name__ == "__main__":
    fetch_ipv4_bogons()
    fetch_ipv6_bogons()
