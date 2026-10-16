PORTNAME = archive-consumer
DISTVERSION = 1
CATEGORIES = devel
DISTFILES =
LIB_DEPENDS = $(if $(filter yes,$(NEEDS_LIBRARY)),libanswer.so:devel/archive-provider)
RUN_DEPENDS = $(if $(filter yes,$(RUNTIME_PROVIDER)),libanswer.so:devel/archive-provider)
MASTERDIR = $(CURDIR)
include $(PORTSDIR)/Mk/linux.port.pre.mk
override_targets += do-fetch do-extract do-patch do-configure do-build do-install
do-fetch do-patch:
	@:
do-extract:
	@mkdir -p $(WRKSRC)
do-configure:
	@echo configure >> $(TEST_ROOT)/events
do-build:
	@echo build >> $(TEST_ROOT)/events
	@test "$(FAIL_BUILD)" != yes
	@$(CC) $(if $(filter yes,$(NEEDS_LIBRARY)),-DHAVE_ANSWER -I$(DESTDIR)$(PREFIX)/include) \
	  $(FILESDIR)/main.c $(if $(filter yes,$(NEEDS_LIBRARY)),-L$(DESTDIR)$(PREFIX)/lib -Wl$(comma)-rpath$(comma)$(DESTDIR)$(PREFIX)/lib -lanswer) -o $(WRKSRC)/consumer
do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin
	@cp $(WRKSRC)/consumer $(STAGEDIR)$(PREFIX)/bin/consumer
include $(PORTSDIR)/Mk/linux.port.post.mk
