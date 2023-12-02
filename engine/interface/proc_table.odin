package amber_engine_interface

import "../config"
import aec "shared:ae_common"

proctable_init :: proc(table: ^aec.Proc_Table) {
	table.get_version = config.get_version
}
