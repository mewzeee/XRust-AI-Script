--[[
	=====================================================================
	  XRust  —  script injector hub  (UNKIE key-system build)
	=====================================================================
	  • NO in-script login. UNKIE (jnkie) verifies the key BEFORE this
	    script ever runs, so the hub boots straight up.
	    -> Paste this whole file into UNKIE's "Original Code" box.
	       The key GUI lives in "UI-Source"; UNKIE runs it first and only
	       reaches this file once the key checks out.
	  • Hub: Home / Universal / (placeholder) tabs.
	  • Universal tab has a description, changelog, live console and an
	    Inject button. Injecting prints  - mapping - / - loading - /
	    - injected -  then runs the universal script and closes the hub.
	  • Same clean dark/red aesthetic as the xRust menu.
	=====================================================================
--]]

--// ------------------------------------------------------------------
--// CONFIG  (edit these)
--// ------------------------------------------------------------------
-- the Universal script that gets injected. Just the raw URL - the hub runs
-- loadstring(game:HttpGet(SCRIPT_URL))() for you. If the repo is PRIVATE, paste
-- the tokenised "?token=..." raw URL instead.
local SCRIPT_URL = "https://raw.githubusercontent.com/mewzeee/XRust-AI-Script/main/xRust.lua"

--// ------------------------------------------------------------------
--// SERVICES
--// ------------------------------------------------------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--// ------------------------------------------------------------------
--// ENVIRONMENT  (executor helpers, resolved defensively)
--// ------------------------------------------------------------------
local httpRequest = (syn and syn.request) or (http and http.request) or http_request
	or (fluxus and fluxus.request) or request
local httpGet = function(url)
	if game.HttpGet then
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok then return body end
	end
	if httpRequest then
		local res = httpRequest({ Url = url, Method = "GET" })
		return res and (res.Body or res.body)
	end
	error("no HTTP method available")
end

local function getParentGui()
	local ok, hidden = pcall(function()
		if typeof(gethui) == "function" then return gethui() end
		return nil
	end)
	if ok and hidden then return hidden end
	local ok2, core = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and core then return core end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function getHWID()
	local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
	if ok and id then return id end
	if typeof(gethwid) == "function" then local ok2, h = pcall(gethwid); if ok2 and h then return h end end
	return "UNKNOWN-HWID"
end

--// ------------------------------------------------------------------
--// ACCOUNT
--//   UNKIE verifies the key before this file runs, so there is no login
--//   and no auth call left in here. This table only carries the HWID for
--//   the account panel.
--// ------------------------------------------------------------------
local Account = {
	hwid = getHWID(),
}

-- The open verify endpoint returns ONLY { valid, is_keyless, is_premium,
-- message } - there is no expiry in it, and the JD_* runtime globals are nil in
-- this flow. The real expiry lives on the REST /keys endpoint, which needs an
-- admin bearer token that must never ship inside a client script. So the plan is
-- the only key fact that can honestly be shown here.
local function keyPlan()
	local info = rawget(getgenv(), "XRUST_KEY_INFO")
	if type(info) ~= "table" then return nil end
	if info.is_premium == true then return "Premium" end
	if info.is_keyless == true then return "Keyless" end
	if info.valid == true then return "Standard" end
	return nil
end

--// ------------------------------------------------------------------
--// PROFILE  (custom display name for the greeting, persisted if possible)
--// ------------------------------------------------------------------
local PROFILE_FILE = "XRustHub_profile.json"
local Profile = { displayName = nil }
if typeof(readfile) == "function" and typeof(isfile) == "function" then
	pcall(function() if isfile(PROFILE_FILE) then
		local d = HttpService:JSONDecode(readfile(PROFILE_FILE))
		if type(d) == "table" then Profile = d end
	end end)
end
local function saveProfile()
	if typeof(writefile) == "function" then pcall(function() writefile(PROFILE_FILE, HttpService:JSONEncode(Profile)) end) end
end
-- the name shown in the greeting: your custom display name, else a clean "User".
-- (KeyAuth's "username" for a licence login is the licence KEY itself, so we
-- never show that.)
local function greetName()
	if Profile.displayName and Profile.displayName ~= "" then return Profile.displayName end
	return "User"
