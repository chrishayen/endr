.PHONY: build install clean test

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

build:
	odin build src -collection:deps=.endr/packages -out:endr -o:speed

install: build
	mkdir -p $(BINDIR)
	cp endr $(BINDIR)/endr

clean:
	rm -f endr

test:
	odin test tests -collection:deps=.endr/packages
