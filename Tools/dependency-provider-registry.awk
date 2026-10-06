BEGIN {
	FS = "|"
}

function invalid(record, reason) {
	if (state[record] == "") {
		state[record] = reason
		invalid_count++
	}
}

$1 == "registry" {
	record = ++registry_count
	key[record] = $2
	origin[record] = $3
	method[record] = $4
	module[record] = $5
	header[record] = $6
	link_name[record] = $7

	if (NF != 7)
		invalid(record, "invalid-field-count")
	else if (key[record] !~ /^[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-key")
	else if (origin[record] !~ /^[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-origin")
	else if (method[record] != "pkg-config")
		invalid(record, "invalid-method")
	else if (module[record] !~ /^[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-module")
	else if (header[record] ~ /(^|\/)\.\.(\/|$)/ || \
	         header[record] !~ /^([A-Za-z0-9_.+-]+\/)*[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-header")
	else if (link_name[record] !~ /^[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-link-name")
	else if (key[record] in selected_key)
		invalid(record, "duplicate-key")
	else if (origin[record] in selected_origin)
		invalid(record, "duplicate-origin")
	else {
		selected_key[key[record]] = record
		selected_origin[origin[record]] = record
		state[record] = "valid"
	}
}

END {
	printf "dependency_provider_registry_entries = %d\n", registry_count
	printf "dependency_provider_registry_invalid = %d\n", invalid_count
	for (i = 1; i <= registry_count; i++)
		printf "registry.%d = key=%s origin=%s method=%s module=%s header=%s link_name=%s state=%s\n", \
		       i, key[i], origin[i], method[i], module[i], header[i], \
		       link_name[i], state[i]
	if (fail && invalid_count)
		exit 1
}
