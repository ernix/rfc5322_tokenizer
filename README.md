# rfc5322_tokenizer
Pure POSIX-compliant RFC 5322 tokenizer

# SYNOPSIS

~~~
$ awk --posix -f ./tokenizer.awk path/to/some.mbox

$ sh -c 'eval "set -- $1"; printf %s\\t%s\\n "$@"' -- \
    "$(<path/to/some.mbox formail -c -X To: | awk --posix -f ./tokenizer.awk)" \
    | awk '$1 == "addr-spec" { print $2; }'
~~~

The `-c` option of `formail(1)` here is important, because tokens may contain any
ASCII control characters. (even NUL, see `obs-utext` in RFC[^1])

> -c   Concatenate continued fields in the header.  Might be convenient
>      when postprocessing mail with standard (line oriented) text
>      utilities.

You still can loop over tokens safely without formail. See `example.sh` for more detail.

# DESCRIPTION

`tokenizer.awk` is a filter program to produce array-like string that can be `eval`ed[^2].

Each elements are flattened key/value pairs, you can convert each tokens in JSON
format if you have access to JSON encoder/decoder such as `jq(1)`:

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

# MOTIVATION

Email is tough.

When you try to extract recipients from mail headers, you will need to install
some fatty RFC 5322 parsers or will end up with horribly wrong regex solutions.

Despite the importance of Email system (it's too universal, and therefore can be a major attack vector),
there is no standard/promised/built-in/portable/easy-to-use/whatever ways, to do this simple task.

This awk script is my personal experiment to solve the problem without external tools/libraries.

If you can install CPAN modules, you should try [Email::Address::XS](https://metacpan.org/pod/Email::Address::XS).

If you can use newer versions of Python (Batteries included!), the following code gives exact same result as `example.sh`:

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
[^2]: http://www.etalabs.net/sh_tricks.html
