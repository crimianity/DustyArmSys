--[[
    Last updated: 2025-03-24 22:45:00 UTC
    Author: crimianity

    Item Grab System Main Local Script with Mobile Distance, Weld, and Unweld Controls
--]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local ArmModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("ArmModule"))
local HighlightModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("HighlightModule"))
local GrabModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("GrabModule"))
local WeldModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("WeldModule"))
local ActionManager = require(game.ReplicatedStorage:WaitForChild("ActionManager"))

local player = Players.LocalPlayer
local character = script:FindFirstAncestorWhichIsA("Model")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local mouse = player:GetMouse()
local network = script.Parent:WaitForChild("Network")
local CurrentCamera = game.Workspace.CurrentCamera

local MAX_FORCE = script.Parent.Force.Value
local MAX_RANGE = 20 -- Ensure the max range is set to 20 studs

-- Determine if the player is on a mobile device.
local isMobile = UserInputService.TouchEnabled

-- Initialize modules.
local armModule = ArmModule.new(character)
local highlightModule = HighlightModule.new()
local grabModule = GrabModule.new(MAX_FORCE, MAX_RANGE, humanoidRootPart, isMobile)
local weldModule = WeldModule.new(humanoidRootPart)

if not isMobile then
	-- Desktop behavior.
	mouse.Move:Connect(function()
		if not grabModule.object then
			highlightModule:updateHoverHighlight(mouse.Target, humanoidRootPart)
			grabModule:updateGrabAction(mouse.Target)
			weldModule:updateWeldActions(mouse.Target, nil)
		else
			weldModule:updateWeldActions(mouse.Target, grabModule.object)
		end
	end)

	mouse.WheelForward:Connect(function()
		if grabModule.object then
			local newScale = grabModule:updateDistance(0.5)
			armModule:scaleArm(newScale)
		end
	end)

	mouse.WheelBackward:Connect(function()
		if grabModule.object then
			local newScale = grabModule:updateDistance(-0.5)
			armModule:scaleArm(newScale)
		end
	end)

	grabModule.onGrabBegan = function()
		if grabModule.grabConnection then
			grabModule.grabConnection:Disconnect()
		end

		local target = mouse.Target
		if target then
			grabModule:grab(target, humanoidRootPart)
			if grabModule.object then
				local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
				if model then
					highlightModule:createHeldHighlight(model)
					weldModule:setupTouchConnections(model)
				end
				armModule:showArm()
				network:FireServer(grabModule.object)
				grabModule.grabConnection = RunService.RenderStepped:Connect(function()
					if grabModule.object and grabModule.object:FindFirstChild("ArmAttachment") then
						grabModule:updateGrabPosition(humanoidRootPart, mouse)
						armModule:updateArmPosition(grabModule.object, humanoidRootPart, CurrentCamera, mouse)
					end
				end)
			end
		end
	end

	grabModule.onGrabEnded = function()
		armModule:hideArm()
		highlightModule:clearHighlights()
		network:FireServer()
	end
