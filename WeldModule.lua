--[[
    Last updated: 2025-03-26
    Author: crimianity

    Enhanced WeldModule with mobile support and better weld detection
--]]
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ActionManager = require(game.ReplicatedStorage.ActionManager)

local WeldModule = {}

function WeldModule.new(humanoidRootPart)
	local module = {
		actionBound = false,
		unweldActionBound = false,
		heldModel = nil,
		humanoidRootPart = humanoidRootPart
	}

	-- Returns true if the candidate part is valid for a weld constraint
	function module:isValidWeldTarget(part)
		if self.heldModel and part:IsDescendantOf(self.heldModel) then
			return false
		end
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and CollectionService:HasTag(model, "_Item") then
			return false
		end
		if model and model:FindFirstChild("Humanoid") then
			return false
		end
		return true
	end

	function module:isModelWelded(model)
		if model:GetAttribute("IsWelded") then
			return true
		end
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part:FindFirstChild("NewWeld") then
				return true
			end
		end
		return false
	end

	-- Check if a model can be welded (has nearby valid parts or terrain)
	function module:canWeldModel(model)
		if not model or not CollectionService:HasTag(model, "_Item") or self:isModelWelded(model) then
			return false
		end

		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Check nearby parts
				local nearbyParts = workspace:GetPartBoundsInRadius(part.Position, 1.5)
				for _, candidate in ipairs(nearbyParts) do
					if candidate and candidate ~= part and self:isValidWeldTarget(candidate) then
						return true
					end
				end

				-- Check terrain
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {workspace.Terrain}
				rayParams.FilterType = Enum.RaycastFilterType.Include
				local ray = workspace:Raycast(part.Position, Vector3.new(0, -1.5, 0), rayParams)
				if ray then
					return true
				end
			end
		end
		return false
	end

	-- Check if a model can be unwelded (is welded and in range)
	function module:canUnweldModel(model)
		if not model or not CollectionService:HasTag(model, "_Item") then
			return false
		end

		if not self:isModelWelded(model) then
			return false
		end

		if self.humanoidRootPart then
			local distance = (self.humanoidRootPart.Position - model:GetPivot().Position).Magnitude
			return distance <= 20
		end

		return false
	end

	function module:updateWeldActions(target, heldObject)
		if heldObject then
			self.heldModel = heldObject:FindFirstAncestorWhichIsA("Model")
		else
			self.heldModel = nil
		end

		-- Skip action binding if on mobile
		if UserInputService.TouchEnabled then
			return
		end

		-- Use GetPartBoundsInRadius() with a 1.5 stud radius for weld detection.
		local validCandidate = false
		if self.heldModel then
			for _, part in ipairs(self.heldModel:GetDescendants()) do
				if part:IsA("BasePart") then
					local nearbyParts = workspace:GetPartBoundsInRadius(part.Position, 1.5)
					for _, candidate in ipairs(nearbyParts) do
						if candidate and candidate ~= part and self:isValidWeldTarget(candidate) then
							validCandidate = true
							break
						end
					end

					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = {workspace.Terrain}
					rayParams.FilterType = Enum.RaycastFilterType.Include
					local ray = workspace:Raycast(part.Position, Vector3.new(0, -1.5, 0), rayParams)
					if ray then
						validCandidate = true
					end
					if validCandidate then break end
				end
			end
		end

		local canWeld = validCandidate and self.heldModel and CollectionService:HasTag(self.heldModel, "_Item") and (not self:isModelWelded(self.heldModel))
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
		local isWeldedItem = targetModel and CollectionService:HasTag(targetModel, "_Item") and self:isModelWelded(targetModel)
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
		elseif ((not isWeldedItem) or (not isWithinRange)) and self.unweldActionBound then
			ActionManager.unbindAction("Unweld")
			self.unweldActionBound = false
		end
	end

	function module:weld()
		if not self.heldModel then return end

		for _, part in ipairs(self.heldModel:GetDescendants()) do
			if part:IsA("BasePart") then
				local nearbyParts = workspace:GetPartBoundsInRadius(part.Position, 1.5)
				for _, candidate in ipairs(nearbyParts) do
					if candidate and not candidate:IsDescendantOf(self.heldModel) and self:isValidWeldTarget(candidate) then
						local weld = Instance.new("WeldConstraint")
						weld.Name = "NewWeld"
						weld.Part0 = part
						weld.Part1 = candidate
						weld.Parent = part
						candidate.Anchored = true
					end
				end

				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {workspace.Terrain}
				rayParams.FilterType = Enum.RaycastFilterType.Include
				local ray = workspace:Raycast(part.Position, Vector3.new(0, -10, 0), rayParams)
				if ray then
					part.Anchored = true
				end
			end
		end

		self.heldModel:SetAttribute("IsWelded", true)
		if self.actionBound then
			ActionManager.unbindAction("Weld")
			self.actionBound = false
		end
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

		model:SetAttribute("IsWelded", false)
		self:updateWeldActions(nil, model)
	end

	function module:destroy()
		if self.actionBound then
			ActionManager.unbindAction("Weld")
		end
		if self.unweldActionBound then
			ActionManager.unbindAction("Unweld")
		end
	end

	return module
end

return WeldModule
