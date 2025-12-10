local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Dependencies
local ModuleLoader = require(ReplicatedStorage.Shared.Modules.ModuleLoader)

ModuleLoader.ChangeSettings({
	FOLDER_SEARCH_DEPTH = 2,
	YIELD_THRESHOLD = 10,
	VERBOSE_LOADING = false,
	WAIT_FOR_SERVER = true,
})

ModuleLoader.Start(StarterPlayer.StarterPlayerScripts.Client.Controllers)
