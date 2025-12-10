local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local ModuleLoader = require(ReplicatedStorage.Shared.Modules.ModuleLoader)

ModuleLoader.ChangeSettings({
	FOLDER_SEARCH_DEPTH = 5,
	YIELD_THRESHOLD = 10,
	VERBOSE_LOADING = false,
	WAIT_FOR_SERVER = true,
})

ModuleLoader.Start(script.Services)
