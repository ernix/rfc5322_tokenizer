#!/bin/sh

#
# Compare sequencial headers to find a forged `Received:` header.
#
# Assume the first `Received:` header as an trust anchor,
# dig up and output the last trusty server name.
#
# Return exit code 1 If found a forged header.
#

dir=$(cd "$(dirname "$0")" && pwd)
eval "set -- $(awk -f "$dir/tokenizer.awk")"

_trust_received_header() {
  # $1: by, $2: prev_from
  if test -z "$1"; then
    return 1
  fi

  if test -z "$2"; then
    return 0
  fi

  # if previous "from" not contains current "by"
  if test "${2#*"$1"}" = "$2"; then
    return 1
  fi

  return 0
}

from=
by=
prev_from=
prev_by=
header=
prep=
trust=
while test $# -gt 0; do
  key="$1"; shift
  value="$1"; shift

  case "$header:$prep:$key" in
    *:field-name)
      if ! _trust_received_header "$by", "$prev_from"; then
        trust="$prev_by"
        break
      fi
      prep=
      header="$value"
      ;;
    Received:from:comment)
      prev_from="$from"
      from="$value"
      ;;
    Received:by:domain)
      prev_by="$by"
      by="$value"
      ;;
    Received:*:word)
      case $value in
        from|by|via|with|id|for)
          # In fact, RFC 5321 specifies strict token order in trace info,
          # but this script doesn't care.
          # In any case, malicious `Received:` headers can't predict next (the
          # one right above) header that will be used for tracing.
          prep="$value"
          ;;
        *)
          ;;
      esac
      ;;
    Received:*)
      ;;
    *)
      prep=
      ;;
  esac
done

# In case when the last header is `Received:`
if test "$header" = "Received"; then
  if ! _trust_received_header "$by", "$prev_from"; then
    trust="$prev_by"
  fi
fi

if test -n "$trust"; then
  printf "%s\n" "$trust"
  exit 1
elif test -n "$by"; then
  printf "%s\n" "$by"
  exit 0
fi