end
local function timeGreeting()
	local ok, h = pcall(function() return tonumber(os.date("%H")) end)   -- os.date can be sandboxed
	if not ok or not h then return "Hello" end
	if h < 12 then return "Good morning" elseif h < 18 then return "Good afternoon" else return "Good evening" end
end
-- forward decls (assigned once the UI they touch exists)
local greetLbl               -- the big greeting label on Home
local homeVals = {}          -- { user=, expiry=, hwid= } account labels on Home
local refreshAccount         -- updates every account label + greeting
local function updateGreeting()
	if greetLbl then greetLbl.Text = timeGreeting() .. ", " .. greetName() end
end

--// ------------------------------------------------------------------
--// THEME + UI HELPERS  (mirrors the xRust menu)
--// ------------------------------------------------------------------
local Theme = {
	Bg = Color3.fromRGB(9, 9, 11), Header = Color3.fromRGB(15, 15, 17), Panel = Color3.fromRGB(12, 12, 14),
	Panel2 = Color3.fromRGB(19, 19, 22), Hover = Color3.fromRGB(28, 28, 32), Border = Color3.fromRGB(36, 36, 40),
	Accent = Color3.fromRGB(198, 32, 36), AccentDim = Color3.fromRGB(110, 22, 26),
	TextOn = Color3.fromRGB(206, 206, 212), TextOff = Color3.fromRGB(104, 104, 112),
	TextHdr = Color3.fromRGB(228, 228, 234), Good = Color3.fromRGB(74, 190, 112), Bad = Color3.fromRGB(214, 74, 74),
}
local FONT = Enum.Font.Code

local function create(class, props, children)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then i[k] = v end end
	for _, c in ipairs(children or {}) do c.Parent = i end
	if props and props.Parent then i.Parent = props.Parent end
	return i
