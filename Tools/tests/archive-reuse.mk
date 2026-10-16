PORTS_GROUP_DEFAULT = target
PORTS_LISTS = target@devel/archive-consumer
PORTS_FALLBACK_LISTS = target@devel/archive-provider
FEEDS = $(TEST_ROOT)/feeds
default_ignore_lists = %
PREFIX = /usr/local
DESTDIR = $(TEST_ROOT)/installed
PORTS_ENVS = PORTSDIR=$(portdir) TEST_ROOT=$(TEST_ROOT) PACKAGES=$(TEST_ROOT)/packages
USE_HOSTTOOLS =
include $(portdir)/Tools/tools.mk
