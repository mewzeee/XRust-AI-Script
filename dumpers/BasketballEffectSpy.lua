--[[
	=====================================================================
	  Basketball Legends — effect call spy
	=====================================================================
	  WHY: cloning Assets.Effects gives you the geometry, not the show. The
	  animation lives in the game's client code (Controllers.VisualController)
	  and is kicked off by the server through
	      Packages.Knit.Services.VisualService.RE.Effects
	  So the right move isn't to rebuild the animation — it's to call the
	  game's own handler with the same arguments the server sends.

	  This listens for those arguments and prints them.

	  HOW IT WORKS / WHY IT'S SAFE:
	    * It adds ITS OWN :Connect to OnClientEvent. That's an extra
	      listener, not a hook — the game's handler is untouched and still
	      runs normally. No hookmetamethod, no hookfunction, no upvalue
	      patching. Nothing the Lost Front detector looked for.
	    * getconnections() is only READ here, to show what's attached.

	  USE:
	    1. Run this.
	    2. Hit greens / dunk / let others score for ~30s.
	    3. Send the printed lines. Then the green effect can call the real
	       thing instead of cloning a corpse of it.
	=====================================================================
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local out = {}
local function w(s) table.insert(out, s); print(s) end
local function hdr(s) w(""); w("=== " .. s .. " ===") end

local function save()
	local body = table.concat(out, "\n")
	if typeof(writefile) == "function" then pcall(function() writefile("BBL_EffectSpy.txt", body) end) end
	if typeof(setclipboard) == "function" then pcall(function() setclipboard(body) end) end
end

-- readable one-liner for any argument type
local function brief(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "Instance" then
		return ("<%s %s>"):format(v.ClassName, v:GetFullName())
	elseif t == "table" then
		if depth > 2 then return "<table ...>" end
		local parts = {}
		local n = 0
		for k, v2 in pairs(v) do
			n = n + 1
			if n > 12 then table.insert(parts, "...") break end
			table.insert(parts, tostring(k) .. "=" .. brief(v2, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "Vector3" or t == "CFrame" or t == "Color3" then
		return t .. "(" .. tostring(v) .. ")"
	end
	return tostring(v) .. " <" .. t .. ">"
end

w("Basketball Legends effect spy — " .. os.date("!%H:%M:%S") .. " UTC")

local svc = RS:FindFirstChild("Packages")
	and RS.Packages:FindFirstChild("Knit")
	and RS.Packages.Knit:FindFirstChild("Services")

-- ── who already handles these events? ─────────────────────────────────
hdr("EXISTING HANDLERS")
if typeof(getconnections) == "function" and svc then
	local watch = {
		{ "VisualService", "Effects" },
		{ "ControlService", "ShootMeterRelease" },
		{ "ControlService", "Shoot" },
	}
	for _, p in ipairs(watch) do
		local s = svc:FindFirstChild(p[1])
		local re = s and s:FindFirstChild("RE") and s.RE:FindFirstChild(p[2])
		if re then
			local ok, conns = pcall(getconnections, re.OnClientEvent)
			w(("%s.RE.%s -> %s listener(s)"):format(p[1], p[2], ok and #conns or "?"))
			if ok then
				for i, c in ipairs(conns) do
					-- a connection is USERDATA: rawget() bypasses __index and
					-- returns nil, so this printed "?" for every listener and
					-- told us nothing. Index it normally.
					local gotFn, fn = pcall(function() return c.Function end)
					local desc = "no .Function (foreign state?)"
					if gotFn and type(fn) == "function" then
						local okI, src, ln = pcall(debug.info, fn, "sl")
						desc = okI and (tostring(src) .. ":" .. tostring(ln)) or "<fn, no debug.info>"
					end
					w(("   [%d] %s"):format(i, desc))
				end
			end
		else
			w(("%s.RE.%s : not found"):format(p[1], p[2]))
		end
	end
else
	w("no getconnections (or no Knit services)")
end

-- ── listen alongside the game ─────────────────────────────────────────
hdr("LIVE CALLS  (go score — greens, dunks, anything)")
local hits = 0
local function attach(serviceName, eventName)
	local s = svc and svc:FindFirstChild(serviceName)
	local re = s and s:FindFirstChild("RE") and s.RE:FindFirstChild(eventName)
	if not re then return end
	-- our own connection; the game's handler still fires exactly as before
	re.OnClientEvent:Connect(function(...)
		hits = hits + 1
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do table.insert(parts, ("[%d] %s"):format(i, brief(args[i]))) end
		w(("%s.%s (%d args)  %s"):format(serviceName, eventName, args.n, table.concat(parts, "  ")))
		if hits % 3 == 0 then save() end
	end)
	w("listening: " .. serviceName .. "." .. eventName)
end

attach("VisualService", "Effects")
attach("ControlService", "ShootMeterRelease")
attach("ControlService", "Shoot")

save()
warn("[spy] listening for 60s — go hit some greens, then send BBL_EffectSpy.txt")
task.delay(60, function()
	w("")
	w("(spy finished — " .. hits .. " calls seen)")
	save()
	warn("[spy] done: " .. hits .. " calls. Written to BBL_EffectSpy.txt + clipboard.")
end)
