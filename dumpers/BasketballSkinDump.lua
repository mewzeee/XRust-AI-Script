--[[
	=====================================================================
	  Basketball Legends — skin / effect dumper
	=====================================================================
	  Run this, then open your Inventory and EQUIP an effect and a skin.
	  It writes BBL_SkinDump.txt next to your executor and prints a summary.

	  READ-ONLY. It only looks at instances, attributes and remote NAMES.
	  It does NOT hook __namecall or anything else — that is what got the
	  Lost Front account shadow-punished (0 damage while the script ran).
	  Nothing here touches the metatable.

	  What it's hunting, and why:
	   1. Effect/skin TEMPLATES — the game has to store the VFX somewhere
	      (usually ReplicatedStorage) to clone onto the ball. If they're
	      plain instances, a client-side changer is just: clone the one you
	      want onto the ball yourself.
	   2. Your EQUIPPED value — an attribute/StringValue on the player or
	      leaderstats saying which effect is active. If the game reads that
	      client-side to decide what to render, changing it locally may be
	      enough (visible to you only).
	   3. The REMOTE that equips — tells us whether the server owns the
	      decision. If it does, a client-side change is cosmetic-for-you and
	      nothing more.
	   4. What actually appears ON the ball when an effect is equipped —
	      the ground truth. Whatever gets parented to the ball IS the effect.
	=====================================================================
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local function path(inst)
	local ok, p = pcall(function() return inst:GetFullName() end)
	return ok and p or tostring(inst)
end

w("Basketball Legends dump — " .. os.date("!%Y-%m-%d %H:%M:%S") .. " UTC")
w("place: " .. tostring(game.PlaceId))

-- ── 1. anything that smells like an effect/skin library ────────────────
hdr("TEMPLATE FOLDERS (ReplicatedStorage)")
local WORDS = { "effect", "skin", "cosmetic", "item", "trail", "particle", "vfx", "aura", "ball" }
local function looksRelevant(n)
	n = n:lower()
	for _, k in ipairs(WORDS) do if n:find(k, 1, true) then return true end end
	return false
end

local seen = 0
for _, d in ipairs(RS:GetDescendants()) do
	if looksRelevant(d.Name) and (d:IsA("Folder") or d:IsA("Model") or d:IsA("Configuration")) then
		local kids = d:GetChildren()
		w(("%-70s  %-14s  %d children"):format(path(d), d.ClassName, #kids))
		-- list the children: these are usually the actual effect names
		for i, k in ipairs(kids) do
			if i > 25 then w("      ... +" .. (#kids - 25) .. " more"); break end
			w("      - " .. k.Name .. "  <" .. k.ClassName .. ">")
		end
		seen = seen + 1
		if seen > 12 then w("(stopping after 12 folders)"); break end
	end
end
if seen == 0 then w("none found in ReplicatedStorage — try StarterPlayer / workspace") end

-- ── 2. what the game thinks you have equipped ─────────────────────────
hdr("YOUR EQUIPPED STATE")
local function dumpAttrs(inst, label)
	local ok, attrs = pcall(function() return inst:GetAttributes() end)
	if ok and attrs then
		for k, v in pairs(attrs) do
			w(("%-24s attr  %-28s = %s"):format(label, k, tostring(v)))
		end
	end
	for _, d in ipairs(inst:GetChildren()) do
		if d:IsA("ValueBase") then
			w(("%-24s value %-28s = %s"):format(label, d.Name, tostring(d.Value)))
		end
	end
end
dumpAttrs(LocalPlayer, "Player")
local ls = LocalPlayer:FindFirstChild("leaderstats")
if ls then dumpAttrs(ls, "leaderstats") end
for _, d in ipairs(LocalPlayer:GetDescendants()) do
	if d:IsA("ValueBase") and looksRelevant(d.Name) then
		w(("Player descendant  %-40s = %s"):format(path(d), tostring(d.Value)))
	end
end

-- ── 3. remotes (names + parent only — nothing is called or hooked) ────
hdr("REMOTES THAT LOOK COSMETIC")
for _, d in ipairs(game:GetDescendants()) do
	if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and looksRelevant(d.Name) then
		w(("%-16s %s"):format(d.ClassName, path(d)))
	end
end

-- ── 4. ground truth: what is actually parented to the ball ────────────
hdr("LIVE BALL CONTENTS  (equip an effect, then watch this)")
local function findBall()
	local c = LocalPlayer.Character
	local held = c and c:FindFirstChild("Basketball")
	if held then return held end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Basketball" then return d end
	end
end

local ball = findBall()
if not ball then
	w("no basketball found — grab one and run again")
else
	w("ball: " .. path(ball) .. "  <" .. ball.ClassName .. ">")
	if ball:IsA("BasePart") then
		w(("  Color=%s  Material=%s  Transparency=%.2f"):format(tostring(ball.Color), tostring(ball.Material), ball.Transparency))
	end
	dumpAttrs(ball, "Ball")
	for _, d in ipairs(ball:GetDescendants()) do
		local extra = ""
		if d:IsA("SpecialMesh") or d:IsA("MeshPart") then
			extra = "  MeshId=" .. tostring(d.MeshId) .. "  TextureId=" .. tostring(d.TextureId or d.TextureID)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			extra = "  Texture=" .. tostring(d.Texture)
		elseif d:IsA("ParticleEmitter") then
			extra = "  Texture=" .. tostring(d.Texture)
		end
		w(("  %-30s <%s>%s"):format(d.Name, d.ClassName, extra))
	end
end

-- ── write it out ──────────────────────────────────────────────────────
local body = table.concat(out, "\n")
if typeof(writefile) == "function" then
	pcall(function() writefile("BBL_SkinDump.txt", body) end)
	warn("[dump] wrote BBL_SkinDump.txt (" .. #body .. " bytes)")
else
	warn("[dump] no writefile — copy the console output instead")
end
if typeof(setclipboard) == "function" then
	pcall(function() setclipboard(body) end)
	warn("[dump] copied to clipboard")
end
