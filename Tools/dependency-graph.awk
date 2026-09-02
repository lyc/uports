BEGIN {
	FS = "|"
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
		edge_to[from, ++edge_count_from[from]] = to
		indegree[to]++
	}
}

END {
	for (i = 1; i <= node_count; i++) {
		node = node_order[i]
		if (indegree[node] == 0)
			queue[++queue_tail] = node
	}

	while (queue_head < queue_tail) {
		node = queue[++queue_head]
		processed++
		for (i = 1; i <= edge_count_from[node]; i++) {
			to = edge_to[node, i]
			indegree[to]--
			if (indegree[to] == 0)
				queue[++queue_tail] = to
		}
	}

	if (processed == node_count) {
		print "dependency_cycle = none"
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
