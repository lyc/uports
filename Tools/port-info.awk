# Extract the package-info fields needed by tools.mk without loading the full
# ports framework for every port.

BEGIN {
	flavor_marker = "(^|[^A-Za-z0-9_])FLAVORS([^A-Za-z0-9_]|$)"
	work_marker = "^((override|export)[[:space:]]+)*WRKDIR"
	work_marker = work_marker "[[:space:]]*[:+?]?="
	cookie_marker = "^((override|export)[[:space:]]+)*[A-Z_]+_COOKIE"
	cookie_marker = cookie_marker "[[:space:]]*[:+?]?="
	group_count = split(groups, display_groups, " ")
	if (mode == "info-compact-groups") {
		if (cols < 40)
			cols = 80
		cols -= 4
		print_compact_groups()
		exit
	}
	if (makefile != "") {
		init_port(curdir)
		parse_file(makefile)

		print package_info()
		exit
	}
}

mode == "info-ports" || mode == "info-compact" || mode == "info-candidates" {
	group = $1
	port = $2
	base = $3
	status = $4
	flag = $5
	suffix = $6
	if (status == "")
		status = " "

	if (mode == "info-candidates" || NF < 9) {
		init_port(base "/" port)
		parse_file(base "/" port "/Makefile")
	}
	if (mode == "info-candidates") {
		probe = status_probe ? "probe" : "fast"
		if (work_mapping)
			probe = "custom"
		for (field = 1; field <= 9; field++)
			printf "%s|", $field
		print probe "|" package_version() "|" vars["LICENSE"]
		next
	}

	row_count++
	row_instance[row_count] = group SUBSEP base SUBSEP port
	row_group[row_count] = group
	row_origin[row_count] = port
	if (!(row_instance[row_count] in first_row))
		first_row[row_instance[row_count]] = row_count
	context_head[port, group] = first_row[row_instance[row_count]]
	context_count[row_instance[row_count]]++
	context_row[row_instance[row_count],
	    context_count[row_instance[row_count]]] = row_count
	row_flag[row_count] = flag
	row_status[row_count] = status
	row_port[row_count] = port suffix
	row_flavor[row_count] = ($7 == "") ? "-" : $7
	row_version[row_count] = (NF >= 9) ? $8 : package_version()
	row_license[row_count] = (NF >= 9) ? $9 : vars["LICENSE"]

	if (length(row_port[row_count]) > port_width)
		port_width = length(row_port[row_count])
	if (length(row_version[row_count]) > version_width)
		version_width = length(row_version[row_count])
}

END {
	if (mode == "info-compact")
		print_compact_ports()
	else if (mode == "info-ports")
		print_info_ports()
}

function compact_append(entry) {
	if ((compact_has_data ||
	    length(compact_line) > length(compact_indent)) &&
	    length(compact_line) + compact_has_data + length(entry) > cols) {
		sub(/[[:space:]]+$/, "", compact_line)
		print "    " compact_line
		compact_line = compact_indent
		compact_has_data = 0
	}
	if (compact_has_data)
		compact_line = compact_line " "
	compact_line = compact_line entry
	compact_has_data = 1
}

function compact_status(i, primary,    entry, state) {
	state = trim(row_status[i])
	entry = (state == "") ? "." : state
	if (row_version[i] != row_version[primary])
		entry = entry "(v" row_version[i] ")"
	if (row_license[i] != row_license[primary])
		entry = entry "(license=" row_license[i] ")"
	return entry
}

# Keep one group's Flavors together when group summaries need separate lines.
function compact_group(head, primary,    entry, position, i) {
	entry = row_group[head] ":"
	if (row_flavor[head] == "-")
		return entry compact_status(head, primary)
	entry = entry "{"
	for (position = 1; position <= context_count[row_instance[head]];
	    position++) {
		i = context_row[row_instance[head], position]
		if (position > 1)
			entry = entry ", "
		entry = entry row_flavor[i] ":" compact_status(i, primary)
	}
	return entry "}"
}

function print_compact_groups(    g) {
	compact_indent = "groups: "
	compact_line = compact_indent
	compact_has_data = 0
	for (g = 1; g <= group_count; g++)
		compact_append((display_groups[g] == default_group \
		    ? "[*]" : "") \
		    display_groups[g])
	print "    " compact_line
}

