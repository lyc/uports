BEGIN {
	FS = "|"
}

$1 == "context" {
	context_opsys[$2, $3] = $4
	context_arch[$2, $3] = $5
	context_cross[$2, $3] = $6
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

$1 == "readiness" {
	readiness[$2, $3, $4] = $5
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
		if (exports && (consumer[i] != export_node ||
		    !dependency_needed(export_phase, type[i])))
			continue
		context = (type[i] == "build") ? "build" : "target"
		opsys = context_opsys[context, group[i]]
		arch = context_arch[context, group[i]]
		key = context SUBSEP group[i] SUBSEP opsys SUBSEP arch SUBSEP origin[i]
		if (external_only && !(key in policy_kind))
			continue

		kind = uports_kind[i]
		identity = (uports_instance[i] == "") ? "none" : uports_instance[i]
		resolution = uports_resolution[i]
		state = resolution

		if (key in policy_kind) {
			kind = policy_kind[key]
			identity = policy_identity[key]
			validator = validation[identity, origin[i]]
			if (kind == "system" && context == "target" &&
			    context_cross[context, group[i]] == "yes") {
				resolution = "invalid-provider"
				state = "system-cross-provider"
			} else if (validator == "valid") {
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
		if (readiness_report && key in policy_kind) {
			header = readiness_value(identity, origin[i], "HEADER")
			library = readiness_value(identity, origin[i], "LIBRARY")
			metadata = readiness_value(identity, origin[i], "METADATA")
			tool = readiness_value(identity, origin[i], "TOOL")
			readiness_state = state
			if (state == "validated" && (header == "missing" ||
			    library == "missing" || metadata == "missing" || tool == "missing"))
				readiness_state = "probe-failed"
			if (readiness_state != "validated")
				readiness_invalid++
			printf "readiness.%s = consumer=%s origin=%s kind=%s identity=%s header=%s library=%s metadata=%s tool=%s state=%s\n", \
			       dependency_id[i], consumer[i], origin[i], kind, identity,
			       header, library, metadata, tool,
			       (readiness_state == "validated" ? "ready" : readiness_state)
			readiness_count++
			continue
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
		if (exports && type[i] == "lib" && resolution == "selected") {
			if (kind == "uports")
				uports_library_count++
			else if (kind == "system" || kind == "sdk")
				external_library_count++
		}
		if (records) {
			if (state == "validated")
				printf "record|%s|%s|%s|%s|%s|%s\n", dependency_id[i], kind, identity, context, opsys, arch
			else if (resolution == "invalid-provider")
				printf "invalid|%s|%s\n", dependency_id[i], state
			continue
		}
		if (!environment && !readiness_report)
			printf "selection.%s = consumer=%s context=%s opsys=%s arch=%s type=%s requirement=%s origin=%s provider_kind=%s provider_identity=%s resolution=%s state=%s\n", \
			       dependency_id[i], consumer[i], context, opsys, arch, type[i], \
			       requirement[i], origin[i], kind, identity, resolution, state
	}

	if (readiness_report) {
		printf "dependency_provider_readiness = %d\n", readiness_count
		printf "dependency_provider_readiness_invalid = %d\n", readiness_invalid
		if (fail && readiness_invalid)
			exit 1
	} else if (records) {
		if (fail && invalid_count)
			exit 1
	} else if (!environment) {
		printf "dependency_provider_selections = %d\n", dependency_count
		printf "dependency_provider_selection_invalid = %d\n", invalid_count
	} else {
		emit_environments()
	}
	if (fail && !readiness_report && invalid_count)
		exit 1
}

function readiness_value(identity, origin, category) {
	if ((identity SUBSEP origin SUBSEP category) in readiness)
		return readiness[identity, origin, category]
	return "unspecified"
}

function dependency_needed(phase, type) {
	if (phase == "configure" || phase == "build" || phase == "rebuild")
		return type == "build" || type == "lib"
	return phase == "stage" || phase == "package" ||
	       phase == "install" || phase == "restage" ||
	       phase == "reinstall" || phase == "generate-plist"
}

function valid_path(value) {
	return value ~ /^\/[A-Za-z0-9_.\/+-]+$/ &&
	       value !~ /(^|\/)\.\.(\/|$)/
}

function add_path(node, type, value, key) {
	if (!valid_path(value)) {
		invalid_count++
		environment_error[node] = "invalid-path"
		return
	}
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

function emit_environments(consumer_count, i, node, identity, key, sysroot, j, runtime_variable) {
	for (i = 1; i <= dependency_count; i++) {
		if (exports && (consumer[i] != export_node ||
		    !dependency_needed(export_phase, type[i])))
			continue
		if (resolved_resolution[i] != "selected" || resolved_state[i] != "validated")
			continue
		node = consumer[i]
		identity = resolved_identity[i]
		if (!(node in environment_consumer_seen)) {
			environment_consumer_seen[node] = 1
			environment_consumer[++consumer_count] = node
			environment_opsys[node] = resolved_opsys[i]
			environment_arch[node] = resolved_arch[i]
		}
		if (resolved_context[i] == "target")
			environment_target_opsys[node] = resolved_opsys[i]
		if (!exports || resolved_context[i] == "build")
			append_paths(node, identity, origin[i], "bindir")
		append_paths(node, identity, origin[i], "includedir")
		append_paths(node, identity, origin[i], "libdir")
		append_paths(node, identity, origin[i], "pkgconfigdir")
		if (exports && resolved_context[i] == "target" &&
		    (resolved_opsys[i] != build_opsys || resolved_arch[i] != build_arch)) {
			key = identity SUBSEP origin[i] SUBSEP "runtimedir"
			for (j = 1; j <= contribution_count[key]; j++)
				add_path(node, "targetruntimedir", contribution[key, j])
		} else
			append_paths(node, identity, origin[i], "runtimedir")
		key = identity SUBSEP origin[i] SUBSEP "sysroot"
		if (resolved_kind[i] == "sdk" && contribution_count[key] == 0) {
			invalid_count++
			environment_error[node] = "sdk-sysroot-missing"
		}
		for (j = 1; j <= contribution_count[key]; j++) {
			sysroot = contribution[key, j]
			if (!valid_path(sysroot)) {
				invalid_count++
				environment_error[node] = "invalid-path"
				continue
			}
			if (environment_sysroot[node] != "" && environment_sysroot[node] != sysroot) {
				invalid_count++
				environment_error[node] = "conflicting-sysroots"
			} else
				environment_sysroot[node] = sysroot
			environment_sysroot_opsys[node] = resolved_opsys[i]
		}
	}

	if (exports) {
		if (invalid_count == 0 && (export_node in environment_consumer_seen))
			emit_exports(export_node)
		if (invalid_count)
			printf "invalid external provider environment for %s\n", export_node > "/dev/stderr"
		return
	}
	if (preflight && invalid_count) {
		for (i = 1; i <= consumer_count; i++) {
			node = environment_consumer[i]
			if (environment_error[node] != "")
				printf "external provider environment invalid: consumer=%s state=%s\n", node, environment_error[node] > "/dev/stderr"
		}
	}
	for (i = 1; i <= consumer_count; i++) {
		node = environment_consumer[i]
		runtime_variable = "LD_LIBRARY_PATH"
		if (environment_target_opsys[node] == "darwin" ||
		    (environment_target_opsys[node] == "" && environment_opsys[node] == "darwin"))
			runtime_variable = "DYLD_LIBRARY_PATH"
		printf "environment.%s = bindirs=%s includedirs=%s libdirs=%s pkgconfigdirs=%s runtimedirs=%s runtime_variable=%s sysroot=%s state=%s\n", \
		       node, joined_paths(node, "bindir", ":"), \
		       joined_paths(node, "includedir", ":"), \
		       joined_paths(node, "libdir", ":"), \
		       joined_paths(node, "pkgconfigdir", ":"), \
		       joined_paths(node, "runtimedir", ":"), \
		       runtime_variable, \
		       (environment_sysroot[node] == "" ? "none" : environment_sysroot[node]), \
		       (environment_error[node] == "" ? "valid" : environment_error[node])
	}
	printf "dependency_provider_environments = %d\n", consumer_count
	printf "dependency_provider_environment_invalid = %d\n", invalid_count
}

function flags(node, type, prefix, result, j) {
	result = ""
	for (j = 1; j <= environment_path_count[node, type]; j++)
		result = result (result == "" ? "" : " ") prefix environment_path[node, type, j]
	return result
}

function emit_exports(node, value, sysroot, sysroot_flag, runtime) {
	if (external_library_count && !uports_library_count)
		print "UPORTS_LIB_DEPENDS_USES_UPORTS=no; export UPORTS_LIB_DEPENDS_USES_UPORTS"
	value = joined_paths(node, "bindir", ":")
	if (value != "none")
		printf "PATH='%s':\"${PATH-}\"; export PATH\n", value
	sysroot_flag = ""
	if (environment_sysroot[node] != "") {
		sysroot = environment_sysroot[node]
		if (environment_sysroot_opsys[node] == "darwin")
			sysroot_flag = "-isysroot " sysroot
		else
			sysroot_flag = "--sysroot=" sysroot
		printf "SDKROOT='%s'; export SDKROOT\n", sysroot
		printf "PKG_CONFIG_SYSROOT_DIR='%s'; export PKG_CONFIG_SYSROOT_DIR\n", sysroot
	}
	value = flags(node, "includedir", "-I")
	if (sysroot_flag != "")
		value = sysroot_flag (value == "" ? "" : " ") value
	if (value != "")
		printf "CPPFLAGS='%s'${CPPFLAGS:+ }\"${CPPFLAGS-}\"; export CPPFLAGS\n", value
	if (value != "") {
		printf "CFLAGS='%s'${CFLAGS:+ }\"${CFLAGS-}\"; export CFLAGS\n", value
		printf "CXXFLAGS='%s'${CXXFLAGS:+ }\"${CXXFLAGS-}\"; export CXXFLAGS\n", value
	}
	value = flags(node, "libdir", "-L")
	if (build_opsys == "darwin") {
		runtime = flags(node, "runtimedir", "-Wl,-rpath,")
		if (runtime != "")
			value = value (value == "" ? "" : " ") runtime
	}
	if (sysroot_flag != "")
		value = value (value == "" ? "" : " ") sysroot_flag
	if (value != "")
		printf "LDFLAGS='%s'${LDFLAGS:+ }\"${LDFLAGS-}\"; export LDFLAGS\n", value
	value = joined_paths(node, "pkgconfigdir", ":")
	if (value != "none")
		printf "PKG_CONFIG_PATH='%s'${PKG_CONFIG_PATH:+:}\"${PKG_CONFIG_PATH-}\"; export PKG_CONFIG_PATH\n", value
	runtime = joined_paths(node, "runtimedir", ":")
	if (runtime != "none") {
		value = (build_opsys == "darwin" ? "DYLD_LIBRARY_PATH" : "LD_LIBRARY_PATH")
		printf "%s='%s'${%s:+:}\"${%s-}\"; export %s\n", value, runtime, value, value, value
	}
	runtime = joined_paths(node, "targetruntimedir", ":")
	if (runtime != "none")
		printf "UPORTS_TARGET_RUNTIME_DIRS='%s'; export UPORTS_TARGET_RUNTIME_DIRS\n", runtime
}
