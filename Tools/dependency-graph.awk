BEGIN {
	FS = "|"
}

NF == 1 && length($1) > 0 {
	node = $1
	if (!(node in node_seen)) {
		node_seen[node] = 1
		node_order[++node_count] = node
	}
}

NF >= 2 {
	from = $1
	to = $2

	if (!(from in node_seen)) {
		node_seen[from] = 1
		node_order[++node_count] = from
	}
	if (!(to in node_seen)) {
		node_seen[to] = 1
		node_order[++node_count] = to
	}

	edge_key = from SUBSEP to
	if (!(edge_key in edge_seen)) {
		edge_seen[edge_key] = 1
		# Records retain consumer -> provider meaning.  Ordering reverses
		# that relationship so every provider precedes its consumers.
		edge_to[to, ++edge_count_from[to]] = from
		indegree[from]++
	}

	if (NF >= 3) {
		target_key = to SUBSEP $3
		if (!(target_key in target_seen)) {
			target_seen[target_key] = 1
			target_for_node[to, ++target_count_for_node[to]] = $3
		}
	}
}

END {
	while (processed < node_count) {
		node = ""
		for (i = 1; i <= node_count; i++) {
			candidate = node_order[i]
			if (!done[candidate] && indegree[candidate] == 0) {
				node = candidate
				break
			}
		}
		if (node == "")
			break

		done[node] = 1
		ordered[++processed] = node
		for (i = 1; i <= edge_count_from[node]; i++) {
			to = edge_to[node, i]
			indegree[to]--
		}
	}

	if (processed == node_count) {
		if (raw_targets) {
			for (i = 1; i <= node_count; i++) {
				node = ordered[i]
				for (j = 1; j <= target_count_for_node[node]; j++) {
					printf "%s%s", separator, target_for_node[node, j]
					separator = " "
				}
			}
			printf "\n"
			exit 0
		}
		print "dependency_cycle = none"
		printf "dependency_order_count = %d\n", node_count
		printf "dependency_order ="
		for (i = 1; i <= node_count; i++)
			printf " %s", ordered[i]
		printf "\n"
		exit 0
	}

	printf "dependency_cycle = detected\n"
	printf "dependency_cycle_blocked_nodes ="
	for (i = 1; i <= node_count; i++) {
		node = node_order[i]
		if (indegree[node] > 0)
			printf " %s", node
	}
	printf "\n"

	if (fail)
		exit 1
}
