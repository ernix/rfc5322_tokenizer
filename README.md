# rfc5322_tokenizer
Pure POSIX-compliant RFC 5322 tokenizer

# INSTALL and UNINSTALL

```
$ make install
$ make uninstall
```

# SYNOPSIS

```
$ parse-address To < path/to/some.mbox
$ trace-received < path/to/some.mbox
```

# DESCRIPTION

## tokenizer.awk

`tokenizer.awk` is a filter program to produce array-like string that can be `eval`ed[^2].

Elements are flattened key/value pairs, you can convert each tokens to JSON
format if you have access to JSON encoder/decoder such as `jq(1)`:

```sh
#!/bin/sh

# Convert tokens to JSON

# Please see `Working with arrays` section in
# Rich's sh (POSIX shell) tricks:
# http://www.etalabs.net/sh_tricks.html
eval "set -- $(awk -f tokenizer.awk)"

# Each even index number elements indicate token names.
# Each odd index number elements contain their token values.
jq -n '[$ARGS.positional | _nwise(2) | {key: .[0], value: .[1]}]' --args -- "$@"
```

## parse-address

Read a mail message from stdin and print one `addr-spec` per line extracted
from the header field named by the first argument.

```
$ parse-address To < path/to/some.mbox
```

Exit status is 0 on success, 1 if the argument is missing.

## trace-received

Read a mail message from stdin, walk the `Received:` headers from the bottom
(oldest) to the top (newest), and print the last trusted sender domain.
Consecutive headers are checked to verify that the `from` clause of each hop
matches the `by` clause of the previous one. If a mismatch is found - a sign
of a forged header - the trustworthy sender domain is printed and the command
exits with status 1. Exits with status 0 if all hops are consistent.

```
$ trace-received < path/to/some.mbox
```

# MOTIVATION

Email is tough.

When you try to extract email addresses from mail headers, you will need to install
some fatty RFC 5322 parsers or will end up with horribly wrong regexp solutions.

For example, assume you are using `procmail(1)` to file spam mails by the From header.
You will end up with some simple procmail recipes like the following:

```procmail
:0
* ^From:.*spammer@example\.com
$HOME/Maildir/.Junk/
```

Unfortunately, the above rule can't handle this valid email:

```
From: "John Doe" (\() <(I'm not)spammer@example.(and (this (is (nested (comment ;\))))))com>
```

The problem here is, email address syntax is somehow a context-free language
just like HTML/XML and [it is simply wrong to use regexp](https://stackoverflow.com/a/590789/482519).

Despite the importance of email (it's too universal, and therefore can be a major attack vector),
we can't even determine which addresses actually exist in mail headers without correct libraries.
There really is no standard/promised/built-in/portable/easy-to-use/whatever way to do this simple task.

This awk script is my personal experiment to solve the problem without external tools/libraries.

```procmail
:0
* ? parse-address From | grep -qxF "spammer@example.com"
$HOME/Maildir/.Junk/
```

If you can install CPAN modules, you should try [Email::Address::XS](https://metacpan.org/pod/Email::Address::XS).

If you can use newer versions of Python (Batteries included!), the following code gives exact same result as `parse-address To`:

```python
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
```

# SUPPORTED TOKENS

* `addr-spec`
* `comment`
* `date-time`
* `field-name`
* `msg-id`
* `obs-phrase`
* `phrase`
* `unstructured`

* `---`
    Special marker token to represent separators for ambiguous nested structures.

## `Received`

* `address`
* `domain`
* `msg-id`
* `word`

# TESTING

```
$ prove
```

[^1]: https://datatracker.ietf.org/doc/html/rfc5322
[^2]: http://www.etalabs.net/sh_tricks.html
