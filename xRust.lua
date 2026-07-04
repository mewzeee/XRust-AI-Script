--[[
	=====================================================================
	  xRust-style UI  —  compact dark/red interface + client-side aim/visual hub
	=====================================================================
	  • Zero external libraries. Executor paste-run or LocalScript in
	    StarterPlayerScripts.
	  • Aesthetic: pure black, deep-red accent, sharp corners, 1px borders,
	    monospace (Code) font, checkbox toggles, no bounce/gloss.
	  • Layout mirrors the reference: category rail (Aim/Visuals/Misc/Config/
	    PlayerList) -> sub-tab bar -> side-by-side panels of items.
	  • Aim category is genuine camera-based aim assist (no fake server exploits).
	  • Every loop is single/shared and killed the instant its feature is off.
	=====================================================================
--]]

--// Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local Stats            = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--=====================================================================
--  ENVIRONMENT
--=====================================================================
local function getParentGui()
	local ok, hidden = pcall(function()
		if typeof(gethui) == "function" then return gethui() end
		return nil
	end)
	if ok and hidden then return hidden end
	local ok2, core = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and core and not LocalPlayer:FindFirstChild("PlayerGui") then return core end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local FS = {
	enabled = (typeof(writefile) == "function" and typeof(readfile) == "function"
		and typeof(isfile) == "function"),
	folder = "xRust",
}
if FS.enabled then
	pcall(function()
		if typeof(isfolder) == "function" and not isfolder(FS.folder)
			and typeof(makefolder) == "function" then makefolder(FS.folder) end
	end)
end

local hasMouseClick = (typeof(mouse1click) == "function")

--=====================================================================
--  LIBRARY CORE
--=====================================================================
local Library = {
	Name = "xRust",
	Flags = {}, Options = {}, Connections = {}, Loops = {}, Accents = {}, AccentFns = {},
	Toggled = true, Destroyed = false,
	Theme = {
		Bg        = Color3.fromRGB(9, 9, 11),
		Header    = Color3.fromRGB(15, 15, 17),
		Panel     = Color3.fromRGB(12, 12, 14),
		Panel2    = Color3.fromRGB(19, 19, 22),
		Hover     = Color3.fromRGB(28, 28, 32),
		Border    = Color3.fromRGB(36, 36, 40),
		BorderRed = Color3.fromRGB(70, 18, 22),
		Accent    = Color3.fromRGB(198, 32, 36),
		AccentDim = Color3.fromRGB(110, 22, 26),
		TextOn    = Color3.fromRGB(206, 206, 212),
		TextOff   = Color3.fromRGB(104, 104, 112),
		TextHdr   = Color3.fromRGB(228, 228, 234),
		Good      = Color3.fromRGB(74, 190, 112),
	},
	Font = Enum.Font.Code,
}

function Library:Connect(sig, fn)
	local c = sig:Connect(fn); table.insert(self.Connections, c); return c
end
function Library:StartLoop(name, ev, fn)
	if self.Loops[name] then self.Loops[name]:Disconnect() end
	self.Loops[name] = ev:Connect(fn)
end
function Library:StopLoop(name)
	if self.Loops[name] then self.Loops[name]:Disconnect(); self.Loops[name] = nil end
end
-- render-bound loop: runs at a fixed RenderPriority AFTER the camera has its
-- final CFrame for the frame. The plain RenderStepped EVENT fires before the
-- game camera / bypass cam / aimbot settle the view, which made
-- screen-projected visuals (esp boxes, snaplines) shake a frame behind.
-- StopLoop works on these too.
function Library:StartRenderLoop(name, priority, fn)
	self:StopLoop(name)
	local bindName = "xRust_" .. name
	RunService:BindToRenderStep(bindName, priority, fn)
	self.Loops[name] = { Disconnect = function()
		pcall(function() RunService:UnbindFromRenderStep(bindName) end)
	end }
end
function Library:RegisterAccent(inst, prop)
	table.insert(self.Accents, { inst = inst, prop = prop }); inst[prop] = self.Theme.Accent
end
-- functions run whenever the accent changes (SetAccent or RGB rainbow); used by
-- toggles so their ON colour follows the accent live, without re-toggling.
function Library:AddAccentFn(fn) table.insert(self.AccentFns, fn); pcall(fn, self.Theme.Accent) end
function Library:ApplyAccent(c, tween)
	for _, a in ipairs(self.Accents) do
		if a.inst and a.inst.Parent then
			if tween then TweenService:Create(a.inst, TweenInfo.new(0.12), { [a.prop] = c }):Play()
			else a.inst[a.prop] = c end
		end
	end
	for _, fn in ipairs(self.AccentFns) do pcall(fn, c) end
end
function Library:SetAccent(c)
	self.Theme.Accent = c
	self:ApplyAccent(c, true)
end

--// creation helpers ---------------------------------------------------
local function create(class, props, children)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then i[k] = v end end
	for _, c in ipairs(children or {}) do c.Parent = i end
	if props and props.Parent then i.Parent = props.Parent end
	return i
end
local function corner(parent, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r or 5), Parent = parent })
end
local function border(parent, color, th)
	return create("UIStroke", { Color = color or Library.Theme.Border, Thickness = th or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end
local function pad(parent, l, t, r, b)
	return create("UIPadding", { Parent = parent,
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0) })
end
local function label(parent, text, opts)
	opts = opts or {}
	return create("TextLabel", { Parent = parent, BackgroundTransparency = 1,
		Font = opts.Font or Library.Font, Text = text, TextSize = opts.Size or 12,
		TextColor3 = opts.Color or Library.Theme.TextOn,
		TextXAlignment = opts.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = opts.YAlign or Enum.TextYAlignment.Center,
		Size = opts.Sz or UDim2.new(1, 0, 1, 0), Position = opts.Pos or UDim2.new(),
		TextTruncate = opts.Truncate or Enum.TextTruncate.None })
end

-- compact key names so chips like [MouseButton2] fit their box
local KEY_SHORT = {
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
	LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift",
	LeftAlt = "LAlt", RightAlt = "RAlt", Backspace = "Bksp", Return = "Enter",
	CapsLock = "Caps", LeftBracket = "[", RightBracket = "]",
}
local function shortKey(k)
	if not k then return "None" end
	local n = tostring(k):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
	return KEY_SHORT[n] or n
end

-- a GuiObject is really on screen only if it and every GuiObject ancestor is
-- Visible. Hidden tabs KEEP their AbsolutePosition, so anything that manually
-- hit-tests mouse coords (the colour pickers) must check this - otherwise a
-- picker left open on a hidden tab eats the same drag and its colour
-- "randomly" changes too.
local function guiVisible(g)
	while g and g:IsA("GuiObject") do
		if not g.Visible then return false end
		g = g.Parent
	end
	return true
end

-- draw/stretch a 1px Frame as a 2D line between two screen points (absolute space)
local function updateLine(frame, from, to, thickness, color)
	local dir = to - from
	local dist = dir.Magnitude
	frame.Size = UDim2.fromOffset(dist, thickness or 1)
	frame.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
	frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	if color then frame.BackgroundColor3 = color end
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, frame.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

--=====================================================================
--  ROOT WINDOW
--=====================================================================
local ScreenGui = create("ScreenGui", { Name = "xRust_" .. math.random(1000, 9999),
	ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true, DisplayOrder = 999999 })
pcall(function() if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
ScreenGui.Parent = getParentGui()

local Main = create("Frame", { Name = "Main", Parent = ScreenGui,
	Size = UDim2.new(0, 720, 0, 500), Position = UDim2.new(0.5, -360, 0.5, -250),
	BackgroundColor3 = Library.Theme.Bg, BorderSizePixel = 0, ClipsDescendants = true })
local MainStroke = border(Main, Library.Theme.Accent, 1)
Library:RegisterAccent(MainStroke, "Color")
create("UIScale", { Name = "Scale", Parent = Main })

-- header
local Header = create("Frame", { Name = "Header", Parent = Main,
	Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Library.Theme.Header, BorderSizePixel = 0 })
label(Header, "  " .. Library.Name, { Color = Library.Theme.Accent, Size = 15,
	Font = Enum.Font.Code, Sz = UDim2.new(1, -120, 1, 0), Pos = UDim2.new(0, 6, 0, 0) })
local titleTag = Header:FindFirstChildOfClass("TextLabel")
Library:RegisterAccent(titleTag, "TextColor3")
local headerLine = create("Frame", { Parent = Header, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
	BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.4 })
Library:RegisterAccent(headerLine, "BackgroundColor3")

-- header buttons
local function headerBtn(offset, sym, col)
	local b = create("TextButton", { Parent = Header, Text = sym, AutoButtonColor = false,
		Size = UDim2.new(0, 24, 0, 20), Position = UDim2.new(1, offset, 0.5, -10),
		BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0,
		Font = Library.Font, TextSize = 13, TextColor3 = col or Library.Theme.TextOff })
	border(b, Library.Theme.Border, 1)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = Library.Theme.Hover }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = Library.Theme.Panel2 }):Play() end)
	return b
end
local CloseBtn = headerBtn(-28, "x", Library.Theme.Accent)
local MinBtn   = headerBtn(-56, "_")
makeDraggable(Main, Header)

-- body columns
local Rail = create("Frame", { Name = "Rail", Parent = Main,
	Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(0, 132, 1, -30),
	BackgroundColor3 = Library.Theme.Panel, BorderSizePixel = 0 })
create("Frame", { Parent = Rail, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0),
	Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = Library.Theme.Border })
local RailList = create("Frame", { Parent = Rail, BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 1, -8) })
create("UIListLayout", { Parent = RailList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

local Right = create("Frame", { Name = "Right", Parent = Main, BackgroundTransparency = 1,
	Position = UDim2.new(0, 132, 0, 30), Size = UDim2.new(1, -132, 1, -30) })
local SubBarHolder = create("Frame", { Parent = Right, BackgroundColor3 = Library.Theme.Header,
	BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30) })
create("Frame", { Parent = SubBarHolder, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Library.Theme.Border })
local PagesHolder = create("Frame", { Parent = Right, BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30) })

--=====================================================================
--  NOTIFICATIONS
--=====================================================================
local NotifHolder = create("Frame", { Parent = ScreenGui, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12), Size = UDim2.new(0, 250, 1, -24), BackgroundTransparency = 1 })
create("UIListLayout", { Parent = NotifHolder, Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder })

