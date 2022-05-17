# rfc5322_tokenizer
Pure POSIX-compliant RFC 5322 tokenizer

# SYNOPSIS

~~~
$ awk --posix -f ./tokenizer.awk path/to/some.mbox

$ sh -c 'eval "set -- $1"; printf %s\\n "$@"' -- \
    "$(<path/to/some.mbox formail -X To: | awk --posix -f ./tokenizer.awk)" \
    | paste -sd "\t\n" | awk '$1 == "addr-spec" { print $2; }'
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

If you don't have `formail(1)`, you still can loop over tokens. See `example.sh`.

# Hey! `eval` is poking my eyes out! What is this heck?

Please see `Working with arrays` section in [Rich's sh (POSIX shell) tricks](http://www.etalabs.net/sh_tricks.html)
