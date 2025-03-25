--[[
    Item Grab System Main Local Script
    Modified to:
    1. Properly handle Tool.CanBeDropped property
    2. Remove non-existent updateDropAction call
    3. Maintain all weld/grab functionality
--]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")

local ArmModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("ArmModule"))
local HighlightModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("HighlightModule"))
local GrabModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("GrabModule"))
local WeldModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("WeldModule"))
local ToolModule = require(game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("ToolModule"))
local ActionManager = require(game.ReplicatedStorage:WaitForChild("ActionManager"))

local player = Players.LocalPlayer
local character = script:FindFirstAncestorWhichIsA("Model")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local mouse = player:GetMouse()
local network = script.Parent:WaitForChild("Network")
local CurrentCamera = game.Workspace.CurrentCamera

local MAX_FORCE = script.Parent.Force.Value
local MAX_RANGE = 20

local isMobile = UserInputService.TouchEnabled

-- Initialize modules
local armModule = ArmModule.new(character)
local highlightModule = HighlightModule.new()
local grabModule = GrabModule.new(MAX_FORCE, MAX_RANGE, humanoidRootPart, isMobile)
local weldModule = WeldModule.new(humanoidRootPart)
local toolModule = ToolModule.new(player, isMobile)

local function prepareForGrab()
	humanoid:UnequipTools()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end

local function resetGuiAfterGrab()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
end

