package amber_engine_globals

import cfg "engine:config"
import "engine:loader"
import "engine:storage"
import aec "shared:ae_common"

config: cfg.Config
mod_manager: loader.Mod_Manager
library_mod_loader: loader.Mod_Loader
proc_table: aec.Proc_Table
storage: storage.Storage

