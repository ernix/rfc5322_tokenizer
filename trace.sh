#!/bin/sh

# Trace chained Received headers and find the trust anchor
# If some forged header found, exit with status 1.

dir=$(cd "$(dirname "$0")" && pwd)
eval "set -- $(awk -f "$dir/tokenizer.awk")"

header=
trace_key=
from=
by=
ex_from=
orig=
while test $# -gt 0; do
  key="$1"; shift
  value="$1"; shift

  case "$header:$trace_key:$key" in
    *:field-name)
      trace_key=
      header="$value"
      continue
      ;;
    Received:from:comment)
      ex_from="$from"
      from="$value"
      ;;
    Received:by:domain)
      if test -n "$ex_from"; then
        if test "${ex_from#*"$value"}" = "$ex_from"; then
          orig="$by"
          break
        fi
      fi
      by="$value"
      ;;
    Received:*)
      case $value in
        from|by|via|with|id|for)
          trace_key="$value"
          ;;
        *)
          ;;
      esac
      ;;
    *)
      trace_key=
      ;;
  esac
done

if test -n "$orig"; then
  printf "%s\n" "$orig"
  exit 1
else
  printf "%s\n" "$by"
  exit 0
fi
