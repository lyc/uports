BEGIN {
	FS = "|"
}

$1 == "node" {
	node = $2
	if (!(node in node_seen)) {
		node_seen[node] = 1
		node_order[++node_count] = node
	}
}

$1 == "dependency" {
	consumer = $2
	dep_index = ++dependency_count[consumer]
	dependency_provider[consumer, dep_index] = $3
	dependency_type[consumer, dep_index] = $4
	dependency_target[consumer, dep_index] = $5
	dependency_suffix[consumer, dep_index] = $6
	dependency_resolution[consumer, dep_index] = $7
}

$1 == "request" {
	request_node[++request_count] = $2
	request_phase[request_count] = $3
}

function dependency_level(phase) {
	if (phase == "configure" || phase == "build" || phase == "rebuild")
		return 1
	if (phase == "stage" || phase == "package" || phase == "install" ||
	    phase == "restage" || phase == "reinstall" ||
	    phase == "generate-plist")
		return 2
	return 0
}

function target_rank(phase) {
	if (phase == "fetch") return 1
	if (phase == "extract") return 2
	if (phase == "patch") return 3
	if (phase == "configure") return 4
	if (phase == "build" || phase == "rebuild") return 5
	if (phase == "stage" || phase == "restage" ||
	    phase == "generate-plist") return 6
	if (phase == "package") return 7
	if (phase == "install" || phase == "reinstall") return 8
	return 0
}

function dependency_needed(phase, type, rank) {
	rank = dependency_level(phase)
	return rank == 2 || (rank == 1 && (type == "build" || type == "lib"))
}

function valid_provider_phase(phase) {
	return phase == "fetch" || phase == "extract" || phase == "patch" ||
	       phase == "configure" || phase == "build" || phase == "stage" ||
	       phase == "package" || phase == "install"
}

function add_request(node, phase, rank) {
	rank = target_rank(phase)
	if (!(node in requested) || rank > requested_rank[node]) {
		requested[node] = 1
		requested_phase[node] = phase
		requested_rank[node] = rank
		return 1
	}
	return 0
}

function add_provider_target(node, phase, target, rank) {
	rank = target_rank(phase)
	if (!(node in provider_target) || rank > provider_target_rank[node]) {
		provider_target[node] = target
		provider_target_rank[node] = rank
	}
}

END {
	if (request_count == 0 && root != "") {
		request_node[++request_count] = root
		request_phase[request_count] = root_phase
	}
	if (request_count == 0) {
		print "dependency execution request is not a selected instance" > "/dev/stderr"
		exit 1
	}

	for (r = 1; r <= request_count; r++) {
		node = request_node[r]
		if (!(node in node_seen)) {
			print "dependency execution request is not a selected instance" > "/dev/stderr"
			exit 1
		}
		is_root[node] = 1
		add_request(node, request_phase[r])
	}
	changed = 1
	while (changed) {
		changed = 0
		for (n = 1; n <= node_count; n++) {
			consumer = node_order[n]
			if (!(consumer in requested))
				continue
			for (i = 1; i <= dependency_count[consumer]; i++) {
				type = dependency_type[consumer, i]
				if (!dependency_needed(requested_phase[consumer], type))
					continue
				if (dependency_resolution[consumer, i] != "selected") {
					if (!unresolved[consumer, i]++)
						unresolved_count++
					continue
				}
				provider = dependency_provider[consumer, i]
				target = dependency_target[consumer, i]
				phase = dependency_suffix[consumer, i]
				if (!valid_provider_phase(phase)) {
					if (!invalid_target[consumer, i]++)
						invalid_target_count++
					continue
				}
				selected_edge[consumer, i] = 1
				add_provider_target(provider, phase, target)
				if (add_request(provider, phase))
					changed = 1
			}
		}
	}

	if (unresolved_count) {
		printf "unresolved_dependencies = %d\n", unresolved_count > "/dev/stderr"
		exit 1
	}
	if (invalid_target_count) {
		printf "invalid_dependency_targets = %d\n", invalid_target_count > "/dev/stderr"
		exit 1
	}

	for (n = 1; n <= node_count; n++) {
		consumer = node_order[n]
		if (!(consumer in requested))
			continue
		closure_count++
		for (i = 1; i <= dependency_count[consumer]; i++) {
			if (!selected_edge[consumer, i])
				continue
			provider = dependency_provider[consumer, i]
			edge_key = consumer SUBSEP provider
			if (!(edge_key in edge_seen)) {
				edge_seen[edge_key] = 1
				edge_to[provider, ++edge_count_from[provider]] = consumer
				indegree[consumer]++
			}
		}
	}

	while (processed < closure_count) {
		node = ""
		for (n = 1; n <= node_count; n++) {
			candidate = node_order[n]
			if ((candidate in requested) && !done[candidate] &&
			    indegree[candidate] == 0) {
				node = candidate
				break
			}
		}
		if (node == "")
			break
		done[node] = 1
		ordered[++processed] = node
		for (i = 1; i <= edge_count_from[node]; i++)
			indegree[edge_to[node, i]]--
	}

	if (processed != closure_count) {
		print "dependency_cycle = detected" > "/dev/stderr"
		exit 1
	}

	if (inspect) {
		if (request_count == 1) {
			printf "dependency_execution_root = %s\n", request_node[1]
			printf "dependency_execution_phase = %s\n", request_phase[1]
		} else {
			printf "dependency_execution_roots ="
			for (r = 1; r <= request_count; r++)
				printf " %s.%s", request_node[r], request_phase[r]
			printf "\n"
		}
		printf "dependency_execution_instances = %d\n", closure_count
		printf "dependency_execution_targets ="
		separator = " "
	}
	for (n = 1; n <= processed; n++) {
		node = ordered[n]
		if (!(node in provider_target))
			continue
		printf "%s%s", separator, provider_target[node]
		separator = " "
	}
	printf "\n"
}
