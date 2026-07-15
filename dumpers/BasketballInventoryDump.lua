--[[
	=====================================================================
	  Basketball Legends — client inventory cache dumper
	=====================================================================
	  Finds WHERE the client keeps your inventory + the item catalogue.

	  The "unlock all" trick is a client-side UI spoof: rows get pushed into
	  the table the inventory window reads from. The "Rarity: ??? / Item
	  Type: ???" in the screenshots is the giveaway — the injected rows have
	  no matching catalogue entry, so the UI can't resolve their metadata.

	  Run this WITH THE INVENTORY WINDOW OPEN, on the Skins tab.

	  READ-ONLY. getgc/debug inspection only — no hookmetamethod, no
	  hookfunction, no remote calls. (That is what got the Lost Front
	  account shadow-punished into 0 damage.)
	=====================================================================
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local scanned = 0
local function breathe()
	scanned = scanned + 1
	if scanned % 500 == 0 then task.wait() end
end

w("Basketball Legends inventory dump — " .. os.date("!%Y-%m-%d %H:%M:%S") .. " UTC")

-- ── 1. Knit controllers (client side — services were server-facing) ────
-- every section is pcall-wrapped: one failure must not cost us the whole dump
hdr("KNIT CONTROLLERS")
pcall(function()
local knit = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Knit")
local ctrls = knit and (knit:FindFirstChild("Controllers") or knit:FindFirstChild("Controller"))
if ctrls then
	for _, c in ipairs(ctrls:GetChildren()) do
		w(c.Name .. "  <" .. c.ClassName .. ">")
	end
else
	w("no Controllers folder under Knit — searching for any *Controller module")
	for _, d in ipairs(RS:GetDescendants()) do
		breathe()
		if d:IsA("ModuleScript") and d.Name:lower():find("controller", 1, true) then
			w("  " .. d:GetFullName())
		end
	end
end
end)

-- ── 2. PlayerScripts / PlayerGui: where the inventory UI lives ─────────
hdr("INVENTORY UI + LOCAL MODULES")
pcall(function()
local ps = LocalPlayer:FindFirstChild("PlayerScripts")
if ps then
	for _, d in ipairs(ps:GetDescendants()) do
		breathe()
		local n = d.Name:lower()
		if d:IsA("ModuleScript") and (n:find("invent") or n:find("item") or n:find("economy")
			or n:find("cosmetic") or n:find("skin") or n:find("data")) then
			w("PS  " .. d:GetFullName())
		end
	end
end
local pg = LocalPlayer:FindFirstChild("PlayerGui")
if pg then
	for _, d in ipairs(pg:GetDescendants()) do
		breathe()
		if d.Name:lower():find("invent", 1, true) then
			w("GUI " .. d:GetFullName() .. "  <" .. d.ClassName .. ">")
		end
	end
end
end)

-- ── 3. THE IMPORTANT ONE: live tables in the garbage collector ─────────
-- getgc(true) walks every live table/function. The inventory cache is a plain
-- Lua table somewhere in there; find it by shape rather than by name.
--
-- NOTE: everything below runs inside a function so an early `return` bails out
-- of THIS section only. A bare top-level return skipped the writefile at the
-- bottom and produced a 0-byte dump.
hdr("REPLICAS (getgc)")
local function scanGC()
if typeof(getgc) ~= "function" then
	w("executor has no getgc — cannot inspect live tables")
else
	-- This game runs ReplicaService: your data is a server-owned table mirrored
	-- to the client as a Replica object { Data=..., Class=..., Id=..., Tags=... }.
	-- The inventory lives in Replica.Data — that is what an "unlock all" writes
	-- to. So look for the Replica SHAPE, not for tables that happen to be big.
	-- (The old size>3 filter is why an empty account matched nothing.)
	local function isReplica(t)
		return type(rawget(t, "Data")) == "table"
			and rawget(t, "Id") ~= nil
			and (rawget(t, "Class") ~= nil or rawget(t, "Tags") ~= nil)
	end

	-- print a table a couple of levels deep so the schema is readable
	local function dump(t, indent, depth)
		if depth > 3 then w(indent .. "...") return end
		local n = 0
		for k, v in pairs(t) do
			n = n + 1
			if n > 40 then w(indent .. "... (more)") return end
			if type(v) == "table" then
				local cnt = 0
				for _ in pairs(v) do cnt = cnt + 1 end
				w(("%s%s = <table, %d entries>"):format(indent, tostring(k), cnt))
				dump(v, indent .. "    ", depth + 1)
			else
				w(("%s%s = %s  <%s>"):format(indent, tostring(k), tostring(v), type(v)))
			end
		end
	end

	local seen, found = {}, 0
	local gc = getgc(true)
	for _, obj in ipairs(gc) do
		breathe()
		if type(obj) == "table" and not seen[obj] then
			seen[obj] = true
			local ok, hit = pcall(isReplica, obj)
			if ok and hit then
				found = found + 1
				w("")
				w(("--- Replica #%d  Class=%s  Id=%s ---"):format(
					found, tostring(rawget(obj, "Class")), tostring(rawget(obj, "Id"))))
				dump(rawget(obj, "Data"), "  ", 1)
				if found >= 6 then w("(stopping at 6 replicas)") break end
			end
		end
	end
	if found == 0 then
		w("no Replica-shaped tables found.")
		w("Data may not have replicated yet — stay in-game a few seconds and re-run.")
	end
end
end
local gcOk, gcErr = pcall(scanGC)
if not gcOk then w("[getgc scan errored] " .. tostring(gcErr)) end

-- ── 4. the catalogue: what "Rarity: ???" fails to look up ──────────────
hdr("ITEM CATALOGUE MODULES")
pcall(function()
	for _, d in ipairs(RS:GetDescendants()) do
		breathe()
		local n = d.Name:lower()
		if d:IsA("ModuleScript") and (n:find("item") or n:find("rarit") or n:find("catalog")
			or n:find("shop") or n:find("case") or n:find("cosmetic")) then
			w(d:GetFullName())
		end
	end
end)

-- ── 5. THE CATALOGUE ITSELF ───────────────────────────────────────────
-- Modules.Items is the master list. It's what "Rarity: ???" fails to look up,
-- and it's the source of truth for what an inventory row must look like.
-- require() on a shared data module just returns its table.
hdr("ReplicatedStorage.Modules.Items")
pcall(function()
	local mods = RS:FindFirstChild("Modules")
	local itemsMod = mods and mods:FindFirstChild("Items")
	if not itemsMod then w("not found"); return end

	local ok, items = pcall(require, itemsMod)
	if not ok then w("require failed: " .. tostring(items)); return end
	if type(items) ~= "table" then w("returned a " .. type(items)); return end

	local count = 0
	for _ in pairs(items) do count = count + 1 end
	w(("top level: %d entries"):format(count))

	-- print the first few whole, so the row schema is unambiguous
	local shown = 0
	for k, v in pairs(items) do
		breathe()
		if type(v) == "table" then
			local parts = {}
			for k2, v2 in pairs(v) do
				if type(v2) == "table" then
					local c = 0
					for _ in pairs(v2) do c = c + 1 end
					table.insert(parts, tostring(k2) .. "=<tbl:" .. c .. ">")
				else
					table.insert(parts, tostring(k2) .. "=" .. tostring(v2))
				end
			end
			table.sort(parts)
			w(("  [%s] %s"):format(tostring(k), table.concat(parts, ", ")))
		else
			w(("  [%s] = %s  <%s>"):format(tostring(k), tostring(v), type(v)))
		end
		shown = shown + 1
		if shown >= 12 then w("  ... (+" .. (count - shown) .. " more)") break end
	end
end)

local body = table.concat(out, "\n")
if typeof(writefile) == "function" then
	pcall(function() writefile("BBL_InvDump.txt", body) end)
	warn("[dump] wrote BBL_InvDump.txt (" .. #body .. " bytes)")
end
if typeof(setclipboard) == "function" then
	pcall(function() setclipboard(body) end)
	warn("[dump] copied to clipboard")
end
