--[[
	=====================================================================
	  Basketball Legends — court geometry dump
	=====================================================================
	  WHY: 3PT rage teleport keeps landing just out of bounds (behind the
	  hoop / past the white lines). The script has been GUESSING the court
	  shape from a Bounds box that turns out to be bigger than the painted
	  court. This prints the real geometry so the bounds check can be built
	  from fact: the exact size and position of every part on the court you
	  are standing on, which part is the floor under you, and where the
	  hoop / 2PT zone / Bounds sit relative to it.

	  Read-only. Nothing is fired or changed.

	  USE:
	    1. STAND ON THE COURT you'd shoot 3s on (in a match or practice).
	    2. Run this.
	    3. Send BBL_CourtDump.txt.
	=====================================================================
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local function save()
	local body = table.concat(out, "\n")
	if typeof(writefile) == "function" then pcall(function() writefile("BBL_CourtDump.txt", body) end) end
	if typeof(setclipboard) == "function" then pcall(function() setclipboard(body) end) end
end

local function v3(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end

-- size + world position of a part or a model (bounding box for models)
local function extent(inst)
	if inst:IsA("BasePart") then
		return inst.Size, inst.Position
	end
	local ok, cf, size = pcall(function() return inst:GetBoundingBox() end)
	if ok and cf then return size, cf.Position end
	return nil, nil
end

w("Basketball Legends court dump — " .. os.date("!%H:%M:%S") .. " UTC")

local myc = LocalPlayer.Character
local hrp = myc and myc:FindFirstChild("HumanoidRootPart")
if not hrp then w("no character/HumanoidRootPart — spawn in first"); save(); return end
w("you are at " .. v3(hrp.Position))
w("attributes: Court=" .. tostring(LocalPlayer:GetAttribute("Court"))
	.. "  Team=" .. tostring(LocalPlayer:GetAttribute("Team")))

-- ── the floor directly under you ──────────────────────────────────────
-- this part IS the court surface; the 3PT bounds should be its top-face
-- rectangle, and "same part" is how we tell on-court from off-court.
hdr("FLOOR UNDER YOU")
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { myc }
local floorHit = Workspace:Raycast(hrp.Position + Vector3.new(0, 3, 0), Vector3.new(0, -18, 0), rp)
if floorHit then
	local f = floorHit.Instance
	w("part: " .. f:GetFullName())
	w("class: " .. f.ClassName .. "  size: " .. v3(f.Size) .. "  pos: " .. v3(f.Position))
	w("material: " .. tostring(f.Material) .. "  anchored: " .. tostring(f.Anchored))
	w("top Y: " .. ("%.1f"):format(floorHit.Position.Y))
else
	w("no floor hit under you")
end

-- ── which court are you on ────────────────────────────────────────────
local courts = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Courts")
local myCourt, bestD = nil, math.huge
if courts then
	for _, c in ipairs(courts:GetChildren()) do
		local ok, piv = pcall(function() return c:GetPivot().Position end)
		if ok then
			local d = (piv - hrp.Position).Magnitude
			if d < bestD then myCourt, bestD = c, d end
		end
	end
end

if not myCourt then w(""); w("no court found near you"); save(); return end

hdr("NEAREST COURT: " .. myCourt.Name .. "  (" .. ("%.1f"):format(bestD) .. " studs to pivot)")
local okp, piv = pcall(function() return myCourt:GetPivot().Position end)
if okp then w("pivot: " .. v3(piv)) end

-- every child, with size + position, so the real playable rectangle is visible
hdr("COURT CHILDREN (name | class | size | pos)")
for _, d in ipairs(myCourt:GetChildren()) do
	local size, pos = extent(d)
	w(("%-22s | %-14s | %s | %s"):format(
		d.Name, d.ClassName,
		size and v3(size) or "?", pos and v3(pos) or "?"))
end

-- the parts the bounds code specifically leans on
hdr("KEY MODELS (Bounds / 2PT / Basket variants)")
for _, name in ipairs({ "Bounds", "2PT", "Home2PT", "Away2PT", "Basket", "HomeBasket", "AwayBasket", "Rack" }) do
	local m = myCourt:FindFirstChild(name)
	if m then
		local size, pos = extent(m)
		w(("%-12s FOUND  size=%s pos=%s"):format(name, size and v3(size) or "?", pos and v3(pos) or "?"))
	else
		w(("%-12s missing"):format(name))
	end
end

-- descendants that look like the boundary line / floor, in case the real
-- court rectangle is a nested part rather than a top-level child
hdr("LINE / FLOOR / COURT-LIKE DESCENDANTS")
local pat = { "line", "floor", "court", "ground", "baseline", "boundary", "outline" }
local n = 0
for _, d in ipairs(myCourt:GetDescendants()) do
	if d:IsA("BasePart") then
		local low = d.Name:lower()
		for _, p in ipairs(pat) do
			if low:find(p, 1, true) then
				n = n + 1
				if n <= 40 then
					w(("%s | size=%s pos=%s"):format(d:GetFullName(), v3(d.Size), v3(d.Position)))
				end
				break
			end
		end
	end
end
w("total line/floor-like: " .. n)

save()
warn("[courtdump] done — send BBL_CourtDump.txt (also on clipboard).")
