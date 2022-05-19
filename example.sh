#!/bin/sh

# Extract email addresses in To: header

dir=$(cd "$(dirname "$0")" && pwd)
eval "set -- $(awk -f "$dir/tokenizer.awk" "$dir/sample/rfc5322_appendix_a_5.mbox")"

header=
while test $# -gt 0; do
  key="$1"; shift
  value="$1"; shift

  case $key in
    field-name)
      header="$value"
      ;;
    addr-spec)
      if test "$header" = "To"; then
        printf "%s\n" "$value"
      fi
      ;;
    *)
      ;;
  esac
done

# c@public.example
# joe@example.org
# jdoe@one.test
