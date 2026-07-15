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
hdr("KNIT CONTROLLERS")
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

-- ── 2. PlayerScripts / PlayerGui: where the inventory UI lives ─────────
hdr("INVENTORY UI + LOCAL MODULES")
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

-- ── 3. THE IMPORTANT ONE: live tables in the garbage collector ─────────
-- getgc(true) walks every live table/function. The inventory cache is a plain
-- Lua table somewhere in there; find it by shape rather than by name.
hdr("CANDIDATE INVENTORY TABLES (getgc)")
if typeof(getgc) ~= "function" then
	w("executor has no getgc — cannot inspect live tables")
else
	local ITEM_KEYS = { "Rarity", "rarity", "ItemType", "item_type", "Type", "Name", "name", "Id", "id" }
	local INV_KEYS  = { "Inventory", "inventory", "Items", "items", "Owned", "owned",
		"Skins", "skins", "Effects", "effects", "Cosmetics", "cosmetics", "Equipped", "equipped" }

	local function looksLikeItem(t)
		if type(t) ~= "table" then return false end
		local hits = 0
		for _, k in ipairs(ITEM_KEYS) do if rawget(t, k) ~= nil then hits = hits + 1 end end
		return hits >= 2
	end

	local seen, found = {}, 0
	local ok, gc = pcall(getgc, true)
	if not ok then w("getgc(true) failed: " .. tostring(gc)) return end

	for _, obj in ipairs(gc) do
		breathe()
		if type(obj) == "table" and not seen[obj] then
			seen[obj] = true

			-- (a) a table with inventory-ish KEYS
			for _, k in ipairs(INV_KEYS) do
				local v = rawget(obj, k)
				if type(v) == "table" then
					local cnt = 0
					for _ in pairs(v) do cnt = cnt + 1 end
					if cnt > 3 then
						w(("[keyed] .%s -> %d entries"):format(k, cnt))
						-- show a couple of entries so we can see the shape
						local shown = 0
						for k2, v2 in pairs(v) do
							w(("        %s = %s  <%s>"):format(tostring(k2), tostring(v2), type(v2)))
							if type(v2) == "table" then
								for k3, v3 in pairs(v2) do
									w(("            .%s = %s"):format(tostring(k3), tostring(v3)))
								end
							end
							shown = shown + 1
							if shown >= 2 then break end
						end
						found = found + 1
					end
				end
			end

			-- (b) an ARRAY of item-shaped tables = the inventory list itself
			if #obj > 3 and looksLikeItem(obj[1]) then
				w(("[array] %d item-shaped entries"):format(#obj))
				for i = 1, math.min(2, #obj) do
					local parts = {}
					for k, v in pairs(obj[i]) do table.insert(parts, tostring(k) .. "=" .. tostring(v)) end
					table.sort(parts)
					w("        [" .. i .. "] " .. table.concat(parts, ", "))
				end
				found = found + 1
			end

			if found > 25 then w("(stopping at 25 candidates)") break end
		end
	end
	if found == 0 then w("nothing matched — open the Inventory window first, then re-run") end
end

-- ── 4. the catalogue: what "Rarity: ???" fails to look up ──────────────
hdr("ITEM CATALOGUE MODULES")
for _, d in ipairs(RS:GetDescendants()) do
	breathe()
	local n = d.Name:lower()
	if d:IsA("ModuleScript") and (n:find("item") or n:find("rarit") or n:find("catalog")
		or n:find("shop") or n:find("case") or n:find("cosmetic")) then
		w(d:GetFullName())
	end
end

local body = table.concat(out, "\n")
if typeof(writefile) == "function" then
	pcall(function() writefile("BBL_InvDump.txt", body) end)
	warn("[dump] wrote BBL_InvDump.txt (" .. #body .. " bytes)")
end
if typeof(setclipboard) == "function" then
	pcall(function() setclipboard(body) end)
	warn("[dump] copied to clipboard")
end
