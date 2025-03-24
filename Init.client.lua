--[[
    Last updated: 2025-03-24 02:37:47 UTC
    Author: crimianity
    
    Item Grab System Main Local Script
--]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

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

-- Initialize modules
local armModule = ArmModule.new(character)
local highlightModule = HighlightModule.new()
local grabModule = GrabModule.new(MAX_FORCE, MAX_RANGE, humanoidRootPart)
local weldModule = WeldModule.new(humanoidRootPart) -- Pass humanoidRootPart here

-- Mouse movement handler
mouse.Move:Connect(function()
	if not grabModule.object then -- Only update highlight when not holding object
		highlightModule:updateHoverHighlight(mouse.Target, humanoidRootPart)
		grabModule:updateGrabAction(mouse.Target) -- Update grab action visibility
		weldModule:updateWeldActions(mouse.Target, nil) -- Update weld/unweld action visibility
	else
		weldModule:updateWeldActions(mouse.Target, grabModule.object) -- Update with held object
	end
end)

-- Mouse wheel handlers
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

-- Set up grab callbacks
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

			-- Show the arm and start updating its position
			armModule:showArm()
			network:FireServer(grabModule.object)

			-- Set up render stepped connection for position updates
			grabModule.grabConnection = RunService.RenderStepped:Connect(function()
				if grabModule.object and grabModule.object:FindFirstChild("ArmAttachment") then
					grabModule:updateGrabPosition(humanoidRootPart, mouse)

					-- Update arm position and scale to keep it connected to the ArmAttachment
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

-- Clean up on death
humanoid.Died:Connect(function()
	grabModule:destroy() -- This will handle unbinding the grab action
	grabModule:release()
	highlightModule:clearHighlights()
	armModule:destroy()
	weldModule:destroy() -- This will handle unbinding both weld and unweld actions
end)
