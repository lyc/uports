BEGIN { FS = "|" }

function invalid(record, reason) {
	if (state[record] == "") {
		state[record] = reason
		invalid_count++
	}
}

$1 == "tool" {
	record = ++registry_count
	key[record] = $2
	origin[record] = $3
	minimum[record] = $4
	candidates[record] = $5
	explicit[record] = $6
	required[record] = $7
	command[record] = $8
	context[record] = (NF == 8 ? "build" : $9)

	if (NF != 8 && NF != 9)
		invalid(record, "invalid-field-count")
	else if (context[record] != "build" && context[record] != "both")
		invalid(record, "invalid-context")
	else if (key[record] !~ /^[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-key")
	else if (origin[record] !~ /^[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+$/)
		invalid(record, "invalid-origin")
	else if (minimum[record] !~ /^[0-9]+(\.[0-9]+)*$/)
		invalid(record, "invalid-min-version")
	else if (candidates[record] !~ /^[A-Za-z0-9_.+-]+( [A-Za-z0-9_.+-]+)*$/)
		invalid(record, "invalid-candidates")
	else if (required[record] !~ /^[A-Za-z0-9_.+-]+( [A-Za-z0-9_.+-]+)*$/)
		invalid(record, "invalid-required-commands")
	else if (command[record] !~ /^[A-Za-z0-9_.+-]+$/ || index(" " required[record] " ", " " command[record] " ") == 0)
		invalid(record, "invalid-primary-command")
	else if (explicit[record] != "" && (explicit[record] !~ /^\/[A-Za-z0-9_.\/+,@:%-]+$/ || explicit[record] ~ /(^|\/)\.\.(\/|$)/))
		invalid(record, "invalid-explicit-path")
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
	printf "dependency_provider_tool_registry_entries = %d\n", registry_count
	printf "dependency_provider_tool_registry_invalid = %d\n", invalid_count
	for (i = 1; i <= registry_count; i++) {
		explicit_display = explicit[i] == "" ? "none" : explicit[i]
		printf "tool.%d = key=%s origin=%s minimum=%s candidates=%s explicit=%s state=%s required=%s command=%s context=%s\n", \
		       i, key[i], origin[i], minimum[i], candidates[i], \
		       explicit_display, state[i], required[i], command[i], context[i]
	}
	if (fail && invalid_count)
		exit 1
}
