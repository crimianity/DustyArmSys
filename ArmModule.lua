-- ArmModule.lua
local TweenService = game:GetService("TweenService")

local ArmModule = {}

function ArmModule.new(character)
	local CurrentCamera = game.Workspace.CurrentCamera

	-- Create arm instance
	local RightArm = game.ReplicatedStorage.RArm:Clone()
	RightArm.Parent = CurrentCamera
	RightArm.PrimaryPart.Transparency = 1

	-- Copy character appearance
	if character:FindFirstChildOfClass("Shirt") then
		character:FindFirstChildOfClass("Shirt"):Clone().Parent = RightArm
	end

	if character:FindFirstChildOfClass("BodyColors") then
		character:FindFirstChildOfClass("BodyColors"):Clone().Parent = RightArm
	end

	local armScale = 1
	local baseArmLength = 5 -- Base length of the arm (adjust as needed)

	local module = {
		arm = RightArm,
		armScale = armScale,
		baseArmLength = baseArmLength,
		updateConnection = nil
	}

	function module:scaleArm(scale)
		for _, part in ipairs(self.arm:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * Vector3.new(1, scale/self.armScale, 1)
			end
		end
		self.armScale = scale
	end

	function module:showArm()
		TweenService:Create(self.arm.PrimaryPart, TweenInfo.new(0.075), {Transparency = 0}):Play()
	end

	function module:hideArm()
		TweenService:Create(self.arm.PrimaryPart, TweenInfo.new(0.075), {Transparency = 1}):Play()
	end

	function module:updateArmPosition(object, humanoidRootPart, camera, mouse)
		if not object or not object:FindFirstChild("ArmAttachment") then return end

		-- Get the ArmAttachment's world position
		local armAttachment = object.ArmAttachment
		local attachmentWorldPos = armAttachment.WorldPosition

		-- Calculate the arm's start position (relative to the camera)
		local cameraCF = camera.CFrame
		local armStartPos = cameraCF.Position + cameraCF.RightVector * 1 + cameraCF.UpVector * -1.5 + cameraCF.LookVector * -1

		-- Calculate the distance between the arm's start position and the ArmAttachment
		local distance = (attachmentWorldPos - armStartPos).Magnitude

		-- Calculate the required scale for the arm to reach the ArmAttachment
		local requiredScale = distance / self.baseArmLength
		self:scaleArm(requiredScale)

		-- Position the arm so it touches the ArmAttachment
		local toAttachment = (attachmentWorldPos - armStartPos).Unit
		local armCF = CFrame.new(armStartPos, attachmentWorldPos)
		self.arm:SetPrimaryPartCFrame(armCF * CFrame.Angles(math.rad(90), math.rad(90), 0))
	end

	function module:destroy()
		if self.updateConnection then
			self.updateConnection:Disconnect()
		end
		self.arm:Destroy()
	end

	return module
end

return ArmModule