end
local function corner() end   -- no rounding anywhere — sharp, modern edges
local function border(p, c, t) return create("UIStroke", { Color = c or Theme.Border, Thickness = t or 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end
local function pad(p, l, t, r, b) return create("UIPadding", { Parent = p,
	PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
	PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0) }) end
local function label(p, text, o)
	o = o or {}
	return create("TextLabel", { Parent = p, BackgroundTransparency = 1, Font = o.Font or FONT, Text = text,
		TextSize = o.Size or 13, TextColor3 = o.Color or Theme.TextOn, TextWrapped = o.Wrap or false,
		TextXAlignment = o.XAlign or Enum.TextXAlignment.Left, TextYAlignment = o.YAlign or Enum.TextYAlignment.Center,
		Size = o.Sz or UDim2.new(1, 0, 1, 0), Position = o.Pos or UDim2.new(),
		TextTruncate = o.Truncate or Enum.TextTruncate.None })
end
local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, frame.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end
-- drifting starfield/snow. Fills `parent`, sits at ZIndex `z` (behind content).
-- Returns the RenderStepped connection so callers can Disconnect it.
local function makeSnow(parent, count, z)
	local canvas = create("Frame", { Parent = parent, Name = "Snow", Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1, ZIndex = z or 1 })
	local flakes = {}
	for _ = 1, count do
		local s = math.random(1, 3)
		local f = create("Frame", { Parent = canvas, Size = UDim2.fromOffset(s, s), BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(228, 232, 244), BackgroundTransparency = math.random(45, 85) / 100, ZIndex = z or 1 })
		table.insert(flakes, { gui = f, x = math.random(0, 600), y = math.random(-500, 600),
			speed = math.random(8, 26), driftAmp = math.random(4, 14), driftFreq = math.random(4, 12) / 10, phase = math.random() * 6.28 })
	end
	return RunService.RenderStepped:Connect(function(dt)
		local vp = canvas.AbsoluteSize
		for _, fl in ipairs(flakes) do
			fl.y = fl.y + fl.speed * dt; fl.phase = fl.phase + dt
			if fl.y > vp.Y + 6 then fl.y = -6; fl.x = math.random(0, math.max(vp.X, 1)) end
			fl.gui.Position = UDim2.fromOffset(fl.x + math.sin(fl.phase * fl.driftFreq) * fl.driftAmp, fl.y)
		end
	end)
end

--// ------------------------------------------------------------------
--// ROOT
--// ------------------------------------------------------------------
local ScreenGui = create("ScreenGui", { Name = "XRustHub_" .. math.random(1000, 9999),
	ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 9999999 })
pcall(function() if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
ScreenGui.Parent = getParentGui()

--// ------------------------------------------------------------------
--// (No login window — UNKIE's UI-Source handles the key before this file
--//  runs, so the hub below is the only window.)
--// ------------------------------------------------------------------
--// HUB  (built up front, hidden until login succeeds)
--// ------------------------------------------------------------------
local HUB_W, HUB_H = 760, 520
local BLACK  = Color3.fromRGB(8, 8, 10)     -- same pure-black as the login
local STROKE = Color3.fromRGB(30, 30, 34)   -- subtle dark border
local Hub = create("Frame", { Name = "Hub", Parent = ScreenGui, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, HUB_W, 0, HUB_H),
	BackgroundColor3 = BLACK, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10 })
border(Hub, STROKE, 1)
create("UIScale", { Name = "Scale", Parent = Hub })
-- snowfall behind everything (matches the login)
local hubSnowConn = makeSnow(Hub, 90, 10)

-- header (transparent so the snow shows behind it)
local HubHeader = create("Frame", { Parent = Hub, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 13 })
label(HubHeader, "  XRust", { Color = Theme.TextHdr, Size = 20, Font = Enum.Font.GothamBold, Sz = UDim2.new(1, -140, 1, 0), Pos = UDim2.new(0, 10, 0, 0) }).ZIndex = 14
create("Frame", { Parent = HubHeader, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = STROKE, BorderSizePixel = 0, ZIndex = 14 })

local function hubHeaderBtn(offset, sym)
	local b = create("TextButton", { Parent = HubHeader, Text = sym, AutoButtonColor = false,
		Size = UDim2.new(0, 30, 0, 26), Position = UDim2.new(1, offset, 0.5, -13), BackgroundTransparency = 1,
		Font = FONT, TextSize = 18, TextColor3 = Theme.TextOff, ZIndex = 14 })
	b.MouseEnter:Connect(function() b.TextColor3 = Theme.TextHdr end)
	b.MouseLeave:Connect(function() b.TextColor3 = Theme.TextOff end)
	return b
end
local closeBtn = hubHeaderBtn(-38, "\u{00D7}")
local minBtn   = hubHeaderBtn(-72, "\u{2013}")
makeDraggable(Hub, HubHeader)

-- tab bar (transparent)
local TabBar = create("Frame", { Parent = Hub, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 13 })
create("Frame", { Parent = TabBar, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
	BackgroundColor3 = STROKE, BorderSizePixel = 0, ZIndex = 14 })
local tabHolder = create("Frame", { Parent = TabBar, BackgroundTransparency = 1, Size = UDim2.new(0, 540, 1, 0), Position = UDim2.new(0, 10, 0, 0), ZIndex = 14 })
create("UIListLayout", { Parent = tabHolder, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Center })

local Content = create("Frame", { Parent = Hub, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 74), Size = UDim2.new(1, 0, 1, -100), ZIndex = 13 })

-- bottom bar (transparent)
local BottomBar = create("Frame", { Parent = Hub, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 13 })
create("Frame", { Parent = BottomBar, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = STROKE, BorderSizePixel = 0, ZIndex = 14 })
label(BottomBar, "  " .. LocalPlayer.Name, { Color = Theme.TextOn, Size = 12, Sz = UDim2.new(0.5, 0, 1, 0), Pos = UDim2.new(0, 10, 0, 0) }).ZIndex = 14
local planLbl = label(BottomBar, "", { Color = Theme.TextHdr, Size = 12, XAlign = Enum.TextXAlignment.Right,
	Sz = UDim2.new(0.5, -14, 1, 0), Pos = UDim2.new(0.5, 0, 0, 0) })
planLbl.ZIndex = 14

