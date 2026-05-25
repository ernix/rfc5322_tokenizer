#!/bin/sh

# Extract email addresses in target header

if test -z "$1"; then
  printf "%s\n" "Require exact 1 positional argument" >&2
  exit 1
fi

target=$(printf "%s" "$1" | tr "[:upper:]" "[:lower:]")

dir=$(cd "$(dirname "$0")" && pwd)
eval "set -- $(awk -f "$dir/tokenizer.awk")"

header=
while test $# -gt 0; do
  key="$1"; shift
  value="$1"; shift

  case $header:$key in
    *:field-name)
      header=$(printf "%s" "$value" | tr "[:upper:]" "[:lower:]")
      ;;
    "$target:addr-spec")
      printf "%s\n" "$value"
      ;;
    *)
      ;;
  esac
done
