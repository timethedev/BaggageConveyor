--!strict
--[[
	crusherfire's Module Loader!
	
	-- FEATURES --
	* CollectionService tags!
	* Supports module priority by setting an attribute "LoaderPriority" on the ModuleScript with a number value.
		* Larger number == higher priority.
	
	DEFAULT FILTERING BEHAVIOR:
	Run-context specific loading. If, for the purpose of organization, modules need to be located in the same folder but have certain ones
	required by client/server contexts, you can set boolean attributes like "ClientOnly" or "ServerOnly" to have the client/server ignore modules.
	
	You can also set a boolean attribute "IgnoreLoader" on a ModuleScript have the module loader ignore it.
	
	Modules that are not a direct child of a container or whose ancestry are not folders that lead back to a container will not be loaded.
	
	If you do not like this default filtering behavior, you can pass your own filtering predicate to the StartCustom() function and define your own
	behavior. Otherwise, use the Start() function for the default behavior.
	--------------
]]
-----------------------------
-- SERVICES --
-----------------------------
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
-----------------------------
-- VARIABLES --
-----------------------------
local isClient = RunService:IsClient()
local require = require
local loadedEvent: RemoteEvent
if isClient then
	loadedEvent = script:WaitForChild("LoadedEvent")
else
	loadedEvent = Instance.new("RemoteEvent")
	loadedEvent.Name = "LoadedEvent"
	loadedEvent.Parent = script
end
local tracker = {
	Load = {} :: { [ModuleScript]: any },
	Init = {} :: { [ModuleScript]: boolean },
	Start = {} :: { [ModuleScript]: boolean },
}
local trackerForActors = {
	Load = {} :: { [ModuleScript]: Actor },
	Init = {},
	Start = {},
}
export type LoaderSettings = {
	FOLDER_SEARCH_DEPTH: number?,
	YIELD_THRESHOLD: number?, -- how long the loader will wait for :Init() or :Start() to yield before warning and cancelling it
	VERBOSE_LOADING: boolean?,
	WAIT_FOR_SERVER: boolean?,
	USE_COLLECTION_SERVICE: boolean?,
}
export type KeepModulePredicate = (container: Instance, module: ModuleScript) -> boolean
-- CONSTANTS --
local SETTINGS: LoaderSettings = {
	FOLDER_SEARCH_DEPTH = 1,
	YIELD_THRESHOLD = 10,
	VERBOSE_LOADING = false,
	WAIT_FOR_SERVER = true,
	USE_COLLECTION_SERVICE = true,
}
local PRINT_IDENTIFIER = if isClient then "[C]" else "[S]"
local LOADED_IDENTIFIER = if isClient then "Client" else "Server"
local TAG = script:GetAttribute("LoaderTag")
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- <strong><code>!YIELDS!</code></strong>
local function waitForEither<Func, T...>(eventYes: RBXScriptSignal, eventNo: RBXScriptSignal): boolean
	local thread = coroutine.running()
	local connection1: any = nil
	local connection2: any = nil
	connection1 = eventYes:Once(function(...)
		if connection1 == nil then
			return
		end
		connection1:Disconnect()
		connection2:Disconnect()
		connection1 = nil
		connection2 = nil
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, true, ...)
		end
	end)
	connection2 = eventNo:Once(function(...)
		if connection2 == nil then
			return
		end
		connection1:Disconnect()
		connection2:Disconnect()
		connection1 = nil
		connection2 = nil
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, false, ...)
		end
	end)
	return coroutine.yield()
end
local function copy<T>(t: T, deep: boolean?): T
	if not deep then
		return (table.clone(t :: any) :: any) :: T
	end
	local function deepCopy(object: any)
		assert(typeof(object) == "table", "Expected table for deepCopy!")
		-- Returns a deep copy of the provided table.
		local newObject = setmetatable({}, getmetatable(object)) -- Clone metaData
		for index: any, value: any in object do
			if typeof(value) == "table" then
				newObject[index] = deepCopy(value)
				continue
			end
			newObject[index] = value
		end
		return newObject
	end
	return deepCopy(t :: any) :: T
end
local function reconcile<S, T>(src: S, template: T): S & T
	assert(type(src) == "table", "First argument must be a table")
	assert(type(template) == "table", "Second argument must be a table")
	local tbl = table.clone(src)
	for k, v in template do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = reconcile(sv, v)
			else
				tbl[k] = copy(sv, true)
			end
		end
	end
	return (tbl :: any) :: S & T
end
-- Returns a new array that is the result of array1 and array2
local function mergeArrays(array1: { [number]: any }, array2: { [number]: any })
	local length = #array2
	local newArray = table.clone(array2)
	for i, v in ipairs(array1) do
		newArray[length + i] = v
	end
	return newArray
