#!/bin/sh
# shellcheck disable=1007

#
# Compare sequencial headers to find a forged `Received:` header.
#
# Assume the first `Received:` header as an trust anchor,
# dig up and output the last trusty sender.
#
# Return exit code 1 if found a forged header.
#

dir=$(cd "$(dirname "$0")" && pwd)
eval "set -- $(awk -f "$dir/tokenizer.awk")"

# In case when the last header is "Received:"
set -- "$@" field-name X-Dummy

from= by= prev_from= header= prep= found=
while test $# -gt 0; do
  key="$1"; shift
  value="$1"; shift

  case "$header,$prep,$from,$by,$key" in
    received,from,,*,domain)
      # trust anchor
      from="$value"
      ;;
    received,by,*,,domain)
      # trust anchor
      by="$value"
      ;;
    received,from,*,domain)
      prev_from="$from"
      from="$value"
      ;;
    received,by,*,domain)
      by="$value"
      ;;
    received,*,word)
      prep=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
      case "$prep" in
        from|by|via|with|id|for)
          ;;
        *)
          prep=
          ;;
      esac
      ;;
    *,field-name)
      prep=
      header=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
      if test -n "$by" && test -n "$prev_from"; then
        # if previous "from" not contains current "by"
        if test "$prev_from" != "$by"; then
          found=yes
          from="$prev_from"
          break
        fi
      fi
      ;;
    *)
      ;;
  esac
done

if test -n "$from"; then
  printf "%s\n" "$from"
fi

if test "$found" = yes; then
  exit 1
else
  exit 0
fi
