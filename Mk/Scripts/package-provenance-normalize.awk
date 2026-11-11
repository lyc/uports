# Package compatibility excludes instance-local build/staging locations.
BEGIN { FS = OFS = "|" }
function normalize_target(target, parts, count) {
    count = split(target, parts, "@")
    if (count != 2 || parts[1] ~ /:/)
        return target
    sub(/:/, "@", parts[2])
    return parts[1] ":" parts[2]
}
{
    # Target spelling changed; group, port, Flavor and phase did not.
    for (i = 1; i + 5 <= NF; i++) {
        if ($(i + 5) != "uports")
            continue
        if ($i == "dependency" && i + 7 <= NF)
            $(i + 7) = normalize_target($(i + 7))
        if ($i == "provider" && i + 10 <= NF)
            $(i + 10) = normalize_target($(i + 10))
    }
    # Older cmake USES records used discovery results as the requirement.
    # Keep the declared origin/provider identity; normalize only that spelling.
    for (i = 1; i + 5 <= NF; i++) {
        if (($i == "dependency" || $i == "provider") &&
            $(i + 4) == "devel/cmake" && $(i + 5) == "uports" &&
            ($(i + 2) == "build" || $(i + 2) == "run") &&
            ($(i + 3) == "" || $(i + 3) ~ /^\/.*\/cmake$/))
            $(i + 3) = "cmake"
    }
    for (i = 1; i + 5 <= NF; i++) if ($i == "instance") {
        n = split($(i + 5), env, " "); value = ""
        for (j = 1; j <= n; j++) {
            if (env[j] ~ /^ALTERNATIVE_WRKDIR=/)
                continue
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
