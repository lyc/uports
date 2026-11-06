# Sourced by fetch executors. Native fetch tools must not load consumer libs.
# Preserve the caller's loader paths captured before dependency contributions.

if [ "${UPORTS_DEPENDENCY_BASE_LD_LIBRARY_PATH_SET+x}" = x ]; then
	if [ "$UPORTS_DEPENDENCY_BASE_LD_LIBRARY_PATH_SET" = set ]; then
		LD_LIBRARY_PATH=$UPORTS_DEPENDENCY_BASE_LD_LIBRARY_PATH
		export LD_LIBRARY_PATH
	else
		unset LD_LIBRARY_PATH
	fi
fi

if [ "${UPORTS_DEPENDENCY_BASE_DYLD_LIBRARY_PATH_SET+x}" = x ]; then
	if [ "$UPORTS_DEPENDENCY_BASE_DYLD_LIBRARY_PATH_SET" = set ]; then
		DYLD_LIBRARY_PATH=$UPORTS_DEPENDENCY_BASE_DYLD_LIBRARY_PATH
		export DYLD_LIBRARY_PATH
	else
		unset DYLD_LIBRARY_PATH
	fi
fi