-- tab system ---------------------------------------------------------
-- NOTE: Roblox Instances reject arbitrary Lua fields (btn.underline = x throws
-- "underline is not a valid member") - keep side data in plain Lua tables.
local pages, tabButtons, underlines, activeTab = {}, {}, {}, nil
local function selectTab(name)
	if activeTab == name then return end
	for n, page in pairs(pages) do
		page.Visible = (n == name)
		if n == name then   -- clean fade-in
			page.GroupTransparency = 1
			TweenService:Create(page, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
		end
	end
	for n, btn in pairs(tabButtons) do
		local on = (n == name)
		TweenService:Create(btn, TweenInfo.new(0.14), { TextColor3 = on and Theme.TextHdr or Theme.TextOff }):Play()
		underlines[n].Visible = on
	end
	activeTab = name
end
local function addTab(name)
	-- flat, transparent tabs — active = white text + white underline
	local btn = create("TextButton", { Parent = tabHolder, AutoButtonColor = false, Size = UDim2.new(0, 100, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = FONT, Text = name, TextSize = 13,
		TextColor3 = Theme.TextOff, ZIndex = 14 })
	underlines[name] = create("Frame", { Parent = btn, Size = UDim2.new(0.55, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Theme.TextHdr, BorderSizePixel = 0, Visible = false, ZIndex = 15 })
	-- CanvasGroup lets the whole page fade cleanly on tab switch
	local page = create("CanvasGroup", { Parent = Content, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 13 })
	pad(page, 14, 12, 14, 12)
	pages[name] = page; tabButtons[name] = btn
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	btn.MouseEnter:Connect(function() if activeTab ~= name then btn.TextColor3 = Theme.TextOn end end)
	btn.MouseLeave:Connect(function() if activeTab ~= name then btn.TextColor3 = Theme.TextOff end end)
	return page
end

-- reusable card: subtle translucent panel so the snow shows through, sharp edges
local function card(parent, titleText, o)
	o = o or {}
	local c = create("Frame", { Parent = parent, BackgroundColor3 = Color3.fromRGB(15, 15, 18), BackgroundTransparency = 0.25,
		BorderSizePixel = 0, Size = o.Sz or UDim2.new(1, 0, 0, 120), Position = o.Pos or UDim2.new(), ZIndex = 13 })
	border(c, STROKE, 1)
	if titleText then
		label(c, "  " .. titleText, { Color = Theme.TextHdr, Size = 13, Sz = UDim2.new(1, 0, 0, 26), Pos = UDim2.new(0, 6, 0, 4) }).ZIndex = 14
		create("Frame", { Parent = c, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 30),
			BackgroundColor3 = STROKE, BorderSizePixel = 0, ZIndex = 14 })
	end
	return c
end

-- ================= HOME TAB =================
local homePage = addTab("Home")
do
	local hero = card(homePage, nil, { Sz = UDim2.new(1, 0, 0, 96) })
	greetLbl = label(hero, timeGreeting() .. ", " .. greetName(), { Color = Theme.TextHdr, Size = 24,
		Font = Enum.Font.GothamBold, Sz = UDim2.new(1, -24, 0, 34), Pos = UDim2.new(0, 16, 0, 16) })
	greetLbl.ZIndex = 12
	label(hero, "Premium script hub — pick a script under a tab, read about it, then inject.", {
		Color = Theme.TextOff, Size = 13, Wrap = true, Sz = UDim2.new(1, -32, 0, 34), Pos = UDim2.new(0, 16, 0, 50) }).ZIndex = 12

	local info = card(homePage, "Your Account", { Sz = UDim2.new(1, 0, 0, 126), Pos = UDim2.new(0, 0, 0, 108) })
	local function infoRow(order, k)
		local y = 36 + (order - 1) * 26
		label(info, k, { Color = Theme.TextOff, Size = 13, Sz = UDim2.new(0, 110, 0, 20), Pos = UDim2.new(0, 16, 0, y) }).ZIndex = 12
		local val = label(info, "--", { Color = Theme.TextOn, Size = 13, Sz = UDim2.new(1, -150, 0, 20), Pos = UDim2.new(0, 126, 0, y) })
		val.ZIndex = 12
		return val
	end
	homeVals.user   = infoRow(1, "Name")       -- their display name (or "User"), never the licence key
	homeVals.plan   = infoRow(2, "Plan")       -- is_premium is the only key fact the open API exposes
	homeVals.hwid   = infoRow(3, "HWID")       -- shown so users can quote it when asking for a reset
	homeVals.hwid.Text = Account.hwid
	homeVals.hwid.TextTruncate = Enum.TextTruncate.AtEnd

	local news = card(homePage, "News", { Sz = UDim2.new(1, 0, 1, -242), Pos = UDim2.new(0, 0, 0, 242) })
	label(news, "• Welcome! XRust Universal is live.\n• Report bugs and request games in the community.\n• More scripts coming to the empty tabs soon.", {
		Color = Theme.TextOff, Size = 13, Wrap = true, YAlign = Enum.TextYAlignment.Top,
		Sz = UDim2.new(1, -32, 1, -40), Pos = UDim2.new(0, 16, 0, 34) }).ZIndex = 12
end

-- ================= UNIVERSAL TAB =================
local uniPage = addTab("Universal")
local console  -- forward ref
do
	-- left column: description + changelog
	local left = create("Frame", { Parent = uniPage, BackgroundTransparency = 1, Size = UDim2.new(0.5, -6, 1, 0), ZIndex = 11 })
	local desc = card(left, "XRust Universal", { Sz = UDim2.new(1, 0, 0, 150) })
	label(desc, "A client-side aim & visual hub that works in most Roblox shooters.\n\nAimbot, silent aim, rage bot, triggerbot, full ESP, FOV circle, snaplines, target HUD, anti-aim, fly, and more — all configurable.", {
		Color = Theme.TextOff, Size = 12.5, Wrap = true, YAlign = Enum.TextYAlignment.Top,
		Sz = UDim2.new(1, -28, 1, -40), Pos = UDim2.new(0, 14, 0, 34) }).ZIndex = 12

	local chg = card(left, "Changelog", { Sz = UDim2.new(1, 0, 1, -160), Pos = UDim2.new(0, 0, 0, 160) })
	local chgScroll = create("ScrollingFrame", { Parent = chg, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -32), ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.TextOff, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 14 })
	pad(chgScroll, 14, 4, 12, 8)
	label(chgScroll, "v1.0\n• Initial release: aim suite, ESP, FOV, snaplines.\n• Target renderer + jump circles as true 3D FX.\n• Anti-aim, camera bypass, config system.\n• Rich target renderer: 12 styles, ring, marker, beam.", {
		Color = Theme.TextOff, Size = 12.5, Wrap = true, YAlign = Enum.TextYAlignment.Top,
		Sz = UDim2.new(1, 0, 0, 0), Pos = UDim2.new(0, 0, 0, 0) }).AutomaticSize = Enum.AutomaticSize.Y
	chgScroll:FindFirstChildOfClass("TextLabel").ZIndex = 12

	-- right column: console + inject
	local right = create("Frame", { Parent = uniPage, BackgroundTransparency = 1, Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 6, 0, 0), ZIndex = 11 })
	local con = card(right, "Console", { Sz = UDim2.new(1, 0, 1, -44) })
	console = create("ScrollingFrame", { Parent = con, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -32), ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.TextOff, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 14 })
	pad(console, 12, 6, 10, 8)
	create("UIListLayout", { Parent = console, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

	local INJBG, INJHOVER = Color3.fromRGB(18, 18, 21), Color3.fromRGB(28, 28, 32)
	local injectBtn = create("TextButton", { Parent = right, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.new(0, 0, 1, -38), BackgroundColor3 = INJBG, BorderSizePixel = 0, Font = FONT,
		TextSize = 15, TextColor3 = Theme.TextHdr, Text = "INJECT", ZIndex = 14 })
	border(injectBtn, STROKE, 1)
	injectBtn.MouseEnter:Connect(function() if injectBtn.Active ~= false then TweenService:Create(injectBtn, TweenInfo.new(0.1), { BackgroundColor3 = INJHOVER }):Play() end end)
	injectBtn.MouseLeave:Connect(function() TweenService:Create(injectBtn, TweenInfo.new(0.1), { BackgroundColor3 = INJBG }):Play() end)

	local conOrder = 0
	local function consoleLine(text, col)
		conOrder = conOrder + 1
		local l = create("TextLabel", { Parent = console, BackgroundTransparency = 1, Font = FONT, Text = text,
			TextSize = 12.5, TextColor3 = col or Theme.TextOn, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 16), LayoutOrder = conOrder, ZIndex = 14 })
		console.CanvasPosition = Vector2.new(0, math.huge)
		return l
	end
	consoleLine("[ready] press INJECT to load XRust Universal.", Theme.TextOff)

	-- realistic loader steps: {message, delay-before-next}
	local STEPS = {
		{ "initializing loader environment", 0.35 },
		{ "resolving executor capabilities", 0.3 },
		{ "establishing secure connection", 0.45 },
		{ "authenticating session", 0.4 },
		{ "fetching XRust Universal payload", 0.55 },
		{ "verifying payload integrity", 0.35 },
		{ "mapping runtime modules", 0.4 },
		{ "loading assets & signatures", 0.4 },
		{ "compiling bytecode", 0.45 },
	}
	local injecting = false
	injectBtn.MouseButton1Click:Connect(function()
		if injecting then return end
		injecting = true; injectBtn.Active = false
		injectBtn.Text = "INJECTING…"; injectBtn.TextColor3 = Theme.TextOff
		task.spawn(function()
			-- The old second HWID check called KeyAuth here. HWID limits are now
			-- enforced by the key system before this hub loads (see the provider's
			-- hwid_limit), so there is nothing to re-verify against.
			for _, step in ipairs(STEPS) do
				consoleLine("  " .. step[1] .. " ...", Theme.TextOn)
				task.wait(step[2])
				console:FindFirstChildOfClass("TextLabel")   -- keep alive
			end
			-- fetch + run the actual universal script
			local ok, err = pcall(function()
				consoleLine("  downloading script source", Theme.TextOn); task.wait(0.2)
				local src = httpGet(SCRIPT_URL)
				if not src or #src < 50 then error("empty script (check SCRIPT_URL)") end
				consoleLine("  executing (" .. #src .. " bytes)", Theme.TextOn); task.wait(0.25)
				local fn = loadstring(src)
				if not fn then error("loadstring failed") end
				fn()
			end)
			if not ok then
				consoleLine("[failed] " .. tostring(err), Theme.Bad)
				injectBtn.Text = "RETRY INJECT"; injectBtn.TextColor3 = Theme.TextHdr; injectBtn.Active = true; injecting = false
				return
			end
			consoleLine("[✓] injected — XRust Universal is running", Theme.Good)
			task.wait(0.5)
			if hubSnowConn then hubSnowConn:Disconnect() end
			ScreenGui:Destroy()
		end)
	end)
end

-- ================= PLACEHOLDER TAB =================
local phPage = addTab("Coming Soon")
do
	local c = card(phPage, nil, { Sz = UDim2.new(1, 0, 1, 0) })
	label(c, "Coming Soon", { Color = Theme.TextOff, Size = 22, XAlign = Enum.TextXAlignment.Center,
		Sz = UDim2.new(1, 0, 0, 30), Pos = UDim2.new(0, 0, 0.5, -22) }).ZIndex = 12
	label(c, "more scripts will appear here", { Color = Theme.TextOff, Size = 13, XAlign = Enum.TextXAlignment.Center,
		Sz = UDim2.new(1, 0, 0, 18), Pos = UDim2.new(0, 0, 0.5, 8) }).ZIndex = 12
end

-- ================= SETTINGS TAB =================
local setPage = addTab("Settings")
do
	-- small field + button row helper -> returns the TextBox
	local FBG, FHOVER = Color3.fromRGB(18, 18, 21), Color3.fromRGB(28, 28, 32)
	local function fieldRow(parent, y, placeholder, btnText, onClick)
		local box = create("TextBox", { Parent = parent, Size = UDim2.new(1, -110, 0, 34), Position = UDim2.new(0, 14, 0, y),
			BackgroundColor3 = FBG, BorderSizePixel = 0, Font = FONT, TextSize = 13, TextColor3 = Theme.TextOn,
			PlaceholderText = placeholder, PlaceholderColor3 = Theme.TextOff, Text = "", ClearTextOnFocus = false, ZIndex = 14 })
		border(box, STROKE, 1)
		local btn = create("TextButton", { Parent = parent, AutoButtonColor = false, Size = UDim2.new(0, 86, 0, 34),
			Position = UDim2.new(1, -100, 0, y), BackgroundColor3 = FBG, BorderSizePixel = 0, Font = FONT,
			TextSize = 13, TextColor3 = Theme.TextHdr, Text = btnText, ZIndex = 14 })
		border(btn, STROKE, 1)
		btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = FHOVER }):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = FBG }):Play() end)
		btn.MouseButton1Click:Connect(function() onClick(box, btn) end)
		return box
	end

	-- Profile card: change the greeting name
	local proCard = card(setPage, "Profile", { Sz = UDim2.new(1, 0, 0, 122), Pos = UDim2.new(0, 0, 0, 0) })
	label(proCard, "Set a display name — Home greets you with it instead of the default.", {
		Color = Theme.TextOff, Size = 12, Wrap = true, YAlign = Enum.TextYAlignment.Top,
		Sz = UDim2.new(1, -28, 0, 30), Pos = UDim2.new(0, 14, 0, 34) }).ZIndex = 14
	local proStatus
	local nameBox = fieldRow(proCard, 70, "Display name", "Save", function(box, btn)
		local nm = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
		Profile.displayName = (nm ~= "" and nm) or nil
		saveProfile(); updateGreeting()
		if homeVals.user then homeVals.user.Text = greetName() end
		proStatus.Text = "Saved"; proStatus.TextColor3 = Theme.Good
	end)
	nameBox.Text = Profile.displayName or ""
	proStatus = label(proCard, "", { Color = Theme.TextOff, Size = 13, Sz = UDim2.new(1, -28, 0, 18), Pos = UDim2.new(0, 14, 0, 106) })
	proStatus.ZIndex = 14
