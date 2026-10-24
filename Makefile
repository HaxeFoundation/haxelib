HAXE = haxe

prefix = /usr/local
bindir = $(prefix)/bin
datadir = $(prefix)/share

HAXELIB_OUTPUT = haxelib


TARGET_CACHE_FILE = bin/.target_cache
HAXELIB_TARGET_CACHED = $(file < $(TARGET_CACHE_FILE))

ifdef HAXELIB_TARGET
ifneq ($(HAXELIB_TARGET), $(HAXELIB_TARGET_CACHED))
# invalidate haxelib executable if target changed
$(shell rm $(HAXELIB_OUTPUT))
endif
else ifneq ($(HAXELIB_TARGET_CACHED),)
HAXELIB_TARGET = $(HAXELIB_TARGET_CACHED)
else
HAXELIB_TARGET = neko
endif


ifeq ($(HAXELIB_TARGET),neko)
NEKOTOOLS = nekotools

run.n:
	$(HAXE) client.hxml

ifeq ($(OS),Windows_NT)
HAXELIB_OUTPUT = haxelib.exe

$(HAXELIB_OUTPUT): run.n
	$(NEKOTOOLS) boot run.n
	mv run.exe $@
	echo $(HAXELIB_TARGET) > $(TARGET_CACHE_FILE)

else

ifdef NEKO_LIB_PATH
LDFLAGS = -Wl,-rpath,$(NEKO_LIB_PATH)
endif

LDLIBS = -lneko

%.c: %.n
	$(NEKOTOOLS) boot -c $<

$(HAXELIB_OUTPUT): run.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@ $(LDLIBS)
	echo $(HAXELIB_TARGET) > $(TARGET_CACHE_FILE)

endif

install:
	cp $(HAXELIB_OUTPUT) $(bindir)/haxelib
endif

ifeq ($(HAXELIB_TARGET),eval)

bin/haxelib_eval.hxb:
	$(HAXE) client_eval_hxb.hxml

SCRIPT = "\#!/bin/sh\nhaxe --hxb-lib %hxb_file% --run haxelib.client.Main \"\$$@\"\n"

$(HAXELIB_OUTPUT): bin/haxelib_eval.hxb
	printf $(subst %hxb_file%,\"$(CURDIR)/bin/haxelib_eval.hxb\",$(SCRIPT)) > $@
	echo $(HAXELIB_TARGET) > $(TARGET_CACHE_FILE)

install:
	mkdir -p $(datadir)/haxelib
	mv bin/haxelib_eval.hxb $(datadir)/haxelib/

	printf $(subst %hxb_file%,"$(datadir)/haxelib/haxelib_eval.hxb",$(SCRIPT)) > $(bindir)/haxelib

endif

uninstall:
	rm -rf $(bindir)/haxelib $(datadir)/haxelib

clean:
	rm -rf run.n run.c $(HAXELIB_OUTPUT) bin/haxelib_eval.hxb $(TARGET_CACHE_FILE)

.DEFAULT_GOAL := $(HAXELIB_OUTPUT)

.PHONY: install uninstall clean

.SUFFIXES:

