--[[
	=====================================================================
	  Basketball Legends — auto-farmer recon
	=====================================================================
	  WHY: the farmer needs to know things the script has never mapped —
	  how you JOIN a 1v1 queue, how to tell someone is WAITING in one, and
	  how the game signals match START / SCORE / WIN. None of that is in
	  xRustBasketball.lua, the dumps, or the notes. This gathers it.

	  SAFE BY CONSTRUCTION: everything here READS or passively LISTENS.
	  There is NO FireServer anywhere — we never poke the server with a
	  guessed queue call, which is the one thing that could get an account
	  actioned. Run it, then manually do ONE 1v1 (walk to a pad, join,
	  play, win) while it watches, and send BBL_FarmRecon.txt.

	  USE:
	    1. Run this at the lobby / court select.
	    2. It prints the static map (remotes, pads, prompts, attributes).
	    3. Within 120s, manually JOIN a 1v1 and play a point.
	    4. Send BBL_FarmRecon.txt — it captures what fired as you did.
	=====================================================================
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local function save()
	local body = table.concat(out, "\n")
	if typeof(writefile) == "function" then pcall(function() writefile("BBL_FarmRecon.txt", body) end) end
	if typeof(setclipboard) == "function" then pcall(function() setclipboard(body) end) end
end

local function brief(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "Instance" then return ("<%s %s>"):format(v.ClassName, v:GetFullName()) end
	if t == "table" then
		if depth > 2 then return "<table ...>" end
		local parts, n = {}, 0
		for k, v2 in pairs(v) do
			n = n + 1
			if n > 10 then table.insert(parts, "...") break end
			table.insert(parts, tostring(k) .. "=" .. brief(v2, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	if t == "Vector3" or t == "CFrame" or t == "Color3" then return t .. "(" .. tostring(v) .. ")" end
	return tostring(v) .. " <" .. t .. ">"
end

w("Basketball Legends farm recon — " .. os.date("!%H:%M:%S") .. " UTC")
w("place " .. tostring(game.PlaceId) .. "  job " .. tostring(game.JobId))

-- ── 1. every Knit service remote, by name ─────────────────────────────
-- the queue/matchmaking call is almost certainly one of these; the name
-- (Queue/Play/Matchmake/Join/Ready/Challenge/Duel/1v1) is the tell.
hdr("KNIT SERVICE REMOTES")
local svc = RS:FindFirstChild("Packages")
	and RS.Packages:FindFirstChild("Knit")
	and RS.Packages.Knit:FindFirstChild("Services")
if svc then
	for _, s in ipairs(svc:GetChildren()) do
		local re = s:FindFirstChild("RE")
		local rf = s:FindFirstChild("RF")
		local names = {}
		if re then for _, r in ipairs(re:GetChildren()) do table.insert(names, "RE." .. r.Name) end end
		if rf then for _, r in ipairs(rf:GetChildren()) do table.insert(names, "RF." .. r.Name) end end
		if #names > 0 then
			table.sort(names)
			w(("%s: %s"):format(s.Name, table.concat(names, ", ")))
		end
	end
else
	w("no Knit services found")
end

-- ── 2. queue infrastructure in the world ──────────────────────────────
-- pads are usually a Part you touch or a ProximityPrompt you hold E on.
hdr("PROXIMITY PROMPTS (workspace)")
local prompts = 0
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		prompts = prompts + 1
		if prompts <= 40 then
			w(("%s | ActionText=%q ObjectText=%q"):format(
				d:GetFullName(), tostring(d.ActionText), tostring(d.ObjectText)))
		end
	end
end
w("total prompts: " .. prompts)

hdr("QUEUE-LIKE PARTS (name matches queue/join/play/pad/spot/duel/1v1)")
local pat = { "queue", "join", "play", "pad", "spot", "duel", "1v1", "wait", "ready", "match", "team" }
local qhits = 0
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("BasePart") or d:IsA("Model") then
		local low = d.Name:lower()
		for _, p in ipairs(pat) do
			if low:find(p, 1, true) then
				qhits = qhits + 1
				if qhits <= 60 then w(("%s <%s>"):format(d:GetFullName(), d.ClassName)) end
				break
			end
		end
	end
end
w("total queue-like: " .. qhits)

-- courts + who is where, so the farmer can pick a court with someone waiting
hdr("COURTS SNAPSHOT")
local courts = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Courts")
if courts then
	for i, c in ipairs(courts:GetChildren()) do
		local kids = {}
		for _, k in ipairs(c:GetChildren()) do table.insert(kids, k.Name) end
		table.sort(kids)
		w(("[%d] %s children: %s"):format(i, c.Name, table.concat(kids, ", ")))
	end
else
	w("Workspace.Game.Courts not found")
end

-- ── 3. player + attribute state ───────────────────────────────────────
-- match/queue state usually surfaces as attributes on the player.
hdr("LOCALPLAYER ATTRIBUTES")
local function dumpAttrs(inst, label)
	local a = inst:GetAttributes()
	local parts = {}
	for k, v in pairs(a) do table.insert(parts, k .. "=" .. tostring(v)) end
	table.sort(parts)
	w(("%s: %s"):format(label, #parts > 0 and table.concat(parts, ", ") or "(none)"))
end
dumpAttrs(LocalPlayer, "LocalPlayer")
w("Team=" .. tostring(LocalPlayer.Team) .. "  Neutral=" .. tostring(LocalPlayer.Neutral))

hdr("OTHER PLAYERS")
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		dumpAttrs(p, p.Name)
	end
end

-- ── 4. live watch: attributes + remote traffic while YOU queue ─────────
-- Passive listeners only. When you manually join and play, this records
-- the exact events and attribute flips that mark join / start / score /
-- win — that is the state machine the farmer will drive.
hdr("LIVE WATCH (120s) — go join a 1v1 and play a point NOW")
local hits = 0

-- attribute changes on the local player
LocalPlayer.AttributeChanged:Connect(function(name)
	hits = hits + 1
	w(("+%0.1fs attr %s -> %s"):format(os.clock(), name, tostring(LocalPlayer:GetAttribute(name))))
	if hits % 3 == 0 then save() end
end)
LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	hits = hits + 1
	w(("+%0.1fs Team -> %s"):format(os.clock(), tostring(LocalPlayer.Team)))
	save()
end)

-- passively listen on every service RE (incoming server->client only)
if svc then
	for _, s in ipairs(svc:GetChildren()) do
		local re = s:FindFirstChild("RE")
		if re then
			for _, r in ipairs(re:GetChildren()) do
				if r:IsA("RemoteEvent") then
					local sname, rname = s.Name, r.Name
					r.OnClientEvent:Connect(function(...)
						hits = hits + 1
						local args = table.pack(...)
						local parts = {}
						for i = 1, math.min(args.n, 6) do
							table.insert(parts, ("[%d]%s"):format(i, brief(args[i])))
						end
						w(("+%0.1fs %s.RE.%s (%d) %s"):format(
							os.clock(), sname, rname, args.n, table.concat(parts, " ")))
						if hits % 3 == 0 then save() end
					end)
				end
			end
		end
	end
end

save()
warn("[recon] static map written. WATCHING 120s — join a 1v1 and play a point.")
task.delay(120, function()
	w("")
	w("(recon finished — " .. hits .. " live events)")
	save()
	warn("[recon] done: " .. hits .. " events. BBL_FarmRecon.txt + clipboard.")
end)
