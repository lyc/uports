#
# To be able to use GROUP capability (provided by tools.mk),
# at least one group must be defeind (default "host" if not defined),
# and its own DESTDIR and PREFIX must be provided.
#

DESTDIR			?= $(shell cd && pwd)/local
PREFIX			?= /usr

include Tools/tools.mk

#
# define your own targets...
#

all:

clean:
	@find . -type f -name \*~ -o -name .DS_Store | xargs rm -fr

distclean: ports.distclean clean