function print_compact_ports(    i, j, g, n, origin, primary, head,
	entry, count, port_size, version_size, license_size, prefix,
	entries, combined, wrapped) {
	if (cols < 40)
		cols = 80
	cols -= 4
	if (compact_groups_printed != "yes")
		print_compact_groups()
	for (i = 1; i <= row_count; i++) {
		origin = row_origin[i]
		if (!(origin in compact_primary)) {
			compact_origins[++n] = origin
			compact_primary[origin] = i
		}
		primary = compact_primary[origin]
		if (row_group[i] == default_group &&
		    row_group[primary] != default_group)
			compact_primary[origin] = i
	}
	port_size = length("PORT")
	version_size = length("VERSION")
	license_size = length("LICENSE")
	for (j = 1; j <= n; j++) {
		primary = compact_primary[compact_origins[j]]
		if (length(row_origin[primary]) > port_size)
			port_size = length(row_origin[primary])
		if (length(row_version[primary]) > version_size)
			version_size = length(row_version[primary])
		if (length(row_license[primary]) > license_size)
			license_size = length(row_license[primary])
	}
	printf "    %6s%-*s  %-*s  %-*s  %s\n", "", port_size, "PORT",
	    version_size, "VERSION", license_size, "LICENSE", "GROUPS/FLAVORS"
	for (j = 1; j <= n; j++) {
		origin = compact_origins[j]
		primary = compact_primary[origin]
		prefix = sprintf("[%s%s]: %-*s  %-*s  %-*s  ",
		    row_flag[primary], row_status[primary], port_size, origin,
		    version_size, row_version[primary],
		    license_size, row_license[primary])
		compact_indent = sprintf("%*s", length(prefix), "")
		count = 0
		combined = ""
		for (g = 1; g <= group_count; g++) {
			head = context_head[origin, display_groups[g]]
			if (!head)
				continue
			entry = compact_group(head, primary)
			entries[++count] = entry
			combined = combined ((count == 1) ? "" : " ") entry
		}
		wrapped = length(prefix) + length(combined) > cols
		if (!wrapped)
			print "    " prefix combined
		else {
			for (g = 1; g <= count; g++)
				print "    " ((g == 1) ? prefix : compact_indent) \
				    entries[g]
		}
	}
}

function init_port(port_curdir,    i) {
	for (i in vars)
		delete vars[i]
	for (i in seen)
		delete seen[i]
	for (i in parent_active)
		delete parent_active[i]
	for (i in active)
		delete active[i]
	for (i in matched)
		delete matched[i]

	vars["PORTSDIR"] = portdir
	vars["CURDIR"] = port_curdir
	vars["OPSYS"] = opsys
	vars["ARCH"] = arch
	status_probe = 0
	work_mapping = 0
	if_depth = 0
}

function package_version(    distversion) {
	distversion = vars["DISTVERSION"]
	if (distversion == "" && vars["PORTVERSION"] != "")
		distversion = portversion_to_distversion(vars["PORTVERSION"])

	return vars["DISTVERSIONPREFIX"] distversion_to_full(distversion) \
	    vars["DISTVERSIONSUFFIX"]
}

function package_info() {
	return package_version() " " vars["LICENSE"]
}

function print_info_ports(    i, key, first, entry, status, prefix, line,
	license_width, width) {
	for (i = 1; i <= row_count; i++) {
		key = row_instance[i]
		if (!(key in first_row))
			first_row[key] = i
		first = first_row[key]
		status = trim(row_status[i])
		entry = row_flavor[i] ":" ((status == "") ? "." : status)
		if (row_version[i] != row_version[first])
			entry = entry "(version=" row_version[i] ")"
		if (row_license[i] != row_license[first])
			entry = entry "(license=" row_license[i] ")"
		flavor_entry[i] = entry
		if (length(row_license[i]) > license_width)
			license_width = length(row_license[i])
	}
	if (version_width < length("VERSION"))
		version_width = length("VERSION")
	if (license_width < length("LICENSE"))
		license_width = length("LICENSE")
	printf "%27s%-*s  %-*s  %-*s  %s\n", "",
	    port_width, "PORT", version_width, "VERSION",
	    license_width, "LICENSE", "FLAVORS/STATUS"
	for (i = 1; i <= row_count; i++) {
		key = row_instance[i]
		if (first_row[key] != i)
			continue
		prefix = sprintf("%21s[%s%s]: %-*s  %-*s  %-*s  ", "",
		    row_flag[i], row_status[i], port_width, row_port[i],
		    version_width, row_version[i],
		    license_width, row_license[i])
		width = length(prefix)
		line = prefix
		for (first = i + 1; first <= row_count; first++) {
			if (row_instance[first] != key)
				continue
			entry = flavor_entry[first]
			if (length(line) > width &&
			    length(line) + 1 + length(entry) > 160) {
				print line
				line = sprintf("%*s", width, "")
			}
			if (length(line) > width)
				line = line " "
			line = line entry
		}
		print line
	}
}

function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}

function dirname(path) {
	sub(/\/[^\/]*$/, "", path)
	return path
}

