#!/bin/sh

# Convert tokens to JSON

dir=$(cd "$(dirname "$0")" && pwd)

# Please see `Working with arrays` section in
# Rich's sh (POSIX shell) tricks:
# http://www.etalabs.net/sh_tricks.html
eval "set -- $(awk -f "$dir/tokenizer.awk")"

# Each odd index elements indicate token name
# Each even index elements contains token value
jq -n '[$ARGS.positional | _nwise(2) | {key: .[0], value: .[1]}]' --args -- "$@"
