# Package compatibility excludes instance-local build/staging locations.
BEGIN { FS = OFS = "|" }
{
    for (i = 1; i + 5 <= NF; i++) if ($i == "instance") {
        n = split($(i + 5), env, " "); value = ""
        for (j = 1; j <= n; j++) {
            if (env[j] ~ /^(USE_GLOBALBASE|DISTDIR_SITE|PACKAGES_SITE|SCMDIR_SITE|FORCE_DEVELOPMENT_INSTALL)=/)
                continue
            if (env[j] ~ /^(PORTSDIR|DESTDIR)=/)
                sub(/=.*/, "=<local>", env[j])
            value = value (value == "" ? "" : " ") env[j]
        }
        $(i + 5) = value
    }
    print
}
