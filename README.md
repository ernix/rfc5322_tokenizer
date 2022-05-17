# rfc5322_tokenizer
Pure POSIX-compliant RFC 5322 tokenizer

# SYNOPSIS

~~~
$ awk --posix -f ./tokenizer.awk path/to/some.mbox

$ sh -c 'eval "set -- $1"; printf %s\\t%s\\n "$@"' -- \
    "$(<path/to/some.mbox formail -c -X To: | awk --posix -f ./tokenizer.awk)" \
    | awk '$1 == "addr-spec" { print $2; }'
~~~

# DESCRIPTION

Email is tough.

When you try to extract recipients from mail headers, you will need to install
some fatty RFC 5322 parsers or will end up with horribly wrong regex solutions.

This awk script is my personal experiment to solve the problem without external tools/libraries.

If you have access to perl/CPAN, there is [Email::Address](https://metacpan.org/pod/Email::Address).

If you can use newer versions of Python, the following code will do the same
thing of the 2nd example in SYNOPSIS section:

~~~python
import sys
from email.parser import Parser
from email.policy import default
from email.errors import MessageError


parser = Parser(policy=default)

try:
    msg = parser.parse(sys.stdin, headersonly=True)
    tos = msg.get("To")
    if tos:
        for addr in tos.addresses:
            print(addr.addr_spec)
except (TypeError, MessageError):
    pass
~~~

The `-c` option of `formail(1)` is to ensure LF as separator for futher processes.

Because tokens may contain any ASCII control characters. (even NUL, see `obs-utext` in RFC[^1])

> -c   Concatenate continued fields in the header.  Might be convenient
>      when postprocessing mail with standard (line oriented) text
>      utilities.


You still can loop over tokens safely without formail. See `example.sh`.

# USAGE

`tokenizer.awk` is a filter program to produce array-like string that can be `eval`ed.

Each elements represent list of key/value pairs, so if you want tokens in JSON
format you would like to use some JSON converter like following:

~~~sh
#!/bin/sh

# Convert tokens to JSON

# Please see `Working with arrays` section in
# Rich's sh (POSIX shell) tricks:
# http://www.etalabs.net/sh_tricks.html
eval "set -- $(awk -f tokenizer.awk)"

# Each even index number elements indicate token names.
# Each odd index number elements contain its token values.
jq -n '[$ARGS.positional | _nwise(2) | {key: .[0], value: .[1]}]' --args -- "$@"
~~~

# SUPPORTED TOKENS

* `addr-spec`
* `comment`
* `day-name`
* `day`
* `field-name`
* `hour`
* `minute`
* `month`
* `msg-id`
* `obs-day`
* `obs-hour`
* `obs-minute`
* `obs-phrase`
* `obs-second`
* `obs-year`
* `obs-zone`
* `phrase`
* `second`
* `unstructured`
* `year`
* `zone`

* `---`
    Special marker token to represent separators for ambiguous nested structures.

# TESTING

~~~
$ prove
~~~

[^1]: https://datatracker.ietf.org/doc/html/rfc5322
