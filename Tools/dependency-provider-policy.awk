BEGIN {
	FS = "|"
}

$1 == "group" {
	groups[$2] = 1
}

$1 == "policy" {
	raw[++policy_count] = $2
}

function invalid(record, reason) {
	if (state[record] == "") {
		state[record] = reason
		invalid_count++
	}
}

END {
	for (i = 1; i <= policy_count; i++) {
		count = split(raw[i], field, "@")
		if (count != 7) {
			invalid(i, "invalid-field-count")
			continue
		}
		kind[i] = field[1]
		context[i] = field[2]
		group[i] = field[3]
		opsys[i] = field[4]
		arch[i] = field[5]
		origin[i] = field[6]
		identity[i] = field[7]

		if (kind[i] != "system" && kind[i] != "sdk")
			invalid(i, "invalid-kind")
		else if (context[i] != "build" && context[i] != "target")
			invalid(i, "invalid-context")
		else if (kind[i] == "sdk" && context[i] != "target")
			invalid(i, "sdk-requires-target-context")
		else if (!(group[i] in groups))
			invalid(i, "unknown-consumer-group")
		else if (opsys[i] !~ /^[A-Za-z0-9_.+-]+$/)
			invalid(i, "invalid-opsys")
		else if (arch[i] !~ /^[A-Za-z0-9_.+-]+$/)
			invalid(i, "invalid-arch")
		else if (origin[i] !~ /^[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+$/)
			invalid(i, "invalid-origin")
		else if (identity[i] !~ /^[A-Za-z0-9_.+-]+$/)
			invalid(i, "invalid-identity")
		else {
			key = context[i] SUBSEP group[i] SUBSEP opsys[i] SUBSEP \
			      arch[i] SUBSEP origin[i]
			if (key in selected)
				invalid(i, "duplicate-selection-key")
			else {
				selected[key] = i
				state[i] = "valid"
			}
		}
	}

	printf "dependency_provider_policies = %d\n", policy_count
	printf "dependency_provider_policy_invalid = %d\n", invalid_count
	for (i = 1; i <= policy_count; i++) {
		if (state[i] == "invalid-field-count")
			printf "policy.%d = raw=%s state=%s\n", i, raw[i], state[i]
		else
			printf "policy.%d = kind=%s context=%s consumer_group=%s opsys=%s arch=%s origin=%s identity=%s state=%s\n", \
			       i, kind[i], context[i], group[i], opsys[i], arch[i], \
			       origin[i], identity[i], state[i]
	}
	if (fail && invalid_count)
		exit 1
}
