HAXE = haxe

prefix = /usr/local
bindir = $(prefix)/bin
datadir = $(prefix)/share

HAXELIB_OUTPUT = haxelib

NEKOTOOLS = nekotools

run.n:
	$(HAXE) client.hxml

ifeq ($(OS),Windows_NT)
HAXELIB_OUTPUT = haxelib.exe

$(HAXELIB_OUTPUT): run.n
	$(NEKOTOOLS) boot run.n
	mv run.exe $@

else

ifdef NEKO_LIB_PATH
LDFLAGS = -Wl,-rpath,$(NEKO_LIB_PATH)
endif

LDLIBS = -lneko

%.c: %.n
	$(NEKOTOOLS) boot -c $<

$(HAXELIB_OUTPUT): run.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@ $(LDLIBS)

endif

install:
	cp $(HAXELIB_OUTPUT) $(bindir)/haxelib

uninstall:
	rm $(bindir)/haxelib -rf

clean:
	rm run.n run.c $(HAXELIB_OUTPUT) -rf

.DEFAULT_GOAL := $(HAXELIB_OUTPUT)

.PHONY: install uninstall clean

.SUFFIXES:

