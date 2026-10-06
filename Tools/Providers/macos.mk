# Native macOS provider profile.
#
# Homebrew and MacPorts prefixes are searched as ordinary metadata prefixes;
# no package-manager command is executed.

dependency-provider-profile-macos-opsys = darwin
dependency-provider-profile-macos-pkg-config-candidates = pkg-config pkgconf
dependency-provider-profile-macos-cc-candidates = cc clang
dependency-provider-profile-macos-prefixes = /usr /usr/local /opt/homebrew /opt/local
