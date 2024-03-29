package amber_engine_common

import "base:intrinsics"
import "core:log"
import "core:sync"

_ :: log
_ :: sync

// A simple Id Generator for numeric ids
// @params: T = numeric Id type
// @note: Does not expect the counter to overflow. If an overflow occurs the 
//        counter will panic. If overflow is to be expected use 
//        Cyclic_Id_Generator
// @thread_safety: Thread-safe
// TODO(Vicix): Is panicking the best solution?
Id_Generator :: struct($T: typeid) where intrinsics.type_is_ordered_numeric(T) {
	counter: T,
}

// Generates a new id
// @thread_safety: Thread-safe
idgenerator_generate :: proc(generator: ^Id_Generator($T)) -> (result: T) {
	result = intrinsics.atomic_add(&generator.counter, 1)

	if result == max(T) {
		log.panicf("Id_Generator for type %v is about to overflow", typeid_of(T))
	}

	return
}

// Peeks the next id generated by idgenerator_generate
// @note: Calling this function does not affect in any way the next result of
//        idgenerator_generate. To generate a new id in a definitive matter use
//        idgenerator_generate
// @thread_safety: Thread-safe
idgenerator_peek_next :: proc(generator: ^Id_Generator($T)) -> T {
	return intrinsics.atomic_load(&generator.counter)
}

// Checks if an id could have been generated by the generator

// @thread_safety: Thread-safe
idgenerator_is_id_valid :: proc(generator: ^Id_Generator($T), id: T) -> bool {
	return id < idgenerator_peek_next(generator)
}

// An Id Generator that supports overflow
// @params: T = numerid Id type
// @performance: Cyclic_Id_Generator uses a mutex-based implementation while 
//               Id_Generator uses an atomic-based one. Prefer using 
//               Id_Generator when possible, since it is faster
// @thread_safery: Thread-safe
Cyclic_Id_Generator :: struct($T: typeid) where intrinsics.type_is_ordered_numeric(T) {
	counter: T,
	mutex:   sync.Mutex,
}

// Generates a new id between the provided range of possibilities
// @params: minimum = specifies the minimum new id value (inclusive)
//          maximum = specifies the maximum new id value (exclusive)
// @expects: minimum != maximum
// @note: The range is of the following type [minimum, maximum), in other words:
//        minimum <= returned id < maximum
// @thread_safery: Thread-safe
cyclicidgenerator_generate :: proc(
	generator: ^Cyclic_Id_Generator($T),
	minimum: T,
	maximum: T,
) -> T {
	assert(minimum != maximum)

	defer generator.counter += (T)(1)
	sync.mutex_guard(&generator.mutex)

	if generator.counter < minimum {
		generator.counter = minimum
	} else if generator.counter >= maximum {
		generator.counter = maximim - (T)(1)
	}

	return generator.counter
}

// Sets the next id that will be generated by cyclicidgenerator_generate or
// cyclicidgenerator_peek_next
// @note: Depending on the range provided to cyclicidgenerator_generate the next
//        generated id might not be the one set. cyclicidgenerator_peek_next 
//        will always return the id provided
// @thread_safery: Thread-safe
cyclicidgenerator_set_next :: proc(generator: ^Cyclic_Id_Generator($T), next: T) {
	sync.mutex_guard(&generator.mutex)

	generator.counter = next
}

// Peeks the next generated id by cyclicidgenerator_generate
// @note: Calling this function does not affect in any way the next result of
//        cyclicidgenerator_generate. To generate a new id in a definitive 
//        matter use cyclicidgenerator_generate
// @thread_safery: Thread-safe
cyclicidgenerator_peek_next :: proc(generator: ^Cyclic_Id_Generator($T)) -> T {
	sync.mutex_guard(&generator.mutex)

	return generator.counter
}

