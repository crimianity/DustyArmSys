-- GrabModule.lua
-- Last updated: 2025-03-24 00:22:50 UTC
-- Author: crimianity

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ActionManager = require(game.ReplicatedStorage.ActionManager)

local GrabModule = {}

-- Added optional parameter "isMobile" (default false) to support mobile control flow.
function GrabModule.new(maxForce, maxRange, humanoidRootPart, isMobile)
	local module = {
		object = nil,
		distance = 0,
		grabConnection = nil,
		grabForce = nil,
		onGrabStarted = nil,
		onGrabEnded = nil,
		actionBound = false,
		humanoidRootPart = humanoidRootPart, -- Store humanoidRootPart in the module
		isMobile = isMobile or false  -- flag indicating whether mobile control is active
	}

	local function grabActionHandler(action, inputState, inputObject)
		if action == "Grab" then
			if inputState == Enum.UserInputState.Begin then
				if module.onGrabBegan then
					module.onGrabBegan()
				end
			elseif inputState == Enum.UserInputState.End then
				-- Instead of calling onGrabEnded directly, we'll just call release
				module:release()
			end
		end
	end

	-- In mobile mode we do not bind the computer grab action.
	function module:updateGrabAction(target)
		if self.isMobile then
			return
		end

		local isValidTarget = false
		if target and self.humanoidRootPart then -- Check if humanoidRootPart exists
			local model = target:FindFirstAncestorWhichIsA("Model")
			local distance = (self.humanoidRootPart.Position - target.Position).Magnitude
			isValidTarget = model and CollectionService:HasTag(model, "_Item") and distance <= 20
		end

		if isValidTarget and not self.actionBound then
			-- Bind the grab action with the ActionManager
			ActionManager.bindAction(
				"Grab",
				grabActionHandler,
				Enum.UserInputType.MouseButton1, -- Keyboard/Mouse input
				Enum.KeyCode.ButtonR2,  -- Gamepad input
				0  -- Display order
			)
			self.actionBound = true
		elseif not isValidTarget and self.actionBound then
			ActionManager.unbindAction("Grab")
			self.actionBound = false
		end
	end

	function module:grab(target, humanoidRootPart)
		if self.grabConnection then
			self.grabConnection:Disconnect()
		end

		self.object = target
		if self.object then
			local model = self.object:FindFirstAncestorWhichIsA("Model")
			if not (model and CollectionService:HasTag(model, "_Item")) then
				return
			end

			self.distance = (humanoidRootPart.Position - self.object.Position).Magnitude
			if self.distance <= 20 then  -- Ensure the object is within 20 studs
				-- Create grab force with exact same properties as original
				self.grabForce = Instance.new("BodyPosition")
				self.grabForce.MaxForce = Vector3.new(maxForce, maxForce, maxForce)
				self.grabForce.P = self.grabForce.P -- Keep default P value
				self.grabForce.D = 550
				self.grabForce.Parent = self.object

				if not self.object:FindFirstChild("ArmAttachment") then
					local attachment = Instance.new("Attachment")
					attachment.Name = "ArmAttachment"
					attachment.Parent = self.object
				end

				if self.onGrabStarted then
					self.onGrabStarted(self.object)
				end
			else
				-- Optionally, you can add a message or feedback to the player indicating the object is too far away.
				warn("Object is too far away to grab.")
			end
		end
	end

	function module:updateGrabPosition(humanoidRootPart, inputSource)
		-- inputSource is expected to have a Hit property with a Position field.
		if self.object and self.grabForce then
			-- Exactly match the original position calculation.
			local cf = CFrame.new(humanoidRootPart.Position, inputSource.Hit.Position)
			self.grabForce.Position = cf.Position + cf.LookVector * self.distance
		end
	end

	function module:release()
		if self.grabConnection then
			self.grabConnection:Disconnect()
		end

		if self.grabForce then
			self.grabForce:Destroy()
			self.grabForce = nil
		end

		-- Store the callback in a temporary variable
		local callback = self.onGrabEnded

		-- Clear object before calling callback to prevent recursion
		self.object = nil

		-- Call the callback if it exists
		if callback then
			callback()
		end
	end

	function module:updateDistance(delta)
		if self.object then
			self.distance = math.clamp(self.distance + delta, 5, 15)
			return self.distance / 3
		end
		return 1
	end

	function module:destroy()
		if self.actionBound then
			ActionManager.unbindAction("Grab")
			self.actionBound = false
		end
	end

	return module
end

return GrabModule
