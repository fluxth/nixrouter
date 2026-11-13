#!/usr/bin/env python3

import os
import asyncio
import urllib.request
import ipaddress
from pathlib import Path
import tempfile
import shutil
from ipaddress import ip_network

from typing import Iterator


def fetch_bogon_list(url: str) -> Iterator[str]:
    with urllib.request.urlopen(url) as response:
        for binary_line in response:
            line = binary_line.decode().strip()

            if len(line) == 0:
                continue

            if line[0] == "#":
                continue

            # verify it actually is a prefix, raises ValueError if not
            ip_network(line)

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

    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as tmp:
        tmp.write(HEADER.format(set_name=set_name, set_type=set_type))

        for ip in fetch_bogon_list(url):
            tmp.write(f"    {ip},\n")
            count += 1

        tmp.write(FOOTER)
        tmp.write(f"# prefix count: {count}\n")

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