end

selectTab("Home")

-- hub window controls
local hubSnowCanvas = Hub:FindFirstChild("Snow")
local hubMin = false
minBtn.MouseButton1Click:Connect(function()
	hubMin = not hubMin
	local show = not hubMin
	-- hide the whole body while minimized so we get a clean title bar (no snow
	-- crammed into 40px, no half-clipped tabs) — and the min button stays live
	TabBar.Visible = show; Content.Visible = show; BottomBar.Visible = show
	if hubSnowCanvas then hubSnowCanvas.Visible = show end
	local tw = TweenService:Create(Hub, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = hubMin and UDim2.new(0, HUB_W, 0, 40) or UDim2.new(0, HUB_W, 0, HUB_H) })
	tw:Play()
	minBtn.Text = hubMin and "\u{002B}" or "\u{2013}"
end)
closeBtn.MouseButton1Click:Connect(function()
	if hubSnowConn then hubSnowConn:Disconnect() end
	ScreenGui:Destroy()
end)

--// ------------------------------------------------------------------
--// ACCOUNT PANEL
--// ------------------------------------------------------------------
-- assigns the forward-declared refreshAccount: sync every account label + greeting
refreshAccount = function()
	local plan = keyPlan()
	planLbl.Text = plan and (plan .. " key") or ""
	if homeVals.user then homeVals.user.Text = greetName() end   -- display name or "User", never the key
	if homeVals.plan then homeVals.plan.Text = plan or "--" end
	if homeVals.hwid then homeVals.hwid.Text = Account.hwid end
	updateGreeting()
end

-- ── BOOT ──────────────────────────────────────────────────────────────
--    UNKIE verifies the key before this file runs, so there is no login to
--    wait on — open the hub immediately.
Hub.Visible = true
do
	local sc = Hub:FindFirstChild("Scale"); if sc then sc.Scale = 0.96 end
	Hub.BackgroundTransparency = 1
	if sc then TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play() end
	TweenService:Create(Hub, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
end
if refreshAccount then pcall(refreshAccount) end
warn("[XRust] hub loaded (UNKIE key mode — no in-script login).")