else
	-- Mobile behavior.
	local mobileHolder = player:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("MobileHolder")
	local mobileGrabButton = mobileHolder:WaitForChild("GrabButton")
	local mobileDropButton = mobileHolder:WaitForChild("DropButton")
	local mobileFurtherButton = mobileHolder:WaitForChild("FurtherButton")
	local mobileCloserButton = mobileHolder:WaitForChild("CloserButton")
	local mobileWeldButton = mobileHolder:WaitForChild("WeldButton")
	local mobileUnweldButton = mobileHolder:WaitForChild("UnweldButton")

	mobileGrabButton.Visible = false
	mobileDropButton.Visible = false
	mobileFurtherButton.Visible = false
	mobileCloserButton.Visible = false
	mobileWeldButton.Visible = false
	mobileUnweldButton.Visible = false

	local mobileCurrentTarget = nil   -- current target under the center of the screen.

	-- Flags for distance adjustment.
	local furtherActive = false
	local closerActive = false

	-- Set up raycast parameters to ignore the player's character.
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {character}

	-- Update the center-screen target.
	RunService.RenderStepped:Connect(function()
		local viewportSize = CurrentCamera.ViewportSize
		local centerX = viewportSize.X / 2
		local centerY = viewportSize.Y / 2
		local unitRay = CurrentCamera:ScreenPointToRay(centerX, centerY)
		local rayOrigin = unitRay.Origin
		local rayDirection = unitRay.Direction * 500
		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		if raycastResult and raycastResult.Instance then
			local candidate = raycastResult.Instance
			local model = candidate:FindFirstAncestorWhichIsA("Model")
			-- Show GrabButton only if an _Item is under center and no object is held.
			if model and CollectionService:HasTag(model, "_Item") and not grabModule.object then
				mobileCurrentTarget = candidate
				mobileGrabButton.Visible = true
			else
				mobileCurrentTarget = nil
				mobileGrabButton.Visible = false
			end
		else
			mobileCurrentTarget = nil
			mobileGrabButton.Visible = false
		end

		-- If holding an item, update the arm position based on the center of the screen.
		if grabModule.object and grabModule.grabConnection then
			local centerHit = CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 20
			local mobileInput = { Hit = { Position = centerHit } }
			-- Adjust distance based on further/closer button status.
			local delta = 0
			if furtherActive then
				delta = delta + 0.5
			end
			if closerActive then
				delta = delta - 0.5
			end
			if delta ~= 0 then
				local newScale = grabModule:updateDistance(delta)
				armModule:scaleArm(newScale)
			end
			grabModule:updateGrabPosition(humanoidRootPart, mobileInput)
			armModule:updateArmPosition(grabModule.object, humanoidRootPart, CurrentCamera, mobileInput)

			-- Handle weld/unweld button visibility.
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				if weldModule:isModelWelded(model) then
					mobileUnweldButton.Visible = true
					mobileWeldButton.Visible = false
				elseif next(weldModule.touchingValidParts) ~= nil then
					mobileWeldButton.Visible = true
					mobileUnweldButton.Visible = false
				else
					mobileWeldButton.Visible = false
					mobileUnweldButton.Visible = false
				end
			end
		end
	end)

	-- Mobile Grab Button pressed.
	mobileGrabButton.MouseButton1Click:Connect(function()
		if mobileCurrentTarget then
			if grabModule.grabConnection then
				grabModule.grabConnection:Disconnect()
			end

			grabModule:grab(mobileCurrentTarget, humanoidRootPart)
			if grabModule.object then
				local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
				if model then
					highlightModule:createHeldHighlight(model)
					weldModule:setupTouchConnections(model)
				end
				armModule:showArm()
				network:FireServer(grabModule.object)
				mobileGrabButton.Visible = false
				mobileDropButton.Visible = true
				mobileFurtherButton.Visible = true
				mobileCloserButton.Visible = true
				-- Weld and Unweld buttons are managed in RenderStepped.

				grabModule.grabConnection = RunService.RenderStepped:Connect(function()
					if grabModule.object and grabModule.object:FindFirstChild("ArmAttachment") then
						local centerHit = CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 20
						local mobileInput = { Hit = { Position = centerHit } }
						grabModule:updateGrabPosition(humanoidRootPart, mobileInput)
						armModule:updateArmPosition(grabModule.object, humanoidRootPart, CurrentCamera, mobileInput)
					end
				end)
			end
		end
	end)

	-- Mobile Drop Button pressed.
	mobileDropButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			if grabModule.onGrabEnded then
				grabModule.onGrabEnded()
			end
			grabModule:release()
		end
		mobileDropButton.Visible = false
		mobileFurtherButton.Visible = false
		mobileCloserButton.Visible = false
		mobileWeldButton.Visible = false
		mobileUnweldButton.Visible = false
	end)

	-- Further button press events.
	mobileFurtherButton.MouseButton1Down:Connect(function()
		furtherActive = true
	end)
	mobileFurtherButton.MouseButton1Up:Connect(function()
		furtherActive = false
	end)

	-- Closer button press events.
	mobileCloserButton.MouseButton1Down:Connect(function()
		closerActive = true
	end)
	mobileCloserButton.MouseButton1Up:Connect(function()
		closerActive = false
	end)

	-- Weld Button pressed.
	mobileWeldButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				weldModule:weld()
				mobileWeldButton.Visible = false
			end
		end
	end)

	-- Unweld Button pressed.
	mobileUnweldButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				weldModule:unweld(model)
				mobileUnweldButton.Visible = false
			end
		end
	end)

	-- Ensure that if the player is holding an item, the GrabButton stays hidden.
	grabModule.onGrabEnded = function()
		armModule:hideArm()
		highlightModule:clearHighlights()
		network:FireServer()
		mobileDropButton.Visible = false
		mobileFurtherButton.Visible = false
		mobileCloserButton.Visible = false
		mobileWeldButton.Visible = false
		mobileUnweldButton.Visible = false
	end
end

-- Clean up on death.
humanoid.Died:Connect(function()
	grabModule:destroy()
	grabModule:release()
	highlightModule:clearHighlights()
	armModule:destroy()
	weldModule:destroy()
end)
