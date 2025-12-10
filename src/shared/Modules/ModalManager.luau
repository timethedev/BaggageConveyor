local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local peek = Fusion.peek
local Children = Fusion.Children
local scope = Fusion.scoped(Fusion)

local ModalManager = {
	Modals = {},
	IsModalOnScreen = scope:Value(false),
	OpenedModalId = scope:Value(""),
	OnModalClosed = Signal.Good.new(),
	_isToggling = false, -- Debounce flag
}

if RunService:IsRunning() then
	-- Hydrate the FOV of the camera
	scope:Hydrate(game.Workspace.CurrentCamera)({
		FieldOfView = scope:Spring(
			scope:Computed(function(use)
				if use(ModalManager.IsModalOnScreen) then
					return 90
				else
					return 70
				end
			end),
			60
		),
	})

	-- Render blur effect
	scope:New("BlurEffect")({
		Parent = game:GetService("Lighting"),
		Size = scope:Spring(
			scope:Computed(function(use)
				if use(ModalManager.IsModalOnScreen) then
					return 16
				else
					return 0
				end
			end),
			70
		),
	})
end

function ModalManager.RegisterModal(
	Id: string,
	GUIObject: GuiObject,
	opts: { Fullscreen: boolean?, CloseButton: GuiButton }
)
	local Visible = scope:Value(false)
	local originalPosition = GUIObject.Position

	if opts and opts.CloseButton then
		opts.CloseButton.Activated:Connect(function()
			ModalManager.ToggleModal(Id, true)
		end)
	end

	if not opts or not opts.Fullscreen then
		scope:Hydrate(GUIObject)({
			Position = scope:Spring(
				scope:Computed(function(use)
					if use(Visible) then
						return originalPosition
					else
						return UDim2.fromScale(originalPosition.X.Scale, 0.7)
					end
				end),
				60
			),

			[Children] = {
				scope:New("UIScale")({
					Scale = scope:Spring(
						scope:Computed(function(use)
							if use(Visible) then
								return 1.001
							else
								return 0
							end
						end),
						75
					),
				}),
			},
		})
	end

	scope:Observer(Visible):onChange(function()
		if peek(Visible) then
			GUIObject.Visible = true
		else
			if not opts or not opts.Fullscreen then
				task.wait(0.0275)
			end
			GUIObject.Visible = false
		end
	end)

	-- Shows the modal
	local Show = function()
		Visible:set(true)
		ModalManager.IsModalOnScreen:set(true)
		ModalManager.OpenedModalId:set(Id) -- <- Set the opened modal ID
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Hides the modal
	local Hide = function()
		ModalManager.OnModalClosed:Fire(Id)
		Visible:set(false)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		-- Check if any other modals are visible before setting IsModalOnScreen to false
		local anyModalVisible = false
		for _, data in pairs(ModalManager.Modals) do
			if data.Id ~= Id and peek(data.Visible) then
				anyModalVisible = true
				break
			end
		end

		if not anyModalVisible then
			ModalManager.IsModalOnScreen:set(false)
		end

		if peek(ModalManager.OpenedModalId) == Id then
			ModalManager.OpenedModalId:set("") -- <- Clear the opened modal ID if it's this one
		end

		-- Ensure cleanup after animation
		task.delay(0.1, function()
			if not peek(ModalManager.IsModalOnScreen) then
				-- Double check no modals are visible
				local stillVisible = false
				for _, data in pairs(ModalManager.Modals) do
					if peek(data.Visible) then
						stillVisible = true
						break
					end
				end
				if not stillVisible then
					ModalManager.IsModalOnScreen:set(false)
				end
			end
		end)
	end

	-- Toggles the modal's visibility
	local Toggle = function()
		pcall(function()
			if peek(Visible) then
				Hide()
			else
				Show()
			end
		end)
	end

	-- Store modal data and control functions
	ModalManager.Modals[GUIObject] = {
		Id = Id,
		Show = Show,
		Hide = Hide,
		Toggle = Toggle,
		Visible = Visible,
		GUIObject = GUIObject,
	}
end

-- Toggles a modal by its GUIId
function ModalManager.ToggleModal(Id: string, Hide: boolean?)
	-- Prevent rapid toggling
	if ModalManager._isToggling then
		return
	end
	ModalManager._isToggling = true

	local foundModal = TableUtil.Find(ModalManager.Modals, function(modal)
		return modal.Id == Id
	end)

	if foundModal then
		local GUIObject: GuiObject = foundModal.GUIObject

		-- Toggle the modal if it is registered
		if ModalManager.Modals[GUIObject] then
			-- Close all other modals
			for modal, data in ModalManager.Modals do
				if modal ~= GUIObject and peek(data.GUIObject.Visible) then
					data.Hide()
				end
			end

			if Hide == nil then
				ModalManager.Modals[GUIObject].Toggle()
			elseif Hide == true then
				ModalManager.Modals[GUIObject].Hide()
			end
		else
			warn("Modal not registered:", GUIObject.Name)
		end
	else
		warn("Modal with Id not found:", Id)
	end

	-- Release the toggle lock after a short delay
	task.delay(0.1, function()
		ModalManager._isToggling = false
	end)
end

function ModalManager.CloseAllModals()
	for _, data in pairs(ModalManager.Modals) do
		if peek(data.GUIObject.Visible) then
			data.Hide()
		end
	end
	ModalManager.IsModalOnScreen:set(false)
end

return ModalManager
