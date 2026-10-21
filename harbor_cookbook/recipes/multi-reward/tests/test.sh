#!/bin/bash

apt-get update
apt-get install -y curl

curl -LsSf https://astral.sh/uv/0.13.4/install.sh | (set -eu; uv_installer="$(mktemp)"; trap 'rm -f "$uv_installer"' EXIT; cat > "$uv_installer"; printf '1f5390d273b0158bd5eaa3527ae049f3667baa881abb1e7c883dd637d84432f9  %s\n' "$uv_installer" | sha256sum -c -; sh "$uv_installer")

source $HOME/.local/bin/env

correctness=0
performance=0

uvx \
  --with pytest==8.4.1 \
  --with pytest-json-ctrf==0.3.5 \
  pytest --ctrf /logs/verifier/ctrf.json /tests/test_correctness.py -rA \
  && correctness=1

uvx \
  --with pytest==8.4.1 \
  --with pytest-json-ctrf==0.3.5 \
  pytest --ctrf /logs/verifier/ctrf_performance.json /tests/test_performance.py -rA \
  && performance=1

python3 -c "
import json
json.dump({'correctness': $correctness, 'performance': $performance}, open('/logs/verifier/reward.json', 'w'))
"
