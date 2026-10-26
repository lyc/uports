PORTNAME = archive-provider
DISTVERSION = 1
CATEGORIES = devel
DISTFILES =
MASTERDIR = $(CURDIR)
include $(PORTSDIR)/Mk/linux.port.pre.mk
override_targets += do-fetch do-extract do-patch do-configure do-build do-install
do-fetch do-patch do-configure:
	@:
do-extract:
	@mkdir -p $(WRKSRC)
do-build:
	@$(CC) -shared -fPIC $(FILESDIR)/answer.c -o $(WRKSRC)/libanswer.so
do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/include $(STAGEDIR)$(PREFIX)/lib
	@cp $(FILESDIR)/answer.h $(STAGEDIR)$(PREFIX)/include/
	@cp $(WRKSRC)/libanswer.so $(STAGEDIR)$(PREFIX)/lib/
include $(PORTSDIR)/Mk/linux.port.post.mk
