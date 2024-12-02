
cmake_minimum_required(VERSION 3.20)

# directory containing all the static libs needed for gRPC
set(GRPC_LIBS_DIR "${COMMON_DIR}/api/deps/grpc_web/libs")

# directory containing all the headers for gRPC
set(GRPC_INCLUDE_DIR "${COMMON_DIR}/api/deps/grpc_include")

# GRPC generated stubs
set(GRPC_STUBS_DIR "${REPO_ROOT_DIR}/grpc")
set(GRPC_TRACKING_STUB_DIR "${REPO_ROOT_DIR}/grpc/tracking")

# headers
set(GRPC_INCLUDE "${GRPC_INCLUDE_DIR}/grpc"
	"${GRPC_INCLUDE_DIR}/protobuf"
	"${GRPC_STUBS_DIR}"
	"${GRPC_TRACKING_STUB_DIR}")

ADD_LIBRARY(grpc_libabsl_bad_any_cast_impl STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_bad_any_cast_impl PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_bad_any_cast_impl.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_bad_optional_access STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_bad_optional_access PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_bad_optional_access.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_bad_variant_access STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_bad_variant_access PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_bad_variant_access.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_base STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_base PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_base.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_city STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_city PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_city.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_civil_time STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_civil_time PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_civil_time.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_cord STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_cord PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_cord.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_debugging_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_debugging_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_debugging_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_demangle_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_demangle_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_demangle_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_examine_stack STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_examine_stack PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_examine_stack.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 11

ADD_LIBRARY(grpc_libabsl_exponential_biased STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_exponential_biased PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_exponential_biased.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_failure_signal_handler STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_failure_signal_handler PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_failure_signal_handler.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_commandlineflag STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_commandlineflag PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_commandlineflag.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_commandlineflag_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_commandlineflag_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_commandlineflag_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_config STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_config PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_config.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_marshalling STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_marshalling PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_marshalling.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_parse STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_parse PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_parse.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_private_handle_accessor STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_private_handle_accessor PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_private_handle_accessor.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 21

ADD_LIBRARY(grpc_libabsl_flags_program_name STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_program_name PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_program_name.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_reflection STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_reflection PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_reflection.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_usage STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_usage PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_usage.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_flags_usage_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_flags_usage_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_flags_usage_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_graphcycles_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_graphcycles_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_graphcycles_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_hash STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_hash PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_hash.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_hashtablez_sampler STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_hashtablez_sampler PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_hashtablez_sampler.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_int128 STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_int128 PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_int128.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_leak_check STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_leak_check PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_leak_check.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_leak_check_disable STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_leak_check_disable PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_leak_check_disable.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 31

ADD_LIBRARY(grpc_libabsl_log_severity STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_log_severity PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_log_severity.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_malloc_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_malloc_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_malloc_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_periodic_sampler STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_periodic_sampler PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_periodic_sampler.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_distributions STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_distributions PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_distributions.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_distribution_test_util STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_distribution_test_util PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_distribution_test_util.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_platform STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_platform PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_platform.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_pool_urbg STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_pool_urbg PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_pool_urbg.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_randen STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_randen PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_randen.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_randen_hwaes STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_randen_hwaes PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_randen_hwaes.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_randen_hwaes_impl STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_randen_hwaes_impl PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_randen_hwaes_impl.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 41

ADD_LIBRARY(grpc_libabsl_random_internal_randen_slow STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_randen_slow PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_randen_slow.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_internal_seed_material STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_internal_seed_material PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_internal_seed_material.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_seed_gen_exception STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_seed_gen_exception PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_seed_gen_exception.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_random_seed_sequences STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_random_seed_sequences PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_random_seed_sequences.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_raw_hash_set STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_raw_hash_set PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_raw_hash_set.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_raw_logging_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_raw_logging_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_raw_logging_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_scoped_set_env STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_scoped_set_env PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_scoped_set_env.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_spinlock_wait STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_spinlock_wait PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_spinlock_wait.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_stacktrace STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_stacktrace PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_stacktrace.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_status STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_status PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_status.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 51

ADD_LIBRARY(grpc_libabsl_statusor STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_statusor PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_statusor.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_str_format_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_str_format_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_str_format_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_strerror STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_strerror PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_strerror.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_strings STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_strings PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_strings.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_strings_internal STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_strings_internal PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_strings_internal.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_symbolize STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_symbolize PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_symbolize.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_synchronization STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_synchronization PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_synchronization.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_throw_delegate STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_throw_delegate PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_throw_delegate.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_time STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_time PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_time.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libabsl_time_zone STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libabsl_time_zone PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libabsl_time_zone.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 61

ADD_LIBRARY(grpc_libaddress_sorting STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libaddress_sorting PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libaddress_sorting.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libcares STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libcares PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libcares.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libcrypto STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libcrypto PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libcrypto.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgpr STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgpr PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgpr.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc++ STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc++ PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc++.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc++_alts STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc++_alts PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc++_alts.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc++_error_details STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc++_error_details PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc++_error_details.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc++_unsecure STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc++_unsecure PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc++_unsecure.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libgrpc_plugin_support STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc_plugin_support PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc_plugin_support.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

# 71

ADD_LIBRARY(grpc_libgrpc_unsecure STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libgrpc_unsecure PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libgrpc_unsecure.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libprotobuf-lite STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libprotobuf-lite PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libprotobuf-lite.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libprotobuf STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libprotobuf PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libprotobuf.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libre2 STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libre2 PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libre2.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libssl STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libssl PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libssl.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libtesting STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libtesting PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libtesting.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libupb STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libupb PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libupb.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

ADD_LIBRARY(grpc_libz STATIC IMPORTED)
SET_TARGET_PROPERTIES(grpc_libz PROPERTIES
		IMPORTED_LOCATION ${GRPC_LIBS_DIR}/libz.a
		IMPORTED_LINK_INTERFACE_MULTIPLICITY 10)

add_library(grpc INTERFACE)
target_link_libraries(grpc INTERFACE
		-Wl,--start-group
		grpc_libabsl_bad_any_cast_impl
		grpc_libabsl_bad_optional_access
		grpc_libabsl_bad_variant_access
		grpc_libabsl_base
		grpc_libabsl_city
		grpc_libabsl_civil_time
		grpc_libabsl_cord
		grpc_libabsl_debugging_internal
		grpc_libabsl_demangle_internal
		grpc_libabsl_examine_stack
		grpc_libabsl_exponential_biased
		grpc_libabsl_failure_signal_handler
		grpc_libabsl_flags
		grpc_libabsl_flags_commandlineflag
		grpc_libabsl_flags_commandlineflag_internal
		grpc_libabsl_flags_config
		grpc_libabsl_flags_internal
		grpc_libabsl_flags_marshalling
		grpc_libabsl_flags_parse
		grpc_libabsl_flags_private_handle_accessor
		grpc_libabsl_flags_program_name
		grpc_libabsl_flags_reflection
		grpc_libabsl_flags_usage
		grpc_libabsl_flags_usage_internal
		grpc_libabsl_graphcycles_internal
		grpc_libabsl_hash
		grpc_libabsl_hashtablez_sampler
		grpc_libabsl_int128
		grpc_libabsl_leak_check
		grpc_libabsl_leak_check_disable
		grpc_libabsl_log_severity
		grpc_libabsl_malloc_internal
		grpc_libabsl_periodic_sampler
		grpc_libabsl_random_distributions
		grpc_libabsl_random_internal_distribution_test_util
		grpc_libabsl_random_internal_platform
		grpc_libabsl_random_internal_pool_urbg
		grpc_libabsl_random_internal_randen
		grpc_libabsl_random_internal_randen_hwaes
		grpc_libabsl_random_internal_randen_hwaes_impl
		grpc_libabsl_random_internal_randen_slow
		grpc_libabsl_random_internal_seed_material
		grpc_libabsl_random_seed_gen_exception
		grpc_libabsl_random_seed_sequences
		grpc_libabsl_raw_hash_set
		grpc_libabsl_raw_logging_internal
		grpc_libabsl_scoped_set_env
		grpc_libabsl_spinlock_wait
		grpc_libabsl_stacktrace
		grpc_libabsl_status
		grpc_libabsl_statusor
		grpc_libabsl_str_format_internal
		grpc_libabsl_strerror
		grpc_libabsl_strings
		grpc_libabsl_strings_internal
		grpc_libabsl_symbolize
		grpc_libabsl_synchronization
		grpc_libabsl_throw_delegate
		grpc_libabsl_time
		grpc_libabsl_time_zone
		grpc_libaddress_sorting
		grpc_libcares
		grpc_libcrypto
		grpc_libgpr
		grpc_libgrpc++
		grpc_libgrpc++_alts
		grpc_libgrpc++_error_details
		grpc_libgrpc++_unsecure
		grpc_libgrpc
		grpc_libgrpc_plugin_support
		grpc_libgrpc_unsecure
		grpc_libprotobuf-lite
		grpc_libprotobuf
		grpc_libre2
		grpc_libssl
		grpc_libtesting
		grpc_libupb
		grpc_libz
		-Wl,--end-group)