if not isMobile then
	-- Desktop behavior
	mouse.Move:Connect(function()
		-- Update tool hover state
		toolModule:updateHover(mouse.Target)

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

		prepareForGrab()

		local target = mouse.Target
		if target then
			grabModule:grab(target, humanoidRootPart)
			if grabModule.object then
				local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
				if model then
					highlightModule:createHeldHighlight(model)
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
		resetGuiAfterGrab()
	end
else
	-- Mobile behavior
	local mobileHolder = player:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("MobileHolder")
	local mobileGrabButton = mobileHolder:WaitForChild("GrabButton")
	local mobileDropButton = mobileHolder:WaitForChild("DropButton")
	local mobileEquipButton = mobileHolder:WaitForChild("EquipButton")
	local mobileDropToolButton = mobileHolder:WaitForChild("DropToolButton")
	local mobileFurtherButton = mobileHolder:WaitForChild("FurtherButton")
	local mobileCloserButton = mobileHolder:WaitForChild("CloserButton")
	local mobileWeldButton = mobileHolder:WaitForChild("WeldButton")
	local mobileUnweldButton = mobileHolder:WaitForChild("UnweldButton")

	-- Initialize all buttons as invisible
	for _, button in ipairs(mobileHolder:GetChildren()) do
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			button.Visible = false
		end
	end

	local mobileCurrentTarget = nil
	local furtherActive = false
	local closerActive = false

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {character}

	RunService.RenderStepped:Connect(function()
		local viewportSize = CurrentCamera.ViewportSize
		local centerX = viewportSize.X / 2
		local centerY = viewportSize.Y / 2
		local unitRay = CurrentCamera:ScreenPointToRay(centerX, centerY)
		local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, raycastParams)

		if raycastResult and raycastResult.Instance then
			local candidate = raycastResult.Instance
			toolModule:updateHover(candidate)

			local model = candidate:FindFirstAncestorWhichIsA("Model")
			if model and CollectionService:HasTag(model, "_Item") and not grabModule.object then
				mobileCurrentTarget = candidate
				mobileGrabButton.Visible = true
			else
				mobileCurrentTarget = nil
				mobileGrabButton.Visible = false
			end

			-- Tool equip button visibility
			mobileEquipButton.Visible = toolModule:getCurrentTool() ~= nil

			-- Tool drop button visibility
			local equippedTool = character:FindFirstChildWhichIsA("Tool")
			mobileDropToolButton.Visible = equippedTool and equippedTool.CanBeDropped

			-- Grabbed object drop button
			mobileDropButton.Visible = grabModule.object ~= nil
		else
			mobileCurrentTarget = nil
			mobileGrabButton.Visible = false
			mobileEquipButton.Visible = false
			mobileDropToolButton.Visible = false
			mobileDropButton.Visible = false
		end

		-- Update held object position and weld buttons
		if grabModule.object and grabModule.grabConnection then
			local centerHit = CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 20
			local mobileInput = { Hit = { Position = centerHit } }

			-- Handle distance adjustment
			local delta = (furtherActive and 0.5 or 0) + (closerActive and -0.5 or 0)
			if delta ~= 0 then
				armModule:scaleArm(grabModule:updateDistance(delta))
			end

			-- Update position
			grabModule:updateGrabPosition(humanoidRootPart, mobileInput)
			armModule:updateArmPosition(grabModule.object, humanoidRootPart, CurrentCamera, mobileInput)

			-- Update weld buttons
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				local isWelded = weldModule:isModelWelded(model)
				mobileWeldButton.Visible = not isWelded and weldModule:canWeldModel(model)
				mobileUnweldButton.Visible = isWelded
				mobileFurtherButton.Visible = true
				mobileCloserButton.Visible = true
			end
		else
			mobileWeldButton.Visible = false
			mobileUnweldButton.Visible = false
			mobileFurtherButton.Visible = false
			mobileCloserButton.Visible = false
		end
	end)

	-- Button connections
	mobileGrabButton.MouseButton1Click:Connect(function()
		if mobileCurrentTarget then
			if grabModule.grabConnection then grabModule.grabConnection:Disconnect() end

			prepareForGrab()
			grabModule:grab(mobileCurrentTarget, humanoidRootPart)

			if grabModule.object then
				local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
				if model then highlightModule:createHeldHighlight(model) end

				armModule:showArm()
				network:FireServer(grabModule.object)

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

	mobileEquipButton.MouseButton1Click:Connect(function()
		local toolModel = toolModule:getCurrentTool()
		if toolModel then
			toolModule:equipTool(toolModel)
			mobileEquipButton.Visible = false
		end
	end)

	mobileDropToolButton.MouseButton1Click:Connect(function()
		local tool = character:FindFirstChildWhichIsA("Tool")
		if tool and tool.CanBeDropped then
			tool.Parent = workspace
			local dropPosition = humanoidRootPart.Position
			if tool:FindFirstChild("Handle") then
				tool.Handle.CFrame = CFrame.new(dropPosition)
			elseif tool.PrimaryPart then
				tool:SetPrimaryPartCFrame(CFrame.new(dropPosition))
			end
			mobileDropToolButton.Visible = false
		end
		resetGuiAfterGrab()
	end)

	mobileDropButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			if grabModule.onGrabEnded then grabModule.onGrabEnded() end
			grabModule:release()
			mobileDropButton.Visible = false
		end
		resetGuiAfterGrab()
	end)

	mobileFurtherButton.MouseButton1Down:Connect(function() furtherActive = true end)
	mobileFurtherButton.MouseButton1Up:Connect(function() furtherActive = false end)
	mobileCloserButton.MouseButton1Down:Connect(function() closerActive = true end)
	mobileCloserButton.MouseButton1Up:Connect(function() closerActive = false end)

	mobileWeldButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				weldModule:weld()
				mobileWeldButton.Visible = false
			end
		end
	end)

	mobileUnweldButton.MouseButton1Click:Connect(function()
		if grabModule.object then
			local model = grabModule.object:FindFirstAncestorWhichIsA("Model")
			if model then
				weldModule:unweld(model)
				mobileUnweldButton.Visible = false
			end
		end
	end)

	grabModule.onGrabEnded = function()
		armModule:hideArm()
		highlightModule:clearHighlights()
		network:FireServer()
		resetGuiAfterGrab()
		for _, button in ipairs({mobileDropButton, mobileFurtherButton, mobileCloserButton, mobileWeldButton, mobileUnweldButton}) do
			button.Visible = false
		end
	end
end

humanoid.Died:Connect(function()
	grabModule:destroy()
	grabModule:release()
	highlightModule:clearHighlights()
	armModule:destroy()
	weldModule:destroy()
end)