function parse_file(file,    line, raw, nextline, incfile, base, var, op, value,
	read_status) {
	if (seen[file]++)
		return

	base = dirname(file)
	parent_active[0] = 1
	active[0] = 1

	while ((read_status = getline raw < file) > 0) {
		while (raw ~ /\\$/) {
			sub(/\\$/, "", raw)
			if ((getline nextline < file) <= 0)
				break
			raw = raw nextline
		}

		line = trim(raw)
		if (line == "" || line ~ /^#/)
			continue
		# Evaluate declarations and custom artifact paths with actual make.
		if (line ~ flavor_marker)
			status_probe = 1
		if (line ~ work_marker) {
			status_probe = 1
			work_mapping = 1
		}
		if (line ~ cookie_marker)
			status_probe = 1

		if (line ~ /^ifeq[[:space:]]*\(/) {
			handle_ifeq(line)
			continue
		}
		if (line ~ /^else[[:space:]]+ifeq[[:space:]]*\(/) {
			handle_else_ifeq(line)
			continue
		}
		if (line ~ /^else([[:space:]]*#.*)?$/) {
			handle_else()
			continue
		}
		if (line ~ /^endif([[:space:]]*#.*)?$/) {
			if_depth--
			continue
		}

		if (!active[if_depth])
			continue

		if (line ~ /^include[[:space:]]+/) {
			incfile = line
			sub(/^include[[:space:]]+/, "", incfile)
			incfile = expand(trim(incfile))
			if (incfile ~ /\$/) {
				status_probe = 1
				work_mapping = 1
				continue
			}
			if (incfile !~ /^\//)
				incfile = base "/" incfile
			if (incfile ~ "/Mk/linux[.]port([.]pre|[.]post)?[.]mk$")
				continue
			parse_file(incfile)
			continue
		}

		if (line ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:+?]?=/) {
			var = line
			sub(/[[:space:]]*[:+?]?=.*/, "", var)
			op = line
			sub(/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*/, "", op)
			sub(/[[:space:]].*/, "", op)
			value = line
			sub(/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:+?]?=[[:space:]]*/, "", value)
			value = trim(value)

			if (op == "?=" && (var in vars))
				continue
			if (op == "+=")
				vars[var] = trim(vars[var] " " expand(value))
			else
				vars[var] = expand(value)
		}
	}

	if (read_status < 0) {
		status_probe = 1
		work_mapping = 1
	}
	close(file)
}

function handle_ifeq(line,    expr, parts, lhs, rhs) {
	expr = line
	sub(/^ifeq[[:space:]]*\(/, "", expr)
	sub(/\)[[:space:]]*$/, "", expr)
	split(expr, parts, ",")
	lhs = expand(trim(parts[1]))
	rhs = expand(trim(parts[2]))

	if_depth++
	parent_active[if_depth] = active[if_depth - 1]
	matched[if_depth] = parent_active[if_depth] && (lhs == rhs)
	active[if_depth] = matched[if_depth]
}

function handle_else_ifeq(line,    expr, parts, lhs, rhs, ok) {
	expr = line
	sub(/^else[[:space:]]+ifeq[[:space:]]*\(/, "", expr)
	sub(/\)[[:space:]]*$/, "", expr)
	split(expr, parts, ",")
	lhs = expand(trim(parts[1]))
	rhs = expand(trim(parts[2]))
	ok = parent_active[if_depth] && !matched[if_depth] && (lhs == rhs)
	if (ok)
		matched[if_depth] = 1
	active[if_depth] = ok
}

function handle_else(    ok) {
	ok = parent_active[if_depth] && !matched[if_depth]
	matched[if_depth] = 1
	active[if_depth] = ok
}

function expand(s,    out, start, rest, end, name, repl) {
	out = s
	while (match(out, /\$\([A-Za-z_][A-Za-z0-9_]*\)|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$\(shell[^)]*\)/)) {
		start = RSTART
		rest = substr(out, RSTART, RLENGTH)
		if (rest ~ /^\$\(shell/) {
			repl = shell_value(rest)
		} else {
			name = substr(rest, 3, length(rest) - 3)
			repl = vars[name]
		}
		out = substr(out, 1, start - 1) repl substr(out, start + length(rest))
	}
	return out
}

function shell_value(s) {
	if (s ~ /uname -s/ && s ~ /tr/)
		return opsys
	if (s ~ /uname -m/)
		return arch
	return ""
}

function portversion_to_distversion(s) {
	gsub(/:/, "::", s)
	return s
}

function distversion_to_full(s,    out, i, c) {
	out = ""
	for (i = 1; i <= length(s); i++) {
		c = substr(s, i, 1)
		if (c == ":" && i < length(s)) {
			i++
			out = out substr(s, i, 1)
		} else {
			out = out c
		}
	}
	return out
}
