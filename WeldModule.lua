--[[
    Last updated: 2025-03-23 19:13:16 UTC (modified 2025-03-24 22:45:00 UTC)
    Author: crimianity

    WeldModule for Item Grab System with enhanced welding functionality.
    Now it uses the "IsWelded" attribute on the model to determine and set the welded state.
--]]

local CollectionService = game:GetService("CollectionService")
local ActionManager = require(game.ReplicatedStorage.ActionManager)

local WeldModule = {}

function WeldModule.new(humanoidRootPart)
	local module = {
		touchingValidParts = {},
		actionBound = false,
		unweldActionBound = false,
		heldModel = nil,
		humanoidRootPart = humanoidRootPart
	}

	function module:isValidWeldTarget(part)
		local function isPartOfItem(testPart)
			local model = testPart:FindFirstAncestorWhichIsA("Model")
			return model and CollectionService:HasTag(model, "_Item")
		end

		if isPartOfItem(part) then return false end

		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChild("Humanoid") then return false end

		return true
	end

	function module:isModelWelded(model)
		-- Check using the IsWelded attribute.
		if model:GetAttribute("IsWelded") then
			return true
		end
		-- Fallback: check if any part has a weld.
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part:FindFirstChild("NewWeld") then
				return true
			end
		end
		return false
	end

	function module:updateWeldActions(target, heldObject)
		if heldObject then
			self.heldModel = heldObject:FindFirstAncestorWhichIsA("Model")
		else
			self.heldModel = nil
		end

		local hasValidTouchingParts = next(self.touchingValidParts) ~= nil
		local canWeld = hasValidTouchingParts and 
			self.heldModel and 
			CollectionService:HasTag(self.heldModel, "_Item") and 
			(not self:isModelWelded(self.heldModel))

		if canWeld and not self.actionBound then
			ActionManager.bindAction(
				"Weld",
				function(action, inputState)
					if inputState == Enum.UserInputState.Begin then
						self:weld()
					end
				end,
				Enum.KeyCode.Z,
				Enum.KeyCode.ButtonB,
				2
			)
			self.actionBound = true
		elseif not canWeld and self.actionBound then
			ActionManager.unbindAction("Weld")
			self.actionBound = false
		end

		local targetModel = target and target:FindFirstAncestorWhichIsA("Model")
		local isWeldedItem = targetModel and 
			CollectionService:HasTag(targetModel, "_Item") and 
			self:isModelWelded(targetModel)

		local isWithinRange = false
		if targetModel and self.humanoidRootPart then
			local distance = (self.humanoidRootPart.Position - targetModel:GetPivot().Position).Magnitude
			isWithinRange = distance <= 20
		end

		if isWeldedItem and isWithinRange and not self.unweldActionBound then
			ActionManager.bindAction(
				"Unweld",
				function(action, inputState)
					if inputState == Enum.UserInputState.Begin then
						self:unweld(targetModel)
					end
				end,
				Enum.KeyCode.Z,
				Enum.KeyCode.ButtonY,
				3
			)
			self.unweldActionBound = true
		elseif (not isWeldedItem or not isWithinRange) and self.unweldActionBound then
			ActionManager.unbindAction("Unweld")
			self.unweldActionBound = false
		end
	end

	function module:setupTouchConnections(model)
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(touchedPart)
					if self:isValidWeldTarget(touchedPart) then
						self.touchingValidParts[part] = touchedPart
						self:updateWeldActions(nil, model)
					end
				end)

				part.TouchEnded:Connect(function(touchedPart)
					if self.touchingValidParts[part] == touchedPart then
						self.touchingValidParts[part] = nil
						self:updateWeldActions(nil, model)
					end
				end)
			end
		end
	end

	function module:weld()
		if not self.heldModel then return end

		for part, touchingPart in pairs(self.touchingValidParts) do
			if part:IsDescendantOf(self.heldModel) then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "NewWeld"
				weld.Part0 = part
				weld.Part1 = touchingPart
				weld.Parent = part
				touchingPart.Anchored = true
			end
		end

		table.clear(self.touchingValidParts)
		self:updateWeldActions(nil, self.heldModel)
		-- Mark the model as welded.
		self.heldModel:SetAttribute("IsWelded", true)
	end

	function module:unweld(model)
		local partsToUnanchor = {}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local weld = part:FindFirstChild("NewWeld")
				if weld then
					if weld.Part1 then
						table.insert(partsToUnanchor, weld.Part1)
					end
					weld:Destroy()
				end
				part.Anchored = false
			end
		end

		for _, part in ipairs(partsToUnanchor) do
			part.Anchored = false
		end

		self:updateWeldActions(nil, model)
		-- Mark the model as not welded.
		model:SetAttribute("IsWelded", false)
	end

	function module:destroy()
		if self.actionBound then
			ActionManager.unbindAction("Weld")
		end
		if self.unweldActionBound then
			ActionManager.unbindAction("Unweld")
		end
		table.clear(self.touchingValidParts)
	end

	return module
end

return WeldModule
