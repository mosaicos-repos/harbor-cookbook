#!/bin/bash

apt-get update
apt-get install -y curl

(
  uv_installer="$(mktemp)" || exit 1
  trap 'rm -f "$uv_installer"' EXIT
  curl -LsSf https://astral.sh/uv/0.13.4/install.sh -o "$uv_installer" || exit 1
  printf '1f5390d273b0158bd5eaa3527ae049f3667baa881abb1e7c883dd637d84432f9  %s\n' "$uv_installer" | sha256sum -c - || exit 1
  sh "$uv_installer" || exit 1
) || {
  echo 'Authenticated uv bootstrap failed; refusing cached executable fallback' >&2
  mkdir -p /logs/verifier
  printf '{"correctness":0,"performance":0}\n' > /logs/verifier/reward.json
  exit 1
}

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
