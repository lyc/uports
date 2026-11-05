# Match an installed full name or its exact base, never a name prefix.
{
    name = $1
    sub(/:$/, "", name)
    suffix = "-" $2
    base = name
    if (substr(name, length(name) - length(suffix) + 1) == suffix)
        base = substr(name, 1, length(name) - length(suffix))
    if (name == p || base == p || (match_origin && $3 == p))
        print
}
