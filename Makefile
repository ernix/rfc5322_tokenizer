PREFIX     = $(HOME)/.local
BINDIR     = $(DESTDIR)$(PREFIX)/bin
LIBEXECDIR = $(DESTDIR)$(PREFIX)/libexec/rfc5322_tokenizer

SCRIPTS = parse_address trace_received

.PHONY: install uninstall

install:
	install -d $(LIBEXECDIR) $(BINDIR)
	install -m 644 src/tokenizer.awk     $(LIBEXECDIR)/tokenizer.awk
	install -m 755 src/parse_address.sh  $(LIBEXECDIR)/parse_address
	install -m 755 src/trace_received.sh $(LIBEXECDIR)/trace_received
	for s in $(SCRIPTS); do \
	    printf '#!/bin/sh\nexec $(PREFIX)/libexec/rfc5322_tokenizer/%s "$$@"\n' $$s \
	        > $(BINDIR)/$$s; \
	    chmod 755 $(BINDIR)/$$s; \
	done

uninstall:
	rm -f $(addprefix $(BINDIR)/, $(SCRIPTS))
	rm -rf $(LIBEXECDIR)
