#!/bin/bash

curl -LsSf https://astral.sh/uv/0.13.4/install.sh | (set -eu; uv_installer="$(mktemp)"; trap 'rm -f "$uv_installer"' EXIT; cat > "$uv_installer"; printf '1f5390d273b0158bd5eaa3527ae049f3667baa881abb1e7c883dd637d84432f9  %s\n' "$uv_installer" | sha256sum -c -; sh "$uv_installer")
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
