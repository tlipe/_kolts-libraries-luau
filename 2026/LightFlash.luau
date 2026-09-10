--!strict

return function(char: Model)
	local Lighting = game:GetService("Lighting")
	local self = {}

	self.OriginColorCorrect = Color3.fromRGB(255, 255, 255) :: Color3

	if char then
		self.Character = char
	else
		error("[ERROR] Character is nil or invalid")
	end

	function self:flash(timeout: number?) : ()
		local character: Model = self.Character

		local HightNew = character:FindFirstChildOfClass("Highlight") or Instance.new("Highlight", self.Character)
		HightNew.FillColor = Color3.fromRGB(255, 255, 255)
		HightNew.OutlineColor = Color3.fromRGB(255, 255, 255)
		HightNew.FillTransparency = 0
		HightNew.Enabled = false
		
		local ColorCorrect: ColorCorrectionEffect = (Lighting:FindFirstChild("ColorCorrection") :: ColorCorrectionEffect) or Instance.new("ColorCorrectionEffect", Lighting)
		ColorCorrect.Name = "ColorCorrection"
		ColorCorrect.Brightness = 0
		ColorCorrect.Contrast = 0
		ColorCorrect.Saturation = 0
		ColorCorrect.TintColor = Color3.fromRGB(255, 255, 255)

		HightNew.Enabled = true
		ColorCorrect.TintColor = Color3.new(0, 0, 0)

		task.wait(timeout or 0.1)

		HightNew.Enabled = false
		ColorCorrect.TintColor = (self.OriginColorCorrect :: Color3)
	end

	return self
end
