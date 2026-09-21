BEGIN {
	FS = "|"
}

$1 == "context" {
	context_opsys[$2, $3] = $4
	context_arch[$2, $3] = $5
}

$1 == "policy" {
	count = split($2, field, "@")
	if (count == 7) {
		key = field[2] SUBSEP field[3] SUBSEP field[4] SUBSEP \
		      field[5] SUBSEP field[6]
		policy_kind[key] = field[1]
		policy_identity[key] = field[7]
	}
}

$1 == "validation" {
	validation[$2, $3] = $4
}

$1 == "dependency" {
	dependency_count++
	dependency_id[dependency_count] = $2
	consumer[dependency_count] = $3
	group[dependency_count] = $4
	type[dependency_count] = $5
	requirement[dependency_count] = $6
	origin[dependency_count] = $7
	uports_kind[dependency_count] = $8
	uports_instance[dependency_count] = $9
	uports_resolution[dependency_count] = $10
}

END {
	for (i = 1; i <= dependency_count; i++) {
		context = (type[i] == "build") ? "build" : "target"
		opsys = context_opsys[context, group[i]]
		arch = context_arch[context, group[i]]
		key = context SUBSEP group[i] SUBSEP opsys SUBSEP arch SUBSEP origin[i]

		kind = uports_kind[i]
		identity = (uports_instance[i] == "") ? "none" : uports_instance[i]
		resolution = uports_resolution[i]
		state = resolution

		if (key in policy_kind) {
			kind = policy_kind[key]
			identity = policy_identity[key]
			validator = validation[identity, origin[i]]
			if (validator == "valid") {
				resolution = "selected"
				state = "validated"
			} else if (validator == "failed") {
				resolution = "invalid-provider"
				state = "validation-failed"
			} else {
				resolution = "invalid-provider"
				state = "validator-missing"
			}
		}

		if (resolution != "selected")
			invalid_count++
		printf "selection.%s = consumer=%s context=%s opsys=%s arch=%s type=%s requirement=%s origin=%s provider_kind=%s provider_identity=%s resolution=%s state=%s\n", \
		       dependency_id[i], consumer[i], context, opsys, arch, type[i], \
		       requirement[i], origin[i], kind, identity, resolution, state
	}

	printf "dependency_provider_selections = %d\n", dependency_count
	printf "dependency_provider_selection_invalid = %d\n", invalid_count
	if (fail && invalid_count)
		exit 1
}
