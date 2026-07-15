--[[
	=====================================================================
	  Basketball Legends — data layer dumper  (run 3)
	=====================================================================
	  Two things left to learn:
	    1. WHAT an inventory row / catalogue row actually contains. The last
	       dump printed "Conqueror=<tbl:5>" — the field COUNT, not the
	       fields. Without the schema an injected row can't match.
	    2. WHERE your live data is. The getgc Replica hunt found nothing,
	       so stop guessing: ReplicatedStorage.Controllers.DataController is
	       the game's OWN data API. Require it and read what it exposes.

	  require() on a shared module returns the table the game itself uses —
	  same object, not a copy.

	  READ-ONLY. No hookmetamethod, no hookfunction, no remote calls,
	  no writes.
	=====================================================================
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local n = 0
local function breathe()
	n = n + 1
	if n % 400 == 0 then task.wait() end
end

-- print a table properly, a few levels deep
local function dump(t, indent, depth, cap)
	depth = depth or 1
	cap = cap or 40
	if type(t) ~= "table" then w(indent .. tostring(t) .. "  <" .. type(t) .. ">") return end
	if depth > 4 then w(indent .. "...") return end
	local i = 0
	for k, v in pairs(t) do
		breathe()
		i = i + 1
		if i > cap then w(indent .. "... (more)") return end
		if type(v) == "table" then
			local c = 0
			for _ in pairs(v) do c = c + 1 end
			w(("%s%s:  <table %d>"):format(indent, tostring(k), c))
			dump(v, indent .. "   ", depth + 1, cap)
		else
			w(("%s%s = %s  <%s>"):format(indent, tostring(k), tostring(v), type(v)))
		end
	end
end

w("Basketball Legends data dump — " .. os.date("!%Y-%m-%d %H:%M:%S") .. " UTC")

-- ── 1. ROW SCHEMA: what is actually inside a catalogue entry ──────────
hdr("CATALOGUE ROW SCHEMA")
pcall(function()
	local items = require(RS.Modules.Items)
	-- one real example from each category we care about, printed WHOLE
	local picks = {
		{ "Skins", "Conqueror" }, { "Skins", "Royalty" }, { "Skins", "Default" },
		{ "Effects", "Helios" }, { "Effects", "Default" },
		{ "Emotes", "Griddy" }, { "Banners", "Default" }, { "Dunks", "Default" },
	}
	for _, p in ipairs(picks) do
		local cat, name = p[1], p[2]
		local row = items[cat] and items[cat][name]
		if row then
			w("")
			w(("--- Items.%s.%s ---"):format(cat, name))
			dump(row, "  ", 1, 60)
		else
			w(("Items.%s.%s : not found"):format(cat, name))
		end
	end

	-- how many of each, so we know the shape of the whole thing
	w("")
	for cat, tbl in pairs(items) do
		if type(tbl) == "table" then
			local c = 0
			for _ in pairs(tbl) do c = c + 1 end
			w(("%-12s %d entries"):format(cat, c))
		end
	end
end)

-- ── 2. THE GAME'S OWN DATA API ────────────────────────────────────────
hdr("Controllers.DataController")
pcall(function()
	local dc = RS:FindFirstChild("Controllers") and RS.Controllers:FindFirstChild("DataController")
	if not dc then w("not found") return end
	local ok, mod = pcall(require, dc)
	if not ok then w("require failed: " .. tostring(mod)) return end
	w("type: " .. type(mod))
	if type(mod) == "table" then
		for k, v in pairs(mod) do
			breathe()
			if type(v) == "table" then
				local c = 0
				for _ in pairs(v) do c = c + 1 end
				w(("%-26s <table %d>"):format(tostring(k), c))
			else
				w(("%-26s %s  <%s>"):format(tostring(k), tostring(v), type(v)))
			end
		end
		-- anything that smells like the live profile gets opened up
		for _, key in ipairs({ "Data", "data", "Replica", "replica", "Profile", "profile", "Cache" }) do
			local v = rawget(mod, key)
			if type(v) == "table" then
				w("")
				w("--- DataController." .. key .. " ---")
				dump(v, "  ", 1, 60)
			end
		end
	end
end)

-- ── 3. ReplicaController: ask it, don't hunt for it ───────────────────
hdr("ReplicaController")
pcall(function()
	local rc = RS.Packages:FindFirstChild("ReplicaController")
	if not rc then w("not found") return end
	local ok, RC = pcall(require, rc)
	if not ok then w("require failed: " .. tostring(RC)) return end

	w("exposed keys:")
	for k, v in pairs(RC) do w(("  %-30s <%s>"):format(tostring(k), type(v))) end

	-- ReplicaOfClassCreated fires for replicas that ALREADY exist as well as
	-- new ones, so this catches our live data without needing its id.
	if type(RC.ReplicaOfClassCreated) == "function" then
		local classes = { "PlayerData", "PlayerProfile", "Data", "Profile", "PlayerReplica" }
		for _, cls in ipairs(classes) do
			pcall(function()
				RC.ReplicaOfClassCreated(cls, function(replica)
					w("")
					w("--- Replica class '" .. cls .. "' ---")
					pcall(function() w("  Id = " .. tostring(replica.Id)) end)
					pcall(function() dump(replica.Data, "  ", 1, 60) end)
				end)
			end)
		end
		task.wait(2)   -- give the listeners a moment to fire
	end
end)

-- ── 4. last resort: getgc, matched loosely ────────────────────────────
hdr("getgc — tables holding a Skins/Effects map")
pcall(function()
	if typeof(getgc) ~= "function" then w("no getgc") return end
	local seen, found = {}, 0
	for _, o in ipairs(getgc(true)) do
		breathe()
		if type(o) == "table" and not seen[o] then
			seen[o] = true
			-- your live inventory must contain per-category tables
			local sk, ef = rawget(o, "Skins"), rawget(o, "Effects")
			if type(sk) == "table" and type(ef) == "table" then
				found = found + 1
				w("")
				w("--- candidate #" .. found .. " ---")
				dump(o, "  ", 1, 25)
				if found >= 4 then break end
			end
		end
	end
	if found == 0 then w("none") end
end)

local body = table.concat(out, "\n")
if typeof(writefile) == "function" then
	pcall(function() writefile("BBL_DataDump.txt", body) end)
	warn("[dump] wrote BBL_DataDump.txt (" .. #body .. " bytes)")
end
if typeof(setclipboard) == "function" then
	pcall(function() setclipboard(body) end)
	warn("[dump] copied to clipboard")
end
