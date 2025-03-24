-- HighlightModule.lua
local CollectionService = game:GetService("CollectionService")

local HighlightModule = {}

function HighlightModule.new()
	local module = {
		currentHighlightedModel = nil,
		hoverHighlight = nil,
		heldHighlight = nil
	}

	function module:updateHoverHighlight(target, humanoidRootPart) -- Add humanoidRootPart parameter
		local newModel = nil

		if target and humanoidRootPart then
			newModel = target:FindFirstAncestorWhichIsA("Model")
			if newModel and CollectionService:HasTag(newModel, "_Item") then
				-- Check if the object is within 20 studs
				local distance = (humanoidRootPart.Position - target.Position).Magnitude
				if distance > 20 then
					newModel = nil -- Do not highlight if out of range
				end
			else
				newModel = nil
			end
		end

		if newModel ~= self.currentHighlightedModel then
			if self.hoverHighlight then
				self.hoverHighlight:Destroy()
				self.hoverHighlight = nil
			end

			self.currentHighlightedModel = newModel
			if self.currentHighlightedModel then
				self.hoverHighlight = Instance.new("Highlight")
				self.hoverHighlight.FillTransparency = 1
				self.hoverHighlight.Parent = self.currentHighlightedModel
			end
		end
	end

	function module:createHeldHighlight(model)
		if self.heldHighlight then
			self.heldHighlight:Destroy()
		end

		self.heldHighlight = Instance.new("Highlight")
		self.heldHighlight.FillTransparency = 1
		self.heldHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		self.heldHighlight.Parent = model
	end

	function module:clearHighlights()
		if self.hoverHighlight then
			self.hoverHighlight:Destroy()
			self.hoverHighlight = nil
		end
		if self.heldHighlight then
			self.heldHighlight:Destroy()
			self.heldHighlight = nil
		end
		self.currentHighlightedModel = nil
	end

	return module
end

return HighlightModule
