# Extract the package-info fields needed by tools.mk without loading the full
# ports framework for every port.

BEGIN {
	if (makefile != "") {
		init_port(curdir)
		parse_file(makefile)

		print package_info()
		exit
	}
}

mode == "info-ports" {
	group = $1
	port = $2
	base = $3
	status = $4
	flag = $5
	suffix = $6
	if (status == "")
		status = " "

	init_port(base "/" port)
	parse_file(base "/" port "/Makefile")

	row_count++
	row_flag[row_count] = flag
	row_status[row_count] = status
	row_port[row_count] = port suffix
	row_version[row_count] = package_version()
	row_license[row_count] = vars["LICENSE"]

	if (length(row_port[row_count]) > port_width)
		port_width = length(row_port[row_count])
	if (length(row_version[row_count]) > version_width)
		version_width = length(row_version[row_count])
}

END {
	if (mode == "info-ports")
		print_info_ports()
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

function print_info_ports(    i) {
	for (i = 1; i <= row_count; i++) {
		printf "                     [%s%s]: %-*s  %-*s  %s\n",
		    row_flag[i], row_status[i], port_width, row_port[i],
		    version_width, row_version[i], row_license[i]
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

function parse_file(file,    line, raw, nextline, incfile, base, var, op, value) {
	if (seen[file]++)
		return

	base = dirname(file)
	parent_active[0] = 1
	active[0] = 1

	while ((getline raw < file) > 0) {
		while (raw ~ /\\$/) {
			sub(/\\$/, "", raw)
			if ((getline nextline < file) <= 0)
				break
			raw = raw nextline
		}

		line = trim(raw)
		if (line == "" || line ~ /^#/)
			continue

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
