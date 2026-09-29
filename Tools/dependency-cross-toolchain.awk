BEGIN {
	FS = "|"
}

$1 == "toolchain" {
	group[++group_count] = $2
	triplet[$2] = $3
}

$1 == "tool" {
	tool_count++
	tool_group[tool_count] = $2
	tool_name[tool_count] = $3
	tool_command[tool_count] = $4
	tool_state[tool_count] = $5
	tool_path[tool_count] = $6
	if ($5 != "ready") {
		missing_count++
		group_missing[$2]++
	}
}

END {
	for (i = 1; i <= group_count; i++) {
		name = group[i]
		printf "toolchain.%s = cross_compile=%s state=%s\n", name,
		       triplet[name], (group_missing[name] ? "missing-tools" : "ready")
		for (j = 1; j <= tool_count; j++) {
			if (tool_group[j] != name)
				continue
			printf "toolchain.%s.%s = command=%s path=%s state=%s\n", name,
			       tool_name[j], tool_command[j], tool_path[j], tool_state[j]
		}
	}
	printf "dependency_cross_toolchains = %d\n", group_count
	printf "dependency_cross_toolchain_tools = %d\n", tool_count
	printf "dependency_cross_toolchain_missing = %d\n", missing_count
	if (fail && missing_count) {
		for (i = 1; i <= tool_count; i++)
			if (tool_state[i] != "ready")
				printf "cross toolchain missing: group=%s command=%s\n",
				       tool_group[i], tool_command[i] > "/dev/stderr"
		exit 1
	}
}
