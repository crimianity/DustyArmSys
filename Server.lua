--[[
    Last updated: 2025-03-23 19:13:16 UTC
    Author: crimianity
    
    Server-side handling for Item Grab System with Welding and Tool Equip functionality.
    Handles normal grab/release, welding/unwelding, and now tool equipping, which deletes the _Tool model.
--]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local network           = script.Parent.Network

local character         = script:FindFirstAncestorWhichIsA("Model")
local humanoidRootPart  = character:WaitForChild("HumanoidRootPart")
local humanoid          = character:WaitForChild("Humanoid")
local player            = Players:GetPlayerFromCharacter(character)
local currentObject     = nil

local range = script.Parent.Range.Value

function canSetNetworkOwnership(part)
	-- Don't change network ownership of welded parts
	if part:FindFirstChild("NewWeld") then
		return false
	end

	-- Reject anchored parts
	if part.Anchored then 
		return false 
	end

	-- We only allow network ownership change for parts that are part of a model tagged with _Item.
	local model = part:FindFirstAncestorWhichIsA("Model")
	if model then
		-- Exclude player characters by checking if the model contains a Humanoid.
		if model:FindFirstChildWhichIsA("Humanoid") then
			return false
		end
		-- Only allow if the model is tagged with _Item and is in the workspace.
		if CollectionService:HasTag(model, "_Item") then
			return part:IsDescendantOf(workspace)
		end
	end
	return false 
end

function isWithinRange(object)
	return (object.Position - humanoidRootPart.Position).Magnitude < ((range * 1.25) + 5)    
end

function handleWeldState(model, action)
	if not model then return end

	if action == "weld" then
		model:SetAttribute("IsWelded", true)
	elseif action == "unweld" then
		model:SetAttribute("IsWelded", false)
		-- Reset network ownership for all parts
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				if part:IsDescendantOf(workspace) then
					part:SetNetworkOwnershipAuto()
				end
			end
		end
	end
end

local conn = network.OnServerEvent:Connect(function(firer, object, action)
	if firer ~= player then return end

	-- Handle tool equip request.
	if action == "equipTool" then
		if object and object:IsA("Model") then
			-- Destroying the model on the server replicates the deletion to all clients.
			object:Destroy()
		end
		return
	end

	if typeof(object) == "Instance" then
		if action == "weld" or action == "unweld" then
			-- Handle weld/unweld states
			if CollectionService:HasTag(object, "_Item") then
				handleWeldState(object, action)
			end
		else
			-- Handle normal grab/release.
			if currentObject then
				if currentObject:IsDescendantOf(workspace) then
					currentObject:SetNetworkOwnershipAuto()
				end
			end
			currentObject = nil

			if object and object:IsA("BasePart") and isWithinRange(object) and canSetNetworkOwnership(object) then
				currentObject = object
				currentObject:SetNetworkOwner(player)
			end
		end
	end
end)

local dstCheck = RunService.Heartbeat:Connect(function()
	if currentObject and (not isWithinRange(currentObject) or (not currentObject:IsDescendantOf(workspace))) then
		if currentObject:IsDescendantOf(workspace) then
			currentObject:SetNetworkOwnershipAuto()
		end
		currentObject = nil
	end
end)

humanoid.Died:Connect(function()
	conn:Disconnect()
	dstCheck:Disconnect()
	if currentObject and currentObject:IsDescendantOf(workspace) then
		currentObject:SetNetworkOwnershipAuto()
	end
end)
