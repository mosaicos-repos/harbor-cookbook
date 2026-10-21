#!/bin/bash

(
  uv_installer="$(mktemp)" || exit 1
  trap 'rm -f "$uv_installer"' EXIT
  curl -LsSf https://astral.sh/uv/0.13.4/install.sh -o "$uv_installer" || exit 1
  printf '1f5390d273b0158bd5eaa3527ae049f3667baa881abb1e7c883dd637d84432f9  %s\n' "$uv_installer" | sha256sum -c - || exit 1
  sh "$uv_installer" || exit 1
) || {
  echo 'Authenticated uv bootstrap failed; refusing cached executable fallback' >&2
  exit 1
}
source $HOME/.local/bin/env

uv run --with mcp python3 << 'EOF'
import asyncio
from mcp.client.session import ClientSession
from mcp.client.streamable_http import streamablehttp_client


async def main():
    async with streamablehttp_client("http://mcp-server:8000/mcp") as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()

            secret = await session.call_tool("get_secret", {})
            with open("/app/secret.txt", "w") as f:
                f.write(secret.content[0].text)

            timestamp = await session.call_tool("get_timestamp", {})
            with open("/app/timestamp.txt", "w") as f:
                f.write(timestamp.content[0].text)


asyncio.run(main())
EOF
