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

$1 == "contribution" {
	contribution_key = $2 SUBSEP $3 SUBSEP $4
	contribution[contribution_key, ++contribution_count[contribution_key]] = $5
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
		resolved_kind[i] = kind
		resolved_identity[i] = identity
		resolved_resolution[i] = resolution
		resolved_state[i] = state
		resolved_context[i] = context
		resolved_opsys[i] = opsys
		resolved_arch[i] = arch
		if (!environment)
			printf "selection.%s = consumer=%s context=%s opsys=%s arch=%s type=%s requirement=%s origin=%s provider_kind=%s provider_identity=%s resolution=%s state=%s\n", \
			       dependency_id[i], consumer[i], context, opsys, arch, type[i], \
			       requirement[i], origin[i], kind, identity, resolution, state
	}

	if (!environment) {
		printf "dependency_provider_selections = %d\n", dependency_count
		printf "dependency_provider_selection_invalid = %d\n", invalid_count
	} else {
		emit_environments()
	}
	if (fail && invalid_count)
		exit 1
}

function add_path(node, type, value, key) {
	key = node SUBSEP type SUBSEP value
	if (!(key in environment_path_seen)) {
		environment_path_seen[key] = 1
		environment_path[node, type, ++environment_path_count[node, type]] = value
	}
}

function append_paths(node, identity, origin, type, key, j) {
	key = identity SUBSEP origin SUBSEP type
	for (j = 1; j <= contribution_count[key]; j++)
		add_path(node, type, contribution[key, j])
}

function joined_paths(node, type, separator, result, j) {
	result = ""
	for (j = 1; j <= environment_path_count[node, type]; j++)
		result = result (result == "" ? "" : separator) environment_path[node, type, j]
	return (result == "" ? "none" : result)
}

function emit_environments(consumer_count, i, node, identity, key, sysroot, j) {
	for (i = 1; i <= dependency_count; i++) {
		if (resolved_resolution[i] != "selected" || resolved_state[i] != "validated")
			continue
		node = consumer[i]
		identity = resolved_identity[i]
		if (!(node in environment_consumer_seen)) {
			environment_consumer_seen[node] = 1
			environment_consumer[++consumer_count] = node
			environment_opsys[node] = resolved_opsys[i]
		}
		append_paths(node, identity, origin[i], "bindir")
		append_paths(node, identity, origin[i], "includedir")
		append_paths(node, identity, origin[i], "libdir")
		append_paths(node, identity, origin[i], "pkgconfigdir")
		append_paths(node, identity, origin[i], "runtimedir")
		key = identity SUBSEP origin[i] SUBSEP "sysroot"
		if (resolved_kind[i] == "sdk" && contribution_count[key] == 0) {
			invalid_count++
			environment_error[node] = "sdk-sysroot-missing"
		}
		for (j = 1; j <= contribution_count[key]; j++) {
			sysroot = contribution[key, j]
			if (environment_sysroot[node] != "" && environment_sysroot[node] != sysroot) {
				invalid_count++
				environment_error[node] = "conflicting-sysroots"
			} else
				environment_sysroot[node] = sysroot
		}
	}

	for (i = 1; i <= consumer_count; i++) {
		node = environment_consumer[i]
		printf "environment.%s = bindirs=%s includedirs=%s libdirs=%s pkgconfigdirs=%s runtimedirs=%s runtime_variable=%s sysroot=%s state=%s\n", \
		       node, joined_paths(node, "bindir", ":"), \
		       joined_paths(node, "includedir", ":"), \
		       joined_paths(node, "libdir", ":"), \
		       joined_paths(node, "pkgconfigdir", ":"), \
		       joined_paths(node, "runtimedir", ":"), \
		       (environment_opsys[node] == "darwin" ? "DYLD_LIBRARY_PATH" : "LD_LIBRARY_PATH"), \
		       (environment_sysroot[node] == "" ? "none" : environment_sysroot[node]), \
		       (environment_error[node] == "" ? "valid" : environment_error[node])
	}
	printf "dependency_provider_environments = %d\n", consumer_count
	printf "dependency_provider_environment_invalid = %d\n", invalid_count
}
