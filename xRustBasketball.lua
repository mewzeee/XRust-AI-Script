--[[
	=====================================================================
	  xRust — Basketball Legends
	=====================================================================
	  • Same UI library / look as the xRust Universal hub.
	  • Categories: Shooting (Auto Green) · Guarding · PlayerList · Config
	  • Auto Green drives the game's own shot meter at
	    PlayerGui.Visual.Shooting.Bar — hold the shoot key and the bar is
	    tweened to full once it passes the release point.
	  • Everything loads OFF.
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
	-- separate from the Universal hub's "xRust" folder: the flags differ, so a
	-- config saved in one script would be meaningless in the other
	folder = "xRust_Basketball",
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
	Name = "xRust | Basketball Legends",
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
--  BALL  (shared: everything below needs to find the basketball)
--=====================================================================
-- The ball is parented to the character while held, and loose in workspace
-- otherwise. Cache the last one we saw so ESP/trail survive the hand-off.
local lastBall = nil
local function findBall()
	local c = LocalPlayer.Character
	local held = c and c:FindFirstChild("Basketball")
	if held then
		lastBall = (held:IsA("BasePart") and held) or held:FindFirstChildWhichIsA("BasePart")
		return lastBall
	end
	-- loose ball: nearest thing named Basketball in workspace
	local best, bestD = nil, math.huge
	local myc = getChar()
	local myPos = myc and myc.HumanoidRootPart.Position or Vector3.zero
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Basketball" then
			local dist = (d.Position - myPos).Magnitude
			if dist < bestD then best, bestD = d, dist end
		end
	end
	if best then lastBall = best end
	return best
end
local function ballHeld()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("Basketball") ~= nil
end

--=====================================================================
--  SHOOTING CATEGORY
--=====================================================================
local ShootCat = Library:AddCategory("Shooting", 1)

--== Auto Green ==--
local greenPage = ShootCat:AddTab("Auto Green")
local greenP  = greenPage:AddPanel("Auto Green")
local greenP2 = greenPage:AddPanel("Settings")

-- The game greens a shot when its meter (PlayerGui.Visual.Shooting.Bar) is
-- released at full. Two ways to get there:
--   Snap  - wait until the bar passes `release`, then jump it to full. Fast,
--           but the bar visibly teleports.
--   Ramp  - from the moment the bar starts moving, drive it up ourselves at a
--           steady rate so it *climbs* to full. Looks like a real shot.
F.Green = { enabled = false, mode = "Ramp", release = 0.9, tween = 0.045, rampTime = 0.35,
	key = Enum.KeyCode.E, requireBall = true, jitter = 0, sound = false,
	rage = false, rageDepth = 3, rageHold = 0.6 }

local function shootingBar()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local vis = pg and pg:FindFirstChild("Visual")
	local shooting = vis and vis:FindFirstChild("Shooting")
	return shooting and shooting:FindFirstChild("Bar")
end

greenP:AddToggle({ Text = "Enabled", Flag = "green_enabled", Callback = function(on)
	F.Green.enabled = on
	if on and not shootingBar() then
		Library:Notify("Auto Green", "Shot meter not found — are you in a match?", 4)
	end
end })
greenP:AddToggle({ Text = "Require Basketball", Flag = "green_ball", Callback = function(on) F.Green.requireBall = on end })
greenP:AddToggle({ Text = "Rage Green", Flag = "green_rage", Callback = function(on)
	F.Green.rage = on
	if on then Library:Notify("Rage Green", "Drops you through the floor on release so nobody can contest.", 5, "good") end
end })
greenP:AddToggle({ Text = "Green Sound", Flag = "green_sound", Callback = function(on) F.Green.sound = on end })

greenP2:AddDropdown({ Text = "Mode", Flag = "green_mode", Options = { "Ramp", "Snap" }, Default = "Ramp",
	Callback = function(v) F.Green.mode = v end })
greenP2:AddSlider({ Text = "Ramp Time", Flag = "green_ramp", Min = 0.1, Max = 1.5, Decimals = 2, Default = 0.35,
	Suffix = "s", Callback = function(v) F.Green.rampTime = v end })
greenP2:AddSlider({ Text = "Release Point", Flag = "green_release", Min = 0.5, Max = 0.99, Decimals = 2, Default = 0.9,
	Callback = function(v) F.Green.release = v end })
greenP2:AddSlider({ Text = "Snap Time", Flag = "green_tween", Min = 0.01, Max = 0.2, Decimals = 3, Default = 0.045,
	Suffix = "s", Callback = function(v) F.Green.tween = v end })
greenP2:AddSlider({ Text = "Jitter", Flag = "green_jitter", Min = 0, Max = 0.05, Decimals = 3, Default = 0,
	Callback = function(v) F.Green.jitter = v end })
greenP2:AddSlider({ Text = "Rage Depth", Flag = "green_depth", Min = 1, Max = 8, Decimals = 1, Default = 3,
	Suffix = "m", Callback = function(v) F.Green.rageDepth = v end })
greenP2:AddSlider({ Text = "Rage Hold", Flag = "green_hold", Min = 0.2, Max = 2, Decimals = 2, Default = 0.6,
	Suffix = "s", Callback = function(v) F.Green.rageHold = v end })
greenP2:AddDropdown({ Text = "Shoot Key", Flag = "green_key", Options = { "E", "Q", "F", "R", "MouseButton1" },
	Default = "E", Callback = function(v)
		F.Green.key = (v == "MouseButton1") and Enum.UserInputType.MouseButton1 or Enum.KeyCode[v]
	end })

local function greenKeyDown()
	local k = F.Green.key
	if typeof(k) == "EnumItem" and k.EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(k)
	end
	return UserInputService:IsKeyDown(k)
end

local function playGreenSound()
	if not F.Green.sound then return end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://6042053626"
		s.Volume = 0.6
		s.Parent = Workspace
		s:Play()
		task.delay(2, function() s:Destroy() end)
	end)
end

-- Rage Green: sink the character straight down for the duration of the shot.
-- Only a few studs - deep enough that no defender's hitbox reaches you, shallow
-- enough that the game doesn't count it as a void fall and reset you. The
-- HumanoidRootPart is put back exactly where it started.
local function rageDrop()
	local myc = getChar()
	if not myc then return end
	local hrp = myc.HumanoidRootPart
	local origin = hrp.CFrame
	local hum = myc:FindFirstChildOfClass("Humanoid")
	local parts = {}
	for _, p in ipairs(myc:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			table.insert(parts, p); p.CanCollide = false
		end
	end
	if hum then hum.PlatformStand = true end
	hrp.CFrame = origin - Vector3.new(0, F.Green.rageDepth, 0)
	hrp.AssemblyLinearVelocity = Vector3.zero

	task.delay(F.Green.rageHold, function()
		pcall(function()
			if hrp and hrp.Parent then
				hrp.CFrame = origin
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			for _, p in ipairs(parts) do if p and p.Parent then p.CanCollide = true end end
			if hum and hum.Parent then hum.PlatformStand = false end
		end)
	end)
end

local greenBusy = false
Library:Connect(UserInputService.InputBegan, function(input, gpe)
	if gpe or not F.Green.enabled or Library.Destroyed or greenBusy then return end
	local k = F.Green.key
	local match = (typeof(k) == "EnumItem" and k.EnumType == Enum.UserInputType)
		and (input.UserInputType == k) or (input.KeyCode == k)
	if not match then return end
	if F.Green.requireBall and not ballHeld() then return end

	greenBusy = true
	task.spawn(function()
		local dropped = false
		local rampStart = nil
		while F.Green.enabled and greenKeyDown() and not Library.Destroyed do
			local bar = shootingBar()
			if bar then
				local y = bar.Size.Y.Scale
				if F.Green.rage and not dropped and y > 0.15 then
					dropped = true
					pcall(rageDrop)
				end
				if F.Green.mode == "Ramp" then
					-- climb the bar ourselves at a constant rate once it starts
					if y > 0.02 then
						rampStart = rampStart or os.clock()
						local a = math.clamp((os.clock() - rampStart) / math.max(0.05, F.Green.rampTime), 0, 1)
						local target = math.clamp(y + (1 - y) * a, y, 1)
						if F.Green.jitter > 0 then
							target = math.clamp(target - math.random() * F.Green.jitter, 0, 1)
						end
						bar.Size = UDim2.new(1, 0, target, 0)
						if a >= 1 then
							bar.Size = UDim2.new(1, 0, 1, 0)
							playGreenSound()
						end
					end
				else
					if y > F.Green.release then
						bar:TweenSize(UDim2.new(1, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, F.Green.tween, true)
						task.wait()
						if bar and bar.Parent then bar.Size = UDim2.new(1, 0, 1, 0) end
						playGreenSound()
					end
				end
			end
			task.wait()
		end
		greenBusy = false
	end)
end)

--== Ball Visuals ==--
local bvPage = ShootCat:AddTab("Ball Visuals")
local bvP  = bvPage:AddPanel("Ball ESP")
local bvP2 = bvPage:AddPanel("Trail / Trajectory")

F.Ball = { esp = false, espColor = COLORS.Orange or COLORS.Red, chams = false, tracer = false, dist = false,
	trail = false, trailColor = COLORS.Orange or COLORS.Red, trailLen = 1.2,
	traj = false, trajColor = COLORS.Cyan, trajSteps = 40, trajTime = 1.6,
	hl = nil, bb = nil, distLbl = nil, trailObj = nil, trajParts = {} }

bvP:AddToggle({ Text = "Ball ESP", Flag = "ball_esp", Callback = function(on) F.Ball.esp = on end })
bvP:AddToggle({ Text = "Ball Chams", Flag = "ball_chams", Callback = function(on) F.Ball.chams = on end })
bvP:AddToggle({ Text = "Ball Tracer", Flag = "ball_tracer", Callback = function(on) F.Ball.tracer = on end })
bvP:AddToggle({ Text = "Ball Distance", Flag = "ball_dist", Callback = function(on) F.Ball.dist = on end })
bvP:AddColorPicker({ Text = "ESP Color", Flag = "ball_espcol", Default = COLORS.Orange or COLORS.Red,
	Callback = function(c) F.Ball.espColor = c end })

bvP2:AddToggle({ Text = "Shot Trail", Flag = "ball_trail", Callback = function(on) F.Ball.trail = on end })
bvP2:AddSlider({ Text = "Trail Length", Flag = "ball_traillen", Min = 0.2, Max = 5, Decimals = 1, Default = 1.2,
	Suffix = "s", Callback = function(v) F.Ball.trailLen = v end })
bvP2:AddColorPicker({ Text = "Trail Color", Flag = "ball_trailcol", Default = COLORS.Orange or COLORS.Red,
	Callback = function(c) F.Ball.trailColor = c end })
bvP2:AddToggle({ Text = "Trajectory Preview", Flag = "ball_traj", Callback = function(on)
	F.Ball.traj = on
	if not on then
		for _, p in ipairs(F.Ball.trajParts) do pcall(function() p:Destroy() end) end
		F.Ball.trajParts = {}
	end
end })
bvP2:AddSlider({ Text = "Trajectory Steps", Flag = "ball_trajsteps", Min = 10, Max = 80, Default = 40,
	Callback = function(v) F.Ball.trajSteps = v end })
bvP2:AddColorPicker({ Text = "Trajectory Color", Flag = "ball_trajcol", Default = COLORS.Cyan,
	Callback = function(c) F.Ball.trajColor = c end })

local ballTracer = Drawing and Drawing.new and Drawing.new("Line") or nil
if ballTracer then ballTracer.Thickness = 1; ballTracer.Visible = false end

Library:StartLoop("ballvis", RunService.RenderStepped, function()
	if Library.Destroyed then return end
	local ball = findBall()

	-- highlight / chams
	if (F.Ball.esp or F.Ball.chams) and ball then
		if not F.Ball.hl or F.Ball.hl.Parent ~= ball then
			pcall(function() if F.Ball.hl then F.Ball.hl:Destroy() end end)
			F.Ball.hl = Instance.new("Highlight")
			F.Ball.hl.Adornee = ball
			F.Ball.hl.Parent = ball
		end
		F.Ball.hl.FillColor = F.Ball.espColor
		F.Ball.hl.OutlineColor = F.Ball.espColor
		F.Ball.hl.FillTransparency = F.Ball.chams and 0.35 or 1
		F.Ball.hl.OutlineTransparency = F.Ball.esp and 0 or 1
		F.Ball.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		F.Ball.hl.Enabled = true
	elseif F.Ball.hl then
		F.Ball.hl.Enabled = false
	end

	-- distance label
	if F.Ball.dist and ball then
		if not F.Ball.bb or F.Ball.bb.Parent ~= ball then
			pcall(function() if F.Ball.bb then F.Ball.bb:Destroy() end end)
			F.Ball.bb = Instance.new("BillboardGui")
			F.Ball.bb.Size = UDim2.new(0, 90, 0, 16)
			F.Ball.bb.StudsOffset = Vector3.new(0, 1.4, 0)
			F.Ball.bb.AlwaysOnTop = true
			F.Ball.bb.Adornee = ball
			F.Ball.bb.Parent = ball
			F.Ball.distLbl = create("TextLabel", { Parent = F.Ball.bb, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0), Font = FONT, TextSize = 12, TextStrokeTransparency = 0.4 })
		end
		local myc = getChar()
		local d = myc and math.floor((ball.Position - myc.HumanoidRootPart.Position).Magnitude) or 0
		F.Ball.distLbl.Text = d .. "m"
		F.Ball.distLbl.TextColor3 = F.Ball.espColor
		F.Ball.bb.Enabled = true
	elseif F.Ball.bb then
		F.Ball.bb.Enabled = false
	end

	-- tracer from the bottom of the screen to the ball
	if ballTracer then
		if F.Ball.tracer and ball then
			local sp, on = Camera:WorldToViewportPoint(ball.Position)
			if on then
				local vp = Camera.ViewportSize
				ballTracer.From = Vector2.new(vp.X / 2, vp.Y)
				ballTracer.To = Vector2.new(sp.X, sp.Y)
				ballTracer.Color = F.Ball.espColor
				ballTracer.Visible = true
			else
				ballTracer.Visible = false
			end
		else
			ballTracer.Visible = false
		end
	end

	-- shot trail (the game's own Trail instance on the ball)
	if F.Ball.trail and ball then
		if not F.Ball.trailObj or F.Ball.trailObj.Parent ~= ball then
			pcall(function() if F.Ball.trailObj then F.Ball.trailObj:Destroy() end end)
			local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.4, 0); a0.Parent = ball
			local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.4, 0); a1.Parent = ball
			local t = Instance.new("Trail")
			t.Attachment0, t.Attachment1 = a0, a1
			t.FaceCamera = true
			t.Parent = ball
			F.Ball.trailObj = t
		end
		F.Ball.trailObj.Lifetime = F.Ball.trailLen
		F.Ball.trailObj.Color = ColorSequence.new(F.Ball.trailColor)
		F.Ball.trailObj.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		F.Ball.trailObj.Enabled = true
	elseif F.Ball.trailObj then
		F.Ball.trailObj.Enabled = false
	end

	-- trajectory preview: integrate the ball's current velocity under gravity and
	-- draw the arc. Only meaningful once it's actually moving (i.e. shot).
	if F.Ball.traj and ball then
		local vel = ball.AssemblyLinearVelocity
		local steps = math.floor(F.Ball.trajSteps)
		if vel.Magnitude > 4 then
			local g = Workspace.Gravity
			local dt = F.Ball.trajTime / steps
			local pos = ball.Position
			for i = 1, steps do
				local p = F.Ball.trajParts[i]
				if not p or not p.Parent then
					p = Instance.new("Part")
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					p.Material = Enum.Material.Neon
					p.Shape = Enum.PartType.Ball
					p.Size = Vector3.new(0.22, 0.22, 0.22)
					p.Parent = Workspace
					F.Ball.trajParts[i] = p
				end
				local t = dt * i
				p.Position = pos + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
				p.Color = F.Ball.trajColor
				p.Transparency = 0.15 + (i / steps) * 0.55
			end
			for i = steps + 1, #F.Ball.trajParts do
				if F.Ball.trajParts[i] then F.Ball.trajParts[i]:Destroy(); F.Ball.trajParts[i] = nil end
			end
		else
			for _, p in ipairs(F.Ball.trajParts) do p.Transparency = 1 end
		end
	elseif #F.Ball.trajParts > 0 and not F.Ball.traj then
		for _, p in ipairs(F.Ball.trajParts) do pcall(function() p:Destroy() end) end
		F.Ball.trajParts = {}
	end
end)

--=====================================================================
--  GUARDING CATEGORY
--=====================================================================
local GuardCat = Library:AddCategory("Guarding", 2)
local guardPage = GuardCat:AddTab("Auto Guard")
local guardP  = guardPage:AddPanel("Auto Guard")
local guardP2 = guardPage:AddPanel("Settings")

-- Holds you in front of the nearest opponent. Prediction leads their velocity so
-- you arrive where they're going rather than where they were.
F.Guard = { enabled = false, dist = 5, key = nil, ballOnly = false, predict = 0,
	faceTarget = true, smooth = 0, maxRange = 60, target = nil, espTarget = false, hl = nil }

local function playerHasBall(p)
	return p.Character and p.Character:FindFirstChild("Basketball") ~= nil
end

local function guardTarget()
	local myc = getChar()
	if not myc then return nil end
	local myPos = myc.HumanoidRootPart.Position
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			if not F.Guard.ballOnly or playerHasBall(p) then
				local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
				if d < bestD and d <= F.Guard.maxRange then best, bestD = p, d end
			end
		end
	end
	return best
end

guardP:AddToggle({ Text = "Enabled", Flag = "guard_enabled", Bind = true, BindNoToggle = true, Callback = function(on)
	F.Guard.enabled = on
	if not on then
		F.Guard.target = nil
		if F.Guard.hl then F.Guard.hl.Enabled = false end
	end
end })
guardP:AddToggle({ Text = "Ball Carrier Only", Flag = "guard_ballonly", Callback = function(on) F.Guard.ballOnly = on end })
guardP:AddToggle({ Text = "Face Target", Flag = "guard_face", Callback = function(on) F.Guard.faceTarget = on end })
guardP:AddToggle({ Text = "Highlight Target", Flag = "guard_hl", Callback = function(on)
	F.Guard.espTarget = on
	if not on and F.Guard.hl then F.Guard.hl.Enabled = false end
end })

guardP2:AddSlider({ Text = "Distance", Flag = "guard_dist", Min = 2, Max = 12, Decimals = 1, Default = 5,
	Callback = function(v) F.Guard.dist = v end })
guardP2:AddSlider({ Text = "Prediction", Flag = "guard_predict", Min = 0, Max = 0.6, Decimals = 2, Default = 0,
	Suffix = "x", Callback = function(v) F.Guard.predict = v end })
guardP2:AddSlider({ Text = "Smoothing", Flag = "guard_smooth", Min = 0, Max = 20, Default = 0,
	Suffix = "x", Callback = function(v) F.Guard.smooth = v end })
guardP2:AddSlider({ Text = "Max Range", Flag = "guard_range", Min = 10, Max = 150, Default = 60,
	Suffix = "m", Callback = function(v) F.Guard.maxRange = v end })

Library:StartLoop("guard", RunService.RenderStepped, function(dt)
	if not F.Guard.enabled or Library.Destroyed then return end
	local opt = Library.Options["guard_enabled"]
	local key = opt and opt.GetKey and opt:GetKey()
	if key and not isDown(key) then return end   -- bound: hold it. unbound: always on.

	local target = guardTarget()
	F.Guard.target = target
	local myc = getChar()
	if not (target and myc) then
		if F.Guard.hl then F.Guard.hl.Enabled = false end
		return
	end
	local tHrp = target.Character.HumanoidRootPart

	if F.Guard.espTarget then
		if not F.Guard.hl or F.Guard.hl.Adornee ~= target.Character then
			pcall(function() if F.Guard.hl then F.Guard.hl:Destroy() end end)
			F.Guard.hl = Instance.new("Highlight")
			F.Guard.hl.FillTransparency = 0.6
			F.Guard.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			F.Guard.hl.Adornee = target.Character
			F.Guard.hl.Parent = target.Character
		end
		F.Guard.hl.FillColor = Library.Theme.Accent
		F.Guard.hl.OutlineColor = Library.Theme.Accent
		F.Guard.hl.Enabled = true
	elseif F.Guard.hl then
		F.Guard.hl.Enabled = false
	end

	-- lead the target so we land where they're heading
	local lead = tHrp.AssemblyLinearVelocity * F.Guard.predict
	local goalPos = tHrp.Position + lead + (tHrp.CFrame.LookVector * F.Guard.dist)
	local goal = F.Guard.faceTarget and CFrame.new(goalPos, tHrp.Position + lead) or CFrame.new(goalPos)

	local hrp = myc.HumanoidRootPart
	if F.Guard.smooth <= 0 then
		hrp.CFrame = goal
	else
		hrp.CFrame = hrp.CFrame:Lerp(goal, math.clamp(dt * (21 - F.Guard.smooth), 0, 1))
	end
end)

--=====================================================================
--  CONFIG CATEGORY
--=====================================================================
local ConfCat = Library:AddCategory("Config", 4)
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
cfgP:AddButton({ Text = "Unload", Callback = function() Library:Destroy() end })

--=====================================================================
--  PLAYERLIST CATEGORY
--=====================================================================
local PLCat = Library:AddCategory("PlayerList", 3)
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
	F.Green.enabled = false
	F.Guard.enabled = false
	F.Ball.esp, F.Ball.chams, F.Ball.tracer, F.Ball.dist = false, false, false, false
	F.Ball.trail, F.Ball.traj = false, false
	pcall(function()
		-- the ball visuals parent real instances into the ball / workspace, and
		-- the trajectory spawns parts every frame — all of it has to go or it
		-- outlives the menu
		if F.Ball.hl then F.Ball.hl:Destroy() end
		if F.Ball.bb then F.Ball.bb:Destroy() end
		if F.Ball.trailObj then F.Ball.trailObj:Destroy() end
		for _, p in ipairs(F.Ball.trajParts) do p:Destroy() end
		F.Ball.trajParts = {}
		if F.Guard.hl then F.Guard.hl:Destroy() end
		if ballTracer then ballTracer:Remove() end
	end)
	pcall(function()
		if F.Spectate then
			local h = getHumanoid()
			if h then Camera.CameraSubject = h end
			F.Spectate = nil
		end
		local h = getHumanoid()
		if h then h.AutoRotate = true; h.CameraOffset = Vector3.zero; h.PlatformStand = false end
		-- Rage Green disables collision on the character while it drops; if the
		-- menu is unloaded mid-shot, put it back
		local c = LocalPlayer.Character
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
			end
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if Camera then Camera.CameraType = Enum.CameraType.Custom end
	end)
	ScreenGui:Destroy()
end

do
	Main.Visible = true
	local scale = Main:FindFirstChild("Scale"); scale.Scale = 0.96
	Main.BackgroundTransparency = 1
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	TweenService:Create(Main, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	Library:Notify(Library.Name, "Loaded. RightShift toggles the menu.", 5, "good")
end

return Library