function Library:Notify(title, text, dur, kind)
	dur = dur or 4
	local accent = (kind == "good" and self.Theme.Good) or self.Theme.Accent
	local card = create("Frame", { Parent = NotifHolder, Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = self.Theme.Header, BorderSizePixel = 0, ClipsDescendants = true,
		AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, 20, 0, 0) })
	border(card, self.Theme.Border, 1)
	create("Frame", { Parent = card, Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0 })
	local box = create("Frame", { Parent = card, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	pad(box, 10, 7, 10, 7)
	create("UIListLayout", { Parent = box, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	label(box, title, { Color = self.Theme.TextHdr, Size = 12, Sz = UDim2.new(1, 0, 0, 15) }).LayoutOrder = 1
	create("TextLabel", { Parent = box, BackgroundTransparency = 1, LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = self.Font,
		Text = text, TextColor3 = self.Theme.TextOff, TextSize = 11, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left })
	TweenService:Create(card, TweenInfo.new(0.2), { Position = UDim2.new(0, 0, 0, 0) }):Play()
	task.delay(dur, function()
		if card and card.Parent then
			local o = TweenService:Create(card, TweenInfo.new(0.2), { Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1 })
			o:Play(); o.Completed:Wait(); card:Destroy()
		end
	end)
end

--=====================================================================
--  CATEGORY / SUBTAB / PANEL SYSTEM
--=====================================================================
local Categories = {}
local ActiveCat

local function selectCat(cat)
	if ActiveCat == cat then return end
	if ActiveCat then
		ActiveCat.SubBar.Visible = false
		if ActiveCat.ActivePage then ActiveCat.ActivePage.Frame.Visible = false end
		TweenService:Create(ActiveCat.Button, TweenInfo.new(0.1), { TextColor3 = Library.Theme.TextOff }):Play()
		ActiveCat.Indicator.Visible = false
	end
	ActiveCat = cat
	cat.SubBar.Visible = true
	if cat.ActivePage then cat.ActivePage.Frame.Visible = true end
	TweenService:Create(cat.Button, TweenInfo.new(0.1), { TextColor3 = Library.Theme.TextHdr }):Play()
	cat.Indicator.Visible = true
end

function Library:AddCategory(name, order)
	local button = create("TextButton", { Parent = RailList, AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Font = self.Font,
		LayoutOrder = order or 0,
		Text = "   " .. name, TextColor3 = self.Theme.TextOff, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left })
	local indicator = create("Frame", { Parent = button, BorderSizePixel = 0, Visible = false,
		Size = UDim2.new(0, 2, 0, 14), Position = UDim2.new(0, 0, 0.5, -7),
		BackgroundColor3 = self.Theme.Accent })
	self:RegisterAccent(indicator, "BackgroundColor3")

	local subBar = create("Frame", { Parent = SubBarHolder, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), Visible = false })

	local cat = { Button = button, Indicator = indicator, SubBar = subBar,
		SubButtons = {}, Pages = {}, ActivePage = nil }
	table.insert(Categories, cat)

	button.MouseButton1Click:Connect(function() selectCat(cat) end)
	button.MouseEnter:Connect(function()
		if ActiveCat ~= cat then TweenService:Create(button, TweenInfo.new(0.1), { TextColor3 = self.Theme.TextOn }):Play() end
	end)
	button.MouseLeave:Connect(function()
		if ActiveCat ~= cat then TweenService:Create(button, TweenInfo.new(0.1), { TextColor3 = self.Theme.TextOff }):Play() end
	end)

	------------------------------------------------------------------
	local function relayoutSubButtons()
		local n = #cat.SubButtons
		for idx, b in ipairs(cat.SubButtons) do
			b.Size = UDim2.new(1 / n, 0, 1, -1)
			b.Position = UDim2.new((idx - 1) / n, 0, 0, 0)
		end
	end

	local function selectPage(page)
		if cat.ActivePage == page then return end
		if cat.ActivePage then
			cat.ActivePage.Frame.Visible = false
			TweenService:Create(cat.ActivePage.Button, TweenInfo.new(0.1),
				{ BackgroundTransparency = 1, TextColor3 = Library.Theme.TextOff }):Play()
			cat.ActivePage.UnderLine.Visible = false
		end
		cat.ActivePage = page
		page.Frame.Visible = (ActiveCat == cat)
		TweenService:Create(page.Button, TweenInfo.new(0.1),
			{ BackgroundTransparency = 0, TextColor3 = Library.Theme.TextHdr }):Play()
		page.UnderLine.Visible = true
	end

	local catApi = {}

	function catApi:AddTab(tabName)
		local sbtn = create("TextButton", { Parent = subBar, AutoButtonColor = false,
			BackgroundColor3 = Library.Theme.Panel2, BackgroundTransparency = 1, BorderSizePixel = 0,
			Font = Library.Font, Text = tabName, TextColor3 = Library.Theme.TextOff, TextSize = 12 })
		create("Frame", { Parent = sbtn, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Library.Theme.Border })
		local underline = create("Frame", { Parent = sbtn, BorderSizePixel = 0, Visible = false,
			Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
			BackgroundColor3 = Library.Theme.Accent })
		Library:RegisterAccent(underline, "BackgroundColor3")
		table.insert(cat.SubButtons, sbtn)

		local pageFrame = create("Frame", { Parent = PagesHolder, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0), Visible = false })
		pad(pageFrame, 10, 10, 10, 10)
		local panelRow = create("Frame", { Parent = pageFrame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })

		local page = { Button = sbtn, Frame = pageFrame, UnderLine = underline, Panels = {} }
		table.insert(cat.Pages, page)
		sbtn.MouseButton1Click:Connect(function() selectPage(page) end)
		sbtn.MouseEnter:Connect(function()
			if cat.ActivePage ~= page then TweenService:Create(sbtn, TweenInfo.new(0.1), { TextColor3 = Library.Theme.TextOn }):Play() end
		end)
		sbtn.MouseLeave:Connect(function()
			if cat.ActivePage ~= page then TweenService:Create(sbtn, TweenInfo.new(0.1), { TextColor3 = Library.Theme.TextOff }):Play() end
		end)
		relayoutSubButtons()
		if not cat.ActivePage then selectPage(page) end

		--------------------------------------------------------------
		local function relayoutPanels()
			local n = #page.Panels
			for idx, p in ipairs(page.Panels) do
				p.Size = UDim2.new(1 / n, -6, 1, 0)
				p.Position = UDim2.new((idx - 1) / n, (idx == 1 and 0 or 6), 0, 0)
			end
		end

		local pageApi = {}

		function pageApi:AddPanel(panelTitle)
			local panel = create("Frame", { Parent = panelRow, BackgroundColor3 = Library.Theme.Panel,
				BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
			border(panel, Library.Theme.Border, 1); corner(panel, 6)
			table.insert(page.Panels, panel)
			relayoutPanels()

			label(panel, "  " .. (panelTitle or ""), { Color = Library.Theme.TextHdr, Size = 13,
				Sz = UDim2.new(1, 0, 0, 24), Pos = UDim2.new(0, 4, 0, 2) })
			create("Frame", { Parent = panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 0, 25), BackgroundColor3 = Library.Theme.Border })

			local scroll = create("ScrollingFrame", { Parent = panel, BackgroundTransparency = 1,
				BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26),
				ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent,
				CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y })
			Library:RegisterAccent(scroll, "ScrollBarImageColor3")
			pad(scroll, 8, 6, 8, 6)
			create("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

			local comp = {}
			local order = 0
			local function ord() order += 1; return order end
			local function indent(inst, sub) if sub then pad(inst, 16, 0, 0, 0) end end

			----------------------------------------------------------
			-- reusable key-capture chip
			----------------------------------------------------------
			local function makeKeyChip(parent, default, onSet)
				local chip = create("TextButton", { Parent = parent, AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 2, 0.5, 0),
					Size = UDim2.new(0, 58, 0, 16), BackgroundColor3 = Library.Theme.Panel2,
					BorderSizePixel = 0, Font = Library.Font, TextSize = 11,
					TextColor3 = Library.Theme.TextOff, Text = "[None]",
					TextTruncate = Enum.TextTruncate.AtEnd })
				border(chip, Library.Theme.Border, 1)
				local current = default
				local listening = false
				local function nm(k) return "[" .. shortKey(k) .. "]" end
				local function set(k, skip)
					if type(k) == "string" then
						-- from a config: "None" or an enum name (bad names must not error)
						current = nil
						if k ~= "None" then
							local ok, e = pcall(function() return Enum.KeyCode[k] end)
							if ok and e then current = e
							else
								ok, e = pcall(function() return Enum.UserInputType[k] end)
								if ok and e then current = e end
							end
						end
					else current = k end
					chip.Text = nm(current)
					if onSet then onSet(current, skip) end
				end
				chip.MouseButton1Click:Connect(function()
					-- ignore inputs until the opening click fully releases, so MB1 is bindable
					listening = false
					task.defer(function() listening = true end)
					chip.Text = "[...]"; chip.TextColor3 = Library.Theme.Accent
				end)
				local MOUSE = { [Enum.UserInputType.MouseButton1] = true,
					[Enum.UserInputType.MouseButton2] = true, [Enum.UserInputType.MouseButton3] = true }
				Library:Connect(UserInputService.InputBegan, function(input, gpe)
					if listening then
						listening = false; chip.TextColor3 = Library.Theme.TextOff
						if input.KeyCode ~= Enum.KeyCode.Unknown then
							if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then set(nil) else set(input.KeyCode) end
						elseif MOUSE[input.UserInputType] then
							set(input.UserInputType)
						end
					end
				end)
				set(current, true)
				return { Get = function() return current end, Set = function(_, k, s) set(k, s) end, Instance = chip }
			end

			----------------------------------------------------------
			-- TOGGLE  (checkbox + optional bind chip)
			----------------------------------------------------------
			function comp:AddToggle(opts)
				local state = opts.Default or false
				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20), LayoutOrder = ord() })
				indent(row, opts.Sub)
				local box = create("Frame", { Parent = row, BorderSizePixel = 0,
					Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 0, 0.5, -6),
					BackgroundColor3 = Library.Theme.Panel2 })
				local boxBorder = border(box, Library.Theme.Border, 1); corner(box, 3)
				local txt = label(row, opts.Text or "Toggle", { Color = Library.Theme.TextOff, Size = 12,
					Sz = UDim2.new(1, opts.Bind and -84 or -24, 1, 0), Pos = UDim2.new(0, 19, 0, 0),
					Truncate = Enum.TextTruncate.AtEnd })

				local bindApi
				if opts.Bind then
					-- Bind==true means "give it a chip but no default key" (avoid the a-and-nil-or-b trap)
					local bindDefault = (opts.Bind ~= true) and opts.Bind or nil
					bindApi = makeKeyChip(row, bindDefault, function(key)
						Library.Flags[(opts.Flag or opts.Text) .. "_key"] = key and tostring(key):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "") or "None"
					end)
					-- loader so configs restore the bind (the chip parses enum-name strings)
					Library.Options[(opts.Flag or opts.Text) .. "_key"] = {
						Set = function(_, v) if type(v) == "string" then bindApi.Set(nil, v, true) end end,
						Get = function() return bindApi.Get() end,
					}
				end

				local api = {}
				function api:Set(v, skip)
					state = v and true or false
					Library.Flags[opts.Flag or opts.Text] = state
					TweenService:Create(box, TweenInfo.new(0.1), { BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.Panel2 }):Play()
					boxBorder.Color = Library.Theme.Border  -- border stays neutral; only the fill shows accent
					txt.TextColor3 = state and Library.Theme.TextHdr or Library.Theme.TextOff
					if opts.Callback and not skip then pcall(opts.Callback, state) end
				end
				function api:Get() return state end
				function api:GetKey() return bindApi and bindApi.Get() end

				-- keep the ON checkbox in sync with the live accent (and rainbow)
				Library:AddAccentFn(function(c)
					if state then box.BackgroundColor3 = c end
				end)

				local click = create("TextButton", { Parent = row, Text = "", BackgroundTransparency = 1,
					Size = UDim2.new(1, opts.Bind and -64 or 0, 1, 0) })
				click.MouseButton1Click:Connect(function() api:Set(not state) end)
				row.MouseEnter:Connect(function() if not state then txt.TextColor3 = Library.Theme.TextOn end end)
				row.MouseLeave:Connect(function() if not state then txt.TextColor3 = Library.Theme.TextOff end end)

				-- a bind chip normally toggles the feature on key press; BindNoToggle makes it a
				-- pure hold-key (used by the aimbot Enabled toggle so its chip is the aim key)
				if bindApi and not opts.BindNoToggle then
					Library:Connect(UserInputService.InputBegan, function(input, gpe)
						if gpe then return end
						local k = bindApi.Get()
						if k and ((input.KeyCode == k) or (input.UserInputType == k)) then api:Set(not state) end
					end)
				end

				api.Row = row
				function api:SetVisible(v) row.Visible = v end
				if opts.Flag then Library.Options[opts.Flag] = api end
				api:Set(state, true)
				return api
			end

			----------------------------------------------------------
			-- KEYBIND row  (label + [key] chip, fires Callback)
			----------------------------------------------------------
			function comp:AddKeybind(opts)
				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18), LayoutOrder = ord() })
				indent(row, opts.Sub)
				label(row, opts.Text or "Keybind", { Color = Library.Theme.TextOff, Size = 12,
					Sz = UDim2.new(1, -66, 1, 0), Truncate = Enum.TextTruncate.AtEnd })
				local api
				local chip = makeKeyChip(row, opts.Default, function(key, skip)
					Library.Flags[opts.Flag or opts.Text] = key and tostring(key):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "") or "None"
				end)
				api = { Get = chip.Get, Set = function(self, k, s) chip.Set(nil, k, s) end,
					Row = row, SetVisible = function(self, v) row.Visible = v end }
				Library:Connect(UserInputService.InputBegan, function(input, gpe)
					if gpe then return end
					local k = chip.Get()
					if k and ((input.KeyCode == k) or (input.UserInputType == k)) and opts.Callback then pcall(opts.Callback) end
				end)
				if opts.Flag then Library.Options[opts.Flag] = api end
				return api
			end

			----------------------------------------------------------
			-- SLIDER
			----------------------------------------------------------
			function comp:AddSlider(opts)
				local min, max = opts.Min or 0, opts.Max or 100
				local dec = opts.Decimals or 0
				local value = math.clamp(opts.Default or min, min, max)
				local suffix = opts.Suffix or ""
				local function round(v) local m = 10 ^ dec; return math.floor(v * m + 0.5) / m end

				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ord() })
				indent(row, opts.Sub)
				label(row, opts.Text or "Slider", { Color = Library.Theme.TextOff, Size = 12,
					Sz = UDim2.new(1, -50, 0, 14) })
				local valLbl = label(row, "", { Color = Library.Theme.Accent, Size = 12,
					Sz = UDim2.new(0, 50, 0, 14), Pos = UDim2.new(1, -50, 0, 0),
					XAlign = Enum.TextXAlignment.Right })
				Library:RegisterAccent(valLbl, "TextColor3")
				local bar = create("Frame", { Parent = row, BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 6),
					BackgroundColor3 = Library.Theme.Panel2 })
				border(bar, Library.Theme.Border, 1); corner(bar, 3)
				local fill = create("Frame", { Parent = bar, BorderSizePixel = 0,
					Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Library.Theme.Accent })
				Library:RegisterAccent(fill, "BackgroundColor3")

				local api = {}
				function api:Set(v, skip)
					value = round(math.clamp(v, min, max))
					Library.Flags[opts.Flag or opts.Text] = value
					local a = (max - min == 0) and 0 or (value - min) / (max - min)
					fill.Size = UDim2.new(a, 0, 1, 0)
					valLbl.Text = tostring(value) .. suffix
					if opts.Callback and not skip then pcall(opts.Callback, value) end
				end
				function api:Get() return value end

				local dragging = false
				local function upd(inp)
					local rel = math.clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
					api:Set(min + (max - min) * rel)
				end
				bar.InputBegan:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; upd(i) end
				end)
				Library:Connect(UserInputService.InputChanged, function(i)
					if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
				end)
				Library:Connect(UserInputService.InputEnded, function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
				end)
				api.Row = row
				function api:SetVisible(v) row.Visible = v end
				if opts.Flag then Library.Options[opts.Flag] = api end
				api:Set(value, true)
				return api
			end

			----------------------------------------------------------
			-- DROPDOWN
			----------------------------------------------------------
			function comp:AddDropdown(opts)
				local values = opts.Options or {}
				local selected = opts.Default or values[1]
				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18), LayoutOrder = ord() })
				indent(row, opts.Sub)
				local head = create("TextButton", { Parent = row, AutoButtonColor = false, Text = "",
					BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
				border(head, Library.Theme.Border, 1); corner(head, 4)
				label(head, opts.Text or "", { Color = Library.Theme.TextOff, Size = 12,
						Sz = UDim2.new(0.5, -6, 1, 0), Pos = UDim2.new(0, 6, 0, 0), Truncate = Enum.TextTruncate.AtEnd })
					local disp = label(head, tostring(selected), { Color = Library.Theme.TextOn, Size = 12,
					Sz = UDim2.new(0.5, -20, 1, 0), Pos = UDim2.new(0.5, 0, 0, 0), XAlign = Enum.TextXAlignment.Right, Truncate = Enum.TextTruncate.AtEnd })
				local arw = label(head, "▾", { Color = Library.Theme.TextOff, Size = 11,
					Sz = UDim2.new(0, 16, 1, 0), Pos = UDim2.new(1, -16, 0, 0), XAlign = Enum.TextXAlignment.Center })

				local listFrame = create("Frame", { Parent = scroll, BackgroundColor3 = Library.Theme.Bg,
					BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true,
					Visible = false, LayoutOrder = order })
				indent(listFrame, opts.Sub)
				border(listFrame, Library.Theme.Border, 1)
				local listInner = create("Frame", { Parent = listFrame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })
				create("UIListLayout", { Parent = listInner, SortOrder = Enum.SortOrder.LayoutOrder })

				local api, open = {}, false
				local btns = {}
				local function refresh()
					disp.Text = tostring(selected)
					for v, b in pairs(btns) do
						b.TextColor3 = (v == selected) and Library.Theme.Accent or Library.Theme.TextOff
					end
				end
				function api:Set(v, skip)
					selected = v; Library.Flags[opts.Flag or opts.Text] = v; refresh()
					if opts.Callback and not skip then pcall(opts.Callback, v) end
				end
				function api:Get() return selected end

				for _, v in ipairs(values) do
					local b = create("TextButton", { Parent = listInner, AutoButtonColor = false,
						BackgroundColor3 = Library.Theme.Bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 18),
						Font = Library.Font, Text = "  " .. tostring(v), TextSize = 12,
						TextColor3 = Library.Theme.TextOff, TextXAlignment = Enum.TextXAlignment.Left })
					btns[v] = b
					b.MouseEnter:Connect(function() b.BackgroundColor3 = Library.Theme.Panel2 end)
					b.MouseLeave:Connect(function() b.BackgroundColor3 = Library.Theme.Bg end)
					b.MouseButton1Click:Connect(function() api:Set(v); open = false; listFrame.Visible = false; listFrame.Size = UDim2.new(1, 0, 0, 0); arw.Text = "▾" end)
				end
				head.MouseButton1Click:Connect(function()
					open = not open
					listFrame.Visible = true
					listFrame.Size = UDim2.new(1, 0, 0, open and (#values * 18) or 0)
					arw.Text = open and "▴" or "▾"
					if not open then task.defer(function() if not open then listFrame.Visible = false end end) end
				end)
				api.Row = row
				function api:SetVisible(v) row.Visible = v; if not v then listFrame.Visible = false; listFrame.Size = UDim2.new(1, 0, 0, 0) end end
				if opts.Flag then Library.Options[opts.Flag] = api end
				refresh()
				return api
			end

			----------------------------------------------------------
			-- BUTTON / LABEL
			----------------------------------------------------------
			function comp:AddButton(opts)
				local b = create("TextButton", { Parent = scroll, AutoButtonColor = false,
					BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 20), LayoutOrder = ord(), Font = Library.Font,
					Text = opts.Text or "Button", TextSize = 12, TextColor3 = Library.Theme.TextOn })
				border(b, Library.Theme.Border, 1); corner(b, 4)
				b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = Library.Theme.Hover }):Play() end)
				b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = Library.Theme.Panel2 }):Play() end)
				b.MouseButton1Click:Connect(function() if opts.Callback then pcall(opts.Callback) end end)
				return { Instance = b }
			end
			function comp:AddLabel(text)
				local l = create("TextLabel", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = ord(),
					Font = Library.Font, Text = text, TextSize = 11, TextColor3 = Library.Theme.TextOff,
					TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
				return { Set = function(_, t) l.Text = t end, Instance = l }
			end
			----------------------------------------------------------
			-- COLOR PICKER (HSV square + hue bar + hex)
			----------------------------------------------------------
			function comp:AddColorPicker(opts)
				local h, s, v = Color3.toHSV(opts.Default or Color3.fromRGB(255, 0, 0))
				local open = false
				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = ord() })
				indent(row, opts.Sub)
				label(row, opts.Text or "Color", { Color = Library.Theme.TextOff, Size = 12, Sz = UDim2.new(1, -44, 1, 0), Pos = UDim2.new(0, 6, 0, 0) })
				local preview = create("TextButton", { Parent = row, Text = "", AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.new(0, 32, 0, 14),
					BackgroundColor3 = Color3.fromHSV(h, s, v), BorderSizePixel = 0, AutoButtonColor = false })
				corner(preview, 3); border(preview, Library.Theme.Border, 1)

				local panel = create("Frame", { Parent = scroll, BackgroundColor3 = Library.Theme.Bg, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, Visible = false, LayoutOrder = ord() })
				border(panel, Library.Theme.Border, 1); corner(panel, 4)
				local pin = create("Frame", { Parent = panel, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 1, -16) })

				local sv = create("Frame", { Parent = pin, Size = UDim2.new(1, -26, 0, 90), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0 })
				corner(sv, 3)
				local satO = create("Frame", { Parent = sv, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
				corner(satO, 3)
				create("UIGradient", { Parent = satO, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
				local valO = create("Frame", { Parent = sv, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
				corner(valO, 3)
				create("UIGradient", { Parent = valO, Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) })
				local svCur = create("Frame", { Parent = sv, Size = UDim2.new(0, 6, 0, 6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
				corner(svCur, 3); border(svCur, Color3.new(0, 0, 0), 1)

				local hue = create("Frame", { Parent = pin, Size = UDim2.new(0, 18, 0, 90), Position = UDim2.new(1, -18, 0, 0), BorderSizePixel = 0 })
				corner(hue, 3)
				create("UIGradient", { Parent = hue, Rotation = 90, Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
					ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
					ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)) }) })
				local hueCur = create("Frame", { Parent = hue, Size = UDim2.new(1, 4, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, h, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
				border(hueCur, Color3.new(0, 0, 0), 1)

				local hexBox = create("TextBox", { Parent = pin, Position = UDim2.new(0, 0, 0, 96), Size = UDim2.new(1, 0, 0, 18),
					BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Font = Library.Font, TextSize = 12,
					TextColor3 = Library.Theme.TextOn, Text = "#FFFFFF", ClearTextOnFocus = false })
				corner(hexBox, 3); border(hexBox, Library.Theme.Border, 1)

				local api = {}
				local function col() return Color3.fromHSV(h, s, v) end
				local function refresh(skip)
					local c = col()
					preview.BackgroundColor3 = c
					sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					svCur.Position = UDim2.new(s, 0, 1 - v, 0)
					hueCur.Position = UDim2.new(0.5, 0, h, 0)
					hexBox.Text = string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
					Library.Flags[opts.Flag or opts.Text] = { c.R, c.G, c.B }
					if opts.Callback and not skip then pcall(opts.Callback, c) end
				end
				function api:Set(c, skip)
					if type(c) == "table" then c = Color3.new(c[1], c[2], c[3]) end
					if type(c) == "string" then local r, g, b = c:match("#?(%x%x)(%x%x)(%x%x)"); if r then c = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)) end end
					if typeof(c) == "Color3" then h, s, v = Color3.toHSV(c) end
					refresh(skip)
				end
				function api:Get() return col() end
				function api:SetVisible(vis) row.Visible = vis; if not vis then panel.Visible = false; panel.Size = UDim2.new(1, 0, 0, 0); open = false end end

				preview.MouseButton1Click:Connect(function()
					open = not open
					panel.Visible = true
					panel.Size = UDim2.new(1, 0, 0, open and 124 or 0)
					if not open then task.defer(function() if not open then panel.Visible = false end end) end
				end)
				local dragSV, dragHue = false, false
				local function inside(pos, obj) local ap, sz = obj.AbsolutePosition, obj.AbsoluteSize; return pos.X >= ap.X and pos.X <= ap.X + sz.X and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y end
				Library:Connect(UserInputService.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and open and guiVisible(panel) then if inside(i.Position, sv) then dragSV = true elseif inside(i.Position, hue) then dragHue = true end end end)
				Library:Connect(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV, dragHue = false, false end end)
				Library:Connect(UserInputService.InputChanged, function(i)
					if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					if dragSV then
						s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
						v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
						refresh()
					elseif dragHue then
						h = math.clamp((i.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
						refresh()
					end
				end)
				hexBox.FocusLost:Connect(function() api:Set(hexBox.Text) end)

				if opts.Flag then Library.Options[opts.Flag] = api end
				refresh(true)
				return api
			end

			function comp:Scroll() return scroll end

			return comp
		end

		return pageApi
	end

	if not ActiveCat then selectCat(cat) end
	return catApi
end

--=====================================================================
--  CONFIG
--=====================================================================
-- named multi-config system: files on executors, in-memory table otherwise
local Config, memCfgs = {}, {}
local function cfgPath(name) return FS.folder .. "/" .. name .. ".json" end
function Config:Save(name)
	name = name or "default"
	local data = HttpService:JSONEncode(Library.Flags)
	if FS.enabled then
		local ok = pcall(writefile, cfgPath(name), data)
		if not ok then memCfgs[name] = data end
	else memCfgs[name] = data end
	Library:Notify("Config", "Saved '" .. name .. "'.", 2, "good")
end
function Config:Load(name)
	name = name or "default"
	local raw
	if FS.enabled and pcall(function() return isfile(cfgPath(name)) end) and isfile(cfgPath(name)) then
		raw = readfile(cfgPath(name))
	else raw = memCfgs[name] end
	if not raw then Library:Notify("Config", "No config '" .. name .. "'.", 3); return false end
	local ok, dec = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(dec) ~= "table" then Library:Notify("Config", "Config unreadable.", 3); return false end
	-- CLEAN SLATE: flip every toggle OFF before applying, so nothing the
	-- config doesn't mention (script defaults, the previous config) is left
	-- running - a loaded config gives you exactly what it saved, nothing else
	for flag, opt in pairs(Library.Options) do
		if type(Library.Flags[flag]) == "boolean" and Library.Flags[flag] and opt.Set then
			pcall(opt.Set, opt, false)
		end
	end
	for flag, val in pairs(dec) do
		local opt = Library.Options[flag]
		if opt and opt.Set then pcall(opt.Set, opt, val) end
	end
	-- force every on-toggle to the FINAL accent so none are left showing an old
	-- accent colour (the red-while-purple look) from before the config applied.
	-- (uses Flags, not F - F isn't in scope this early in the file)
	if not Library.Flags["rgb_accent"] and not Library.Flags["rgb_sync"] then
		Library:ApplyAccent(Library.Theme.Accent, false)
	end
	Library:Notify("Config", "Loaded '" .. name .. "'.", 2, "good")
	return true
end
function Config:Delete(name)
	if FS.enabled and typeof(delfile) == "function" then pcall(delfile, cfgPath(name)) end
	memCfgs[name] = nil
end
function Config:List()
	local names = {}
	if FS.enabled and typeof(listfiles) == "function" then
		local ok, files = pcall(listfiles, FS.folder)
		if ok then
			for _, f in ipairs(files) do
				local n = f:match("([^/\\]+)%.json$")
				if n then names[#names + 1] = n end
			end
		end
	end
	for n in pairs(memCfgs) do
		local dupe = false
		for _, e in ipairs(names) do if e == n then dupe = true break end end
		if not dupe then names[#names + 1] = n end
	end
	table.sort(names)
	return names
end

--=====================================================================
--  FEATURE STATE + HELPERS
--=====================================================================
local F = {}
Library:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function() Camera = Workspace.CurrentCamera end)
local function getHumanoid() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getChar() local c = LocalPlayer.Character; return (c and c:FindFirstChild("HumanoidRootPart")) and c or nil end

local function isDown(key)
	if not key then return false end
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.KeyCode then return UserInputService:IsKeyDown(key)
		elseif key.EnumType == Enum.UserInputType then return UserInputService:IsMouseButtonPressed(key) end
	end
	return false
end
-- candidate parts used by the "Closest" target mode
local CLOSEST_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart",
	"LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftHand", "RightHand" }

local function partOf(char, want, mouse)
	if want == "Head" then
		return char:FindFirstChild("Head")
	elseif want == "Torso" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	elseif want == "Random" then
		return (math.random() > 0.5) and char:FindFirstChild("Head")
			or (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
	elseif want == "Closest" and mouse then
		-- pick whichever body part sits nearest to the crosshair
		local best, bestD
		for _, n in ipairs(CLOSEST_PARTS) do
			local p = char:FindFirstChild(n)
			if p then
				local sp, on = Camera:WorldToViewportPoint(p.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
					if not bestD or d < bestD then best, bestD = p, d end
				end
			end
		end
		return best
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

-- Friends: excluded from aim / rage / esp / snap.  Keyed by name so they persist.
F.FriendNames = {}
local function isFriend(plr) return F.FriendNames[plr.Name] == true end

-- Global RGB driver shared by ESP / snaplines / FOV circle
F.RGB = { enabled = false, speed = 2, color = Color3.fromRGB(255, 0, 0) }
local function rgbOr(default) return F.RGB.enabled and F.RGB.color or default end

-- shared color palette used by aim visuals + esp (must live above every
-- feature that references it - locals defined lower are invisible up here)
local COLORS = {
	Red = Color3.fromRGB(230,45,55), Crimson = Color3.fromRGB(170,20,60), Rose = Color3.fromRGB(255,90,120),
	Pink = Color3.fromRGB(255,100,190), Magenta = Color3.fromRGB(230,40,220), Purple = Color3.fromRGB(150,90,255),
	Violet = Color3.fromRGB(120,70,230), Indigo = Color3.fromRGB(80,80,240), Blue = Color3.fromRGB(50,130,255),
	Sky = Color3.fromRGB(90,180,255), Cyan = Color3.fromRGB(50,225,235), Teal = Color3.fromRGB(30,200,180),
	Mint = Color3.fromRGB(120,240,190), Green = Color3.fromRGB(70,215,110), Lime = Color3.fromRGB(170,240,70),
	Yellow = Color3.fromRGB(245,225,80), Gold = Color3.fromRGB(255,190,50), Orange = Color3.fromRGB(255,140,40),
	Coral = Color3.fromRGB(255,110,90), White = Color3.new(1,1,1), Black = Color3.fromRGB(15,15,20),
}

-- ===== shared animated-colour engine (defined up here so EVERY feature can
-- ===== use it - it used to live below the features that called it, which is
-- ===== why FOV circle / snapline animations silently never worked) =====
-- setGrad: drive a UIGradient for Gradient (static blend) / Wave (flowing).
-- Wave on a thin line (rot == 0) scrolls a 3-stop c1->c2->c1 blend along it
-- (the tracer wave); Wave on an area spins the gradient; Gradient is static.
local function setGrad(g, c1, c2, mode, speed, rot)
	g.Enabled = true
	g.Color = ColorSequence.new(c1, c2)
	g.Offset = Vector2.new(0, 0)
	if mode == "Wave" then
		if rot == 0 then
			g.Rotation = 0
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(0.5, c2), ColorSequenceKeypoint.new(1, c1) })
			g.Offset = Vector2.new(((tick() * (speed or 2) * 0.25) % 2) - 1, 0)
		else
			g.Rotation = (tick() * (speed or 2) * 45) % 360
		end
	else
		g.Rotation = rot or 45  -- static diagonal for areas; 0 = along the line
	end
end
-- true when a mode needs a real spatial UIGradient
local function usesGrad(mode) return mode == "Gradient" or mode == "Wave" end
-- single colour for things that can't hold a gradient (solid strokes,
-- adornments, highlights): Rainbow cycles, Pulse/Wave/Gradient breathe
-- between the two colours, RGB sync overrides everything
local function animColor(c1, c2, mode, speed)
	if F.RGB.enabled then return F.RGB.color end
	if mode == "Rainbow" then return Color3.fromHSV((tick() * (speed or 2) * 0.1) % 1, 0.9, 1) end
	if mode == "Pulse" or mode == "Wave" or mode == "Gradient" then
		return c1:Lerp(c2, (math.sin(tick() * (speed or 2)) + 1) / 2)
	end
	return c1
end

-- ===== draggable-frame position persistence (saved into configs) =====
-- flag value = {xScale, xOffset, yScale, yOffset}
local function posFlag(flag, holder)
	-- registered eagerly so Config:Load can restore the spot even before the
	-- frame has ever been built (the build then applies holder.pos)
	Library.Options[flag] = { Set = function(_, v)
		if type(v) == "table" and #v == 4 then
			holder.pos = v; Library.Flags[flag] = v
			if holder.gui then holder.gui.Position = UDim2.new(v[1], v[2], v[3], v[4]) end
		end
	end }
end
local function trackPos(flag, holder)
	-- call right after holder.gui exists: applies a loaded position, then
	-- keeps the flag in sync while the frame is dragged
	if holder.pos then holder.gui.Position = UDim2.new(holder.pos[1], holder.pos[2], holder.pos[3], holder.pos[4]) end
	holder.gui:GetPropertyChangedSignal("Position"):Connect(function()
		local p = holder.gui.Position
		Library.Flags[flag] = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	end)
end

--=====================================================================
--  AIM CATEGORY
--=====================================================================
local AimCat = Library:AddCategory("Aim", 1)

--== Aimbot ==--
local aimPage = AimCat:AddTab("Aimbot")
local aimP    = aimPage:AddPanel("Aimbot")
local aimP2   = aimPage:AddPanel("Settings")

-- fov = the EFFECTIVE fov every aim feature + the circle read; fovBase = what
-- the slider sets. Dynamic FOV scales fov = fovBase * dynScale while ADS.
F.Aim = { enabled = false, fov = 120, fovBase = 120, smooth = 3, part = "Head", prediction = 0, priority = "Crosshair",
	teamCheck = false, wallCheck = false, sticky = false, autoShoot = false, fireRate = 0.1, target = nil,
	hlTarget = false, targetColor = COLORS.Red, lockedChar = nil }

-- the bind chip on Enabled IS the hold aim-key (BindNoToggle keeps it from toggling the feature)
aimP:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Bind = true, BindNoToggle = true,
	Callback = function(on) F.Aim.enabled = on end })
aimP:AddToggle({ Text = "Team Check", Flag = "aim_team", Callback = function(on) F.Aim.teamCheck = on end })
aimP:AddToggle({ Text = "Visible Check", Flag = "aim_wall", Callback = function(on) F.Aim.wallCheck = on end })
aimP:AddToggle({ Text = "Sticky Target", Flag = "aim_sticky", Callback = function(on) F.Aim.sticky = on end })
aimP:AddToggle({ Text = "Auto Shoot", Flag = "aim_autoshoot", Callback = function(on) F.Aim.autoShoot = on end })
aimP:AddToggle({ Text = "Highlight Target", Flag = "aim_hltarget", Callback = function(on) F.Aim.hlTarget = on end })

aimP2:AddDropdown({ Text = "Target Part", Flag = "aim_part", Options = { "Closest", "Head", "Torso", "Random" },
	Default = "Head", Callback = function(v) F.Aim.part = v end })
aimP2:AddDropdown({ Text = "Priority", Flag = "aim_priority", Options = { "Crosshair", "Distance", "Health" },
	Default = "Crosshair", Callback = function(v) F.Aim.priority = v end })
aimP2:AddSlider({ Text = "Smoothing", Flag = "aim_smooth", Min = 1, Max = 20, Default = 3,
	Suffix = "x", Callback = function(v) F.Aim.smooth = v end })
aimP2:AddSlider({ Text = "Prediction", Flag = "aim_pred", Min = 0, Max = 1, Decimals = 2, Default = 0,
	Suffix = "x", Callback = function(v) F.Aim.prediction = v end })
aimP2:AddSlider({ Text = "Fire Rate", Flag = "aim_fire", Min = 0.02, Max = 0.5, Decimals = 2, Default = 0.1,
	Suffix = "s", Callback = function(v) F.Aim.fireRate = v end })
aimP2:AddColorPicker({ Text = "Target Color", Flag = "aim_targetcolor", Default = COLORS.Red,
	Callback = function(c) F.Aim.targetColor = c end })
aimP2:AddLabel("Target Color + Highlight Target: whoever the aimbot is locked onto has their whole ESP snap to this colour.")
aimP2:AddLabel("FOV lives on the AimVisuals tab, shared by every aim feature.")

-- shared visibility raycast
local function isVisible(char, pos)
	local origin = Camera.CFrame.Position
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
	local res = Workspace:Raycast(origin, pos - origin, rp)
	if not res then return true end
	return res.Instance:IsDescendantOf(char)
end

-- shared target acquisition (used by both aimbot and rage bot)
local function acquireTarget(cfg)
	local mouse = UserInputService:GetMouseLocation()
	local myPos = getChar() and getChar().HumanoidRootPart.Position
	local bestPart, bestScore
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isFriend(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 and not (cfg.teamCheck and plr.Team == LocalPlayer.Team) then
				local part = partOf(char, cfg.part, mouse)
				if part then
					local sp, on = Camera:WorldToViewportPoint(part.Position)
					if on and sp.Z > 0 then
						local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
						if (not cfg.fov or d <= cfg.fov) and (not cfg.wallCheck or isVisible(char, part.Position)) then
							-- score by chosen priority (lower = better)
							local pr = cfg.priority or "Crosshair"
							local score = d
							if pr == "Distance" then score = myPos and (part.Position - myPos).Magnitude or d
							elseif pr == "Health" then score = hum.Health end
							if not bestScore or score < bestScore then bestPart, bestScore = part, score end
						end
					end
				end
			end
		end
	end
	return bestPart
end

-- point the camera at a part, with smoothing + velocity prediction.
-- When the STANDALONE bypass camera owns the view, writing Camera.CFrame is
-- useless (the orbit cam rebuilds it from its yaw/pitch right after) - so we
-- steer the orbit cam's yaw/pitch instead. Piggyback mode and normal play
-- take the plain Camera.CFrame path.
local function aimAt(part, smooth, pred, dt)
	if not part or not part.Parent then return end
	local aimPos = part.Position
	if pred and pred > 0 then
		local vel = part.AssemblyLinearVelocity
		aimPos = aimPos + vel * pred
	end
	local alpha = (smooth <= 1) and 1 or math.clamp((1 / smooth) * (dt * 60), 0, 1)
	local cam = F.Cam
	if cam and cam.bypass and cam.mode == "Third Person" and cam.bypassMode == "Standalone" and cam.yaw then
		local dir = aimPos - Camera.CFrame.Position
		if dir.Magnitude < 0.05 then return end
		dir = dir.Unit
		local ty = math.atan2(-dir.X, -dir.Z)
		local tp = math.asin(math.clamp(dir.Y, -1, 1))
		local dy = (ty - cam.yaw + math.pi) % (math.pi * 2) - math.pi   -- shortest way round
		cam.yaw = cam.yaw + dy * alpha
		cam.pitch = math.clamp(cam.pitch + (tp - cam.pitch) * alpha, -1.45, 1.45)
		return
	end
	local goal = CFrame.new(Camera.CFrame.Position, aimPos)
	if smooth <= 1 then
		Camera.CFrame = goal
	else
		Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
	end
end

local aimFireCd = 0
Library:StartLoop("aimbot", RunService.RenderStepped, function(dt)
	local rageOwns = F.Rage and F.Rage.enabled and F.Rage.targetChar   -- don't wipe rage's highlight
	if not F.Aim.enabled or Library.Destroyed then
		if not rageOwns then F.Aim.lockedChar = nil end
		return
	end
	local opt = Library.Options["aim_enabled"]
	local key = opt and opt.GetKey and opt:GetKey()
	if not isDown(key) then
		F.Aim.target = nil
		if not rageOwns then F.Aim.lockedChar = nil end
		return
	end
	local part = F.Aim.target
	if not part or not part.Parent then part = acquireTarget(F.Aim) end
	F.Aim.target = F.Aim.sticky and part or nil
	F.Aim.lockedChar = part and part.Parent or nil   -- Highlight Target reads this
	aimAt(part, F.Aim.smooth, F.Aim.prediction, dt)
	-- optional auto-shoot while aiming a valid target
	if part and F.Aim.autoShoot and hasMouseClick and os.clock() >= aimFireCd then
		aimFireCd = os.clock() + F.Aim.fireRate
		pcall(mouse1click)
	end
end)

--== Silent Aim ==--
local silentPage = AimCat:AddTab("Silent Aim")
local silentP  = silentPage:AddPanel("Silent Aim")
local silentP2 = silentPage:AddPanel("Settings")
F.Silent = { enabled = false, part = "Head", teamCheck = false, wallCheck = false,
	priority = "Crosshair", autoShoot = true, fireRate = 0.1 }

silentP:AddToggle({ Text = "Enabled", Flag = "silent_enabled", Bind = true, BindNoToggle = true, Callback = function(on)
	F.Silent.enabled = on
	if on then Library:Notify("Silent Aim", "Bind the chip to hold, or leave [None] for always-on.", 4, "good") end
	if on and not hasMouseClick then Library:Notify("Silent Aim", "Firing needs an executor (mouse1click).", 4) end
end })
silentP:AddToggle({ Text = "Auto Shoot", Flag = "silent_shoot", Default = true, Callback = function(on) F.Silent.autoShoot = on end })
silentP:AddToggle({ Text = "Team Check", Flag = "silent_team", Callback = function(on) F.Silent.teamCheck = on end })
silentP:AddToggle({ Text = "Visible Check", Flag = "silent_wall", Callback = function(on) F.Silent.wallCheck = on end })

silentP2:AddDropdown({ Text = "Target Part", Flag = "silent_part", Options = { "Closest", "Head", "Torso", "Random" },
	Default = "Head", Callback = function(v) F.Silent.part = v end })
silentP2:AddDropdown({ Text = "Priority", Flag = "silent_priority", Options = { "Crosshair", "Distance", "Health" },
	Default = "Crosshair", Callback = function(v) F.Silent.priority = v end })
silentP2:AddSlider({ Text = "Fire Rate", Flag = "silent_fire", Min = 0.02, Max = 0.5, Decimals = 2, Default = 0.1,
	Suffix = "s", Callback = function(v) F.Silent.fireRate = v end })
silentP2:AddLabel("Snaps to the target only on the shot frame - your view stays put otherwise. Uses the shared FOV. True input-synced silent aim needs game-specific hooks.")

-- flick-fire: snap to the target, fire, and restore the camera in the SAME frame so the
-- aim is invisible. No bind = always active; bind a key to gate it to when you hold it.
local silentCd = 0
Library:StartLoop("silent", RunService.Heartbeat, function()
	if not F.Silent.enabled or Library.Destroyed then return end
	local opt = Library.Options["silent_enabled"]
	local key = opt and opt.GetKey and opt:GetKey()
	if key and not isDown(key) then return end            -- if a key is bound, hold it; else always-on
	if not (F.Silent.autoShoot and hasMouseClick) or os.clock() < silentCd then return end
	local part = acquireTarget({ fov = F.Aim.fov, teamCheck = F.Silent.teamCheck,
		wallCheck = F.Silent.wallCheck, part = F.Silent.part, priority = F.Silent.priority })
	if part then
		local save = Camera.CFrame
		Camera.CFrame = CFrame.new(save.Position, part.Position)  -- aim
		silentCd = os.clock() + F.Silent.fireRate
		pcall(mouse1click)                                        -- fire (reads camera synchronously)
		Camera.CFrame = save                                     -- restore instantly (invisible)
	end
end)

--== Rage Bot ==--
local ragePage = AimCat:AddTab("Rage")
local rageP    = ragePage:AddPanel("Rage Bot")
local rageP2   = ragePage:AddPanel("Config")
F.Rage = { enabled = false, onlyFov = false, teamCheck = false, wallCheck = false, autoShoot = true,
	silent = false, faceTarget = false, part = "Head", smooth = 1, prediction = 0, fireRate = 0.05,
	targetChar = nil }

-- Fully automatic. Turn it on (or press the bound key) and it ALWAYS snaps to
-- the nearest enemy and keeps killing - walk around and it clears the lobby.
rageP:AddToggle({ Text = "Rage Bot", Flag = "rage_enabled", Bind = true, Callback = function(on)
	F.Rage.enabled = on
	if on then Library:Notify("Rage", "Rage ON - auto-killing the nearest enemy. Walk around.", 4, "good") end
	if on and not hasMouseClick then Library:Notify("Rage", "Shooting needs an executor (mouse1click) - aim-only here.", 4) end
end })
rageP:AddToggle({ Text = "Auto Shoot", Flag = "rage_autoshoot", Default = true, Callback = function(on) F.Rage.autoShoot = on end })
rageP:AddToggle({ Text = "Silent", Flag = "rage_silent", Callback = function(on) F.Rage.silent = on end })
rageP:AddToggle({ Text = "Face Target On Shot", Flag = "rage_face", Callback = function(on) F.Rage.faceTarget = on end })
rageP:AddToggle({ Text = "Only In FOV Circle", Flag = "rage_fov", Callback = function(on) F.Rage.onlyFov = on end })
rageP:AddToggle({ Text = "Visible Check", Flag = "rage_wall", Callback = function(on) F.Rage.wallCheck = on end })
rageP:AddToggle({ Text = "Team Check", Flag = "rage_team", Callback = function(on) F.Rage.teamCheck = on end })

rageP2:AddDropdown({ Text = "Target Part", Flag = "rage_part", Options = { "Closest", "Head", "Torso", "Random" },
	Default = "Head", Callback = function(v) F.Rage.part = v end })
rageP2:AddSlider({ Text = "Smoothing", Flag = "rage_smooth", Min = 1, Max = 15, Default = 1,
	Suffix = "x", Callback = function(v) F.Rage.smooth = v end })
rageP2:AddSlider({ Text = "Prediction", Flag = "rage_pred", Min = 0, Max = 1, Decimals = 2, Default = 0,
	Suffix = "x", Callback = function(v) F.Rage.prediction = v end })
rageP2:AddSlider({ Text = "Fire Rate", Flag = "rage_fire", Min = 0.02, Max = 0.5, Decimals = 2, Default = 0.05,
	Suffix = "s", Callback = function(v) F.Rage.fireRate = v end })
rageP2:AddLabel("Fires the instant it's on a target (triggerbot-style, no warm-up) at the fire rate.")

-- picks the enemy to rage: nearest to crosshair when Only-In-FOV, otherwise nearest in 3D
-- (so it locks people even when they're off-screen / behind you and snaps the camera onto them)
local function acquireRageTarget()
	local myChar = getChar()
	local myPos = myChar and myChar.HumanoidRootPart.Position
	local mouse = UserInputService:GetMouseLocation()
	local bestPart, bestScore
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isFriend(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 and not (F.Rage.teamCheck and plr.Team == LocalPlayer.Team) then
				local part = partOf(char, F.Rage.part, mouse)
				if part and (not F.Rage.wallCheck or isVisible(char, part.Position)) then
					local score
					if F.Rage.onlyFov then
						local sp, on = Camera:WorldToViewportPoint(part.Position)
						if on and sp.Z > 0 then
							local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
							if d <= F.Aim.fov then score = d end
						end
					else
						score = myPos and (part.Position - myPos).Magnitude or 0
					end
					if score and (not bestScore or score < bestScore) then
						bestPart, bestScore = part, score
					end
				end
			end
		end
	end
	return bestPart
end

local rageFireCd = 0
Library:StartLoop("rage", RunService.RenderStepped, function(dt)
	if not F.Rage.enabled or Library.Destroyed then F.Rage.targetChar = nil; return end
	local part = acquireRageTarget()
	if not part then F.Rage.targetChar = nil; return end
	local char = part.Parent
	F.Rage.targetChar = char
	if F.Aim.hlTarget then F.Aim.lockedChar = char end   -- Highlight Target covers rage too
	-- ALWAYS aim (unless silent, which flicks only on the shot) - bypass-cam aware
	if not F.Rage.silent then aimAt(part, F.Rage.smooth, F.Rage.prediction, dt) end
	-- fire the INSTANT we're on a target, no warm-up (triggerbot-style), paced
	-- by fire rate. Same click path as the aimbot's working auto-shoot.
	if F.Rage.autoShoot and hasMouseClick and os.clock() >= rageFireCd then
		rageFireCd = os.clock() + F.Rage.fireRate
		-- Face Target On Shot: one-frame BODY flick for games whose guns fire
		-- from the character, restored the same frame - so anti-aim spin/away is
		-- untouched and the shot still lines up
		local myChar = F.Rage.faceTarget and getChar() or nil
		local myHrp = myChar and myChar.HumanoidRootPart
		local saveCf
		if myHrp then
			local d = part.Position - myHrp.Position
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.05 then
				saveCf = myHrp.CFrame
				flat = flat.Unit
				myHrp.CFrame = CFrame.new(myHrp.Position) * CFrame.Angles(0, math.atan2(-flat.X, -flat.Z), 0)
			end
		end
		if F.Rage.silent then
			-- flick to the target for the shot only, then restore instantly (no visible aim)
			local save = Camera.CFrame
			Camera.CFrame = CFrame.new(save.Position, part.Position)
			pcall(mouse1click)
			Camera.CFrame = save
		else
			pcall(mouse1click)
		end
		if saveCf then myHrp.CFrame = saveCf end
	end
end)

--== Triggerbot ==--
local trigPage = AimCat:AddTab("Trigger")
local trigP    = trigPage:AddPanel("Triggerbot")
local trigP2   = trigPage:AddPanel("Config")
F.Trig = { enabled = false, mode = "Hold", toggled = false, delay = 0.05,
	teamCheck = false, aliveOnly = false, hitchance = 100 }

trigP:AddToggle({ Text = "Enabled", Flag = "trig_enabled", Callback = function(on)
	F.Trig.enabled = on; F.Trig.toggled = false
	if on and not hasMouseClick then Library:Notify("Trigger", "No mouse1click here - visual detection only.", 4) end
end })
trigP:AddToggle({ Text = "Team Check", Flag = "trig_team", Callback = function(on) F.Trig.teamCheck = on end })
trigP:AddToggle({ Text = "Alive Target Only", Flag = "trig_alive", Callback = function(on) F.Trig.aliveOnly = on end })
trigP:AddDropdown({ Text = "Mode", Flag = "trig_mode", Options = { "Hold", "Toggle" }, Default = "Hold",
	Callback = function(v) F.Trig.mode = v; F.Trig.toggled = false end })
trigP:AddKeybind({ Text = "Trigger Key", Flag = "trig_key", Callback = function()
	-- in Toggle mode, pressing the key flips the active state; in Hold mode the loop reads the key directly
	if F.Trig.mode == "Toggle" and F.Trig.enabled then
		F.Trig.toggled = not F.Trig.toggled
		Library:Notify("Trigger", F.Trig.toggled and "Triggerbot ON" or "Triggerbot OFF", 1.5, F.Trig.toggled and "good" or nil)
	end
end })

trigP2:AddSlider({ Text = "Delay", Flag = "trig_delay", Min = 0, Max = 0.5, Decimals = 2, Default = 0.05,
	Suffix = "s", Callback = function(v) F.Trig.delay = v end })
trigP2:AddSlider({ Text = "Hit Chance", Flag = "trig_hc", Min = 1, Max = 100, Default = 100,
	Suffix = "%", Callback = function(v) F.Trig.hitchance = v end })

local trigCooldown = 0
Library:StartLoop("trigger", RunService.Heartbeat, function()
	if not F.Trig.enabled or Library.Destroyed then return end
	local key = Library.Options["trig_key"] and Library.Options["trig_key"]:Get()
	local armed = (F.Trig.mode == "Toggle") and F.Trig.toggled or (F.Trig.mode == "Hold" and isDown(key))
	if not armed then return end
	if os.clock() < trigCooldown then return end
	local mouse = UserInputService:GetMouseLocation()
	local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 2000, rp)
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local aliveOk = (not F.Trig.aliveOnly) or (hum and hum.Health > 0)
		if plr and plr ~= LocalPlayer and not isFriend(plr) and aliveOk
			and not (F.Trig.teamCheck and plr.Team == LocalPlayer.Team) then
			if math.random(1, 100) <= F.Trig.hitchance then
				trigCooldown = os.clock() + F.Trig.delay
				if hasMouseClick then pcall(mouse1click) end
			end
		end
	end
end)

--== AimVisuals ==--
local avPage = AimCat:AddTab("AimVisuals")
local avP    = avPage:AddPanel("FOV Circle")
local avP2   = avPage:AddPanel("Snaplines")
F.FOVc = { enabled = false, color = COLORS.Red, color2 = COLORS.Cyan, filled = false,
	fillTrans = 0.8, anim = "Off", animSpeed = 2, thick = 1, gui = nil,
	dynamic = false, dynMult = 2, dynSmooth = 0.65, dynScale = 1 }

local function buildFOV()
	if F.FOVc.gui then return end
	local ring = create("Frame", { Parent = ScreenGui, Name = "FOVRing", Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = F.FOVc.color,
		BackgroundTransparency = 1, BorderSizePixel = 0 })
	create("UICorner", { Parent = ring, CornerRadius = UDim.new(1, 0) })
	F.FOVc.stroke = create("UIStroke", { Parent = ring, Color = F.FOVc.color, Thickness = 1 })
	F.FOVc.grad = create("UIGradient", { Parent = ring, Enabled = false })          -- fill gradient
	F.FOVc.strokeGrad = create("UIGradient", { Parent = F.FOVc.stroke, Enabled = false })  -- outline gradient (a gradient under the frame does NOT touch the stroke)
	F.FOVc.gui = ring
end
local function showFovSubs(v)
	for _, f in ipairs({ "fovc_fill", "fovc_filltrans", "fovc_color", "fovc_color2", "fovc_anim", "fovc_animspeed", "fovc_thick" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
avP:AddToggle({ Text = "Show FOV Circle", Flag = "fovc", Callback = function(on)
	F.FOVc.enabled = on; showFovSubs(on)
	if on then
		buildFOV(); F.FOVc.gui.Visible = true
		Library:StartLoop("fovc", RunService.RenderStepped, function()
			local gui = F.FOVc.gui
			local m = UserInputService:GetMouseLocation()
			gui.Position = UDim2.fromOffset(m.X, m.Y)
			local d = (F.Aim.fov or 120) * 2
			gui.Size = UDim2.fromOffset(d, d)
			gui.BackgroundTransparency = F.FOVc.filled and F.FOVc.fillTrans or 1
			F.FOVc.stroke.Thickness = F.FOVc.thick
			local mode = F.FOVc.anim
			if not F.RGB.enabled and usesGrad(mode) then
				-- two-colour blend on the fill AND the outline; Wave spins it round the ring
				setGrad(F.FOVc.grad, F.FOVc.color, F.FOVc.color2, mode, F.FOVc.animSpeed)
				setGrad(F.FOVc.strokeGrad, F.FOVc.color, F.FOVc.color2, mode, F.FOVc.animSpeed)
				gui.BackgroundColor3 = Color3.new(1, 1, 1)
				F.FOVc.stroke.Color = Color3.new(1, 1, 1)
			else
				F.FOVc.grad.Enabled = false; F.FOVc.strokeGrad.Enabled = false
				local c = animColor(F.FOVc.color, F.FOVc.color2, mode, F.FOVc.animSpeed)
				gui.BackgroundColor3 = c
				F.FOVc.stroke.Color = c
			end
		end)
	else Library:StopLoop("fovc"); if F.FOVc.gui then F.FOVc.gui.Visible = false end end
end })
avP:AddSlider({ Text = "FOV", Flag = "aim_fov", Min = 20, Max = 500, Default = 120, Callback = function(v)
	F.Aim.fovBase = v
	if not F.FOVc.dynamic then F.Aim.fov = v end   -- dynamic driver owns fov while on
end })
-- Dynamic FOV: hold Right Click (aim in) and the FOV enlarges by the multiplier
-- (smoothly), then shrinks back on release. Scales the REAL fov, so the circle
-- AND every aim feature widen while you're ADS. Independent of the circle being shown.
local function showDynSubs(v)
	for _, f in ipairs({ "fovc_dynmult", "fovc_dynsmooth" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
avP:AddToggle({ Text = "Dynamic FOV", Flag = "fovc_dyn", Callback = function(on)
	F.FOVc.dynamic = on; showDynSubs(on)
	if on then
		Library:StartLoop("dynfov", RunService.RenderStepped, function(dt)
			local aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			local goal = aiming and F.FOVc.dynMult or 1
			if F.FOVc.dynSmooth > 0 then
				local alpha = math.clamp(1 - (F.FOVc.dynSmooth ^ (dt * 60)), 0.05, 1)
				F.FOVc.dynScale = F.FOVc.dynScale + (goal - F.FOVc.dynScale) * alpha
			else
				F.FOVc.dynScale = goal
			end
			F.Aim.fov = F.Aim.fovBase * F.FOVc.dynScale
		end)
	else
		Library:StopLoop("dynfov"); F.FOVc.dynScale = 1; F.Aim.fov = F.Aim.fovBase
	end
end })
avP:AddSlider({ Text = "Dynamic Mult", Flag = "fovc_dynmult", Min = 1.1, Max = 4, Decimals = 1, Default = 2, Suffix = "x", Sub = true,
	Callback = function(v) F.FOVc.dynMult = v end })
avP:AddSlider({ Text = "Dynamic Smooth", Flag = "fovc_dynsmooth", Min = 0, Max = 0.9, Decimals = 2, Default = 0.65, Sub = true,
	Callback = function(v) F.FOVc.dynSmooth = v end })
showDynSubs(false)
avP:AddToggle({ Text = "Filled", Flag = "fovc_fill", Callback = function(on) F.FOVc.filled = on end })
avP:AddSlider({ Text = "Fill Transparency", Flag = "fovc_filltrans", Min = 0, Max = 1, Decimals = 2, Default = 0.8, Sub = true, Callback = function(v) F.FOVc.fillTrans = v end })
avP:AddColorPicker({ Text = "Color 1", Flag = "fovc_color", Default = COLORS.Red, Callback = function(c) F.FOVc.color = c end })
avP:AddColorPicker({ Text = "Color 2", Flag = "fovc_color2", Default = COLORS.Cyan, Callback = function(c) F.FOVc.color2 = c end })
avP:AddDropdown({ Text = "Animation", Flag = "fovc_anim", Options = { "Off", "Gradient", "Wave", "Pulse", "Rainbow" },
	Default = "Off", Callback = function(v) F.FOVc.anim = v end })
avP:AddSlider({ Text = "Anim Speed", Flag = "fovc_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.FOVc.animSpeed = v end })
avP:AddSlider({ Text = "Thickness", Flag = "fovc_thick", Min = 1, Max = 6, Default = 1, Callback = function(v) F.FOVc.thick = v end })
showFovSubs(false)  -- FOV circle options hidden until it's toggled on

-- Snaplines: ONE line from the chosen origin to the enemy nearest your
-- crosshair, with the exact flowing Wave gradient the tracers use (default on)
F.Snap = { enabled = false, color = COLORS.Red, color2 = COLORS.Cyan, thickness = 1, wallCheck = false,
	teamCheck = false, fovOnly = false, anim = "Wave", animSpeed = 2, origin = "Bottom" }
local snapLine = create("Frame", { Parent = ScreenGui, Name = "Snapline", BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, BackgroundColor3 = COLORS.Red })
local snapGrad = create("UIGradient", { Parent = snapLine, Enabled = false })
local function showSnapSubs(v)
	for _, f in ipairs({ "snap_origin", "snap_fov", "snap_wall", "snap_team", "snap_thick",
		"snap_color", "snap_color2", "snap_anim", "snap_animspeed" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
avP2:AddToggle({ Text = "Snaplines", Flag = "snap", Callback = function(on)
	F.Snap.enabled = on; showSnapSubs(on)
	if on then
		Library:StartRenderLoop("snap", Enum.RenderPriority.Camera.Value + 2, function()
			local vp = Camera.ViewportSize
			local originPt
			if F.Snap.origin == "Crosshair" then originPt = UserInputService:GetMouseLocation()
			elseif F.Snap.origin == "Top" then originPt = Vector2.new(vp.X / 2, 0)
			else originPt = Vector2.new(vp.X / 2, vp.Y) end
			local mouseVp = UserInputService:GetMouseLocation()
			local bestPos, bestDist
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and not isFriend(plr) then
					local char = plr.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
					if head and hum and hum.Health > 0 and not (F.Snap.teamCheck and plr.Team == LocalPlayer.Team) then
						local sp, on2 = Camera:WorldToViewportPoint(head.Position)
						if on2 and sp.Z > 0 then
							local d = (Vector2.new(sp.X, sp.Y) - mouseVp).Magnitude
							local within = (not F.Snap.fovOnly) or d <= F.Aim.fov
							local vis = (not F.Snap.wallCheck) or isVisible(char, head.Position)
							if within and vis and (not bestDist or d < bestDist) then
								bestPos, bestDist = Vector2.new(sp.X, sp.Y), d
							end
						end
					end
				end
			end
			if bestPos then
				local mode = F.Snap.anim
				if not F.RGB.enabled and usesGrad(mode) then
					-- white base + scrolling 3-stop gradient = the tracer wave
					updateLine(snapLine, originPt, bestPos, F.Snap.thickness, Color3.new(1, 1, 1))
					setGrad(snapGrad, F.Snap.color, F.Snap.color2, mode, F.Snap.animSpeed, 0)
				else
					snapGrad.Enabled = false
					updateLine(snapLine, originPt, bestPos, F.Snap.thickness,
						animColor(F.Snap.color, F.Snap.color2, mode, F.Snap.animSpeed))
				end
				snapLine.Visible = true
			else
				snapLine.Visible = false
			end
		end)
	else Library:StopLoop("snap"); snapLine.Visible = false end
end })
avP2:AddDropdown({ Text = "Origin", Flag = "snap_origin", Options = { "Bottom", "Crosshair", "Top" },
	Default = "Bottom", Callback = function(v) F.Snap.origin = v end })
avP2:AddToggle({ Text = "Only In FOV", Flag = "snap_fov", Callback = function(on) F.Snap.fovOnly = on end })
avP2:AddToggle({ Text = "Visible Check", Flag = "snap_wall", Callback = function(on) F.Snap.wallCheck = on end })
avP2:AddToggle({ Text = "Team Check", Flag = "snap_team", Callback = function(on) F.Snap.teamCheck = on end })
avP2:AddSlider({ Text = "Thickness", Flag = "snap_thick", Min = 1, Max = 5, Default = 1, Callback = function(v) F.Snap.thickness = v end })
avP2:AddColorPicker({ Text = "Color 1", Flag = "snap_color", Default = COLORS.Red, Callback = function(c) F.Snap.color = c end })
avP2:AddColorPicker({ Text = "Color 2", Flag = "snap_color2", Default = COLORS.Cyan, Callback = function(c) F.Snap.color2 = c end })
avP2:AddDropdown({ Text = "Animation", Flag = "snap_anim", Options = { "Off", "Gradient", "Wave", "Pulse", "Rainbow" },
	Default = "Wave", Callback = function(v) F.Snap.anim = v end })
avP2:AddSlider({ Text = "Anim Speed", Flag = "snap_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.Snap.animSpeed = v end })
showSnapSubs(false)  -- hidden until Snaplines is toggled on

--=====================================================================
--  VISUALS CATEGORY
--=====================================================================
local VisCat = Library:AddCategory("Visuals", 2)

--== Players ==--
local playersPage = VisCat:AddTab("Players")
local espP  = playersPage:AddPanel("Elements")
local espP2 = playersPage:AddPanel("Options")

F.ESP = { enabled = false, chams = false, glow = false, box = false, skeleton = false, headDot = false,
	tracer = false, names = false, distance = false, health = false, healthbar = false, hbStyle = "Left",
	teamCheck = false, fill = 0.6, color = COLORS.Red, color2 = COLORS.Cyan, anim = "Off", animSpeed = 2,
	tracerOrigin = "Bottom", rainbow = false, boxThick = 2, lineThick = 1, headSize = 6,
	barMode = "ESP Colors", barColor = COLORS.Green, textMode = "ESP Colors", textColor = COLORS.White, objs = {} }

local espHolder = create("Frame", { Parent = ScreenGui, Name = "ESP",
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })

local R15_BONES = { {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"} }
-- R6 limbs are ONE part each, so centre-to-centre lines drew a star, not a
-- skeleton. Entries can carry object-space offsets: {part1, part2, off1, off2}
-- (top of an R6 limb = its shoulder/hip, bottom = its hand/foot).
local R6_BONES = {
	{"Head","Torso", nil, Vector3.new(0, 1, 0)},                            -- head -> shoulder line
	{"Torso","Torso", Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)},         -- spine
	{"Torso","Left Arm", Vector3.new(0, 1, 0), Vector3.new(0, 1, 0)},       -- left collar
	{"Left Arm","Left Arm", Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)},   -- left arm
	{"Torso","Right Arm", Vector3.new(0, 1, 0), Vector3.new(0, 1, 0)},      -- right collar
	{"Right Arm","Right Arm", Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)}, -- right arm
	{"Torso","Left Leg", Vector3.new(0, -1, 0), Vector3.new(0, 1, 0)},      -- left hip
	{"Left Leg","Left Leg", Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)},   -- left leg
	{"Torso","Right Leg", Vector3.new(0, -1, 0), Vector3.new(0, 1, 0)},     -- right hip
	{"Right Leg","Right Leg", Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)}, -- right leg
}

local function makeESPObj(plr)
	local o = {}
	o.box = create("Frame", { Parent = espHolder, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false })
	o.boxStroke = border(o.box, F.ESP.color, 1)
	o.boxGrad = create("UIGradient", { Parent = o.boxStroke, Enabled = false })  -- used in Gradient anim mode
	o.headDot = create("Frame", { Parent = espHolder, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false, BackgroundColor3 = F.ESP.color })
	create("UICorner", { Parent = o.headDot, CornerRadius = UDim.new(1, 0) })
	o.headGrad = create("UIGradient", { Parent = o.headDot, Enabled = false })
	o.tracer = create("Frame", { Parent = espHolder, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false, BackgroundColor3 = F.ESP.color })
	o.tracerGrad = create("UIGradient", { Parent = o.tracer, Enabled = false })  -- gradient along the tracer
	o.bones = {}
	o.boneGrads = {}
	for i = 1, #R15_BONES do
		o.bones[i] = create("Frame", { Parent = espHolder, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, BackgroundColor3 = F.ESP.color })
		o.boneGrads[i] = create("UIGradient", { Parent = o.bones[i], Enabled = false })  -- blend along each bone
	end
	-- health bar (background + fill), positioned each frame relative to the 2D box
	o.hbBg = create("Frame", { Parent = espHolder, BorderSizePixel = 0, Visible = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.25 })
	o.hbFill = create("Frame", { Parent = o.hbBg, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(0, 255, 0) })
	o.hbGrad = create("UIGradient", { Parent = o.hbFill, Enabled = false })  -- wave flow on the hp fill
	o.billboard = create("BillboardGui", { Parent = ScreenGui, Size = UDim2.new(0, 200, 0, 32),
		AlwaysOnTop = true, MaxDistance = 3000, StudsOffset = Vector3.new(0, 3.2, 0), Enabled = false })
	o.nameLbl = create("TextLabel", { Parent = o.billboard, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16), Font = Library.Font, TextSize = 12, TextStrokeTransparency = 0.3 })
	o.infoLbl = create("TextLabel", { Parent = o.billboard, Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = Library.Font, TextSize = 11,
		TextStrokeTransparency = 0.4, TextColor3 = Color3.new(1, 1, 1) })
	o.infoGrad = create("UIGradient", { Parent = o.infoLbl, Enabled = false })  -- wave flow on the text
	F.ESP.objs[plr] = o
	return o
end

local function hideObj(o)
	o.box.Visible = false; o.headDot.Visible = false; o.tracer.Visible = false
	o.hbBg.Visible = false; o.billboard.Enabled = false
	for _, b in ipairs(o.bones) do b.Visible = false end
	if o.hl then o.hl.Enabled = false end
	if o.glow then o.glow.Enabled = false end
end
local function clearESP()
	for _, o in pairs(F.ESP.objs) do
		pcall(function()
			o.box:Destroy(); o.headDot:Destroy(); o.tracer:Destroy(); o.billboard:Destroy(); o.hbBg:Destroy()
			for _, b in ipairs(o.bones) do b:Destroy() end
			if o.hl then o.hl:Destroy() end
			if o.glow then o.glow:Destroy() end
		end)
	end
	F.ESP.objs = {}
end

-- true when the current ESP anim wants a real spatial UIGradient (frames);
-- the shared setGrad/animColor engine lives up in FEATURE STATE + HELPERS
local function espUsesGrad() return usesGrad(F.ESP.anim) end
-- single colour for highlights (chams/glow) which can't hold a real gradient:
-- Wave/Gradient/Pulse smoothly blend the two colours so it visibly shows both
local function espColorNow()
	if F.RGB.enabled then return F.RGB.color end
	local t = tick()
	local m = F.ESP.anim
	if m == "Rainbow" then return Color3.fromHSV((t % 5) / 5, 0.85, 1) end
	if m == "Wave" or m == "Gradient" or m == "Pulse" then
		return F.ESP.color:Lerp(F.ESP.color2, (math.sin(t * F.ESP.animSpeed) + 1) / 2)
	end
	return F.ESP.color
end

local function updateESP()
	if not F.ESP.enabled then return end
	local inset = GuiService:GetGuiInset()
	local vp = Camera.ViewportSize
	local color = espColorNow()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local same = (F.ESP.teamCheck and plr.Team == LocalPlayer.Team) or isFriend(plr)
			local o = F.ESP.objs[plr] or makeESPObj(plr)
			if hrp and hum and hum.Health > 0 and not same then
				-- aimbot Highlight Target: the locked player's ENTIRE esp snaps to
				-- the picked colour. Shadowing color/espUsesGrad here overrides
				-- every element below (box, skeleton, dot, tracer, chams, name)
				-- in one place, gradients/rainbow included.
				local color, espUsesGrad = color, espUsesGrad
				local lockedRecolor = F.Aim.hlTarget and F.Aim.lockedChar == char
				if lockedRecolor then
					color = F.Aim.targetColor
					espUsesGrad = function() return false end
				end
				-- chams (highlight)
				if F.ESP.chams then
					if not o.hl then
						o.hl = Instance.new("Highlight"); o.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; o.hl.Parent = ScreenGui
					end
					o.hl.Adornee = char; o.hl.FillColor = color; o.hl.OutlineColor = color
					o.hl.FillTransparency = F.ESP.fill; o.hl.OutlineTransparency = 0; o.hl.Enabled = true
				elseif o.hl then o.hl.Enabled = false end

					-- glow (soft pulsing highlight, occluded so it bleeds through like a glow)
					if F.ESP.glow then
						if not o.glow then
							o.glow = Instance.new("Highlight"); o.glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; o.glow.Parent = ScreenGui
						end
						o.glow.Adornee = char; o.glow.FillColor = color; o.glow.OutlineColor = color
						o.glow.FillTransparency = 1; o.glow.OutlineTransparency = 0; o.glow.Enabled = true  -- outline-only glow (distinct from chams fill)
					elseif o.glow then o.glow.Enabled = false end

				local rootSp, rootOn = Camera:WorldToViewportPoint(hrp.Position)

				-- 2D box from bounding box corners
				if F.ESP.box and rootOn and rootSp.Z > 0 then
					local cf, size = char:GetBoundingBox()
					local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
					for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
						local w = (cf * CFrame.new(size.X / 2 * x, size.Y / 2 * y, size.Z / 2 * z)).Position
						local s = Camera:WorldToViewportPoint(w)
						minX = math.min(minX, s.X); minY = math.min(minY, s.Y)
						maxX = math.max(maxX, s.X); maxY = math.max(maxY, s.Y)
					end end end
					o.box.Position = UDim2.fromOffset(minX, minY)
					o.box.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
						o.boxStroke.Thickness = F.ESP.boxThick
					if espUsesGrad() then
							setGrad(o.boxGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed)
							o.boxStroke.Color = Color3.new(1, 1, 1)
						else
							o.boxGrad.Enabled = false; o.boxStroke.Color = color
						end
						o.box.Visible = true
				else o.box.Visible = false end

					-- health bar (Left/Right = vertical, Top/Bottom = horizontal), green -> red by hp
					if F.ESP.healthbar and rootOn and rootSp.Z > 0 then
						local cf, size = char:GetBoundingBox()
						local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
						for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
							local s = Camera:WorldToViewportPoint((cf * CFrame.new(size.X / 2 * x, size.Y / 2 * y, size.Z / 2 * z)).Position)
							minX = math.min(minX, s.X); minY = math.min(minY, s.Y)
							maxX = math.max(maxX, s.X); maxY = math.max(maxY, s.Y)
						end end end
						local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						local hpColor = Color3.fromRGB(math.floor((1 - hp) * 235), math.floor(hp * 235), 45)
						local gap, thick = 3, 3
						local style = F.ESP.hbStyle
						if style == "Left" or style == "Right" then
							local x = (style == "Left") and (minX - gap - thick) or (maxX + gap)
							o.hbBg.Position = UDim2.fromOffset(x, minY); o.hbBg.Size = UDim2.fromOffset(thick, maxY - minY)
							o.hbFill.AnchorPoint = Vector2.new(0, 1); o.hbFill.Position = UDim2.new(0, 0, 1, 0); o.hbFill.Size = UDim2.new(1, 0, hp, 0)
						else
							local y = (style == "Top") and (minY - gap - thick) or (maxY + gap)
							o.hbBg.Position = UDim2.fromOffset(minX, y); o.hbBg.Size = UDim2.fromOffset(maxX - minX, thick)
							o.hbFill.AnchorPoint = Vector2.new(0, 0); o.hbFill.Position = UDim2.new(0, 0, 0, 0); o.hbFill.Size = UDim2.new(hp, 0, 1, 0)
						end
						local bm = F.ESP.barMode
						if lockedRecolor then
							o.hbGrad.Enabled = false; o.hbFill.BackgroundColor3 = color
						elseif bm == "Custom" then
							o.hbGrad.Enabled = false; o.hbFill.BackgroundColor3 = F.ESP.barColor
						elseif bm == "Health" then
							o.hbGrad.Enabled = false; o.hbFill.BackgroundColor3 = hpColor
						elseif espUsesGrad() then
							-- ESP Colors: same flowing wave/gradient as the rest of the esp
							setGrad(o.hbGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
							o.hbFill.BackgroundColor3 = Color3.new(1, 1, 1)
						elseif F.RGB.enabled or F.ESP.anim ~= "Off" then
							o.hbGrad.Enabled = false; o.hbFill.BackgroundColor3 = color
						else
							o.hbGrad.Enabled = false; o.hbFill.BackgroundColor3 = hpColor
						end
						o.hbBg.Visible = true
					else o.hbBg.Visible = false end

				-- head dot
				local head = char:FindFirstChild("Head")
				if F.ESP.headDot and head then
					local hs, hon = Camera:WorldToViewportPoint(head.Position)
					if hon and hs.Z > 0 then
						o.headDot.Position = UDim2.fromOffset(hs.X, hs.Y)
						o.headDot.Size = UDim2.fromOffset(F.ESP.headSize, F.ESP.headSize); o.headDot.Visible = true
						if espUsesGrad() then
							setGrad(o.headGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed)
							o.headDot.BackgroundColor3 = Color3.new(1, 1, 1)
						else o.headGrad.Enabled = false; o.headDot.BackgroundColor3 = color end
					else o.headDot.Visible = false end
				else o.headDot.Visible = false end

				-- skeleton
				if F.ESP.skeleton and rootOn then
					local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
					for i, pair in ipairs(bones) do
						local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
						local line = o.bones[i]
						if p1 and p2 then
							local w1 = pair[3] and (p1.CFrame * CFrame.new(pair[3])).Position or p1.Position
							local w2 = pair[4] and (p2.CFrame * CFrame.new(pair[4])).Position or p2.Position
							local s1 = Camera:WorldToViewportPoint(w1)
							local s2 = Camera:WorldToViewportPoint(w2)
							if s1.Z > 0 and s2.Z > 0 then
								updateLine(line, Vector2.new(s1.X, s1.Y),
									Vector2.new(s2.X, s2.Y), F.ESP.lineThick, color)
								if espUsesGrad() then
									setGrad(o.boneGrads[i], F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
									line.BackgroundColor3 = Color3.new(1, 1, 1)
								else o.boneGrads[i].Enabled = false end
								line.Visible = true
							else line.Visible = false end
						else line.Visible = false end
					end
					for i = #bones + 1, #o.bones do o.bones[i].Visible = false end
				else for _, b in ipairs(o.bones) do b.Visible = false end end

				-- tracer
				if F.ESP.tracer and rootOn and rootSp.Z > 0 then
					local originPt
					if F.ESP.tracerOrigin == "Mouse" then originPt = UserInputService:GetMouseLocation()
					elseif F.ESP.tracerOrigin == "Top" then originPt = Vector2.new(vp.X / 2, 0)
					else originPt = Vector2.new(vp.X / 2, vp.Y) end
					updateLine(o.tracer, originPt, Vector2.new(rootSp.X, rootSp.Y), F.ESP.lineThick, color)
					if espUsesGrad() then
						setGrad(o.tracerGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
						o.tracer.BackgroundColor3 = Color3.new(1, 1, 1)
					else o.tracerGrad.Enabled = false end
					o.tracer.Visible = true
				else o.tracer.Visible = false end

				-- name / distance / health text
				if F.ESP.names or F.ESP.distance or F.ESP.health then
					o.billboard.Adornee = head or hrp
					o.nameLbl.Text = F.ESP.names and plr.Name or ""
					o.nameLbl.TextColor3 = color; o.nameLbl.Visible = F.ESP.names
					local info = ""
					if F.ESP.distance then info = "[" .. math.floor((Camera.CFrame.Position - hrp.Position).Magnitude) .. "m]" end
					if F.ESP.health then info = info .. (info ~= "" and " " or "") .. math.floor(hum.Health) .. "hp" end
					local tm = F.ESP.textMode
					if lockedRecolor then
						o.infoGrad.Enabled = false; o.infoLbl.TextColor3 = color
					elseif tm == "Custom" then
						o.infoGrad.Enabled = false; o.infoLbl.TextColor3 = F.ESP.textColor
					elseif tm == "White" then
						o.infoGrad.Enabled = false; o.infoLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
					elseif espUsesGrad() then
						-- ESP Colors: distance/health text flows with the same wave
						setGrad(o.infoGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
						o.infoLbl.TextColor3 = Color3.new(1, 1, 1)
					else
						o.infoGrad.Enabled = false
						o.infoLbl.TextColor3 = (F.RGB.enabled or F.ESP.anim ~= "Off") and color or Color3.fromRGB(235, 235, 235)
					end
					o.infoLbl.Text = info; o.infoLbl.Visible = (info ~= "")
					o.billboard.Enabled = true
				else o.billboard.Enabled = false end
			else
				hideObj(o)
			end
		end
	end
end

espP:AddToggle({ Text = "Enabled", Flag = "esp_enabled", Callback = function(on)
	F.ESP.enabled = on
	-- run AFTER the camera (incl. bypass cam at Camera+1) so boxes project off
	-- the final view and don't shake/lag a frame behind
	if on then Library:StartRenderLoop("esp", Enum.RenderPriority.Camera.Value + 2, updateESP) else Library:StopLoop("esp"); clearESP() end
end })
-- Chams (fill) and Glow (outline) both use a Highlight and fight each other on one character,
-- so they're mutually exclusive - turning one on turns the other off
espP:AddToggle({ Text = "Chams", Flag = "esp_chams", Callback = function(on)
	F.ESP.chams = on
	if on and Library.Options["esp_glow"] then Library.Options["esp_glow"]:Set(false) end
end })
espP:AddToggle({ Text = "Glow", Flag = "esp_glow", Callback = function(on)
	F.ESP.glow = on
	if on and Library.Options["esp_chams"] then Library.Options["esp_chams"]:Set(false) end
end })
espP:AddToggle({ Text = "2D Box", Flag = "esp_box", Callback = function(on) F.ESP.box = on end })
espP:AddToggle({ Text = "Skeleton", Flag = "esp_skel", Callback = function(on) F.ESP.skeleton = on end })
espP:AddToggle({ Text = "Head Dot", Flag = "esp_head", Callback = function(on) F.ESP.headDot = on end })
espP:AddToggle({ Text = "Tracers", Flag = "esp_tracer", Callback = function(on) F.ESP.tracer = on end })
espP:AddToggle({ Text = "Names", Flag = "esp_names", Callback = function(on) F.ESP.names = on end })
espP:AddToggle({ Text = "Distance", Flag = "esp_dist", Callback = function(on) F.ESP.distance = on end })
espP:AddToggle({ Text = "Health Text", Flag = "esp_health", Callback = function(on) F.ESP.health = on end })
espP:AddToggle({ Text = "Health Bar", Flag = "esp_hbar", Callback = function(on) F.ESP.healthbar = on end })

espP2:AddToggle({ Text = "Team Check", Flag = "esp_team", Callback = function(on) F.ESP.teamCheck = on end })
espP2:AddSlider({ Text = "Chams Fill", Flag = "esp_fill", Min = 0, Max = 1, Decimals = 2, Default = 0.6, Callback = function(v) F.ESP.fill = v end })
espP2:AddSlider({ Text = "Box Thickness", Flag = "esp_boxthick", Min = 1, Max = 6, Default = 2, Callback = function(v) F.ESP.boxThick = v end })
espP2:AddSlider({ Text = "Line Thickness", Flag = "esp_linethick", Min = 1, Max = 6, Default = 1, Callback = function(v) F.ESP.lineThick = v end })
espP2:AddSlider({ Text = "Head Dot Size", Flag = "esp_headsize", Min = 3, Max = 16, Default = 6, Callback = function(v) F.ESP.headSize = v end })
espP2:AddDropdown({ Text = "Bar Style", Flag = "esp_hbstyle", Options = { "Left", "Right", "Top", "Bottom" },
	Default = "Left", Callback = function(v) F.ESP.hbStyle = v end })
espP2:AddDropdown({ Text = "Bar Color Mode", Flag = "esp_barmode", Options = { "ESP Colors", "Health", "Custom" },
	Default = "ESP Colors", Callback = function(v) F.ESP.barMode = v end })
espP2:AddColorPicker({ Text = "Bar Color", Flag = "esp_barcolor", Default = COLORS.Green, Sub = true, Callback = function(c) F.ESP.barColor = c end })
espP2:AddDropdown({ Text = "Text Color Mode", Flag = "esp_textmode", Options = { "ESP Colors", "White", "Custom" },
	Default = "ESP Colors", Callback = function(v) F.ESP.textMode = v end })
espP2:AddColorPicker({ Text = "Text Color", Flag = "esp_textcolor", Default = COLORS.White, Sub = true, Callback = function(c) F.ESP.textColor = c end })
espP2:AddDropdown({ Text = "Tracer Origin", Flag = "esp_torigin", Options = { "Bottom", "Top", "Mouse" },
	Default = "Bottom", Callback = function(v) F.ESP.tracerOrigin = v end })
espP2:AddColorPicker({ Text = "Color 1", Flag = "esp_color", Default = COLORS.Red, Callback = function(c) F.ESP.color = c end })
espP2:AddColorPicker({ Text = "Color 2", Flag = "esp_color2", Default = COLORS.Cyan, Callback = function(c) F.ESP.color2 = c end })
espP2:AddDropdown({ Text = "Animation", Flag = "esp_anim", Options = { "Off", "Gradient", "Wave", "Pulse", "Rainbow" },
	Default = "Off", Callback = function(v) F.ESP.anim = v end })
espP2:AddSlider({ Text = "Anim Speed", Flag = "esp_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.ESP.animSpeed = v end })

--== ESP Preview (third panel in this tab): a live mock player that mirrors
--== EXACTLY the elements / colours / animations you have enabled above ==--
F.Preview = { enabled = false }
do
	local espP3 = playersPage:AddPanel("Preview")
	local PW, PH = 64, 112  -- preview bounding-box size in px
	local sc = espP3:Scroll()

	local holder = create("Frame", { Parent = sc, BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 205), LayoutOrder = 5, Visible = false, ClipsDescendants = true })
	corner(holder, 6); border(holder, Library.Theme.Border, 1)
	create("Frame", { Parent = holder, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(22, 25, 22) })  -- "ground"

	-- avatar + tinted copies used to fake chams (fill over) and glow (halo behind)
	local img = "rbxthumb://type=AvatarThumbnail&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
	local glowImg = create("ImageLabel", { Parent = holder, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4), Size = UDim2.new(0, 132, 0, 132), Image = img, Visible = false, ImageTransparency = 0.55 })
	create("ImageLabel", { Parent = holder, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4), Size = UDim2.new(0, 120, 0, 120), Image = img })
	local chamImg = create("ImageLabel", { Parent = holder, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4), Size = UDim2.new(0, 120, 0, 120), Image = img, Visible = false })

	local box = create("Frame", { Parent = holder, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4), Size = UDim2.new(0, PW, 0, PH) })
	local boxStroke = border(box, F.ESP.color, 2); boxStroke.Enabled = false
	local boxGrad = create("UIGradient", { Parent = boxStroke, Enabled = false })

	local headDot = create("Frame", { Parent = box, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10), Visible = false })
	create("UICorner", { Parent = headDot, CornerRadius = UDim.new(1, 0) })
	local headGrad = create("UIGradient", { Parent = headDot, Enabled = false })

	-- stick skeleton, joints as fractions of the box
	local J = { head = Vector2.new(0.5, 0.09), neck = Vector2.new(0.5, 0.2), pelvis = Vector2.new(0.5, 0.52),
		ls = Vector2.new(0.3, 0.24), rs = Vector2.new(0.7, 0.24), lh = Vector2.new(0.18, 0.46), rh = Vector2.new(0.82, 0.46),
		lf = Vector2.new(0.36, 0.94), rf = Vector2.new(0.64, 0.94) }
	local B = { {"head","neck"}, {"neck","pelvis"}, {"neck","ls"}, {"ls","lh"},
		{"neck","rs"}, {"rs","rh"}, {"pelvis","lf"}, {"pelvis","rf"} }
	local boneLines, boneGrads = {}, {}
	for i = 1, #B do
		boneLines[i] = create("Frame", { Parent = box, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
		boneGrads[i] = create("UIGradient", { Parent = boneLines[i], Enabled = false })
	end

	local tracer = create("Frame", { Parent = holder, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	local tracerGrad = create("UIGradient", { Parent = tracer, Enabled = false })

	local hbBg = create("Frame", { Parent = box, BorderSizePixel = 0, Visible = false,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25 })
	local hbFill = create("Frame", { Parent = hbBg, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(0, 255, 0) })
	local hbGrad = create("UIGradient", { Parent = hbFill, Enabled = false })

	local nameLbl = create("TextLabel", { Parent = box, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.new(0, 120, 0, 13), Font = Library.Font,
		Text = LocalPlayer.Name, TextSize = 12, TextStrokeTransparency = 0.4, Visible = false })
	local infoLbl = create("TextLabel", { Parent = box, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.new(0, 120, 0, 12), Font = Library.Font,
		Text = "", TextSize = 11, TextStrokeTransparency = 0.5, TextColor3 = Color3.fromRGB(235, 235, 235), Visible = false })
	local infoGrad = create("UIGradient", { Parent = infoLbl, Enabled = false })
	local offLbl = create("TextLabel", { Parent = holder, BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0, 12), Font = Library.Font, Text = "esp master toggle is OFF", TextSize = 10,
		TextColor3 = Library.Theme.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Visible = false })

	local function updPreview()
		local color = espColorNow()
		local grad = (not F.RGB.enabled) and espUsesGrad()
		local white = Color3.new(1, 1, 1)
		offLbl.Visible = not F.ESP.enabled
		-- chams / glow (tinted avatar copies, standing in for the Highlight)
		chamImg.Visible = F.ESP.chams
		if F.ESP.chams then chamImg.ImageColor3 = color; chamImg.ImageTransparency = F.ESP.fill end
		glowImg.Visible = F.ESP.glow
		if F.ESP.glow then glowImg.ImageColor3 = color end
		-- 2D box
		boxStroke.Enabled = F.ESP.box
		if F.ESP.box then
			boxStroke.Thickness = F.ESP.boxThick
			if grad then setGrad(boxGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed); boxStroke.Color = white
			else boxGrad.Enabled = false; boxStroke.Color = color end
		end
		-- head dot
		headDot.Visible = F.ESP.headDot
		if F.ESP.headDot then
			headDot.Size = UDim2.fromOffset(F.ESP.headSize, F.ESP.headSize)
			if grad then setGrad(headGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed); headDot.BackgroundColor3 = white
			else headGrad.Enabled = false; headDot.BackgroundColor3 = color end
		end
		-- skeleton
		for i, bone in ipairs(B) do
			local ln = boneLines[i]
			ln.Visible = F.ESP.skeleton
			if F.ESP.skeleton then
				local a, b = J[bone[1]], J[bone[2]]
				updateLine(ln, Vector2.new(a.X * PW, a.Y * PH), Vector2.new(b.X * PW, b.Y * PH), F.ESP.lineThick, color)
				if grad then setGrad(boneGrads[i], F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0); ln.BackgroundColor3 = white
				else boneGrads[i].Enabled = false end
			end
		end
		-- tracer (respects your real Tracer Origin setting)
		tracer.Visible = F.ESP.tracer
		if F.ESP.tracer then
			local hs = holder.AbsoluteSize
			local bp = box.AbsolutePosition - holder.AbsolutePosition
			local feet = Vector2.new(bp.X + PW / 2, bp.Y + PH)
			local o = (F.ESP.tracerOrigin == "Top") and Vector2.new(hs.X / 2, 0) or Vector2.new(hs.X / 2, hs.Y)
			updateLine(tracer, o, feet, F.ESP.lineThick, color)
			if grad then setGrad(tracerGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0); tracer.BackgroundColor3 = white
			else tracerGrad.Enabled = false end
		end
		-- health bar: hp sweeps up and down so you can see the colour ramp + your bar style
		local hp = 0.5 + 0.5 * math.sin(tick() * 0.8)
		hbBg.Visible = F.ESP.healthbar
		if F.ESP.healthbar then
			local gap, thick = 3, 3
			local style = F.ESP.hbStyle
			if style == "Left" or style == "Right" then
				hbBg.Position = (style == "Left") and UDim2.new(0, -(gap + thick), 0, 0) or UDim2.new(1, gap, 0, 0)
				hbBg.Size = UDim2.new(0, thick, 1, 0)
				hbFill.AnchorPoint = Vector2.new(0, 1); hbFill.Position = UDim2.new(0, 0, 1, 0); hbFill.Size = UDim2.new(1, 0, hp, 0)
			else
				hbBg.Position = (style == "Top") and UDim2.new(0, 0, 0, -(gap + thick)) or UDim2.new(0, 0, 1, gap)
				hbBg.Size = UDim2.new(1, 0, 0, thick)
				hbFill.AnchorPoint = Vector2.new(0, 0); hbFill.Position = UDim2.new(0, 0, 0, 0); hbFill.Size = UDim2.new(hp, 0, 1, 0)
			end
			local bm = F.ESP.barMode
			if bm == "Custom" then
				hbGrad.Enabled = false; hbFill.BackgroundColor3 = F.ESP.barColor
			elseif bm ~= "Health" and grad then
				setGrad(hbGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
				hbFill.BackgroundColor3 = white
			elseif bm ~= "Health" and (F.RGB.enabled or F.ESP.anim ~= "Off") then
				hbGrad.Enabled = false; hbFill.BackgroundColor3 = color
			else
				hbGrad.Enabled = false
				hbFill.BackgroundColor3 = Color3.fromRGB(math.floor((1 - hp) * 235), math.floor(hp * 235), 45)
			end
		end
		-- name / distance / health text
		nameLbl.Visible = F.ESP.names
		if F.ESP.names then nameLbl.TextColor3 = color end
		local info = ""
		if F.ESP.distance then info = "[14m]" end
		if F.ESP.health then info = info .. (info ~= "" and " " or "") .. math.floor(hp * 100) .. "hp" end
		local tm = F.ESP.textMode
		if tm == "Custom" then
			infoGrad.Enabled = false; infoLbl.TextColor3 = F.ESP.textColor
		elseif tm ~= "White" and grad then
			setGrad(infoGrad, F.ESP.color, F.ESP.color2, F.ESP.anim, F.ESP.animSpeed, 0)
			infoLbl.TextColor3 = white
		elseif tm ~= "White" and (F.RGB.enabled or F.ESP.anim ~= "Off") then
			infoGrad.Enabled = false; infoLbl.TextColor3 = color
		else
			infoGrad.Enabled = false; infoLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
		end
		infoLbl.Text = info; infoLbl.Visible = (info ~= "")
	end

	espP3:AddToggle({ Text = "Show Preview", Flag = "esp_preview", Callback = function(on)
		F.Preview.enabled = on; holder.Visible = on
		if on then Library:StartLoop("preview", RunService.RenderStepped, updPreview)
		else Library:StopLoop("preview") end
	end })
	espP3:AddLabel("Live mirror of your ESP: only the elements you toggled render here, with your real colours, animation, bar style and tracer origin.")
end

--== World ==--
local worldPage = VisCat:AddTab("World")
local worldP = worldPage:AddPanel("Lighting")
F.FB = { enabled = false, brightness = 2.5, saved = {} }
worldP:AddToggle({ Text = "Fullbright", Flag = "fb", Callback = function(on)
	F.FB.enabled = on
	if on then
		F.FB.saved = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, Ambient = Lighting.Ambient }
		Library:StartLoop("fb", RunService.RenderStepped, function()
			Lighting.Brightness = F.FB.brightness; Lighting.ClockTime = 14; Lighting.FogEnd = 1e9; Lighting.Ambient = Color3.fromRGB(140,140,140)
		end)
	else Library:StopLoop("fb"); for k, v in pairs(F.FB.saved) do pcall(function() Lighting[k] = v end) end end
end })
worldP:AddSlider({ Text = "Brightness", Flag = "fb_bright", Min = 1, Max = 6, Decimals = 1, Default = 2.5, Callback = function(v) F.FB.brightness = v end })
F.FOV = { enabled = false, value = 70 }
worldP:AddToggle({ Text = "Custom FOV", Flag = "cfov", Callback = function(on)
	F.FOV.enabled = on
	if on then Library:StartLoop("cfov", RunService.RenderStepped, function() if Camera then Camera.FieldOfView = F.FOV.value end end)
	else Library:StopLoop("cfov"); if Camera then Camera.FieldOfView = 70 end end
end })
worldP:AddSlider({ Text = "FOV", Flag = "cfov_val", Min = 40, Max = 120, Default = 70, Suffix = "°", Callback = function(v) F.FOV.value = v end })

-- World Color / Self Chams
local worldP2 = worldPage:AddPanel("World Color")

-- Ambience: recolours the whole scene (sky/ambient/fog tint) - a "sky colour changer"
F.Ambience = { enabled = false, color = COLORS.Purple, rainbow = false, cc = nil, saved = {} }
worldP2:AddToggle({ Text = "Ambience", Flag = "amb", Callback = function(on)
	F.Ambience.enabled = on
	if on then
		if not F.Ambience.cc then
			F.Ambience.cc = create("ColorCorrectionEffect", { Parent = Lighting, Name = "xRustAmb", Enabled = true })
		end
		F.Ambience.saved = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, FogColor = Lighting.FogColor }
		Library:StartLoop("amb", RunService.RenderStepped, function()
			local c = F.RGB.enabled and F.RGB.color or F.Ambience.color
			Lighting.Ambient = c; Lighting.OutdoorAmbient = c; Lighting.FogColor = c
			if F.Ambience.cc then F.Ambience.cc.TintColor = c; F.Ambience.cc.Saturation = 0.15 end
		end)
	else
		Library:StopLoop("amb")
		if F.Ambience.cc then F.Ambience.cc.TintColor = Color3.new(1, 1, 1); F.Ambience.cc.Saturation = 0 end
		for k, v in pairs(F.Ambience.saved) do pcall(function() Lighting[k] = v end) end
	end
end })
worldP2:AddColorPicker({ Text = "Ambience Color", Flag = "amb_color", Default = COLORS.Purple, Callback = function(c) F.Ambience.color = c end })

-- Self Chams: highlight your own character
F.SelfChams = { enabled = false, color = COLORS.Purple, color2 = COLORS.Cyan, anim = "Off", animSpeed = 2, fill = 0.5, hl = nil }
local function applySelfChams()
	local char = LocalPlayer.Character
	if not char then return end
	if not F.SelfChams.hl or not F.SelfChams.hl.Parent then
		F.SelfChams.hl = Instance.new("Highlight")
		F.SelfChams.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		F.SelfChams.hl.Parent = ScreenGui
	end
	F.SelfChams.hl.Adornee = char
end
worldP2:AddToggle({ Text = "Self Chams", Flag = "self_chams", Callback = function(on)
	F.SelfChams.enabled = on
	if on then
		applySelfChams()
		Library:StartLoop("selfchams", RunService.RenderStepped, function()
			if not F.SelfChams.hl or F.SelfChams.hl.Adornee ~= LocalPlayer.Character then applySelfChams() end
			-- Wave = smooth two-colour blend (highlights can't hold a real gradient)
			local c = animColor(F.SelfChams.color, F.SelfChams.color2, F.SelfChams.anim, F.SelfChams.animSpeed)
			if F.SelfChams.hl then
				F.SelfChams.hl.FillColor = c; F.SelfChams.hl.OutlineColor = c
				F.SelfChams.hl.FillTransparency = F.SelfChams.fill; F.SelfChams.hl.OutlineTransparency = 0
				F.SelfChams.hl.Enabled = true
			end
		end)
	else
		Library:StopLoop("selfchams")
		if F.SelfChams.hl then F.SelfChams.hl.Enabled = false end
	end
end })
worldP2:AddSlider({ Text = "Self Fill", Flag = "self_fill", Min = 0, Max = 1, Decimals = 2, Default = 0.5, Callback = function(v) F.SelfChams.fill = v end })
worldP2:AddColorPicker({ Text = "Self Color 1", Flag = "self_color", Default = COLORS.Purple, Callback = function(c) F.SelfChams.color = c end })
worldP2:AddColorPicker({ Text = "Self Color 2", Flag = "self_color2", Default = COLORS.Cyan, Callback = function(c) F.SelfChams.color2 = c end })
worldP2:AddDropdown({ Text = "Self Animation", Flag = "self_anim", Options = { "Off", "Wave", "Rainbow" },
	Default = "Off", Callback = function(v) F.SelfChams.anim = v end })
worldP2:AddSlider({ Text = "Self Anim Speed", Flag = "self_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.SelfChams.animSpeed = v end })

-- Self Glow: a bright outline highlight on your own character (always visible)
F.SelfGlow = { enabled = false, color = COLORS.Cyan, color2 = COLORS.Purple, anim = "Off", animSpeed = 2, hl = nil }
worldP2:AddToggle({ Text = "Self Glow", Flag = "self_glow", Callback = function(on)
	F.SelfGlow.enabled = on
	if on then
		Library:StartLoop("selfglow", RunService.RenderStepped, function()
			local char = LocalPlayer.Character
			if not char then return end
			if not F.SelfGlow.hl or not F.SelfGlow.hl.Parent then
				F.SelfGlow.hl = Instance.new("Highlight")
				F.SelfGlow.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- always visible = actually shows
				F.SelfGlow.hl.Parent = ScreenGui
			end
			local c = animColor(F.SelfGlow.color, F.SelfGlow.color2, F.SelfGlow.anim, F.SelfGlow.animSpeed)
			F.SelfGlow.hl.Adornee = char
			F.SelfGlow.hl.FillColor = c; F.SelfGlow.hl.OutlineColor = c
			F.SelfGlow.hl.FillTransparency = 0.45  -- steady (no breathing)
			F.SelfGlow.hl.OutlineTransparency = 0
			F.SelfGlow.hl.Enabled = true
		end)
	else
		Library:StopLoop("selfglow")
		if F.SelfGlow.hl then F.SelfGlow.hl.Enabled = false end
	end
end })
worldP2:AddColorPicker({ Text = "Glow Color 1", Flag = "self_glow_color", Default = COLORS.Cyan, Callback = function(c) F.SelfGlow.color = c end })
worldP2:AddColorPicker({ Text = "Glow Color 2", Flag = "self_glow_color2", Default = COLORS.Purple, Callback = function(c) F.SelfGlow.color2 = c end })
worldP2:AddDropdown({ Text = "Glow Animation", Flag = "self_glow_anim", Options = { "Off", "Wave", "Rainbow" },
	Default = "Off", Callback = function(v) F.SelfGlow.anim = v end })
worldP2:AddSlider({ Text = "Glow Anim Speed", Flag = "self_glow_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.SelfGlow.animSpeed = v end })

--== Target HUD ==--
local thudPage = VisCat:AddTab("Target HUD")
local thudP  = thudPage:AddPanel("Show")
local thudP2 = thudPage:AddPanel("Style")

F.THUD = { enabled = false, showName = true, showTool = true, showHealth = true, showDistance = true, showTeam = false,
	bg = Color3.fromRGB(14, 14, 17), bg2 = COLORS.Purple, accent = Library.Theme.Accent, trans = 0.05,
	gradient = false, anim = "Gradient", animSpeed = 2, barWave = false, bar1 = COLORS.Purple, bar2 = COLORS.Cyan, gui = nil }
posFlag("thud_pos", F.THUD)  -- dragged position persists in configs

-- the HUD tracks the enemy nearest your crosshair (excludes friends)
local function hudTarget()
	local mouse = UserInputService:GetMouseLocation()
	local best, bestD
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isFriend(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			if head and hum and hum.Health > 0 then
				local sp, on = Camera:WorldToViewportPoint(head.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
					if not bestD or d < bestD then best, bestD = plr, d end
				end
			end
		end
	end
	return best
end

local function buildTHUD()
	if F.THUD.gui then return end
	local f = create("Frame", { Parent = ScreenGui, Name = "TargetHUD", Position = UDim2.new(0.5, -130, 0, 96),
		Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = F.THUD.bg, BorderSizePixel = 0 })
	border(f, Library.Theme.Border, 1); corner(f, 6)
	F.THUD.grad = create("UIGradient", { Parent = f, Enabled = false })  -- optional gradient background
	F.THUD.accentBar = create("Frame", { Parent = f, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = F.THUD.accent, BorderSizePixel = 0 })
	local inner = create("Frame", { Parent = f, BackgroundTransparency = 1, Position = UDim2.new(0, 3, 0, 0),
		Size = UDim2.new(1, -3, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	pad(inner, 13, 9, 13, 11)
	create("UIListLayout", { Parent = inner, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

	F.THUD.tagLbl = create("TextLabel", { Parent = inner, BackgroundTransparency = 1, LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 12), Font = Library.Font, Text = "TARGET", TextSize = 10,
		TextColor3 = F.THUD.accent, TextXAlignment = Enum.TextXAlignment.Left })
	F.THUD.nameLbl = create("TextLabel", { Parent = inner, BackgroundTransparency = 1, LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.Code, Text = "no target", TextSize = 17,
		TextColor3 = Library.Theme.TextHdr, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	create("Frame", { Parent = inner, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Library.Theme.Border, BorderSizePixel = 0 })

	local function infoRow(order, labelText)
		local row = create("Frame", { Parent = inner, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = order })
		label(row, labelText, { Color = Library.Theme.SubText, Size = 12, Sz = UDim2.new(0.4, 0, 1, 0) })
		local val = label(row, "", { Color = Library.Theme.TextOn, Size = 12, Sz = UDim2.new(0.6, 0, 1, 0),
			XAlign = Enum.TextXAlignment.Right, Truncate = Enum.TextTruncate.AtEnd })
		return row, val
	end
	F.THUD.toolRow, F.THUD.toolVal = infoRow(3, "Tool")
	F.THUD.teamRow, F.THUD.teamVal = infoRow(4, "Team")
	F.THUD.distRow, F.THUD.distVal = infoRow(5, "Distance")
	F.THUD.hpRow,   F.THUD.hpVal   = infoRow(6, "Health")
	local barBg = create("Frame", { Parent = inner, LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0 })
	border(barBg, Library.Theme.Border, 1); corner(barBg, 3)
	F.THUD.hpBar = create("Frame", { Parent = barBg, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 255, 0), BorderSizePixel = 0 })
	F.THUD.hpGrad = create("UIGradient", { Parent = F.THUD.hpBar, Enabled = false })  -- wave colours option
	F.THUD.hpBarBg = barBg
	makeDraggable(f); F.THUD.gui = f
	trackPos("thud_pos", F.THUD)
end

thudP:AddToggle({ Text = "Enabled", Flag = "thud", Callback = function(on)
	F.THUD.enabled = on
	if on then
		buildTHUD(); F.THUD.gui.Visible = true
		Library:StartLoop("thud", RunService.RenderStepped, function()
			-- background: solid or animated gradient
			if F.THUD.gradient then
				setGrad(F.THUD.grad, F.THUD.bg, F.THUD.bg2, F.THUD.anim, F.THUD.animSpeed)
				F.THUD.gui.BackgroundColor3 = Color3.new(1, 1, 1)
			else
				F.THUD.grad.Enabled = false; F.THUD.gui.BackgroundColor3 = F.THUD.bg
			end
			F.THUD.gui.BackgroundTransparency = F.THUD.trans
			F.THUD.accentBar.BackgroundColor3 = F.THUD.accent
			F.THUD.tagLbl.TextColor3 = F.THUD.accent
			local plr = hudTarget()
			if not plr then
				F.THUD.nameLbl.Text = "no target"
				F.THUD.toolRow.Visible = false; F.THUD.distRow.Visible = false; F.THUD.teamRow.Visible = false
				F.THUD.hpRow.Visible = false; F.THUD.hpBarBg.Visible = false
				return
			end
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			F.THUD.nameLbl.Text = F.THUD.showName and plr.Name or plr.DisplayName
			local tool = char and char:FindFirstChildOfClass("Tool")
			F.THUD.toolVal.Text = tool and tool.Name or "None"; F.THUD.toolRow.Visible = F.THUD.showTool
			F.THUD.teamVal.Text = plr.Team and plr.Team.Name or "None"; F.THUD.teamRow.Visible = F.THUD.showTeam
			local myHrp = getChar() and getChar().HumanoidRootPart
			F.THUD.distVal.Text = (hrp and myHrp) and (math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m") or "--"
			F.THUD.distRow.Visible = F.THUD.showDistance
			if hum then
				local hp, maxhp = hum.Health, math.max(hum.MaxHealth, 1)
				local frac = math.clamp(hp / maxhp, 0, 1)
				F.THUD.hpVal.Text = math.floor(hp) .. " / " .. math.floor(maxhp)
				F.THUD.hpBar.Size = UDim2.new(frac, 0, 1, 0)
				if F.THUD.barWave then
					-- bar follows the wave colours instead of green->red hp; it uses
					-- the SAME mode/speed/rotation maths as the BG gradient, so both
					-- animate perfectly in step (no out-of-place phase drift)
					F.THUD.hpBar.BackgroundColor3 = Color3.new(1, 1, 1)
					setGrad(F.THUD.hpGrad, F.THUD.bar1, F.THUD.bar2, F.THUD.anim, F.THUD.animSpeed)
				else
					F.THUD.hpGrad.Enabled = false
					F.THUD.hpBar.BackgroundColor3 = Color3.fromRGB(math.floor((1 - frac) * 235), math.floor(frac * 235), 45)
				end
			end
			F.THUD.hpRow.Visible = F.THUD.showHealth; F.THUD.hpBarBg.Visible = F.THUD.showHealth
		end)
	else Library:StopLoop("thud"); if F.THUD.gui then F.THUD.gui.Visible = false end end
end })
thudP:AddToggle({ Text = "Show Name", Flag = "thud_name", Default = true, Callback = function(on) F.THUD.showName = on end })
thudP:AddToggle({ Text = "Show Tool", Flag = "thud_tool", Default = true, Callback = function(on) F.THUD.showTool = on end })
thudP:AddToggle({ Text = "Show Health", Flag = "thud_health", Default = true, Callback = function(on) F.THUD.showHealth = on end })
thudP:AddToggle({ Text = "Show Distance", Flag = "thud_dist", Default = true, Callback = function(on) F.THUD.showDistance = on end })
thudP:AddToggle({ Text = "Show Team", Flag = "thud_team", Callback = function(on) F.THUD.showTeam = on end })

thudP2:AddColorPicker({ Text = "Accent", Flag = "thud_accent", Default = COLORS.Red, Callback = function(c) F.THUD.accent = c end })
thudP2:AddColorPicker({ Text = "BG Color 1", Flag = "thud_bg", Default = Color3.fromRGB(14, 14, 17), Callback = function(c) F.THUD.bg = c end })
thudP2:AddColorPicker({ Text = "BG Color 2", Flag = "thud_bg2", Default = COLORS.Purple, Callback = function(c) F.THUD.bg2 = c end })
thudP2:AddToggle({ Text = "Gradient BG", Flag = "thud_grad", Callback = function(on) F.THUD.gradient = on end })
thudP2:AddDropdown({ Text = "BG Animation", Flag = "thud_anim", Options = { "Gradient", "Wave" }, Default = "Gradient", Callback = function(v) F.THUD.anim = v end })
thudP2:AddSlider({ Text = "Anim Speed", Flag = "thud_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Callback = function(v) F.THUD.animSpeed = v end })
thudP2:AddToggle({ Text = "Wave Health Bar", Flag = "thud_barwave", Callback = function(on) F.THUD.barWave = on end })
thudP2:AddColorPicker({ Text = "Bar Color 1", Flag = "thud_bar1", Default = COLORS.Purple, Sub = true, Callback = function(c) F.THUD.bar1 = c end })
thudP2:AddColorPicker({ Text = "Bar Color 2", Flag = "thud_bar2", Default = COLORS.Cyan, Sub = true, Callback = function(c) F.THUD.bar2 = c end })
thudP2:AddSlider({ Text = "Transparency", Flag = "thud_trans", Min = 0, Max = 0.9, Decimals = 2, Default = 0.05, Callback = function(v) F.THUD.trans = v end })
thudP2:AddLabel("Drag the HUD anywhere on screen.")

--== Extras: jump circle + target renderer, both TRUE 3D world objects
--== (HandleAdornments in world space = perspective-correct, no fake ovals) ==--
local extraPage = VisCat:AddTab("Extras")
local jcP = extraPage:AddPanel("Jump Circle")
local trP = extraPage:AddPanel("Target Renderer")

-- Jump Circle: a real ring laid flat on the ground (CylinderHandleAdornment
-- adorned to Terrain = world space), spawned every time you jump
F.JumpC = { enabled = false, color = COLORS.Cyan, color2 = COLORS.Purple, anim = "Off", animSpeed = 2,
	style = "Expand", speed = 1, size = 11, thickness = 0.4, filled = false, onTop = true, rings = {} }

local function jcGround()
	local char = getChar(); if not char then return nil end
	local hrp = char.HumanoidRootPart
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char, Camera }
	local res = Workspace:Raycast(hrp.Position, Vector3.new(0, -14, 0), rp)
	return res and (res.Position + Vector3.new(0, 0.08, 0)) or (hrp.Position - Vector3.new(0, 2.9, 0))
end
local function jcClear()
	for _, r in ipairs(F.JumpC.rings) do if r.ad then r.ad:Destroy() end end
	F.JumpC.rings = {}
end
local jcCd = 0
Library:Connect(UserInputService.JumpRequest, function()
	if not F.JumpC.enabled or os.clock() < jcCd then return end
	local pos = jcGround(); if not pos then return end
	jcCd = os.clock() + 0.22
	table.insert(F.JumpC.rings, { pos = pos, born = tick() })
	if F.JumpC.style == "Ripple" then           -- two echo rings chasing the first
		table.insert(F.JumpC.rings, { pos = pos, born = tick() + 0.12 })
		table.insert(F.JumpC.rings, { pos = pos, born = tick() + 0.24 })
	end
end)
local function showJcSubs(v)
	for _, f in ipairs({ "jumpc_style", "jumpc_speed", "jumpc_size", "jumpc_thickness", "jumpc_fill",
		"jumpc_ontop", "jumpc_color", "jumpc_color2", "jumpc_anim", "jumpc_animspeed" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
jcP:AddToggle({ Text = "Jump Circle", Flag = "jumpc", Callback = function(on)
	F.JumpC.enabled = on; showJcSubs(on)
	if on then
		Library:StartLoop("jumpc", RunService.RenderStepped, function()
			local life = 0.85 / F.JumpC.speed
			for i = #F.JumpC.rings, 1, -1 do
				local r = F.JumpC.rings[i]
				local age = tick() - r.born
				if age >= life then
					if r.ad then r.ad:Destroy() end
					table.remove(F.JumpC.rings, i)
				elseif age < 0 then                  -- ripple echo not born yet
					if r.ad then r.ad.Visible = false end
				else
					if not r.ad then
						r.ad = create("CylinderHandleAdornment", { Parent = ScreenGui,
							Adornee = Workspace.Terrain, Height = 0.05, ZIndex = 0 })
						-- Terrain adornee = CFrame is world space; X-rot 90 lays the disc flat
						r.ad.CFrame = CFrame.new(r.pos) * CFrame.Angles(math.rad(90), 0, 0)
					end
					local t = age / life
					local ease = 1 - (1 - t) ^ (F.JumpC.style == "Shockwave" and 4 or 2)
					local rad = (F.JumpC.style == "Shrink") and F.JumpC.size * (1 - ease) or F.JumpC.size * ease
					rad = math.max(rad, 0.05)
					r.ad.Radius = rad
					r.ad.InnerRadius = F.JumpC.filled and 0 or math.max(rad - F.JumpC.thickness, 0)
					r.ad.AlwaysOnTop = F.JumpC.onTop
					r.ad.Color3 = animColor(F.JumpC.color, F.JumpC.color2, F.JumpC.anim, F.JumpC.animSpeed)
					r.ad.Transparency = 0.1 + 0.9 * t   -- fades out over its life
					r.ad.Visible = true
				end
			end
		end)
	else Library:StopLoop("jumpc"); jcClear() end
end })
jcP:AddDropdown({ Text = "Style", Flag = "jumpc_style", Options = { "Expand", "Shockwave", "Ripple", "Shrink" },
	Default = "Expand", Callback = function(v) F.JumpC.style = v end })
jcP:AddSlider({ Text = "Speed", Flag = "jumpc_speed", Min = 0.3, Max = 3, Decimals = 1, Default = 1, Suffix = "x",
	Callback = function(v) F.JumpC.speed = v end })
jcP:AddSlider({ Text = "Size", Flag = "jumpc_size", Min = 3, Max = 25, Default = 11, Callback = function(v) F.JumpC.size = v end })
jcP:AddSlider({ Text = "Ring Thickness", Flag = "jumpc_thickness", Min = 0.1, Max = 2, Decimals = 1, Default = 0.4,
	Callback = function(v) F.JumpC.thickness = v end })
jcP:AddToggle({ Text = "Filled Disc", Flag = "jumpc_fill", Callback = function(on) F.JumpC.filled = on end })
jcP:AddToggle({ Text = "Through Walls", Flag = "jumpc_ontop", Default = true, Callback = function(on) F.JumpC.onTop = on end })
jcP:AddColorPicker({ Text = "Color 1", Flag = "jumpc_color", Default = COLORS.Cyan, Callback = function(c) F.JumpC.color = c end })
jcP:AddColorPicker({ Text = "Color 2", Flag = "jumpc_color2", Default = COLORS.Purple, Callback = function(c) F.JumpC.color2 = c end })
jcP:AddDropdown({ Text = "Animation", Flag = "jumpc_anim", Options = { "Off", "Pulse", "Rainbow" },
	Default = "Off", Callback = function(v) F.JumpC.anim = v end })
jcP:AddSlider({ Text = "Anim Speed", Flag = "jumpc_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2,
	Callback = function(v) F.JumpC.animSpeed = v end })
showJcSubs(false)

-- Target Renderer: rich world-space FX orbiting the enemy nearest your
-- crosshair. Particle system (12 styles, 3 orb shapes, soft glow) + a
-- multi-mode ring system + an overhead marker + a light beam. All real
-- HandleAdornments = perspective-correct 3D.
F.TR = { enabled = false, style = "Orbit", shape = "Sphere", anim = "Wave", color = COLORS.Purple, color2 = COLORS.Cyan,
	speed = 1.5, radius = 2.6, orb = 0.3, strands = 3, trail = 8, heightScale = 1, bob = 0.25, glow = true, onTop = true, animSpeed = 2,
	teamCheck = false,
	ring = true, ringStyle = "Ground", ringCount = 1, ringFill = false, ringThick = 0.22, ringTilt = 0, ringSpeed = 1.2,
	marker = false, markerShape = "Diamond", markerSize = 0.6, markerSpin = 2, markerCur = nil,
	beam = false, beamWidth = 0.14, beamHeight = 30,
	pool = {}, rings = {}, markerAd = nil, beamAd = nil, rot = 0 }

-- structural styles show every orb (a shape), comet styles fade a trail
local TR_STRUCTURAL = { Atom = true, Sphere = true, Rings = true, Cage = true, Spiral = true, Halo = true }

local function trClear()
	for _, e in ipairs(F.TR.pool) do pcall(function() e.core:Destroy(); e.glow:Destroy() end) end
	F.TR.pool = {}
	for _, ad in ipairs(F.TR.rings) do pcall(function() ad:Destroy() end) end
	F.TR.rings = {}
	if F.TR.markerAd then F.TR.markerAd:Destroy(); F.TR.markerAd = nil; F.TR.markerCur = nil end
	if F.TR.beamAd then F.TR.beamAd:Destroy(); F.TR.beamAd = nil end
end
local function trHide()
	for _, e in ipairs(F.TR.pool) do e.core.Visible = false; e.glow.Visible = false end
	for _, ad in ipairs(F.TR.rings) do ad.Visible = false end
	if F.TR.markerAd then F.TR.markerAd.Visible = false end
	if F.TR.beamAd then F.TR.beamAd.Visible = false end
end
local function trTargetChar()
	local mouse = UserInputService:GetMouseLocation()
	local best, bestD
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isFriend(plr) and not (F.TR.teamCheck and plr.Team == LocalPlayer.Team) then
			local ch = plr.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp and hum and hum.Health > 0 then
				local sp, on = Camera:WorldToViewportPoint(hrp.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
					if not bestD or d < bestD then best, bestD = ch, d end
				end
			end
		end
	end
	if not best then return nil end
	return best, best:FindFirstChild("HumanoidRootPart"), best:FindFirstChildOfClass("Humanoid")
end
-- colour for a given trail/position fraction, respecting the anim mode + RGB
local function trColorAt(fade, t)
	if F.RGB.enabled then return F.RGB.color end
	local a = F.TR.anim
	if a == "Gradient" then return F.TR.color:Lerp(F.TR.color2, fade)
	elseif a == "Wave" then
		local phase = (fade - t * F.TR.animSpeed * 0.15) % 1
		return F.TR.color:Lerp(F.TR.color2, (math.sin(phase * math.pi * 2) + 1) / 2)
	elseif a == "Rainbow" then return Color3.fromHSV((t * 0.25 + fade * 0.3) % 1, 0.9, 1)
	elseif a == "Pulse" then return F.TR.color:Lerp(F.TR.color2, (math.sin(t * F.TR.animSpeed) + 1) / 2)
	end
	return F.TR.color
end
local function trOrbClass()
	local s = F.TR.shape
	return (s == "Cube" and "BoxHandleAdornment") or (s == "Cone" and "ConeHandleAdornment") or "SphereHandleAdornment"
end
local function trNewEntry()
	local core = create(trOrbClass(), { Parent = ScreenGui, Adornee = Workspace.Terrain, ZIndex = 2, Visible = false })
	local glow = create("SphereHandleAdornment", { Parent = ScreenGui, Adornee = Workspace.Terrain, ZIndex = 1, Visible = false })
	return { core = core, glow = glow }
end
local function trSetSize(a, r)
	if a:IsA("SphereHandleAdornment") then a.Radius = r
	elseif a:IsA("BoxHandleAdornment") then a.Size = Vector3.new(r * 1.8, r * 1.8, r * 1.8)
	elseif a:IsA("ConeHandleAdornment") then a.Radius = r * 1.1; a.Height = r * 2.4 end
end

local TR_BASE = { "trender_style", "trender_shape", "trender_speed", "trender_radius", "trender_orb", "trender_strands",
	"trender_trail", "trender_height", "trender_bob", "trender_glow", "trender_team", "trender_ontop", "trender_color", "trender_color2",
	"trender_anim", "trender_animspeed", "trender_ring", "trender_marker", "trender_beam" }
local TR_RING = { "trender_ringstyle", "trender_ringcount", "trender_ringfill", "trender_ringthick", "trender_ringtilt", "trender_ringspeed" }
local TR_MARK = { "trender_mshape", "trender_msize", "trender_mspin" }
local TR_BEAM = { "trender_bwidth", "trender_bheight" }
local function trSetVis(list, v) for _, f in ipairs(list) do local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end end end
local function showTrSubs(v)
	trSetVis(TR_BASE, v)
	trSetVis(TR_RING, v and F.TR.ring)
	trSetVis(TR_MARK, v and F.TR.marker)
	trSetVis(TR_BEAM, v and F.TR.beam)
end

trP:AddToggle({ Text = "Target Renderer", Flag = "trender", Callback = function(on)
	F.TR.enabled = on; showTrSubs(on)
	if on then
		Library:StartLoop("trender", RunService.RenderStepped, function(dt)
			local char, hrp, hum = trTargetChar()
			if not (char and hrp) then trHide(); return end
			F.TR.rot = F.TR.rot + dt * F.TR.speed * 2.4
			local t = tick()
			local center = hrp.Position
			local hip = hum and hum.HipHeight or 0
			if hip <= 0.1 then hip = 2 end   -- R6 reports 0
			local feetY = center.Y - (hip + 1)
			local head = char:FindFirstChild("Head")
			local topY = head and (head.Position.Y + 0.7) or (center.Y + 2.4)
			local height = math.max(topY - feetY, 3) * F.TR.heightScale
			local S, K, R = F.TR.strands, F.TR.trail, F.TR.radius
			local N = math.max(S * K, 1)
			local style = F.TR.style
			local structural = TR_STRUCTURAL[style]
			local baseCol = trColorAt(0, t)   -- ring / marker / beam colour
			local n = 0
			for s = 0, S - 1 do
				for k = 0, K - 1 do
					n = n + 1
					local e = F.TR.pool[n]
					if not e then e = trNewEntry(); F.TR.pool[n] = e end
					local i = s * K + k
					local ang = F.TR.rot + s * (math.pi * 2 / S) - k * 0.16
					local frac = (F.TR.rot * 0.22 + k * 0.035 + s / S) % 1
					local pos
					if style == "Orbit" then
						local bob = math.sin(F.TR.rot * 1.35 + s * 2.1) * height * F.TR.bob
						pos = Vector3.new(center.X + math.cos(ang) * R, center.Y + bob, center.Z + math.sin(ang) * R)
					elseif style == "Helix" then
						local rr = R * (1 - frac * 0.25)
						pos = Vector3.new(center.X + math.cos(ang) * rr, feetY + frac * height, center.Z + math.sin(ang) * rr)
					elseif style == "DNA" then
						local f2 = (F.TR.rot * 0.18 + k * 0.03) % 1
						local a2 = F.TR.rot * 1.4 + f2 * math.pi * 4 + s * math.pi
						pos = Vector3.new(center.X + math.cos(a2) * R * 0.6, feetY + f2 * height, center.Z + math.sin(a2) * R * 0.6)
					elseif style == "Tornado" then
						local rr = R * (0.25 + 0.85 * frac)
						pos = Vector3.new(center.X + math.cos(ang) * rr, feetY + frac * height, center.Z + math.sin(ang) * rr)
					elseif style == "Vortex" then
						local rr = R * (1 - 0.72 * frac)
						pos = Vector3.new(center.X + math.cos(ang) * rr, feetY + frac * height, center.Z + math.sin(ang) * rr)
					elseif style == "Galaxy" then
						local plane = CFrame.Angles(0, s * (math.pi / math.max(S, 1)), 0) * CFrame.Angles(math.rad(38), 0, 0)
						pos = center + plane:VectorToWorldSpace(Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R))
					elseif style == "Atom" then
						local plane = CFrame.Angles(0, s * (math.pi / math.max(S, 1)), 0) * CFrame.Angles(math.rad(65), 0, 0)
						local a2 = F.TR.rot * 2 + k * (math.pi * 2 / K)
						pos = center + plane:VectorToWorldSpace(Vector3.new(math.cos(a2) * R, 0, math.sin(a2) * R))
					elseif style == "Sphere" then
						local y = 1 - 2 * (i + 0.5) / N
						local rr = math.sqrt(math.max(1 - y * y, 0))
						local theta = i * 2.399963 + F.TR.rot
						pos = Vector3.new(center.X + rr * math.cos(theta) * R, center.Y + y * R, center.Z + rr * math.sin(theta) * R)
					elseif style == "Rings" then
						local ringY = feetY + ((s + 0.5) / S) * height
						local dir = (s % 2 == 0) and 1 or -1
						local a2 = F.TR.rot * dir + k * (math.pi * 2 / K)
						pos = Vector3.new(center.X + math.cos(a2) * R, ringY, center.Z + math.sin(a2) * R)
					elseif style == "Cage" then
						local a2 = s * (math.pi * 2 / S) + F.TR.rot * 0.4
						local y = feetY + (K > 1 and (k / (K - 1)) or 0.5) * height
						pos = Vector3.new(center.X + math.cos(a2) * R, y, center.Z + math.sin(a2) * R)
					elseif style == "Spiral" then
						local a2 = i * 0.6 + F.TR.rot
						local rr = R * (0.15 + 0.85 * (i / math.max(N - 1, 1)))
						pos = Vector3.new(center.X + math.cos(a2) * rr, feetY + 0.12, center.Z + math.sin(a2) * rr)
					else -- Halo: one ring above the head
						local a2 = F.TR.rot + i * (math.pi * 2 / N)
						pos = Vector3.new(center.X + math.cos(a2) * R * 0.62, topY + 0.5, center.Z + math.sin(a2) * R * 0.62)
					end
					local fade = structural and (i / N) or (k / math.max(K, 1))
					local col = trColorAt(fade, t)
					local core, glow = e.core, e.glow
					local sz
					if structural then
						sz = F.TR.orb * (0.85 + 0.15 * math.sin(t * 3 + i))
						core.Transparency = 0.1
					else
						sz = F.TR.orb * (1 - fade * 0.72) * (k == 0 and (1 + 0.15 * math.sin(t * 6)) or 1)
						core.Transparency = 0.05 + fade * 0.85
					end
					local cf = CFrame.new(pos)
					if not core:IsA("SphereHandleAdornment") then cf = cf * CFrame.Angles(F.TR.rot * 1.5, F.TR.rot * 2, math.rad(45)) end
					core.CFrame = cf
					trSetSize(core, sz)
					core.Color3 = col; core.AlwaysOnTop = F.TR.onTop; core.Visible = true
					if F.TR.glow then
						glow.CFrame = CFrame.new(pos); glow.Radius = sz * 2.3; glow.Color3 = col
						glow.Transparency = structural and 0.6 or math.min(0.92, 0.5 + fade * 0.45)
						glow.AlwaysOnTop = F.TR.onTop; glow.Visible = true
					else glow.Visible = false end
				end
			end
			for j = n + 1, #F.TR.pool do local e = F.TR.pool[j]; e.core.Visible = false; e.glow.Visible = false end

			-- ===== RING SYSTEM (multi-mode, multi-count) =====
			if F.TR.ring then
				local rc = F.TR.ringCount
				for ri = 1, rc do
					local ad = F.TR.rings[ri]
					if not ad then ad = create("CylinderHandleAdornment", { Parent = ScreenGui, Adornee = Workspace.Terrain, Height = 0.06, ZIndex = 1 }); F.TR.rings[ri] = ad end
					local phase = (ri - 1) / rc
					local rstyle, ringY, rr, alpha = F.TR.ringStyle, feetY + 0.06, R, 0.15
					if rstyle == "Ground" then
						ringY = feetY + 0.06 + (ri - 1) * 0.09
						rr = R * (1 + math.sin(t * 2.2 + phase * 6) * 0.06)
					elseif rstyle == "Scan" then
						local sweep = (math.sin(t * F.TR.ringSpeed * 2 + phase * math.pi * 2) + 1) / 2
						ringY = feetY + sweep * height; rr = R * 0.85
					elseif rstyle == "Pulse" then
						local p = (t * F.TR.ringSpeed * 0.6 + phase) % 1
						ringY = feetY + 0.06; rr = R * (0.3 + p * 1.7); alpha = 0.12 + p * 0.82
					elseif rstyle == "Stack" then
						ringY = feetY + ((ri - 0.5) / rc) * height; rr = R
					else -- Halo
						ringY = topY + 0.4 + (ri - 1) * 0.28; rr = R * 0.6
					end
					ad.CFrame = CFrame.new(center.X, ringY, center.Z) * CFrame.Angles(0, F.TR.rot * F.TR.ringSpeed, 0) * CFrame.Angles(math.rad(90) + math.rad(F.TR.ringTilt), 0, 0)
					ad.Radius = rr
					ad.InnerRadius = F.TR.ringFill and 0 or math.max(rr - F.TR.ringThick, 0)
					ad.Angle = F.TR.ringFill and 360 or 300
					ad.Color3 = baseCol; ad.Transparency = math.clamp(alpha, 0, 0.95)
					ad.AlwaysOnTop = F.TR.onTop; ad.Visible = true
				end
				for ri = rc + 1, #F.TR.rings do F.TR.rings[ri].Visible = false end
			else for _, ad in ipairs(F.TR.rings) do ad.Visible = false end end

			-- ===== OVERHEAD MARKER (spinning shape above the head) =====
			if F.TR.marker then
				if not F.TR.markerAd or F.TR.markerCur ~= F.TR.markerShape then
					if F.TR.markerAd then F.TR.markerAd:Destroy() end
					local ms = F.TR.markerShape
					local cls = (ms == "Arrow" and "ConeHandleAdornment") or (ms == "Ring" and "CylinderHandleAdornment") or "BoxHandleAdornment"
					F.TR.markerAd = create(cls, { Parent = ScreenGui, Adornee = Workspace.Terrain, ZIndex = 2 })
					F.TR.markerCur = ms
				end
				local m = F.TR.markerAd
				local my = topY + 1.2 + math.sin(t * 2) * 0.15   -- gentle hover
				local spin = t * F.TR.markerSpin
				local sz = F.TR.markerSize
				if F.TR.markerShape == "Arrow" then
					m.Radius = sz * 0.7; m.Height = sz * 1.9
					m.CFrame = CFrame.new(center.X, my + sz, center.Z) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(90), 0, 0)
				elseif F.TR.markerShape == "Ring" then
					m.Radius = sz; m.InnerRadius = sz * 0.68; m.Height = 0.08; m.Angle = 360
					m.CFrame = CFrame.new(center.X, my, center.Z) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(90), 0, 0)
				else -- Diamond / Cube
					m.Size = Vector3.new(sz, sz, sz)
					local tilt = (F.TR.markerShape == "Diamond") and CFrame.Angles(math.rad(45), spin, math.rad(45)) or CFrame.Angles(0, spin, 0)
					m.CFrame = CFrame.new(center.X, my, center.Z) * tilt
				end
				m.Color3 = baseCol; m.Transparency = 0.1; m.AlwaysOnTop = F.TR.onTop; m.Visible = true
			elseif F.TR.markerAd then F.TR.markerAd.Visible = false end

			-- ===== LIGHT BEAM (vertical pillar) =====
			if F.TR.beam then
				if not F.TR.beamAd then F.TR.beamAd = create("CylinderHandleAdornment", { Parent = ScreenGui, Adornee = Workspace.Terrain, ZIndex = 0 }) end
				local b = F.TR.beamAd
				b.Radius = F.TR.beamWidth; b.InnerRadius = 0; b.Height = F.TR.beamHeight; b.Angle = 360
				b.CFrame = CFrame.new(center.X, feetY + F.TR.beamHeight * 0.5, center.Z) * CFrame.Angles(math.rad(90), 0, 0)
				b.Color3 = baseCol; b.Transparency = 0.5; b.AlwaysOnTop = F.TR.onTop; b.Visible = true
			elseif F.TR.beamAd then F.TR.beamAd.Visible = false end
		end)
	else Library:StopLoop("trender"); trHide() end
end })
trP:AddDropdown({ Text = "Style", Flag = "trender_style", Options = { "Orbit", "Helix", "DNA", "Tornado", "Vortex", "Galaxy", "Atom", "Sphere", "Rings", "Cage", "Spiral", "Halo" },
	Default = "Orbit", Callback = function(v) F.TR.style = v end })
trP:AddDropdown({ Text = "Orb Shape", Flag = "trender_shape", Options = { "Sphere", "Cube", "Cone" }, Default = "Sphere",
	Callback = function(v) F.TR.shape = v; trClear() end })   -- rebuild pool with the new shape
trP:AddSlider({ Text = "Spin Speed", Flag = "trender_speed", Min = 0.2, Max = 6, Decimals = 1, Default = 1.5, Suffix = "x",
	Callback = function(v) F.TR.speed = v end })
trP:AddSlider({ Text = "Radius", Flag = "trender_radius", Min = 1, Max = 8, Decimals = 1, Default = 2.6,
	Callback = function(v) F.TR.radius = v end })
trP:AddSlider({ Text = "Orb Size", Flag = "trender_orb", Min = 0.08, Max = 1, Decimals = 2, Default = 0.3,
	Callback = function(v) F.TR.orb = v end })
trP:AddSlider({ Text = "Strands / Bars", Flag = "trender_strands", Min = 1, Max = 8, Default = 3, Callback = function(v) F.TR.strands = v end })
trP:AddSlider({ Text = "Trail / Density", Flag = "trender_trail", Min = 3, Max = 18, Default = 8, Callback = function(v) F.TR.trail = v end })
trP:AddSlider({ Text = "Height", Flag = "trender_height", Min = 0.3, Max = 2.5, Decimals = 2, Default = 1, Suffix = "x",
	Callback = function(v) F.TR.heightScale = v end })
trP:AddSlider({ Text = "Bob Amount", Flag = "trender_bob", Min = 0, Max = 0.6, Decimals = 2, Default = 0.25,
	Callback = function(v) F.TR.bob = v end })
trP:AddToggle({ Text = "Glow", Flag = "trender_glow", Default = true, Callback = function(on) F.TR.glow = on end })
trP:AddToggle({ Text = "Ring", Flag = "trender_ring", Default = true, Callback = function(on)
	F.TR.ring = on; trSetVis(TR_RING, on and F.TR.enabled) end })
trP:AddDropdown({ Text = "Ring Motion", Flag = "trender_ringstyle", Options = { "Ground", "Scan", "Pulse", "Stack", "Halo" }, Default = "Ground",
	Sub = true, Callback = function(v) F.TR.ringStyle = v end })
trP:AddSlider({ Text = "Ring Count", Flag = "trender_ringcount", Min = 1, Max = 5, Default = 1, Sub = true, Callback = function(v) F.TR.ringCount = v end })
trP:AddToggle({ Text = "Ring Filled", Flag = "trender_ringfill", Sub = true, Callback = function(on) F.TR.ringFill = on end })
trP:AddSlider({ Text = "Ring Thickness", Flag = "trender_ringthick", Min = 0.08, Max = 1.5, Decimals = 2, Default = 0.22,
	Sub = true, Callback = function(v) F.TR.ringThick = v end })
trP:AddSlider({ Text = "Ring Tilt", Flag = "trender_ringtilt", Min = 0, Max = 80, Default = 0, Suffix = "\u{00B0}", Sub = true,
	Callback = function(v) F.TR.ringTilt = v end })
trP:AddSlider({ Text = "Ring Speed", Flag = "trender_ringspeed", Min = 0.2, Max = 5, Decimals = 1, Default = 1.2, Sub = true,
	Callback = function(v) F.TR.ringSpeed = v end })
trP:AddToggle({ Text = "Overhead Marker", Flag = "trender_marker", Callback = function(on)
	F.TR.marker = on; trSetVis(TR_MARK, on and F.TR.enabled) end })
trP:AddDropdown({ Text = "Marker Shape", Flag = "trender_mshape", Options = { "Diamond", "Arrow", "Cube", "Ring" }, Default = "Diamond",
	Sub = true, Callback = function(v) F.TR.markerShape = v end })
trP:AddSlider({ Text = "Marker Size", Flag = "trender_msize", Min = 0.2, Max = 2, Decimals = 2, Default = 0.6, Sub = true,
	Callback = function(v) F.TR.markerSize = v end })
trP:AddSlider({ Text = "Marker Spin", Flag = "trender_mspin", Min = 0, Max = 8, Decimals = 1, Default = 2, Sub = true,
	Callback = function(v) F.TR.markerSpin = v end })
trP:AddToggle({ Text = "Light Beam", Flag = "trender_beam", Callback = function(on)
	F.TR.beam = on; trSetVis(TR_BEAM, on and F.TR.enabled) end })
trP:AddSlider({ Text = "Beam Width", Flag = "trender_bwidth", Min = 0.03, Max = 0.6, Decimals = 2, Default = 0.14, Sub = true,
	Callback = function(v) F.TR.beamWidth = v end })
trP:AddSlider({ Text = "Beam Height", Flag = "trender_bheight", Min = 6, Max = 60, Default = 30, Sub = true,
	Callback = function(v) F.TR.beamHeight = v end })
trP:AddToggle({ Text = "Team Check", Flag = "trender_team", Callback = function(on) F.TR.teamCheck = on end })
trP:AddToggle({ Text = "Through Walls", Flag = "trender_ontop", Default = true, Callback = function(on) F.TR.onTop = on end })
trP:AddColorPicker({ Text = "Color 1", Flag = "trender_color", Default = COLORS.Purple, Callback = function(c) F.TR.color = c end })
trP:AddColorPicker({ Text = "Color 2", Flag = "trender_color2", Default = COLORS.Cyan, Callback = function(c) F.TR.color2 = c end })
trP:AddDropdown({ Text = "Animation", Flag = "trender_anim", Options = { "Off", "Gradient", "Wave", "Rainbow", "Pulse" },
	Default = "Wave", Callback = function(v) F.TR.anim = v end })
trP:AddSlider({ Text = "Anim Speed", Flag = "trender_animspeed", Min = 0.5, Max = 10, Decimals = 1, Default = 2,
	Callback = function(v) F.TR.animSpeed = v end })
showTrSubs(false)

--=====================================================================
--  MISC CATEGORY
--=====================================================================
local MiscCat = Library:AddCategory("Misc", 3)

--== Movement ==--
local movePage = MiscCat:AddTab("Movement")
local moveP = movePage:AddPanel("Movement")

F.Fly = { enabled = false, speed = 60, bv = nil, bg = nil }
local function stopFly()
	Library:StopLoop("fly")
	if F.Fly.bv then F.Fly.bv:Destroy(); F.Fly.bv = nil end
	if F.Fly.bg then F.Fly.bg:Destroy(); F.Fly.bg = nil end
end
local function startFly()
	local char = getChar(); if not char then return end
	local hrp = char.HumanoidRootPart; stopFly()
	F.Fly.bv = create("BodyVelocity", { Parent = hrp, MaxForce = Vector3.one * 9e9, Velocity = Vector3.zero, P = 1250 })
	F.Fly.bg = create("BodyGyro", { Parent = hrp, MaxTorque = Vector3.one * 9e9, P = 9000, D = 500 })
	Library:StartLoop("fly", RunService.RenderStepped, function()
		if not F.Fly.enabled then return end
		local c = getChar(); if not c then return end
		local root = c.HumanoidRootPart
		if not F.Fly.bv or F.Fly.bv.Parent ~= root then startFly(); return end
		local mv, cf = Vector3.zero, Camera.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv -= Vector3.yAxis end
		F.Fly.bv.Velocity = (mv.Magnitude > 0 and mv.Unit or Vector3.zero) * F.Fly.speed
		F.Fly.bg.CFrame = cf
	end)
end
moveP:AddToggle({ Text = "Fly", Flag = "fly", Bind = true, Callback = function(on)
	F.Fly.enabled = on; if on then startFly() else stopFly() end end })
moveP:AddSlider({ Text = "Fly Speed", Flag = "fly_speed", Min = 10, Max = 300, Default = 60, Callback = function(v) F.Fly.speed = v end })
F.Noclip = { enabled = false }
moveP:AddToggle({ Text = "Noclip", Flag = "noclip", Bind = true, Callback = function(on)
	F.Noclip.enabled = on
	if on then Library:StartLoop("noclip", RunService.Stepped, function()
			local c = getChar(); if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end
		end) else Library:StopLoop("noclip") end
end })
F.InfJump = { enabled = false }
moveP:AddToggle({ Text = "Infinite Jump", Flag = "infjump", Callback = function(on) F.InfJump.enabled = on end })
Library:Connect(UserInputService.JumpRequest, function()
	if F.InfJump.enabled then local h = getHumanoid(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

-- Extra movement
local moveP2 = movePage:AddPanel("Extra")

-- Spinbot: spins your character on the spot. Runs on HEARTBEAT with an
-- ABSOLUTE accumulated angle: shiftlock / first person re-face you to the
-- camera every render frame, so an incremental rotate on RenderStepped gets
-- fought and stalls. Heartbeat fires after those camera scripts + physics,
-- so our rotation is what replicates - and since the camera's yaw is
-- mouse-driven (not character-driven), your own view stays perfectly still.
F.Spin = { enabled = false, speed = 20, angle = 0 }
moveP2:AddToggle({ Text = "Spinbot", Flag = "spin", Callback = function(on)
	F.Spin.enabled = on
	if on then
		local hum = getHumanoid(); if hum then hum.AutoRotate = false end
		Library:StartLoop("spin", RunService.Heartbeat, function(dt)
			local char = getChar(); if not char then return end
			local hum2 = getHumanoid(); if hum2 and hum2.AutoRotate then hum2.AutoRotate = false end  -- respawn re-enables it
			F.Spin.angle = (F.Spin.angle + math.rad(F.Spin.speed) * dt * 60) % (math.pi * 2)
			local hrp = char.HumanoidRootPart
			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, F.Spin.angle, 0)
		end)
	else
		Library:StopLoop("spin")
		local hum = getHumanoid(); if hum and not (F.AA and F.AA.enabled) then hum.AutoRotate = true end
	end
end })
moveP2:AddSlider({ Text = "Spin Speed", Flag = "spin_speed", Min = 1, Max = 45, Default = 20, Callback = function(v) F.Spin.speed = v end })

-- Anti-Aim: rewrites your HumanoidRootPart so the SERVER + OTHER PLAYERS see you
-- facing away / spinning / leaning down, desynced from your own view. Only the
-- ROOT replicates in Roblox (joint/head tilts are client-only - that's why the
-- old spine bend was invisible to others), so everything here drives the root.
-- The look-down is a LEAN PIVOTED AT YOUR FEET (feet planted, body angles down)
-- - a real rotation others see, not a horizontal backflip. Fling is prevented by
-- disabling the ragdoll/falling states. Your camera/aim/movement stay untouched.
-- The yaw effects are independent TOGGLES so you can stack them (e.g. Look Away
-- From Target + Jitter, or Spin + Jitter).
F.AA = { enabled = false, spin = false, jitter = false, awayTarget = false, awayCamera = false,
	pitch = -45, speed = 24, angle = 0, jAngle = 120, jFlip = false, randPitch = false,
	crouch = false, crouchMode = "Hold", crouchHeld = false, lastOffset = Vector3.zero, stateHum = nil }

-- nearest enemy inside the FOV circle (crosshair-based, friends excluded)
local function aaEnemyPos()
	local mouse = UserInputService:GetMouseLocation()
	local best, bestD
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isFriend(plr) then
			local ch = plr.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp and hum and hum.Health > 0 then
				local sp, on = Camera:WorldToViewportPoint(hrp.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
					if d <= (F.Aim.fov or 120) and (not bestD or d < bestD) then best, bestD = hrp.Position, d end
				end
			end
		end
	end
	return best
end
-- crouch = a real key event (VirtualInputManager) on the key YOU bind, since
-- every game maps crouch differently
local function aaCrouch(down)
	local opt = Library.Options["aa_crouchkey"]
	local key = opt and opt.Get and opt:Get()
	if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then return end
	pcall(function()
		game:GetService("VirtualInputManager"):SendKeyEvent(down, key, false, game)
	end)
end
local function aaTap()  -- for games where crouch is a toggle, not a hold
	aaCrouch(true); task.delay(0.06, function() aaCrouch(false) end)
end
-- a leaned (non-upright) root makes the Humanoid try to ragdoll / fall / get-up,
-- and THAT is the fling. Disabling those states lets the root hold the lean.
local AA_FLING_STATES = { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp }
local function aaStates(hum, enabled)
	if not hum then return end
	for _, st in ipairs(AA_FLING_STATES) do pcall(function() hum:SetStateEnabled(st, enabled) end) end
end
local function showAaSubs(v)
	for _, f in ipairs({ "aa_spin", "aa_speed", "aa_jitter", "aa_jangle", "aa_awayt", "aa_awayc",
		"aa_pitch", "aa_rpitch", "aa_crouch", "aa_crouchmode", "aa_crouchkey" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
moveP2:AddToggle({ Text = "Anti Aim", Flag = "aa", Bind = true, Callback = function(on)
	F.AA.enabled = on; showAaSubs(on)
	if on then
		if F.AA.crouch then
			if F.AA.crouchMode == "Hold" then aaCrouch(true); F.AA.crouchHeld = true else aaTap() end
		end
		Library:StartLoop("antiaim", RunService.Heartbeat, function(dt)
			local char = getChar(); if not char then return end
			local hrp = char.HumanoidRootPart
			local hum2 = getHumanoid()
			local anyYaw = F.AA.spin or F.AA.jitter or F.AA.awayTarget or F.AA.awayCamera
			local pitchOn = math.abs(F.AA.pitch) > 0.5
			if hum2 then
				if (anyYaw or pitchOn) and hum2.AutoRotate then hum2.AutoRotate = false end
				-- (re)disable fling states whenever the humanoid changes (respawn)
				if F.AA.stateHum ~= hum2 then aaStates(hum2, false); F.AA.stateHum = hum2 end
			end
			-- ===== YAW: independent, stackable. Base facing from away/spin, then
			-- Jitter flicks on top of whatever the base is (or your current facing) =====
			local baseYaw
			if F.AA.awayTarget then
				local ep = aaEnemyPos()
				local away = ep and Vector3.new(hrp.Position.X - ep.X, 0, hrp.Position.Z - ep.Z) or -Camera.CFrame.LookVector
				if away.Magnitude < 0.01 then away = Vector3.new(0, 0, -1) end
				away = away.Unit
				baseYaw = math.atan2(-away.X, -away.Z)
			elseif F.AA.awayCamera then
				local look = Camera.CFrame.LookVector
				baseYaw = math.atan2(look.X, look.Z)   -- 180 from where you look
			elseif F.AA.spin then
				F.AA.angle = (F.AA.angle + math.rad(F.AA.speed) * dt * 60) % (math.pi * 2)
				baseYaw = F.AA.angle
			end
			local yaw = baseYaw
			if F.AA.jitter then
				F.AA.jFlip = not F.AA.jFlip
				local b = baseYaw or select(2, hrp.CFrame:ToOrientation())
				yaw = b + math.rad(F.AA.jAngle) * (F.AA.jFlip and 0.5 or -0.5)   -- flick ± each frame
			end
			if yaw == nil then yaw = select(2, hrp.CFrame:ToOrientation()) end   -- hold facing if no yaw effect
			-- ===== PITCH: lean the root about the FEET (feet stay planted, body
			-- angles down) - a real rotation others see, no horizontal flip.
			-- Drift-corrected: strip the offset we added last frame before re-leaning =====
			if not (anyYaw or pitchOn) then return end   -- nothing enabled: leave the root alone
			local pitch = F.AA.pitch
			if F.AA.randPitch then pitch = pitch * (math.random() < 0.5 and 1 or -1) end
			local L = 2.8   -- approx root->feet distance
			local uprightPos = hrp.Position - F.AA.lastOffset
			local baseCf = CFrame.new(uprightPos) * CFrame.Angles(0, yaw, 0)
			local leaned = baseCf * CFrame.new(0, -L, 0) * CFrame.Angles(math.rad(pitch), 0, 0) * CFrame.new(0, L, 0)
			F.AA.lastOffset = leaned.Position - uprightPos
			hrp.CFrame = leaned
			hrp.AssemblyAngularVelocity = Vector3.zero
			local v = hrp.AssemblyLinearVelocity
			local cap = ((hum2 and hum2.WalkSpeed or 16) + 80)
			if v.Magnitude > cap then hrp.AssemblyLinearVelocity = v.Unit * cap end
		end)
	else
		Library:StopLoop("antiaim")
		F.AA.lastOffset = Vector3.zero
		local hum = getHumanoid()
		if hum then aaStates(hum, true); if not F.Spin.enabled then hum.AutoRotate = true end end
		F.AA.stateHum = nil
		if F.AA.crouchHeld then aaCrouch(false); F.AA.crouchHeld = false
		elseif F.AA.crouch and F.AA.crouchMode == "Tap" then aaTap() end
	end
end })
-- stackable yaw effects (enable any combination)
moveP2:AddToggle({ Text = "Spin", Flag = "aa_spin", Sub = true, Callback = function(on) F.AA.spin = on end })
moveP2:AddSlider({ Text = "Spin Speed", Flag = "aa_speed", Min = 1, Max = 60, Default = 24, Sub = true,
	Callback = function(v) F.AA.speed = v end })
moveP2:AddToggle({ Text = "Jitter", Flag = "aa_jitter", Sub = true, Callback = function(on) F.AA.jitter = on end })
moveP2:AddSlider({ Text = "Jitter Angle", Flag = "aa_jangle", Min = 20, Max = 180, Default = 120, Suffix = "\u{00B0}", Sub = true,
	Callback = function(v) F.AA.jAngle = v end })
moveP2:AddToggle({ Text = "Look Away From Target", Flag = "aa_awayt", Sub = true, Callback = function(on) F.AA.awayTarget = on end })
moveP2:AddToggle({ Text = "Look Away From Camera", Flag = "aa_awayc", Sub = true, Callback = function(on) F.AA.awayCamera = on end })
moveP2:AddSlider({ Text = "Look Pitch", Flag = "aa_pitch", Min = -89, Max = 89, Default = -45, Suffix = "\u{00B0}", Sub = true,
	Callback = function(v) F.AA.pitch = v end })
moveP2:AddToggle({ Text = "Randomize Pitch", Flag = "aa_rpitch", Sub = true, Callback = function(on) F.AA.randPitch = on end })
moveP2:AddToggle({ Text = "Crouch", Flag = "aa_crouch", Sub = true, Callback = function(on)
	F.AA.crouch = on
	if F.AA.enabled then
		if on then
			if F.AA.crouchMode == "Hold" then aaCrouch(true); F.AA.crouchHeld = true else aaTap() end
		else
			if F.AA.crouchHeld then aaCrouch(false); F.AA.crouchHeld = false
			elseif F.AA.crouchMode == "Tap" then aaTap() end
		end
	end
end })
moveP2:AddDropdown({ Text = "Crouch Mode", Flag = "aa_crouchmode", Options = { "Hold", "Tap" }, Default = "Hold",
	Sub = true, Callback = function(v) F.AA.crouchMode = v end })
moveP2:AddKeybind({ Text = "Crouch Key", Flag = "aa_crouchkey", Default = Enum.KeyCode.LeftControl, Sub = true })
moveP2:AddLabel("Stack any effects: Spin / Jitter / Look Away From Target / Camera all combine. Look Pitch leans your body down about the feet (planted, no flip) - a real rotation other players SEE. Your camera, aim and movement stay normal.")
showAaSubs(false)

-- Bunny Hop: auto-jumps the instant you land. Anti-aim rewrites the root
-- every tick which can blank out Humanoid.FloorMaterial, so a short ground
-- raycast backs it up - bhop + anti-aim work together now.
F.BHop = { enabled = false, mode = "Hold Space" }
moveP2:AddToggle({ Text = "Bunny Hop", Flag = "bhop", Callback = function(on)
	F.BHop.enabled = on
	if on then
		Library:StartLoop("bhop", RunService.Heartbeat, function()
			if F.BHop.mode == "Hold Space" and not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
			local hum = getHumanoid(); local char = getChar()
			if not (hum and char) then return end
			local grounded = hum.FloorMaterial ~= Enum.Material.Air
			if not grounded then
				local hrp = char.HumanoidRootPart
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { char }
				local hip = hum.HipHeight > 0.1 and hum.HipHeight or 2
				grounded = Workspace:Raycast(hrp.Position, Vector3.new(0, -(hip + 1.6), 0), rp) ~= nil
			end
			if grounded then
				hum.Jump = true  -- reliable re-jump the instant you land
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	else Library:StopLoop("bhop") end
end })
moveP2:AddDropdown({ Text = "Hop Mode", Flag = "bhop_mode", Options = { "Hold Space", "Always" }, Default = "Hold Space",
	Sub = true, Callback = function(v) F.BHop.mode = v end })

-- Freecam: detach the camera and fly it with WASD (hold Right Click to look around)
F.Freecam = { enabled = false, speed = 60, pos = nil, yaw = 0, pitch = 0 }
moveP2:AddToggle({ Text = "Freecam", Flag = "freecam", Callback = function(on)
	F.Freecam.enabled = on
	if on then
		local cf = Camera.CFrame
		F.Freecam.pos = cf.Position
		F.Freecam.pitch, F.Freecam.yaw = cf:ToOrientation()
		Camera.CameraType = Enum.CameraType.Scriptable
		Library:StartLoop("freecam", RunService.RenderStepped, function(dt)
			local U = UserInputService
			if U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				U.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				local d = U:GetMouseDelta()
				F.Freecam.yaw -= d.X * 0.004
				F.Freecam.pitch = math.clamp(F.Freecam.pitch - d.Y * 0.004, -1.45, 1.45)
			else
				U.MouseBehavior = Enum.MouseBehavior.Default
			end
			local rot = CFrame.fromOrientation(F.Freecam.pitch, F.Freecam.yaw, 0)
			local move = Vector3.zero
			if U:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
			if U:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
			if U:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
			if U:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
			if U:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if U:IsKeyDown(Enum.KeyCode.LeftControl) then move += Vector3.new(0, -1, 0) end
			if move.Magnitude > 0 then F.Freecam.pos += rot:VectorToWorldSpace(move.Unit) * F.Freecam.speed * dt end
			Camera.CFrame = CFrame.new(F.Freecam.pos) * rot
		end)
		Library:Notify("Freecam", "WASD to move, hold Right Click to look.", 4, "good")
	else
		Library:StopLoop("freecam")
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		Camera.CameraType = Enum.CameraType.Custom
	end
end })
moveP2:AddSlider({ Text = "Freecam Speed", Flag = "freecam_speed", Min = 10, Max = 300, Default = 60, Callback = function(v) F.Freecam.speed = v end })

--== Camera ==--
local camPage = MiscCat:AddTab("Camera")
local camP = camPage:AddPanel("Camera")
F.Cam = { mode = "Off", dist = 12, freeZoom = false, bypass = false, bypassMode = "Piggyback", offX = 0, offY = 0,
	sens = 1, smooth = 0, wallCheck = true, yaw = nil, pitch = nil, _lastBase = nil, _lastOut = nil }
local camBound = false
local function unbindCam()
	if camBound then
		camBound = false
		pcall(function() RunService:UnbindFromRenderStep("xRustCam") end)
	end
end
local function camReset()
	unbindCam()
	pcall(function()
		Camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		LocalPlayer.CameraMode = Enum.CameraMode.Classic
		LocalPlayer.CameraMinZoomDistance = 0.5; LocalPlayer.CameraMaxZoomDistance = 400
		local hum = getHumanoid(); if hum then hum.CameraOffset = Vector3.zero end
	end)
	F.Cam.yaw, F.Cam.pitch = nil, nil
	F.Cam._lastBase, F.Cam._lastOut = nil, nil
end
-- FP-lock bypass v4, bound AFTER the game's camera (RenderPriority.Camera+1):
--  * Piggyback (default): the game's camera keeps FULL control of look, aim
--    and movement - aimbot, custom control scripts, everything behaves exactly
--    like first person. After the game finishes its update we only dolly the
--    eye backwards in view space. This is what fixes "bypass breaks
--    aimbot/movement in some games".
--  * Standalone: our own orbit camera (raw mouse deltas) for games whose
--    camera can't be ridden; the aimbot steers it through aimAt.
local function bindCam()
	if camBound then return end
	camBound = true
	RunService:BindToRenderStep("xRustCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		pcall(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			if F.Cam.bypassMode == "Piggyback" then
				if Camera.CameraType == Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Custom end
				F.Cam.yaw, F.Cam.pitch = nil, nil
				local base = Camera.CFrame
				-- if the game didn't update its camera this frame, dollying our
				-- own output again would run away - reuse the last real base
				if F.Cam._lastOut and (base.Position - F.Cam._lastOut.Position).Magnitude < 1e-3
					and base.LookVector:Dot(F.Cam._lastOut.LookVector) > 0.999999 then
					base = F.Cam._lastBase or base
				end
				local off = Vector3.new(F.Cam.offX, F.Cam.offY, F.Cam.dist)
				if F.Cam.wallCheck and off.Magnitude > 0.1 then
					local worldOff = base:VectorToWorldSpace(off)
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = { char, Camera }
					local hit = Workspace:Raycast(base.Position, worldOff, rp)
					if hit then
						local f = math.max(((hit.Position - base.Position).Magnitude - 0.5) / worldOff.Magnitude, 0.05)
						off = off * f
					end
				end
				local out = base * CFrame.new(off)
				F.Cam._lastBase, F.Cam._lastOut = base, out
				Camera.CFrame = out
			else
				-- Standalone orbit camera
				if not F.Cam.yaw then
					local px, py = Camera.CFrame:ToOrientation()
					F.Cam.pitch, F.Cam.yaw = px, py
				end
				Camera.CameraType = Enum.CameraType.Scriptable
				if Library.Toggled or UserInputService:GetFocusedTextBox() then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default   -- free the mouse for the menu
				else
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
					local d = UserInputService:GetMouseDelta()
					F.Cam.yaw = F.Cam.yaw - d.X * 0.004 * F.Cam.sens
					F.Cam.pitch = math.clamp(F.Cam.pitch - d.Y * 0.004 * F.Cam.sens, -1.45, 1.45)
				end
				local hum = getHumanoid()
				if hum then hum.CameraOffset = Vector3.zero end
				local focus = hrp.Position + Vector3.new(0, 1.8, 0)
				local rot = CFrame.fromOrientation(F.Cam.pitch, F.Cam.yaw, 0)
				local off = Vector3.new(F.Cam.offX, F.Cam.offY, F.Cam.dist)
				if F.Cam.wallCheck and off.Magnitude > 0.1 then
					-- popper: pull the camera in front of any wall between you and it
					local worldOff = rot:VectorToWorldSpace(off)
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = { char, Camera }
					local hit = Workspace:Raycast(focus, worldOff, rp)
					if hit then
						local f = math.max(((hit.Position - focus).Magnitude - 0.5) / worldOff.Magnitude, 0.05)
						off = off * f
					end
				end
				local target = CFrame.new(focus) * rot * CFrame.new(off)
				if F.Cam.smooth > 0 then
					-- framerate-independent exponential smoothing
					local alpha = math.clamp(1 - (F.Cam.smooth ^ (dt * 60)), 0.05, 1)
					Camera.CFrame = Camera.CFrame:Lerp(target, alpha)
				else
					Camera.CFrame = target
				end
			end
			-- keep your character visible (the engine hides it in FP)
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end
			end
		end)
	end)
end
-- scroll wheel zooms the bypass camera (updates the Distance slider too)
Library:Connect(UserInputService.InputChanged, function(i, gpe)
	if gpe or Library.Toggled then return end
	if F.Cam.bypass and F.Cam.mode == "Third Person" and i.UserInputType == Enum.UserInputType.MouseWheel then
		local o = Library.Options["tp_dist"]
		if o then o:Set(F.Cam.dist - i.Position.Z * 2) end
	end
end)
local function showCamSubs(v)
	for _, f in ipairs({ "tp_dist", "cam_freezoom", "cam_bypass", "cam_mode", "cam_sens", "cam_smooth", "cam_wallcheck", "cam_offx", "cam_offy" }) do
		local o = Library.Options[f]; if o and o.SetVisible then o:SetVisible(v) end
	end
end
camP:AddDropdown({ Text = "Mode", Flag = "camlock", Options = { "Off", "First Person", "Third Person" },
	Default = "Off", Callback = function(v)
		F.Cam.mode = v
		showCamSubs(v == "Third Person")
		if v == "Off" then Library:StopLoop("camlock"); camReset(); return end
		-- re-applied EVERY frame so games that force a camera mode can't fight it back
		Library:StartLoop("camlock", RunService.RenderStepped, function()
			pcall(function()
				if F.Cam.mode == "First Person" then
					unbindCam()
					LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
					return
				end
				if F.Cam.bypass then
					bindCam()   -- the bound orbit camera does all the work
					return
				end
				unbindCam()
				local hum = getHumanoid()
				if Camera.CameraType == Enum.CameraType.Scriptable then
					Camera.CameraType = Enum.CameraType.Custom
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
				F.Cam.yaw, F.Cam.pitch = nil, nil
				LocalPlayer.CameraMode = Enum.CameraMode.Classic
				LocalPlayer.CameraMinZoomDistance = F.Cam.freeZoom and 0.5 or F.Cam.dist
				LocalPlayer.CameraMaxZoomDistance = F.Cam.freeZoom and 400 or F.Cam.dist
				if hum then hum.CameraOffset = Vector3.new(F.Cam.offX, F.Cam.offY, 0) end
			end)
		end)
	end })
camP:AddSlider({ Text = "Distance", Flag = "tp_dist", Min = 2, Max = 40, Default = 12, Callback = function(v) F.Cam.dist = v end })
camP:AddToggle({ Text = "Free Zoom", Flag = "cam_freezoom", Sub = true, Callback = function(on) F.Cam.freeZoom = on end })
camP:AddToggle({ Text = "FP-Lock Bypass", Flag = "cam_bypass", Sub = true, Callback = function(on)
	F.Cam.bypass = on
	if not on then
		unbindCam()
		pcall(function()
			Camera.CameraType = Enum.CameraType.Custom
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
		F.Cam.yaw, F.Cam.pitch = nil, nil
		F.Cam._lastBase, F.Cam._lastOut = nil, nil
	end
end })
camP:AddDropdown({ Text = "Bypass Mode", Flag = "cam_mode", Options = { "Piggyback", "Standalone" }, Default = "Piggyback",
	Sub = true, Callback = function(v)
		F.Cam.bypassMode = v
		F.Cam.yaw, F.Cam.pitch = nil, nil
		F.Cam._lastBase, F.Cam._lastOut = nil, nil
		if v == "Piggyback" then
			pcall(function()
				Camera.CameraType = Enum.CameraType.Custom
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
		end
	end })
camP:AddSlider({ Text = "Cam Sensitivity", Flag = "cam_sens", Min = 0.2, Max = 3, Decimals = 1, Default = 1, Sub = true, Callback = function(v) F.Cam.sens = v end })
camP:AddSlider({ Text = "Cam Smoothing", Flag = "cam_smooth", Min = 0, Max = 0.9, Decimals = 2, Default = 0, Sub = true, Callback = function(v) F.Cam.smooth = v end })
camP:AddToggle({ Text = "Wall Check", Flag = "cam_wallcheck", Default = true, Sub = true, Callback = function(on) F.Cam.wallCheck = on end })
camP:AddSlider({ Text = "Shoulder Offset X", Flag = "cam_offx", Min = -8, Max = 8, Decimals = 1, Default = 0, Sub = true, Callback = function(v) F.Cam.offX = v end })
camP:AddSlider({ Text = "Height Offset Y", Flag = "cam_offy", Min = -4, Max = 8, Decimals = 1, Default = 0, Sub = true, Callback = function(v) F.Cam.offY = v end })
camP:AddLabel("Bypass modes: PIGGYBACK rides the game's own camera - movement + aimbot work exactly like first person, just pulled back (use this first). STANDALONE is a full replacement orbit cam for stubborn games. Scroll = zoom, both modes.")
showCamSubs(false)

--== Utility ==--
local utilPage = MiscCat:AddTab("Utility")
local utilP  = utilPage:AddPanel("HUD / Crosshair")
local utilP2 = utilPage:AddPanel("Server")

-- HUD
F.HUD = { enabled = false, gui = nil }
posFlag("hud_pos", F.HUD)  -- dragged position persists in configs
local function buildHUD()
	if F.HUD.gui then return end
	local hud = create("Frame", { Parent = ScreenGui, Name = "HUD", Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 130, 0, 38), BackgroundColor3 = Library.Theme.Header, BackgroundTransparency = 0.1, BorderSizePixel = 0 })
	border(hud, Library.Theme.Border, 1)
	create("Frame", { Parent = hud, Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Library.Theme.Accent, BorderSizePixel = 0 })
	F.HUD.fps = label(hud, "FPS --", { Color = Library.Theme.TextHdr, Size = 12, Sz = UDim2.new(1, -10, 0, 16), Pos = UDim2.new(0, 8, 0, 3) })
	F.HUD.ping = label(hud, "PING --", { Color = Library.Theme.TextOff, Size = 11, Sz = UDim2.new(1, -10, 0, 14), Pos = UDim2.new(0, 8, 0, 20) })
	makeDraggable(hud)  -- drag the HUD anywhere
	F.HUD.gui = hud
	trackPos("hud_pos", F.HUD)
end
utilP:AddToggle({ Text = "FPS / Ping HUD", Flag = "hud", Callback = function(on)
	F.HUD.enabled = on
	if on then
		buildHUD(); F.HUD.gui.Visible = true
		local frames, acc = 0, 0
		Library:StartLoop("hud", RunService.RenderStepped, function(dt)
			frames += 1; acc += dt
			if acc >= 0.5 then
				F.HUD.fps.Text = "FPS " .. math.floor(frames / acc); frames, acc = 0, 0
				local p = "--"; pcall(function() p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
				F.HUD.ping.Text = "PING " .. p .. " ms"
			end
		end)
	else Library:StopLoop("hud"); if F.HUD.gui then F.HUD.gui.Visible = false end end
end })
-- Crosshair
F.Xhair = { enabled = false, size = 8, thick = 2, gap = 3, dot = false, color = Color3.fromRGB(198,32,36), gui = nil }
local function buildXhair()
	if F.Xhair.gui then return end
	local h = create("Frame", { Parent = ScreenGui, Name = "Xhair", AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.new(0.5,0,0.5,0), Size = UDim2.new(0,60,0,60), BackgroundTransparency = 1 })
	local function ln() return create("Frame", { Parent = h, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5,0.5) }) end
	F.Xhair.gui = h; F.Xhair.L = { up = ln(), down = ln(), left = ln(), right = ln() }
	F.Xhair.dotF = create("Frame", { Parent = h, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0.5,0) })
end
local function updXhair()
	if not F.Xhair.gui then return end
	local s, t, g, c = F.Xhair.size, F.Xhair.thick, F.Xhair.gap, F.Xhair.color
	local L = F.Xhair.L
	for _, l in pairs(L) do l.BackgroundColor3 = c end
	L.up.Size = UDim2.fromOffset(t, s);  L.up.Position = UDim2.new(0.5,0,0.5,-(g+s/2))
	L.down.Size = UDim2.fromOffset(t, s); L.down.Position = UDim2.new(0.5,0,0.5,(g+s/2))
	L.left.Size = UDim2.fromOffset(s, t); L.left.Position = UDim2.new(0.5,-(g+s/2),0.5,0)
	L.right.Size = UDim2.fromOffset(s, t); L.right.Position = UDim2.new(0.5,(g+s/2),0.5,0)
	F.Xhair.dotF.Visible = F.Xhair.dot; F.Xhair.dotF.BackgroundColor3 = c; F.Xhair.dotF.Size = UDim2.fromOffset(t+1, t+1)
end
utilP:AddToggle({ Text = "Crosshair", Flag = "xhair", Callback = function(on)
	F.Xhair.enabled = on; if on then buildXhair(); F.Xhair.gui.Visible = true; updXhair() elseif F.Xhair.gui then F.Xhair.gui.Visible = false end end })
utilP:AddSlider({ Text = "Length", Flag = "xhair_size", Min = 2, Max = 24, Default = 8, Callback = function(v) F.Xhair.size = v; updXhair() end })
utilP:AddSlider({ Text = "Thickness", Flag = "xhair_thick", Min = 1, Max = 6, Default = 2, Callback = function(v) F.Xhair.thick = v; updXhair() end })
utilP:AddSlider({ Text = "Gap", Flag = "xhair_gap", Min = 0, Max = 16, Default = 3, Callback = function(v) F.Xhair.gap = v; updXhair() end })
utilP:AddToggle({ Text = "Center Dot", Flag = "xhair_dot", Callback = function(on) F.Xhair.dot = on; updXhair() end })
utilP:AddColorPicker({ Text = "Color", Flag = "xhair_color", Default = COLORS.Red, Callback = function(c) F.Xhair.color = c; updXhair() end })
-- Server
utilP2:AddButton({ Text = "Rejoin Server", Callback = function()
	Library:Notify("Server", "Rejoining...", 2)
	pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end })
utilP2:AddButton({ Text = "Server Hop", Callback = function()
	Library:Notify("Server", "Finding new server...", 2)
	pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end })
utilP2:AddButton({ Text = "Copy Job ID", Callback = function()
	if typeof(setclipboard) == "function" then pcall(setclipboard, game.JobId); Library:Notify("Server", "Job ID copied.", 2, "good")
	else Library:Notify("Server", "No clipboard access.", 2) end
end })

--=====================================================================
--  CONFIG CATEGORY
--=====================================================================
local ConfCat = Library:AddCategory("Config", 5)
local confPage = ConfCat:AddTab("Interface")
local uiP  = confPage:AddPanel("Interface")
local cfgP = confPage:AddPanel("Config / About")

uiP:AddDropdown({ Text = "Accent", Flag = "accent", Options = { "Red", "Crimson", "Orange", "Purple", "Blue", "Green" },
	Default = "Red", Callback = function(name)
		local map = { Red = Color3.fromRGB(198,32,36), Crimson = Color3.fromRGB(160,20,50),
			Orange = Color3.fromRGB(220,110,40), Purple = Color3.fromRGB(150,90,255),
			Blue = Color3.fromRGB(60,130,240), Green = Color3.fromRGB(70,190,112) }
		Library:SetAccent(map[name] or map.Red)
	end })
local uiScale = Main:FindFirstChild("Scale")
uiP:AddSlider({ Text = "UI Scale", Flag = "ui_scale", Min = 0.7, Max = 1.4, Decimals = 2, Default = 1,
	Callback = function(v) if uiScale then uiScale.Scale = v end end })
uiP:AddKeybind({ Text = "Menu Key", Flag = "menu_key", Default = Enum.KeyCode.RightShift, Callback = function() Library:ToggleUI() end })
uiP:AddSlider({ Text = "UI Transparency", Flag = "ui_trans", Min = 0, Max = 0.8, Decimals = 2, Default = 0,
	Callback = function(v)
		Main.BackgroundTransparency = v
		Header.BackgroundTransparency = v; Rail.BackgroundTransparency = v; SubBarHolder.BackgroundTransparency = v
	end })

-- RGB engine (shared by ESP / Snaplines / FOV circle, and optionally the menu accent)
F.RainbowAccent = false
local function startRGB()
	Library:StartLoop("rgb", RunService.RenderStepped, function()
		F.RGB.color = Color3.fromHSV((tick() * F.RGB.speed * 0.1) % 1, 1, 1)
		if F.RainbowAccent then Library:ApplyAccent(F.RGB.color, false) end
	end)
end
uiP:AddToggle({ Text = "RGB Sync", Flag = "rgb_sync", Callback = function(on)
	F.RGB.enabled = on
	if on then startRGB() else Library:StopLoop("rgb"); Library:SetAccent(Library.Theme.Accent) end
end })
uiP:AddSlider({ Text = "RGB Speed", Flag = "rgb_speed", Min = 1, Max = 20, Default = 2, Callback = function(v) F.RGB.speed = v end })
uiP:AddToggle({ Text = "Rainbow Accent", Flag = "rgb_accent", Sub = true, Callback = function(on)
	F.RainbowAccent = on
	if not on then Library:SetAccent(Library.Theme.Accent) end
end })


-- Watermark (draggable, top-left)
F.WM = { gui = nil, wave = false, c1 = COLORS.Purple, c2 = COLORS.Cyan, speed = 2 }
posFlag("wm_pos", F.WM)  -- dragged position persists in configs
local function buildWatermark()
	if F.WM.gui then return end
	local wm = create("Frame", { Parent = ScreenGui, Name = "Watermark", Position = UDim2.new(0, 10, 0, 54),
		Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Library.Theme.Header, BackgroundTransparency = 0.1, BorderSizePixel = 0 })
	F.WM.stroke = border(wm, Library.Theme.Border, 1)
	F.WM.strokeGrad = create("UIGradient", { Parent = F.WM.stroke, Enabled = false })  -- wave outline
	pad(wm, 0, 0, 12, 0)  -- right margin so text never touches the edge
	local bar = create("Frame", { Parent = wm, Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Library.Theme.Accent, BorderSizePixel = 0 })
	Library:RegisterAccent(bar, "BackgroundColor3")
	F.WM.lbl = label(wm, "xRust", { Color = Library.Theme.TextHdr, Size = 12, Sz = UDim2.new(0, 0, 1, 0), Pos = UDim2.new(0, 10, 0, 0) })
	F.WM.lbl.AutomaticSize = Enum.AutomaticSize.X
	makeDraggable(wm); F.WM.gui = wm
	trackPos("wm_pos", F.WM)
end
uiP:AddToggle({ Text = "Watermark", Flag = "watermark", Callback = function(on)
	if on then
		buildWatermark(); F.WM.gui.Visible = true
		local frames, acc = 0, 0
		Library:StartLoop("wm", RunService.RenderStepped, function(dt)
			-- wave outline: the same spinning two-colour blend the visuals use
			if F.WM.wave then
				F.WM.stroke.Color = Color3.new(1, 1, 1)
				setGrad(F.WM.strokeGrad, F.WM.c1, F.WM.c2, "Wave", F.WM.speed)
			else
				F.WM.strokeGrad.Enabled = false
				F.WM.stroke.Color = Library.Theme.Border
			end
			frames += 1; acc += dt
			if acc >= 0.5 then
				local fps = math.floor(frames / acc); frames, acc = 0, 0
				local p = "--"; pcall(function() p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
				F.WM.lbl.Text = "xRust  |  " .. fps .. " fps  |  " .. p .. " ms  |  " .. #Players:GetPlayers() .. " players"
			end
		end)
	else Library:StopLoop("wm"); if F.WM.gui then F.WM.gui.Visible = false end end
end })
uiP:AddToggle({ Text = "Wave Outline", Flag = "wm_wave", Sub = true, Callback = function(on) F.WM.wave = on end })
uiP:AddColorPicker({ Text = "Outline Color 1", Flag = "wm_color1", Default = COLORS.Purple, Sub = true, Callback = function(c) F.WM.c1 = c end })
uiP:AddColorPicker({ Text = "Outline Color 2", Flag = "wm_color2", Default = COLORS.Cyan, Sub = true, Callback = function(c) F.WM.c2 = c end })
uiP:AddSlider({ Text = "Outline Speed", Flag = "wm_speed", Min = 0.5, Max = 10, Decimals = 1, Default = 2, Sub = true, Callback = function(v) F.WM.speed = v end })

-- ===== named configs (textbox + save, click a name to load, X to delete) =====
do
	local sc = cfgP:Scroll()
	local hdr = create("Frame", { Parent = sc, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 })
	label(hdr, "Configs", { Color = Library.Theme.Good, Size = 13 })
	local status = label(hdr, "", { Color = Library.Theme.Good, Size = 11, XAlign = Enum.TextXAlignment.Right })
	local function setStatus(t) status.Text = t end

	local inputRow = create("Frame", { Parent = sc, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1 })
	local nameBox = create("TextBox", { Parent = inputRow, Size = UDim2.new(1, -54, 1, 0),
		BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Font = Library.Font, TextSize = 12,
		TextColor3 = Library.Theme.TextOn, PlaceholderText = "config name", Text = "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left })
	corner(nameBox, 4); border(nameBox, Library.Theme.Border, 1); pad(nameBox, 8, 0, 8, 0)
	local saveBtn = create("TextButton", { Parent = inputRow, AutoButtonColor = false,
		Position = UDim2.new(1, -48, 0, 0), Size = UDim2.new(0, 48, 1, 0),
		BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Font = Library.Font,
		Text = "save", TextSize = 12, TextColor3 = Library.Theme.TextOn })
	corner(saveBtn, 4); border(saveBtn, Library.Theme.Border, 1)

	local listHolder = create("Frame", { Parent = sc, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
	create("UIListLayout", { Parent = listHolder, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

	local activeCfg = nil
	local refreshCfgs
	refreshCfgs = function()
		for _, c in ipairs(listHolder:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for i, name in ipairs(Config:List()) do
			local row = create("Frame", { Parent = listHolder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i })
			local loadBtn = create("TextButton", { Parent = row, AutoButtonColor = false, BackgroundTransparency = 1,
				Size = UDim2.new(1, -22, 1, 0), Font = Library.Font, TextSize = 12,
				Text = "\u{25CF} " .. name, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = (name == activeCfg) and Library.Theme.Good or Library.Theme.TextOn })
			local delBtn = create("TextButton", { Parent = row, AutoButtonColor = false, BackgroundTransparency = 1,
				Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 18, 1, 0), Font = Library.Font,
				Text = "\u{00D7}", TextSize = 14, TextColor3 = Library.Theme.TextOff })
			loadBtn.MouseButton1Click:Connect(function()
				if Config:Load(name) then activeCfg = name; setStatus("loaded \"" .. name .. "\""); refreshCfgs() end
			end)
			delBtn.MouseEnter:Connect(function() delBtn.TextColor3 = Library.Theme.Accent end)
			delBtn.MouseLeave:Connect(function() delBtn.TextColor3 = Library.Theme.TextOff end)
			delBtn.MouseButton1Click:Connect(function()
				Config:Delete(name)
				if activeCfg == name then activeCfg = nil end
				setStatus("deleted \"" .. name .. "\""); refreshCfgs()
			end)
		end
	end
	saveBtn.MouseButton1Click:Connect(function()
		local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[^%w_%- ]", "")
		if name == "" then Library:Notify("Config", "Type a config name first.", 2); return end
		Config:Save(name); activeCfg = name
		setStatus("saved \"" .. name .. "\""); refreshCfgs()
	end)
	refreshCfgs()
end
cfgP:AddLabel(FS.enabled and ("Filesystem OK -> /" .. FS.folder .. "/") or "No filesystem: configs held in memory this session.")
cfgP:AddButton({ Text = "Clear Friends", Callback = function()
	F.FriendNames = {}; Library:Notify("Friends", "Friend list cleared.", 2)
	if Library.RefreshPlayerRows then Library.RefreshPlayerRows() end
end })
cfgP:AddLabel(Library.Name .. " - client-side aim/visual hub. All features are local.")
cfgP:AddButton({ Text = "Unload", Callback = function() Library:Destroy() end })

--=====================================================================
--  PLAYERLIST CATEGORY
--=====================================================================
local PLCat = Library:AddCategory("PlayerList", 4)
local plPage = PLCat:AddTab("Players")
local plP = plPage:AddPanel("Players In Server")
local plScroll = plP:Scroll()
local plRows = {}

local plExpanded = nil

local function teleportTo(plr)
	local myc = getChar()
	local tHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if myc and tHrp then
		myc.HumanoidRootPart.CFrame = tHrp.CFrame * CFrame.new(0, 0, 4)
		Library:Notify("Teleport", "Teleported to " .. plr.Name .. ".", 2, "good")
	else Library:Notify("Teleport", "Target/you has no character.", 2) end
end

local function toggleSpectate(plr)
	if F.Spectate == plr then
		F.Spectate = nil
		local h = getHumanoid(); if h then Camera.CameraSubject = h end
		Library:Notify("Spectate", "Stopped spectating.", 2)
	else
		F.Spectate = plr
		local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if h then Camera.CameraSubject = h end
		Library:Notify("Spectate", "Spectating " .. plr.Name .. ".", 2, "good")
	end
end

local function setRowExpanded(plr, open)
	local r = plRows[plr]; if not r then return end
	r.expanded = open; r.detail.Visible = open
	r.container.Size = UDim2.new(1, 0, 0, open and 44 or 20)
	r.arrow.Text = open and "-" or "+"
end

local function nameColor(plr)
	if isFriend(plr) then return Library.Theme.Good end        -- friends show green
	if plr == LocalPlayer then return Library.Theme.Accent end
	return Library.Theme.TextOn
end

-- refresh friend colours + spectate button labels across every row
local function refreshRowStates()
	for plr, r in pairs(plRows) do
		if r.nameLbl then r.nameLbl.TextColor3 = nameColor(plr) end
		if r.spectateBtn then r.spectateBtn.Text = (F.Spectate == plr) and "Unspectate" or "Spectate" end
		if r.friendBtn then
			r.friendBtn.Text = isFriend(plr) and "Unfriend" or "Friend"
			r.friendBtn.TextColor3 = isFriend(plr) and Library.Theme.Good or Library.Theme.TextOn
		end
	end
end
Library.RefreshPlayerRows = refreshRowStates

local function buildRow(plr, order)
	local container = create("Frame", { Parent = plScroll, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, ClipsDescendants = true })
	local header = create("TextButton", { Parent = container, AutoButtonColor = false, Text = "",
		Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Library.Theme.Panel2, BackgroundTransparency = 0.4, BorderSizePixel = 0 })
	local teamColor = plr.Team and plr.Team.TeamColor and plr.Team.TeamColor.Color or Library.Theme.TextOff
	create("Frame", { Parent = header, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = teamColor })
	local arrow = label(header, "+", { Color = Library.Theme.TextOff, Size = 12, Sz = UDim2.new(0, 14, 1, 0), Pos = UDim2.new(0, 6, 0, 0) })
	local nameLbl = label(header, plr.Name .. (plr == LocalPlayer and "  (you)" or ""), {
		Color = nameColor(plr),
		Size = 12, Sz = UDim2.new(1, -90, 1, 0), Pos = UDim2.new(0, 22, 0, 0), Truncate = Enum.TextTruncate.AtEnd })
	local distLbl = label(header, "--", { Color = Library.Theme.TextOff, Size = 11, Sz = UDim2.new(0, 60, 1, 0),
		Pos = UDim2.new(1, -64, 0, 0), XAlign = Enum.TextXAlignment.Right })

	local detail = create("Frame", { Parent = container, BackgroundColor3 = Library.Theme.Bg, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 24), Visible = false })
	local friendBtn, spectateBtn
	local function actionBtn(text, xScale, cb)
		local b = create("TextButton", { Parent = detail, AutoButtonColor = false,
			Size = UDim2.new(1 / 3, -4, 0, 18), Position = UDim2.new(xScale, 2, 0, 3),
			BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Font = Library.Font,
			Text = text, TextSize = 11, TextColor3 = Library.Theme.TextOn })
		border(b, Library.Theme.Border, 1)
		b.MouseButton1Click:Connect(cb)
		return b
	end
	if plr ~= LocalPlayer then
		actionBtn("TP", 0, function() teleportTo(plr) end)
		spectateBtn = actionBtn(F.Spectate == plr and "Unspectate" or "Spectate", 1 / 3, function()
			toggleSpectate(plr); refreshRowStates()
		end)
		friendBtn = actionBtn(isFriend(plr) and "Unfriend" or "Friend", 2 / 3, function()
			if F.FriendNames[plr.Name] then F.FriendNames[plr.Name] = nil else F.FriendNames[plr.Name] = true end
			Library:Notify("Friends", (isFriend(plr) and "Added " or "Removed ") .. plr.Name, 2)
			refreshRowStates()
		end)
		friendBtn.TextColor3 = isFriend(plr) and Library.Theme.Good or Library.Theme.TextOn
	else
		label(detail, "This is you.", { Color = Library.Theme.TextOff, Size = 11, Sz = UDim2.new(1, -8, 1, 0), Pos = UDim2.new(0, 8, 0, 0) })
	end

	header.MouseButton1Click:Connect(function()
		local nowOpen = plExpanded ~= plr
		if plExpanded and plRows[plExpanded] then setRowExpanded(plExpanded, false) end
		plExpanded = nowOpen and plr or nil
		setRowExpanded(plr, nowOpen)
	end)

	plRows[plr] = { container = container, detail = detail, distLbl = distLbl, arrow = arrow,
		nameLbl = nameLbl, friendBtn = friendBtn, spectateBtn = spectateBtn, expanded = false }
end

local function refreshPlayerList()
	for _, r in pairs(plRows) do r.container:Destroy() end
	plRows = {}; plExpanded = nil
	for i, plr in ipairs(Players:GetPlayers()) do buildRow(plr, i) end
end

local function updateDistances()
	local myHrp = getChar() and getChar().HumanoidRootPart
	for plr, r in pairs(plRows) do
		if plr == LocalPlayer then r.distLbl.Text = "--"
		else
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			r.distLbl.Text = (hrp and myHrp) and (math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m") or "--"
		end
	end
end

refreshPlayerList()
Library:Connect(Players.PlayerAdded, refreshPlayerList)
Library:Connect(Players.PlayerRemoving, function(p)
	if F.Spectate == p then F.Spectate = nil; local h = getHumanoid(); if h then Camera.CameraSubject = h end end
	refreshPlayerList()
end)
Library:StartLoop("plist", RunService.Heartbeat, function()
	if F.Spectate then
		local h = F.Spectate.Character and F.Spectate.Character:FindFirstChildOfClass("Humanoid")
		if h then Camera.CameraSubject = h end
	end
	if PLCat.ActivePage and PLCat.ActivePage.Frame.Visible then
		F._plAcc = (F._plAcc or 0) + 1
		if F._plAcc >= 15 then F._plAcc = 0; updateDistances() end
	end
end)

--=====================================================================
--  WINDOW CONTROLS + BOOT
--=====================================================================
function Library:ToggleUI()
	self.Toggled = not self.Toggled
	local scale = Main:FindFirstChild("Scale")
	if self.Toggled then
		Main.Visible = true
		TweenService:Create(Main, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
	else
		local t = TweenService:Create(Main, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
		t:Play(); t.Completed:Connect(function() if not Library.Toggled then Main.Visible = false end end)
	end
end
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	TweenService:Create(Main, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
		{ Size = minimized and UDim2.new(0, 720, 0, 30) or UDim2.new(0, 720, 0, 500) }):Play()
	MinBtn.Text = minimized and "□" or "_"
end)
CloseBtn.MouseButton1Click:Connect(function()
	Library:ToggleUI(); Library:Notify(Library.Name, "Hidden. Press RightShift to reopen.", 3)
end)

function Library:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for name in pairs(self.Loops) do self:StopLoop(name) end
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	clearESP(); stopFly(); pcall(jcClear); pcall(trClear)
	pcall(unbindCam)
	pcall(function() local h = getHumanoid(); if h then aaStates(h, true) end end)  -- restore fling states
	if F.AA and F.AA.crouchHeld then pcall(aaCrouch, false); F.AA.crouchHeld = false end
	pcall(function()
		for k, v in pairs(F.FB.saved or {}) do pcall(function() Lighting[k] = v end) end
		for k, v in pairs((F.Ambience and F.Ambience.saved) or {}) do pcall(function() Lighting[k] = v end) end
		if F.Ambience and F.Ambience.cc then F.Ambience.cc:Destroy() end
		if F.SelfChams and F.SelfChams.hl then F.SelfChams.hl:Destroy() end
		if F.SelfGlow and F.SelfGlow.hl then F.SelfGlow.hl:Destroy() end
		local h = getHumanoid(); if h then h.AutoRotate = true; h.CameraOffset = Vector3.zero end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.Classic; LocalPlayer.CameraMinZoomDistance = 0.5 end)
		if Camera then Camera.FieldOfView = 70; Camera.CameraType = Enum.CameraType.Custom end
	end)
	ScreenGui:Destroy()
end
Library:Connect(Players.PlayerRemoving, function(p)
	local o = F.ESP.objs[p]
	if o then
		pcall(function()
			o.box:Destroy(); o.headDot:Destroy(); o.tracer:Destroy(); o.billboard:Destroy(); o.hbBg:Destroy()
			for _, b in ipairs(o.bones) do b:Destroy() end
			if o.hl then o.hl:Destroy() end
			if o.glow then o.glow:Destroy() end
		end)
		F.ESP.objs[p] = nil
	end
end)

do
	Main.Visible = true
	local scale = Main:FindFirstChild("Scale"); scale.Scale = 0.96
	Main.BackgroundTransparency = 1
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	TweenService:Create(Main, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	Library:Notify(Library.Name, "Loaded. RightShift toggles the menu.", 5, "good")
end

return Library
