# Resolve explicit KEY=value arguments without interpreting replacement text.
# Commented optional entries are omitted from the concrete package manifest.
BEGIN {
	for (i = 1; i < ARGC; i++) {
		separator = index(ARGV[i], "=")
		if (!separator)
			break
		key = substr(ARGV[i], 1, separator - 1)
		if (key !~ /^[A-Za-z0-9_]+$/ || key in values) {
			message = "invalid or duplicate PLIST_SUB key: " key
			print message > "/dev/stderr"
			exit 1
		}
		values[key] = substr(ARGV[i], separator + 1)
		delete ARGV[i]
	}
}
{
	line = $0
	if (line ~ /^@comment([[:space:]]|$)/)
		next
	output = ""
	while (match(line, /%%[A-Za-z0-9_]+%%/)) {
		key = substr(line, RSTART + 2, RLENGTH - 4)
		if (!(key in values)) {
			print "undefined PLIST_SUB key: " key > "/dev/stderr"
			exit 1
		}
		output = output substr(line, 1, RSTART - 1) values[key]
		line = substr(line, RSTART + RLENGTH)
	}
	line = output line
	if (line ~ /%%/) {
		print "unresolved plist token: " line > "/dev/stderr"
		exit 1
	}
	if (line !~ /^@comment([[:space:]]|$)/)
		print line
}
