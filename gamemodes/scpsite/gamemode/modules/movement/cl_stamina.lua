--[[
	Одышка: после «выдоха» и при низкой выносливости — тяжёлое дыхание (звуки D-9341 из SCP:CB).
]]

local nextBreath = 0

hook.Add("Think", "scp.stamina.breath", function()
	local me = LocalPlayer()
	if not IsValid(me) or not me:InGame() or not me:Alive() then return end
	local st = SCP.Stamina.Get(me)
	if st > 45 and not SCP.Stamina.Exhausted(me) then return end
	if RealTime() < nextBreath then return end
	local level = SCP.Stamina.Exhausted(me) and 0 or (st < 25 and 1 or 2)
	surface.PlaySound("scpsite/breath/breath" .. math.random(0, 4) .. ".mp3")
	nextBreath = RealTime() + ({ 1.4, 2.0, 2.8 })[level + 1]
end)
