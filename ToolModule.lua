--[[
    Last updated: 2025-03-25 16:50:00 UTC
    Author: crimianity

    ToolModule

    This module provides functionality for equipping tools from a model tagged with _Tool.
    When the player hovers over a model tagged with _Tool, a highlight is shown.
    On desktop the module binds an action for "Equip" (using the key E) and fires a RemoteEvent to the server
    to delete the model (the server will then handle giving the tool).

    Additionally, a drop monitor is set up so that when the player is holding a tool (i.e. a Tool instance is added
    to the character), the Drop action (Backspace) is bound. When the tool is removed, the drop binding is removed.
    
    For mobile, the module simply handles hovering and equipping (via UI) and does not bind drop keys.
--]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local ActionManager = require(game.ReplicatedStorage:WaitForChild("ActionManager"))

local ToolModule = {}
ToolModule.__index = ToolModule

function ToolModule.new(player, isMobile)
	local self = setmetatable({}, ToolModule)
	self.player = player
	self.isMobile = isMobile or false
	self.character = player.Character or nil
	self.currentHighlightedModel = nil
	self.hoverHighlight = nil
	self.equipActionBound = false
	self.equipActionName = "EquipTool"
	self.dropBound = false
	self.dropActionName = "DropTool"
	return self
end

-- Call this function once on desktop to monitor when a tool is equipped or removed from the character.
function ToolModule:initDropMonitor()
	if self.isMobile or not self.character then
		return
	end
	-- Bind drop action when a Tool is added.
	self.character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			if not self.dropBound then
				self:_bindDropAction(child)
			end
		end
	end)
	-- Unbind drop action when a Tool is removed.
	self.character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			ActionManager.unbindAction(self.dropActionName)
			self.dropBound = false
		end
	end)
end

-- Internal function to bind the Drop action when a Tool is found.
function ToolModule:_bindDropAction(tool)
	if not self.dropBound then
		local function dropActionHandler(action, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				self:dropTool(tool)
			end
		end
		-- Pass valid hotkeys for both bindings (using Backspace for both keyboard and gamepad)
		ActionManager.bindAction(self.dropActionName, dropActionHandler, Enum.KeyCode.Backspace, Enum.KeyCode.Backspace, 1)
		self.dropBound = true
	end
end

-- Function to update the hovering state over a potential tool model.
function ToolModule:updateHover(target)
	local model = nil
	if target then
		model = target:FindFirstAncestorWhichIsA("Model")
		if model and CollectionService:HasTag(model, "_Tool") then
			self:_createHoverHighlight(model)
			if not self.isMobile then
				self:_bindEquipAction(model)
			end
			return
		end
	end
	self:_clearHoverHighlight()
	self:_unbindEquipAction()
end

-- Internal function to create a highlight on the hovered model.
function ToolModule:_createHoverHighlight(model)
	if self.currentHighlightedModel ~= model then
		self:_clearHoverHighlight()
		self.currentHighlightedModel = model
		self.hoverHighlight = Instance.new("Highlight")
		self.hoverHighlight.FillTransparency = 1
		self.hoverHighlight.Parent = model
	end
end

-- Internal function to clear any hover highlights.
function ToolModule:_clearHoverHighlight()
	if self.hoverHighlight then
		self.hoverHighlight:Destroy()
		self.hoverHighlight = nil
	end
	self.currentHighlightedModel = nil
end

-- Internal function to bind the Equip action to the key E using ActionManager (desktop only).
function ToolModule:_bindEquipAction(model)
	if not self.equipActionBound then
		local function equipActionHandler(action, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				self:equipTool(model)
			end
		end
		ActionManager.bindAction(
			self.equipActionName,
			equipActionHandler,
			Enum.KeyCode.E,
			Enum.KeyCode.ButtonX,
			1
		)
		self.equipActionBound = true
	end
end

-- Internal function to unbind the Equip action.
function ToolModule:_unbindEquipAction()
	if self.equipActionBound then
		ActionManager.unbindAction(self.equipActionName)
		self.equipActionBound = false
	end
end

-- Function to handle the equip action.
-- Fires a RemoteEvent to delete the tool model on the server side; the server will give the tool.
function ToolModule:equipTool(model)
	if not model then return end
	local deleteRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DeleteTool")
	deleteRemote:FireServer(model)
	self:_clearHoverHighlight()
	self:_unbindEquipAction()
end

-- Function to drop the tool.
-- Drops the tool at the player's current position (no offset).
function ToolModule:dropTool(tool)
	if not tool then return end
	tool.Parent = workspace
	local hrp = self.character and self.character:FindFirstChild("HumanoidRootPart")
	if hrp then
		if tool:FindFirstChild("Handle") then
			tool.Handle.CFrame = CFrame.new(hrp.Position)
		elseif tool.PrimaryPart then
			tool:SetPrimaryPartCFrame(CFrame.new(hrp.Position))
		end
	end
	ActionManager.unbindAction(self.dropActionName)
	self.dropBound = false
end

-- Getter for the currently hovered tool model.
function ToolModule:getCurrentTool()
	return self.currentHighlightedModel
end

return ToolModule