end
local function filter<T>(t: { T }, predicate: (T, any, { T }) -> boolean): { T }
	assert(type(t) == "table", "First argument must be a table")
	assert(type(predicate) == "function", "Second argument must be a function")
	local newT = table.create(#t)
	if #t > 0 then
		local n = 0
		for i, v in t do
			if predicate(v, i, t) then
				n += 1
				newT[n] = v
			end
		end
	else
		for k, v in t do
			if predicate(v, k, t) then
				newT[k] = v
			end
		end
	end
	return newT
end
-- Returns the 'depth' of <code>descendant</code> in the child hierarchy of <code>root</code>.
-- If the descendant is not found in <code>root</code>, then this function will return 0.
local function getDepthInHierarchy(descendant: Instance, root: Instance): number
	local depth = 0
	local current: Instance? = descendant
	while current and current ~= root do
		current = current.Parent
		depth += 1
	end
	if not current then
		depth = 0
	end
	return depth
end
local function findAllFromClass(class: string, searchIn: Instance, searchDepth: number?): { any }
	assert(class and typeof(class) == "string", "class is invalid or nil")
	assert(searchIn and typeof(searchIn) == "Instance", "searchIn is invalid or nil")
	local foundObjects = {}
	if searchDepth then
		for _, object in pairs(searchIn:GetDescendants()) do
			if object:IsA(class) and getDepthInHierarchy(object, searchIn) <= searchDepth then
				table.insert(foundObjects, object)
			end
		end
	else
		for _, object in pairs(searchIn:GetDescendants()) do
			if object:IsA(class) then
				table.insert(foundObjects, object)
			end
		end
	end
	return foundObjects
end
local function keepModule(container: Instance, module: ModuleScript): boolean
	if module:GetAttribute("ClientOnly") and RunService:IsServer() then
		return false
	elseif module:GetAttribute("ServerOnly") and RunService:IsClient() then
		return false
	elseif module:GetAttribute("IgnoreLoader") then
		return false
	end
	local ancestor = module.Parent
	while ancestor do
		if ancestor == container then
			-- The ancestry should eventually lead to the container (if ancestors were always folders)
			return true
		elseif not ancestor:IsA("Folder") then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end
local function newPrint(...)
	print(PRINT_IDENTIFIER, ...)
end
local function newWarn(...)
	warn(PRINT_IDENTIFIER, ...)
end
local function loadModule(module: ModuleScript)
	if SETTINGS.VERBOSE_LOADING then
		newPrint(("Loading module '%s'"):format(module.Name))
	end
	local mainThread = coroutine.running()
	local startTime = tick()
	local endTime
	local executionSuccess, errMsg = false, ""
	local thread: thread = task.spawn(function()
		local success, result = pcall(function()
			return require(module)
		end)
		if success then
			tracker.Load[module] = result
			if result.Init then
				tracker.Init[module] = false
			end
			if result.Start then
				tracker.Start[module] = false
			end
			executionSuccess = true
		else
			errMsg = result
		end
		endTime = tick()
		if coroutine.status(mainThread) == "suspended" then
			task.spawn(mainThread)
		end
	end)
	if not endTime then
		endTime = tick()
	end
	if coroutine.status(thread) == "suspended" then
		local loopThread = task.spawn(function()
			task.wait(SETTINGS.YIELD_THRESHOLD)
			while true do
				if coroutine.status(thread) == "suspended" then
					newWarn(
						`>> Loading Module '{module.Name}' is taking a while!`,
						("(%.3f seconds elapsed)"):format(tick() - startTime)
					)
				end
				task.wait(5)
			end
		end)
		coroutine.yield()
		if coroutine.status(loopThread) ~= "dead" then
			task.cancel(loopThread)
		end
	end
	if SETTINGS.VERBOSE_LOADING and executionSuccess then
		newPrint(`>> Loaded module {module.Name}`, ("(took %.3f seconds)"):format(endTime - startTime))
	elseif not executionSuccess then
		newWarn(
			`>> Failed to load module {module.Name}`,
			("(took %.3f seconds)\n%s"):format(endTime - startTime, errMsg)
		)
	end
	if SETTINGS.VERBOSE_LOADING then
		newPrint(("Loading module '%s'"):format(module.Name))
	end
end
local function initializeModule(loadedModule, module: ModuleScript)
	if trackerForActors.Load[module] then
		local actorScript: BaseScript = trackerForActors.Load[module]:FindFirstChildWhichIsA("BaseScript") :: any
		trackerForActors.Load[module]:SendMessage("InitModule")
		if SETTINGS.VERBOSE_LOADING then
			newPrint(("Initializing PARALLEL module '%s'"):format(actorScript.Name))
		end
		local startTime = tick()
		if not actorScript:GetAttribute("Initialized") then
			actorScript:GetAttributeChangedSignal("Initialized"):Wait()
		end
		local endTime = tick()
		if SETTINGS.VERBOSE_LOADING and not actorScript:GetAttribute("Errored") then
			newPrint(
				`>> Initialized PARALLEL module {actorScript.Name}`,
				("(took %.3f seconds)"):format(endTime - startTime)
			)
		elseif actorScript:GetAttribute("Errored") then
			newWarn(
				`>> Failed to init PARALLEL module {actorScript.Name}`,
				("(took %.3f seconds)"):format(endTime - startTime)
			)
		end
		return
	end
	if not loadedModule.Init then
		return
	end
	if SETTINGS.VERBOSE_LOADING then
		newPrint(("Initializing module '%s'"):format(module.Name))
	end
	local mainThread = coroutine.running()
	local startTime = tick()
	local endTime
	local executionSuccess, errMsg = false, ""
	local thread: thread = task.spawn(function()
		local success, err = pcall(function()
			loadedModule:Init()
		end)
		executionSuccess = success
		if success then
			tracker.Init[module] = true
		else
			errMsg = err
		end
		endTime = tick()
		if coroutine.status(mainThread) == "suspended" then
			task.spawn(mainThread)
		end
	end)
	if not endTime then
		endTime = tick()
	end
	if coroutine.status(thread) == "suspended" then
		local loopThread = task.spawn(function()
			task.wait(SETTINGS.YIELD_THRESHOLD)
			while true do
				if coroutine.status(thread) == "suspended" then
					newWarn(
						`>> :Init() for Module '{module.Name}' is taking a while!`,
						("(%.3f seconds elapsed)"):format(tick() - startTime)
					)
				end
				task.wait(5)
			end
		end)
		coroutine.yield()
		if coroutine.status(loopThread) ~= "dead" then
			task.cancel(loopThread)
		end
	end
	if SETTINGS.VERBOSE_LOADING and executionSuccess then
		newPrint(`>> Initialized module {module.Name}`, ("(took %.3f seconds)"):format(endTime - startTime))
	elseif not executionSuccess then
		newWarn(
			`>> Failed to init module {module.Name}`,
			("(took %.3f seconds)\n%s"):format(endTime - startTime, errMsg)
		)
	end
end
local function startModule(loadedModule, module: ModuleScript)
	if trackerForActors.Load[module] then
		local actorScript: BaseScript = trackerForActors.Load[module]:FindFirstChildWhichIsA("BaseScript") :: any
		trackerForActors.Load[module]:SendMessage("StartModule")
		if SETTINGS.VERBOSE_LOADING then
			newPrint(("Starting PARALLEL module '%s'"):format(actorScript.Name))
		end
		local startTime = tick()
		if not actorScript:GetAttribute("Started") then
			actorScript:GetAttributeChangedSignal("Started"):Wait()
		end
		local endTime = tick()
		if SETTINGS.VERBOSE_LOADING and not actorScript:GetAttribute("Errored") then
			newPrint(
				`>> Started PARALLEL module {actorScript.Name}`,
				("(took %.3f seconds)"):format(endTime - startTime)
			)
		elseif actorScript:GetAttribute("Errored") then
			newWarn(
				`>> Failed to start PARALLEL module {actorScript.Name}`,
				("(took %.3f seconds)"):format(endTime - startTime)
			)
		end
		return
	end
	if not loadedModule.Start then
		return
	end
	if SETTINGS.VERBOSE_LOADING then
		newPrint(("Starting module '%s'"):format(module.Name))
	end
	local mainThread = coroutine.running()
	local startTime = tick()
	local endTime
	local executionSuccess, errMsg = false, ""
	local thread: thread = task.spawn(function()
		local success, err = pcall(function()
			loadedModule:Start()
		end)
		executionSuccess = success
		if success then
			tracker.Start[module] = true
		else
			errMsg = err
		end
		endTime = tick()
		if coroutine.status(mainThread) == "suspended" then
			task.spawn(mainThread)
		end
	end)
	if not endTime then
		endTime = tick()
	end
	if coroutine.status(thread) == "suspended" then
		local loopThread = task.spawn(function()
			task.wait(SETTINGS.YIELD_THRESHOLD)
			while true do
				if coroutine.status(thread) == "suspended" then
					newWarn(
						`>> :Start() for Module '{module.Name}' is taking a while!`,
						("(%.3f seconds elapsed)"):format(tick() - startTime)
					)
				end
				task.wait(5)
			end
		end)
		coroutine.yield()
		if coroutine.status(loopThread) ~= "dead" then
			task.cancel(loopThread)
		end
	end
	if SETTINGS.VERBOSE_LOADING and executionSuccess then
		newPrint(`>> Started module {module.Name}`, ("(took %.3f seconds)"):format(endTime - startTime))
	elseif not executionSuccess then
		newWarn(
			`>> Failed to start module {module.Name}`,
			("(took %.3f seconds)\n%s"):format(endTime - startTime, errMsg)
		)
	end
end
-- Gets all modules to be loaded in order.
local function getModules(containers: { Instance }): { ModuleScript }
	local totalModules = {}
	for _, container in ipairs(containers) do
		local modules = findAllFromClass("ModuleScript", container, SETTINGS.FOLDER_SEARCH_DEPTH)
		modules = filter(modules, function(module)
			return keepModule(container, module)
		end)
		totalModules = mergeArrays(totalModules, modules)
	end
	if SETTINGS.USE_COLLECTION_SERVICE and TAG ~= "" and TAG ~= nil then
		for _, module in CollectionService:GetTagged(TAG) do
			if not module:IsA("ModuleScript") then
				warn(`item: {module} with tag: {TAG} is not a module script!`)
				continue
			end
			if not keepModule(module.Parent, module) then
				continue
			end
			if table.find(totalModules, module) then
				continue
			end
			table.insert(totalModules, module)
		end
	end
	table.sort(totalModules, function(a, b)
		local aPriority = a:GetAttribute("LoaderPriority")
		local bPriority = b:GetAttribute("LoaderPriority")
		if aPriority and bPriority then
			return aPriority > bPriority
		elseif aPriority and not bPriority then
			return true
		elseif bPriority and not aPriority then
			return false
		else
			return false
		end
	end)
	return totalModules
end
-----------------------------
-- MAIN --
-----------------------------
-- Start the loader with the default module filtering behavior.
local function start(...: Instance)
	local containers = { ... }
	if isClient and SETTINGS.WAIT_FOR_SERVER and not workspace:GetAttribute("ServerLoaded") then
		workspace:GetAttributeChangedSignal("ServerLoaded"):Wait()
	end
	if SETTINGS.VERBOSE_LOADING then
		newWarn("=== LOADING MODULES ===")
		local modules = getModules(containers)
		for _, module in modules do
			loadModule(module)
		end

		newWarn("=== INITIALIZING MODULES ===")
		for _, module in modules do
			if not tracker.Load[module] then
				continue
			end
			initializeModule(tracker.Load[module], module)
		end
		newWarn("=== STARTING MODULES ===")
		for _, module in modules do
			if not tracker.Load[module] then
				continue
			end
			startModule(tracker.Load[module], module)
		end
		newWarn("=== LOADING FINISHED ===")
	else
		local modules = getModules(containers)
		for _, module in modules do
			loadModule(module)
		end
		for _, module in modules do
			if not tracker.Load[module] then
				continue
			end
			if tracker.Load[module] then
				initializeModule(tracker.Load[module], module)
			end
		end
		for _, module in modules do
			if not tracker.Load[module] then
				continue
			end
			if tracker.Load[module] then
				startModule(tracker.Load[module], module)
			end
		end
	end
	workspace:SetAttribute(`{LOADED_IDENTIFIER}Loaded`, true)
	if RunService:IsClient() then
		loadedEvent:FireServer()
	end
end
-- Start the loader with your own custom module filtering behavior for determining what modules should be loaded.
local function startCustom(_keepModule: KeepModulePredicate, ...: Instance)
	keepModule = _keepModule
	start(...)
end
local function isClientLoaded(player: Player): boolean
	return player:GetAttribute("_ModulesLoaded") == true
end
-- <strong><code>!YIELDS!</code></strong>
-- Yields until the client has loaded all their modules.
-- Returns true if loaded or returns false if player left.
local function waitForLoadedClient(player: Player): boolean
	if not player:GetAttribute("_ModulesLoaded") then
		return waitForEither(
			player:GetAttributeChangedSignal("_ModulesLoaded"),
			player:GetPropertyChangedSignal("Parent")
		)
	end
	return true
end
local function changeSettings(settings: LoaderSettings)
	SETTINGS = reconcile(settings, SETTINGS)
end
if not isClient then
	loadedEvent.OnServerEvent:Connect(function(player)
		player:SetAttribute("_ModulesLoaded", true)
	end)
end
return {
	Start = start,
	StartCustom = startCustom,
	ChangeSettings = changeSettings,
	IsClientLoaded = isClientLoaded,
	WaitForLoadedClient = waitForLoadedClient,
}
