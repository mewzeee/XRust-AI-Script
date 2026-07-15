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

				-- Long lists (the skin catalogue is 452) get a search box and a
				-- capped, scrolling body. The old version sized the list to
				-- #values * 18 with every option built inline — 452 entries meant
				-- an 8100px list you could never reach the bottom of.
				local ROW_H, MAX_H = 18, 148
				local searchable = (opts.Search ~= false) and (#values > 10)

				local listFrame = create("Frame", { Parent = scroll, BackgroundColor3 = Library.Theme.Bg,
					BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true,
					Visible = false, LayoutOrder = order })
				indent(listFrame, opts.Sub)
				border(listFrame, Library.Theme.Border, 1)

				local searchBox
				if searchable then
					searchBox = create("TextBox", { Parent = listFrame, Size = UDim2.new(1, 0, 0, ROW_H),
						BackgroundColor3 = Library.Theme.Panel2, BorderSizePixel = 0, Font = Library.Font,
						TextSize = 11.5, TextColor3 = Library.Theme.TextOn, ClearTextOnFocus = false,
						PlaceholderText = "search...", PlaceholderColor3 = Library.Theme.TextOff,
						Text = "", TextXAlignment = Enum.TextXAlignment.Center })
				end

				local listScroll = create("ScrollingFrame", { Parent = listFrame, BackgroundTransparency = 1,
					BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Library.Theme.TextOff,
					CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
					Position = UDim2.new(0, 0, 0, searchable and ROW_H or 0),
					Size = UDim2.new(1, 0, 1, searchable and -ROW_H or 0) })
				create("UIListLayout", { Parent = listScroll, SortOrder = Enum.SortOrder.LayoutOrder })

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

				local shownCount = #values
				local function resize()
					if not open then return end
					local body = math.min(MAX_H, math.max(ROW_H, shownCount * ROW_H))
					listFrame.Size = UDim2.new(1, 0, 0, body + (searchable and ROW_H or 0))
				end
				local function applyFilter(q)
					q = tostring(q or ""):lower()
					local shown = 0
					for v, b in pairs(btns) do
						-- UIListLayout skips hidden children, so hiding is enough
						local hit = (q == "") or (tostring(v):lower():find(q, 1, true) ~= nil)
						b.Visible = hit
						if hit then shown = shown + 1 end
					end
					shownCount = shown
					resize()
				end

				for i, v in ipairs(values) do
					local b = create("TextButton", { Parent = listScroll, AutoButtonColor = false,
						BackgroundColor3 = Library.Theme.Bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, ROW_H),
						Font = Library.Font, Text = "  " .. tostring(v), TextSize = 12, LayoutOrder = i,
						TextColor3 = Library.Theme.TextOff, TextXAlignment = Enum.TextXAlignment.Left })
					btns[v] = b
					b.MouseEnter:Connect(function() b.BackgroundColor3 = Library.Theme.Panel2 end)
					b.MouseLeave:Connect(function() b.BackgroundColor3 = Library.Theme.Bg end)
					b.MouseButton1Click:Connect(function()
						api:Set(v); open = false
						listFrame.Visible = false; listFrame.Size = UDim2.new(1, 0, 0, 0); arw.Text = "▾"
					end)
				end
				if searchBox then
					searchBox:GetPropertyChangedSignal("Text"):Connect(function()
						applyFilter(searchBox.Text)
					end)
				end

				head.MouseButton1Click:Connect(function()
					open = not open
					if open then
						listFrame.Visible = true
						if searchBox then searchBox.Text = "" end
						applyFilter("")
						resize()
						arw.Text = "▴"
					else
						listFrame.Size = UDim2.new(1, 0, 0, 0)
						arw.Text = "▾"
						task.defer(function() if not open then listFrame.Visible = false end end)
					end
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
			-- TEXTBOX  (label on the left, editable field on the right)
			----------------------------------------------------------
			function comp:AddTextbox(opts)
				local row = create("Frame", { Parent = scroll, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20), LayoutOrder = ord() })
				create("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 1, 0),
					Font = Library.Font, Text = opts.Text or "Text", TextSize = 12,
					TextColor3 = Library.Theme.TextOn, TextXAlignment = Enum.TextXAlignment.Left })
				local box = create("TextBox", { Parent = row, Size = UDim2.new(0.58, 0, 1, 0),
					Position = UDim2.new(0.42, 0, 0, 0), BackgroundColor3 = Library.Theme.Panel2,
					BorderSizePixel = 0, Font = Library.Font, TextSize = 11.5,
					TextColor3 = Library.Theme.TextOn, ClearTextOnFocus = false,
					PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = Library.Theme.TextOff,
					Text = opts.Default or "", TextTruncate = Enum.TextTruncate.AtEnd })
				border(box, Library.Theme.Border, 1); corner(box, 4)

				local api = {}
				function api:Set(v)
					box.Text = tostring(v or "")
					if opts.Flag then Library.Flags[opts.Flag] = box.Text end
					if opts.Callback then pcall(opts.Callback, box.Text) end
				end
				function api:Get() return box.Text end
				-- commit on focus loss so a callback doesn't fire per keystroke
				box.FocusLost:Connect(function() api:Set(box.Text) end)
				if opts.Flag then
					Library.Flags[opts.Flag] = box.Text
					Library.Options[opts.Flag] = api
				end
				api.Instance = box
				return api
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
-- otherwise.
--
-- PERF: Workspace:GetDescendants() allocates an array of EVERY instance in the
-- game. Running that per-frame is what made the menu crawl whenever you weren't
-- holding the ball (holding it hit the early return, which is why it went smooth
-- the moment you picked one up). So: use the cached ball while it's still
-- parented, try a cheap shallow pass first, and only fall back to the full walk
-- a couple of times a second.
local lastBall = nil
local nextDeepScan = 0

-- Real layout, straight from the dump:
--   Workspace.Game.Courts.<CourtName>.Rack.Basketball
-- So courts are actual models we can look up rather than infer, and a ball
-- sitting in a court's Rack is a spare on the rack, not a live loose ball.
local function courtsFolder()
	local g = Workspace:FindFirstChild("Game")
	return g and g:FindFirstChild("Courts")
end

-- Which court we're on. The game just tells us: LocalPlayer has a "Court"
-- attribute (an index) while in a match. Fall back to nearest-pivot when it's
-- absent (lobby / practice), since that's the only signal then.
local function currentCourt(from)
	local courts = courtsFolder()
	if not courts then return nil end

	-- Every court is literally named "Court" (only PracticeCourt differs), so the
	-- attribute is an INDEX into GetChildren(), not part of a name.
	local idx = tonumber(LocalPlayer:GetAttribute("Court"))
	if idx then
		local kids = courts:GetChildren()
		if kids[idx] then return kids[idx] end
	end

	local best, bestD = nil, math.huge
	for _, c in ipairs(courts:GetChildren()) do
		local ok, pivot = pcall(function() return c:GetPivot().Position end)
		if ok then
			local d = (pivot - from).Magnitude
			if d < bestD then best, bestD = c, d end
		end
	end
	return best, bestD
end

local function isBall(d)
	return d:IsA("BasePart") and (d.Name == "Basketball" or d.Name == "Ball")
end

-- a ball parented under a court's Rack is racked, not in play
local function isRacked(b)
	local p = b and b.Parent
	return p ~= nil and p.Name == "Rack"
end

-- The ball you hold is a TOOL (Workspace.<you>.Basketball), whose visible body
-- is a BasePart inside it. A loose/racked ball is a plain Part. So: keep both —
-- lastBallTool for anything that needs the Tool's contents (the SpecialMesh
-- lives under there), lastBall for the part to weld to.
local lastBallTool = nil

local function bodyOf(inst)
	if inst:IsA("BasePart") then return inst end
	-- prefer a part that actually carries the mesh
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") and d:FindFirstChildWhichIsA("SpecialMesh") then return d end
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function findBall()
	local c = LocalPlayer.Character
	local held = c and c:FindFirstChild("Basketball")
	if held then
		lastBallTool = held
		lastBall = bodyOf(held)
		return lastBall
	end

	-- cached ball still in the world? nothing to search for.
	if lastBall and lastBall.Parent then return lastBall end

	-- cheap pass: a live loose ball is a direct child of workspace
	for _, d in ipairs(Workspace:GetChildren()) do
		if isBall(d) then lastBall = d; return d end
	end
	-- next cheapest: our own court's rack (Workspace.Game.Courts.<name>.Rack)
	local myc = getChar()
	if myc then
		local court = currentCourt(myc.HumanoidRootPart.Position)
		local rack = court and court:FindFirstChild("Rack")
		if rack then
			for _, d in ipairs(rack:GetChildren()) do
				if isBall(d) then lastBall = d; return d end
			end
		end
	end

	-- expensive pass, throttled. A ball doesn't appear and vanish faster than this.
	if os.clock() < nextDeepScan then return nil end
	nextDeepScan = os.clock() + 0.5

	local best, bestD = nil, math.huge
	local myc = getChar()
	local myPos = myc and myc.HumanoidRootPart.Position or Vector3.zero
	for _, d in ipairs(Workspace:GetDescendants()) do
		if isBall(d) then
			local dist = (d.Position - myPos).Magnitude
			if dist < bestD then best, bestD = d, dist end
		end
	end
	if best then lastBall = best end
	return best
end
-- HOOPS. The old scan only looked at Workspace:GetChildren() — direct children
-- only — so any hoop nested under a court/map folder was invisible to it, which
-- is why Hoop ESP did nothing. Walk descendants instead, but cache the result:
-- hoops don't move or respawn, so this runs once and is reused by both the ESP
-- and the rage teleport.
local hoopCache, nextHoopFind = {}, 0
local HOOP_WORDS = { "hoop", "rim", "net", "basket", "backboard" }
local function looksLikeHoop(name)
	local n = name:lower()
	for _, w in ipairs(HOOP_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end
-- PERF: this walks every instance in the game, so it must never run inside a
-- shot — that was the rage lag spike. It's warmed at load and refreshed on a
-- long timer; hoops don't move.
local function findHoops()
	if os.clock() < nextHoopFind and #hoopCache > 0 then return hoopCache end
	nextHoopFind = os.clock() + 30
	local found = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("BasePart")) and looksLikeHoop(d.Name) then
			-- skip nested matches (a "Rim" inside a "Hoop" model) so one hoop
			-- doesn't get highlighted three times
			local parentIsHoop = d.Parent and d.Parent ~= Workspace and looksLikeHoop(d.Parent.Name)
			if not parentIsHoop then table.insert(found, d) end
		end
	end
	if #found > 0 then hoopCache = found end
	return hoopCache
end
local function hoopPos(h)
	if h:IsA("BasePart") then return h.Position end
	local ok, cf = pcall(function() return h:GetPivot().Position end)
	return ok and cf or nil
end
local function nearestHoop(from)
	local best, bestD = nil, math.huge
	for _, h in ipairs(findHoops()) do
		local p = hoopPos(h)
		if p then
			local d = (p - from).Magnitude
			if d < bestD then best, bestD = p, d end
		end
	end
	return best, bestD
end

-- warm the hoop cache off the critical path so the first rage shot doesn't hitch
task.spawn(function() pcall(findHoops) end)

local function ballHeld()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("Basketball") ~= nil
end

--=====================================================================
--  SHOOTING CATEGORY
--=====================================================================
-- Every category is declared here, up front, because a tab can only be added to
-- a category that already exists — Ball Visuals lives in Visuals but is built
-- long before the Visuals section, so the rail has to be defined first.
local ShootCat = Library:AddCategory("Shooting", 1)
local GuardCat = Library:AddCategory("Guarding", 2)
local SkinCat  = Library:AddCategory("Skins", 3)
local VisCat   = Library:AddCategory("Visuals", 4)
local PLCat    = Library:AddCategory("PlayerList", 5)
local ConfCat  = Library:AddCategory("Config", 6)

--== Auto Green ==--
local greenPage = ShootCat:AddTab("Auto Green")
local greenP  = greenPage:AddPanel("Auto Green")
local greenP2 = greenPage:AddPanel("Rage")

-- HOW THIS WORKS
-- The game greens a shot when its meter (PlayerGui.Visual.Shooting.Bar) reads
-- full at release. So there is exactly one job: make the bar read what we want
-- at the moment you let go.
--
-- Do NOT write bar.Size per frame. The game animates that same property, so a
-- per-frame write fights it (bar visibly jitters up and down) and reading it
-- back feeds our own output into the next target. That was the old bug. Instead
-- we wait for the bar to reach the point the game considers a shot, then fire a
-- SINGLE tween with override=true, which beats the game's own tween cleanly.
--
-- Accuracy is one number: shot %.
--   100  -> always land exactly on green
--    90  -> 90% of shots green, the rest fall just short (a "great")
-- Nothing else to tune.
F.Green = { enabled = false, accuracy = 100, key = Enum.KeyCode.E, requireBall = true,
	speed = 0.12, sound = false,
	rage = false, rageMode = "Drop", rageDepth = 3, rageHold = 0.6, rageRadius = 30 }

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
greenP:AddToggle({ Text = "Green Sound", Flag = "green_sound", Callback = function(on) F.Green.sound = on end })
-- 100 = every shot green. Lower it and that % of shots land on green; the rest
-- stop just short of full, which the game scores as a great instead.
greenP:AddSlider({ Text = "Shot %", Flag = "green_acc", Min = 50, Max = 100, Default = 100,
	Suffix = "%", Callback = function(v) F.Green.accuracy = v end })
greenP:AddSlider({ Text = "Release Speed", Flag = "green_speed", Min = 0.02, Max = 0.4, Decimals = 2, Default = 0.12,
	Suffix = "s", Callback = function(v) F.Green.speed = v end })
greenP:AddDropdown({ Text = "Shoot Key", Flag = "green_key", Options = { "E", "Q", "F", "R", "MouseButton1" },
	Default = "E", Callback = function(v)
		F.Green.key = (v == "MouseButton1") and Enum.UserInputType.MouseButton1 or Enum.KeyCode[v]
	end })

-- Rage panel. (These were dropped when Auto Green was rewritten, which left the
-- panel empty and F.Green.rage permanently false — rage could never fire.)
greenP2:AddToggle({ Text = "Rage Green", Flag = "green_rage", Callback = function(on)
	F.Green.rage = on
	if on then Library:Notify("Rage Green", "Moves you on release so nobody can contest.", 4, "good") end
end })
greenP2:AddDropdown({ Text = "Rage Mode", Flag = "green_ragemode", Options = { "Drop", "3PT Teleport" }, Default = "Drop",
	Callback = function(v) F.Green.rageMode = v end })
greenP2:AddSlider({ Text = "Rage Depth", Flag = "green_depth", Min = 1, Max = 8, Decimals = 1, Default = 3,
	Suffix = "m", Callback = function(v) F.Green.rageDepth = v end })
greenP2:AddSlider({ Text = "Rage Hold", Flag = "green_hold", Min = 0.2, Max = 2, Decimals = 2, Default = 0.6,
	Suffix = "s", Callback = function(v) F.Green.rageHold = v end })
greenP2:AddSlider({ Text = "3PT Radius", Flag = "green_radius", Min = 12, Max = 60, Default = 30,
	Suffix = "m", Callback = function(v) F.Green.rageRadius = v end })

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

-- Rage Teleport: relocate to a spot on the arc around the CURRENT hoop, at
-- rageRadius studs, as far from the nearest defender as possible. The hoop is
-- the anchor rather than the court, because "which court am I on" is really
-- "which hoop am I shooting at" — that works on any map without knowing its
-- layout. Every candidate is raycast-checked for floor first, so it can't drop
-- you out of bounds or off the edge. Facing stays toward the hoop.
local function rageTeleport()
	local myc = getChar()
	if not myc then return end
	local hrp = myc.HumanoidRootPart
	local origin = hrp.CFrame

	-- Use the court's REAL geometry instead of a radius guess. Every court model
	-- carries:
	--   2PT / Home2PT / Away2PT  — the two-point zone. Outside it IS a three.
	--   Bounds                   — the playable area.
	--   Basket / Home/AwayBasket — the hoop.
	-- So "outside the arc but still in bounds" stops being a guess.
	local court = currentCourt(hrp.Position)
	local twoPt, bounds, basket
	if court then
		local team = tostring(LocalPlayer:GetAttribute("Team") or "")
		twoPt  = court:FindFirstChild(team .. "2PT") or court:FindFirstChild("2PT")
		bounds = court:FindFirstChild("Bounds")
		basket = court:FindFirstChild(team .. "Basket") or court:FindFirstChild("Basket")
	end

	local function boxOf(m)
		if not m then return nil end
		local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
		if ok and cf then return cf, size end
		return nil
	end
	local function inBox(pos, cf, size, pad)
		if not cf then return false end
		local rel = cf:PointToObjectSpace(pos)
		pad = pad or 0
		return math.abs(rel.X) <= size.X / 2 + pad and math.abs(rel.Z) <= size.Z / 2 + pad
	end

	local bCf, bSize = boxOf(bounds)
	local tCf, tSize = boxOf(twoPt)
	local hoop = select(1, boxOf(basket)) and boxOf(basket).Position or nearestHoop(hrp.Position)
	if not hoop then
		Library:Notify("Rage Green", "No hoop/court found — falling back to Drop.", 3)
		return false
	end

	-- nearest opponent, to pick the side of the arc they're not on
	local defender, dD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
			if d < dD then defender, dD = p.Character.HumanoidRootPart.Position, d end
		end
	end

	-- Every candidate is raycast straight down. No floor within a few studs of
	-- our current height = off the court (or over a ledge), so it's discarded.
	-- This is what stopped it dumping you out of bounds: the old version scored
	-- purely on distance-from-defender and happily picked a spot in the sea.
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { myc, lastBall }

	local flat = Vector3.new(1, 0, 1)
	local best, bestScore = nil, -math.huge
	-- sweep several rings out from the hoop; the first that satisfies
	-- in-bounds AND outside-2PT AND has floor under it wins
	for ring = 0, 5 do
		local r = F.Green.rageRadius + ring * 4
		for i = 0, 23 do
			local a = (i / 24) * math.pi * 2
			local spot = hoop + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			spot = Vector3.new(spot.X, hrp.Position.Y, spot.Z)

			-- inside the court, outside the two-point zone
			local okBounds = (not bCf) or inBox(spot, bCf, bSize, -3)
			local okThree  = (not tCf) or (not inBox(spot, tCf, tSize, 1))
			if okBounds and okThree then
				local hit = Workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), rp)
				if hit then
					-- floor must be near our own height: rules out rooftops and pits
					local drop = math.abs(hit.Position.Y - (hrp.Position.Y - 3))
					if drop <= 6 then
						local landed = Vector3.new(spot.X, hit.Position.Y + 3, spot.Z)
						local score
						if defender then
							score = ((landed - defender) * flat).Magnitude       -- as far from them as possible
						else
							score = -((landed - hrp.Position) * flat).Magnitude  -- else: move the least
						end
						if score > bestScore then best, bestScore = landed, score end
					end
				end
			end
		end
		if best then break end   -- nearest valid ring is enough
	end
	if not best then
		-- nowhere legal on this court — do nothing rather than teleport you
		-- out of bounds, which is what the old radius-only version did
		return false
	end

	hrp.CFrame = CFrame.new(best, Vector3.new(hoop.X, best.Y, hoop.Z))
	hrp.AssemblyLinearVelocity = Vector3.zero

	task.delay(F.Green.rageHold, function()
		pcall(function()
			if hrp and hrp.Parent then
				hrp.CFrame = origin
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end)
	return true
end

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
		-- Roll accuracy ONCE, up front. Rolling per-frame is what made the old
		-- jitter wander. 100% = dead green; below that, this shot falls short by
		-- a small amount, which the game scores as a great rather than a green.
		local green = (F.Green.accuracy >= 100) or (math.random(1, 100) <= F.Green.accuracy)
		local target = green and 1 or (0.88 + math.random() * 0.06)

		local raged, fired = false, false
		while F.Green.enabled and greenKeyDown() and not Library.Destroyed do
			local bar = shootingBar()
			if bar then
				local y = bar.Size.Y.Scale

				-- rage fires early in the wind-up, before the release
				if F.Green.rage and not raged and y > 0.15 then
					raged = true
					if F.Green.rageMode == "3PT Teleport" then
						local ok, moved = pcall(rageTeleport)
						-- rageTeleport returns false when it can't find a safe
						-- on-court spot; don't silently do nothing, drop instead
						if not ok or moved == false then pcall(rageDrop) end
					else
						pcall(rageDrop)
					end
				end

				-- Fire ONCE, as a single tween, as late as possible: the closer to
				-- release, the less time the game has to animate over the top of
				-- us. Writing bar.Size per frame is what caused the old jitter —
				-- the game animates the same property, so the two fought, and
				-- reading it back fed our own output into the next target.
				-- TweenSize with override=true beats the game's tween cleanly.
				if not fired and y >= 0.75 then
					fired = true
					bar:TweenSize(UDim2.new(1, 0, target, 0), Enum.EasingDirection.Out,
						Enum.EasingStyle.Quad, F.Green.speed, true)
					-- hold it there for as long as the key is down, in case the
					-- game writes over the finished tween
					task.spawn(function()
						local deadline = os.clock() + 1.5
						while greenKeyDown() and os.clock() < deadline and not Library.Destroyed do
							if bar and bar.Parent and bar.Size.Y.Scale > target then
								bar.Size = UDim2.new(1, 0, target, 0)
							end
							task.wait()
						end
					end)
					-- NOTE: the custom green effect is NOT fired from here. It used
					-- to be, which meant it only ever played on greens Auto Green
					-- produced — nothing happened if you greened by hand, or had
					-- Auto Green off. A watcher on the meter itself handles it now
					-- (see "gfxwatch"), so every real green triggers it.
					if green then playGreenSound() end
				end
			end
			task.wait()
		end
		greenBusy = false
	end)
end)

--== Ball Visuals ==--
local bvPage = VisCat:AddTab("Ball Visuals")
local bvP  = bvPage:AddPanel("Ball ESP")
local bvP2 = bvPage:AddPanel("Trail / Trajectory")

F.Ball = { esp = false, espColor = COLORS.Orange or COLORS.Red, chams = false, tracer = false, dist = false,
	trail = false, trailColor = COLORS.Orange or COLORS.Red, trailLen = 1.2,
	traj = false, trajColor = COLORS.Cyan, trajSteps = 40, trajTime = 1.6,
	glow = false, glowRange = 14, glowBright = 2,
	particles = false, rainbow = false, rainbowSpeed = 1,
	landing = false, landingColor = COLORS.Green or COLORS.Cyan,
	hoops = false, hoopColor = COLORS.Purple,
	hl = nil, bb = nil, distLbl = nil, trailObj = nil, trajParts = {},
	light = nil, emitter = nil, landRing = nil, hoopHls = {} }

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
bvP2:AddToggle({ Text = "Landing Marker", Flag = "ball_landing", Callback = function(on)
	F.Ball.landing = on
	if not on and F.Ball.landRing then F.Ball.landRing.Visible = false end
end })
bvP2:AddColorPicker({ Text = "Landing Color", Flag = "ball_landcol", Default = COLORS.Green or COLORS.Cyan,
	Callback = function(c) F.Ball.landingColor = c end })

--== Effects ==--
local fxP = bvPage:AddPanel("Effects")
fxP:AddToggle({ Text = "Ball Glow", Flag = "ball_glow", Callback = function(on)
	F.Ball.glow = on
	if not on and F.Ball.light then F.Ball.light.Enabled = false end
end })
fxP:AddSlider({ Text = "Glow Range", Flag = "ball_glowrange", Min = 4, Max = 40, Default = 14,
	Callback = function(v) F.Ball.glowRange = v end })
fxP:AddSlider({ Text = "Glow Brightness", Flag = "ball_glowbright", Min = 0.5, Max = 6, Decimals = 1, Default = 2,
	Callback = function(v) F.Ball.glowBright = v end })
fxP:AddToggle({ Text = "Ball Particles", Flag = "ball_particles", Callback = function(on)
	F.Ball.particles = on
	if not on and F.Ball.emitter then F.Ball.emitter.Enabled = false end
end })
fxP:AddToggle({ Text = "Rainbow Ball", Flag = "ball_rainbow", Callback = function(on) F.Ball.rainbow = on end })
fxP:AddSlider({ Text = "Rainbow Speed", Flag = "ball_rainbowspd", Min = 0.2, Max = 5, Decimals = 1, Default = 1,
	Suffix = "x", Callback = function(v) F.Ball.rainbowSpeed = v end })
fxP:AddToggle({ Text = "Hoop ESP", Flag = "ball_hoops", Callback = function(on)
	F.Ball.hoops = on
	if not on then
		for _, h in pairs(F.Ball.hoopHls) do pcall(function() h.Enabled = false end) end
	end
end })
fxP:AddColorPicker({ Text = "Hoop Color", Flag = "ball_hoopcol", Default = COLORS.Purple,
	Callback = function(c) F.Ball.hoopColor = c end })

local ballTracer = Drawing and Drawing.new and Drawing.new("Line") or nil
if ballTracer then ballTracer.Thickness = 1; ballTracer.Visible = false end
local nextHoopScan = 0

Library:StartLoop("ballvis", RunService.RenderStepped, function()
	if Library.Destroyed then return end
	-- with every ball visual off there is nothing to draw, so don't even look for
	-- the ball — this loop should cost nothing when the tab is untouched
	if not (F.Ball.esp or F.Ball.chams or F.Ball.tracer or F.Ball.dist
		or F.Ball.trail or F.Ball.traj or F.Ball.glow or F.Ball.particles
		or F.Ball.rainbow or F.Ball.landing or F.Ball.hoops) then
		if ballTracer and ballTracer.Visible then ballTracer.Visible = false end
		if F.Ball.hl and F.Ball.hl.Enabled then F.Ball.hl.Enabled = false end
		if F.Ball.bb and F.Ball.bb.Enabled then F.Ball.bb.Enabled = false end
		if F.Ball.trailObj and F.Ball.trailObj.Enabled then F.Ball.trailObj.Enabled = false end
		return
	end
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

	-- glow
	if F.Ball.glow and ball then
		if not F.Ball.light or F.Ball.light.Parent ~= ball then
			pcall(function() if F.Ball.light then F.Ball.light:Destroy() end end)
			F.Ball.light = Instance.new("PointLight")
			F.Ball.light.Parent = ball
		end
		F.Ball.light.Color = F.Ball.espColor
		F.Ball.light.Range = F.Ball.glowRange
		F.Ball.light.Brightness = F.Ball.glowBright
		F.Ball.light.Enabled = true
	elseif F.Ball.light then
		F.Ball.light.Enabled = false
	end

	-- particles
	if F.Ball.particles and ball then
		if not F.Ball.emitter or F.Ball.emitter.Parent ~= ball then
			pcall(function() if F.Ball.emitter then F.Ball.emitter:Destroy() end end)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxassetid://241650934"
			e.Rate = 40
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Speed = NumberRange.new(0.5, 2)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			e.Parent = ball
			F.Ball.emitter = e
		end
		F.Ball.emitter.Color = ColorSequence.new(F.Ball.espColor)
		F.Ball.emitter.Enabled = true
	elseif F.Ball.emitter then
		F.Ball.emitter.Enabled = false
	end

	-- rainbow: drive espColor/trailColor off a hue cycle, so every effect that
	-- reads them (highlight, glow, particles, trail, tracer) cycles together
	if F.Ball.rainbow then
		local h = (os.clock() * 0.15 * F.Ball.rainbowSpeed) % 1
		local c = Color3.fromHSV(h, 1, 1)
		F.Ball.espColor = c
		F.Ball.trailColor = c
	end

	-- landing marker: raycast straight down from the end of the predicted arc
	if F.Ball.landing and ball then
		local vel = ball.AssemblyLinearVelocity
		if vel.Magnitude > 4 then
			if not F.Ball.landRing or not F.Ball.landRing.Parent then
				pcall(function() if F.Ball.landRing then F.Ball.landRing:Destroy() end end)
				local p = Instance.new("Part")
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
				p.Material = Enum.Material.Neon
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(0.15, 3, 3)
				p.Parent = Workspace
				F.Ball.landRing = p
			end
			-- walk the arc until it drops below the ball's start height, then drop a ray
			local g = Workspace.Gravity
			local pos, hit = ball.Position, nil
			for i = 1, 60 do
				local t = i * 0.05
				local pt = ball.Position + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { LocalPlayer.Character, ball, F.Ball.landRing }
				local res = Workspace:Raycast(pos, pt - pos, rp)
				if res then hit = res.Position; break end
				pos = pt
			end
			if hit then
				F.Ball.landRing.CFrame = CFrame.new(hit + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
				F.Ball.landRing.Color = F.Ball.landingColor
				F.Ball.landRing.Transparency = 0.3
			else
				F.Ball.landRing.Transparency = 1
			end
		elseif F.Ball.landRing then
			F.Ball.landRing.Transparency = 1
		end
	elseif F.Ball.landRing then
		F.Ball.landRing.Transparency = 1
	end

	-- hoop ESP. findHoops() caches, so this is cheap to call every frame; the
	-- highlights just get their colour refreshed.
	if F.Ball.hoops then
		local hoops = findHoops()
		if #hoops == 0 and os.clock() > nextHoopScan then
			nextHoopScan = os.clock() + 6
			Library:Notify("Hoop ESP", "No hoops found in this map's workspace.", 4)
		end
		for _, d in ipairs(hoops) do
			local hl = F.Ball.hoopHls[d]
			if not hl or not hl.Parent then
				hl = Instance.new("Highlight")
				hl.FillTransparency = 0.7
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = d
				hl.Parent = d
				F.Ball.hoopHls[d] = hl
			end
			hl.FillColor = F.Ball.hoopColor
			hl.OutlineColor = F.Ball.hoopColor
			hl.Enabled = true
		end
	end
end)

--== Skin Changer ==--
local skinPage = SkinCat:AddTab("Ball")
local skP  = skinPage:AddPanel("Ball")        -- the cosmetic itself
local skFX = skinPage:AddPanel("Effects")     -- green effect + streak

-- CLIENT-SIDE ONLY. The real equip path is EconomyService.RE.Equip, which is a
-- server call gated on what you own — so this cannot give you skins. What it
-- CAN do is rebuild any skin locally out of the game's own assets:
--
--   ReplicatedStorage.Assets.Ball.<SkinName>   (203 of them)
--       CUSTOM_SKIN_HOLDER   -> meshes that sit on the basketball
--       CUSTOM_AURA          -> parts welded to your character
--
-- Cloning those onto the ball yourself reproduces the look for YOU. Nobody else
-- sees it. The simple path is also still here: the ball's plain skin is just
-- Mesh.TextureId on its SpecialMesh (default 13818804314).
F.Skin = { enabled = false, skin = "None", preset = "None", aura = false,
	texture = "", mesh = "", color = Color3.fromRGB(255, 255, 255),
	useColor = false, material = "Fabric", defaultTex = nil, defaultMesh = nil }

local RS = game:GetService("ReplicatedStorage")
local SKIN_TAG = "XRUST_SKIN"

-- ── the game's own catalogue ───────────────────────────────────────────
-- ReplicatedStorage.Modules.Items is the master list: Skins (452), Effects
-- (484), Emotes, Banners, Cases, Dunks, Tattoos, Sleeves, Abilities.
-- require() on a shared data module hands back the very table the game uses.
local ITEMS do
	local m = RS:FindFirstChild("Modules")
	local mod = m and m:FindFirstChild("Items")
	if mod then
		local ok, t = pcall(require, mod)
		ITEMS = ok and type(t) == "table" and t or nil
	end
end

-- A catalogue row is an ARRAY, not a keyed table:
--   Skins.Conqueror = { "Conqueror", 6, 118518517233869, 80008733581423, "Conqueror" }
--                       [1] label    [2] rarity  [3] BALL TEXTURE  [4] icon  [5] id
-- [3] is the ball's texture: Skins.Default[3] == 14554890555, which is exactly
-- what a default ball's Mesh.TextureId reads on a live client. So changing a
-- skin is: look up [3], write it to Attach.Mesh.TextureId.
local SKIN_TEX_IDX = 3

local function skinCatalogue()
	return ITEMS and ITEMS.Skins or nil
end

-- ── one list to rule them ──────────────────────────────────────────────
-- A skin's TEXTURE (Modules.Items.Skins) and its VFX PREFAB (Assets.Ball)
-- are keyed by the SAME name — Items.Skins.Conqueror and Assets.Ball.Conqueror
-- are the same cosmetic. Two dropdowns meant hunting the same name twice, so
-- this is the union of both, and picking one applies whichever parts exist.
local function skinNames()
	local out, seen = { "None" }, { None = true }
	local cat = skinCatalogue()
	if cat then
		for name in pairs(cat) do
			if not seen[name] then seen[name] = true; table.insert(out, name) end
		end
	end
	-- prefabs that have no catalogue row (pure effects like Helios) still belong
	local f = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Ball")
	if f then
		for _, d in ipairs(f:GetChildren()) do
			if not seen[d.Name] then seen[d.Name] = true; table.insert(out, d.Name) end
		end
	end
	table.sort(out)
	return out
end

-- texture id for a catalogue skin, as an rbxassetid string
local function skinTexture(name)
	local cat = skinCatalogue()
	local row = cat and cat[name]
	local id = row and row[SKIN_TEX_IDX]
	if type(id) == "number" and id > 0 then return "rbxassetid://" .. tostring(id) end
	return nil
end

-- ── the effect/aura library (separate thing) ───────────────────────────
-- Assets.Ball holds the VFX prefabs (particles + CUSTOM_AURA), not textures.
local function skinFolder()
	local a = RS:FindFirstChild("Assets")
	return a and a:FindFirstChild("Ball")
end


-- The SpecialMesh lives somewhere under the Tool, not necessarily on the part
-- we weld to — so search the Tool when there is one.
local function ballMesh()
	local b = findBall()
	if not b then return nil end
	local root = lastBallTool or b
	local m = b:FindFirstChildWhichIsA("SpecialMesh")
		or root:FindFirstChildWhichIsA("SpecialMesh", true)
	return m, b
end

local function rememberDefaults()
	if F.Skin.defaultTex then return end
	local m = ballMesh()
	if m then
		F.Skin.defaultTex = m.TextureId
		F.Skin.defaultMesh = m.MeshId
	end
end

local function restoreSkin()
	local m, b = ballMesh()
	if m and F.Skin.defaultTex then
		pcall(function()
			m.TextureId = F.Skin.defaultTex
			m.MeshId = F.Skin.defaultMesh
		end)
	end
	if b then pcall(function() b.Color = Color3.fromRGB(255, 255, 255) end) end
end

-- id -> the URL form the game itself uses, so it loads identically
local function texUrl(id)
	id = tostring(id):gsub("%D", "")
	if id == "" then return nil end
	return "http://www.roblox.com/asset/?id=" .. id
end

-- strip anything WE parented, leaving the game's own instances alone
local function clearSkinClones()
	local targets = {}
	local ball = findBall()
	if ball then table.insert(targets, ball) end
	if lastBallTool then table.insert(targets, lastBallTool) end
	local c = LocalPlayer.Character
	if c then table.insert(targets, c) end
	for _, root in ipairs(targets) do
		for _, d in ipairs(root:GetDescendants()) do
			-- also catches the _ATT attachment holders we create
			if d.Name == SKIN_TAG or d.Name == SKIN_TAG .. "_ATT" then
				pcall(function() d:Destroy() end)
			end
		end
	end
end

-- Clone a skin's parts and weld them on. Anchored=false + Massless + a
-- WeldConstraint is what makes them ride the ball instead of hanging in the air
-- or dragging its physics around.
-- Clone a subtree onto an anchor part, preserving how it was authored.
-- IMPORTANT: transparency is NOT touched. A skin's parts are deliberately
-- invisible (trans=1.00) — they exist only to mount ParticleEmitters and a
-- PointLight. Forcing them visible (an earlier build did) just draws grey boxes.
local function attachClone(src, anchor, tagName)
	local clone = src:Clone()
	clone.Name = tagName

	local pivot
	local ok = pcall(function()
		if clone:IsA("Model") then pivot = clone:GetPivot() else pivot = clone.CFrame end
	end)
	if not ok or not pivot then pivot = anchor.CFrame end

	local parts = {}
	if clone:IsA("BasePart") then table.insert(parts, clone) end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	for _, p in ipairs(parts) do
		local rel = pivot:ToObjectSpace(p.CFrame)   -- keep the internal layout
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = anchor.CFrame * rel              -- re-based onto the anchor
		local w = Instance.new("WeldConstraint")
		w.Part0 = anchor
		w.Part1 = p
		w.Parent = p
	end
	-- templates often ship with emitters off; the game turns them on itself
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") then d.Enabled = true end
	end
	clone.Parent = anchor
	return #parts
end

-- Mount a loose emitter/light straight onto the part, which is what the game
-- itself does (the live dump shows the aura's emitters parented directly to
-- HumanoidRootPart, not to an attachment). This matters: an emitter parented to
-- a Part fills the part's volume, while one on an Attachment emits from a
-- single point — mounting them on an attachment quietly changes the effect's
-- shape into a pinprick.
local function attachLoose(src, anchor, tagName)
	local c = src:Clone()
	c.Name = tagName
	if c:IsA("ParticleEmitter") or c:IsA("Beam") then c.Enabled = true end
	c.Parent = anchor
	return 1
end

-- Attachments are how the game pins an effect to a SPOT on a limb — eye flames
-- live on an attachment positioned at the eyes, not on the Head itself. Cloning
-- the attachment keeps that offset AND brings its emitters with it. Skipping
-- them (which the first version did, since an Attachment is not a
-- BasePart/Model/emitter) is why EyeFlame never showed.
local function attachAttachment(src, anchor, tagName)
	local a = src:Clone()
	a.Name = tagName
	for _, e in ipairs(a:GetDescendants()) do
		if e:IsA("ParticleEmitter") or e:IsA("Beam") then e.Enabled = true end
	end
	a.Parent = anchor
	return 1
end

-- Shared handler: mount one template child onto a limb/part the right way for
-- whatever it happens to be.
local function mountItem(item, anchor, tagName)
	if item:IsA("BasePart") or item:IsA("Model") then
		return attachClone(item, anchor, tagName)
	elseif item:IsA("Attachment") then
		return attachAttachment(item, anchor, tagName)
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("PointLight") or item:IsA("SpotLight") then
		return attachLoose(item, anchor, tagName)
	elseif item:IsA("CFrameValue") or item:IsA("Folder") then
		-- e.g. UpperTorso.VFX — a wrapper holding the real emitters
		local n = 0
		for _, e in ipairs(item:GetChildren()) do
			n = n + mountItem(e, anchor, tagName)
		end
		return n
	end
	return 0
end

local function applyPreset(name)
	clearSkinClones()
	if name == "None" then return end
	local f = skinFolder()
	local skin = f and f:FindFirstChild(name)
	local ball = findBall()
	if not skin then Library:Notify("Skin", "'" .. name .. "' not in Assets.Ball.", 3); return end
	if not ball then Library:Notify("Skin", "No ball nearby — grab one first.", 3); return end

	local n = 0

	-- 1. Loose ParticleEmitters sitting directly under the skin folder. For
	--    Conqueror these are the six "BallEffect" emitters — they ARE the skin.
	--    (Skins like "Lightning" are nothing BUT one of these.)
	for _, d in ipairs(skin:GetChildren()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("PointLight") then
			n = n + attachLoose(d, ball, SKIN_TAG)
		end
	end

	-- 2. CUSTOM_SKIN_HOLDER: a small tree of invisible anchor parts carrying
	--    more emitters and a PointLight. Cloned whole, transparency untouched.
	local holder = skin:FindFirstChild("CUSTOM_SKIN_HOLDER")
	if holder then n = n + attachClone(holder, ball, SKIN_TAG) end

	-- 3. Some skins DO carry real geometry (Spikes/Grid/Crown/Pumpkin) or a
	--    texture. If one ships its own mesh, put it on the ball's SpecialMesh.
	local m = ballMesh()
	if m then
		local srcMesh, srcDecal
		for _, d in ipairs(skin:GetDescendants()) do
			if not srcMesh and d:IsA("SpecialMesh") and (d.TextureId ~= "" or d.MeshId ~= "") then srcMesh = d end
			if not srcDecal and (d:IsA("Decal") or d:IsA("Texture")) and d.Texture ~= "" then srcDecal = d end
		end
		if srcMesh and srcMesh.TextureId ~= "" then
			pcall(function()
				if srcMesh.MeshId ~= "" then m.MeshId = srcMesh.MeshId end
				m.TextureId = srcMesh.TextureId
			end)
			n = n + 1
		elseif srcDecal then
			pcall(function() m.TextureId = srcDecal.Texture end)
			n = n + 1
		end
	end

	-- Character aura. Each child of CUSTOM_AURA is a MODEL named after the limb
	-- it belongs on (HumanoidRootPart / UpperTorso / LeftHand / RightHand), and
	-- inside is a mix of parts, CFrameValues and loose emitters — so mount each
	-- kind the right way rather than assuming they're all parts.
	if F.Skin.aura then
		local aura = skin:FindFirstChild("CUSTOM_AURA")
		local char = LocalPlayer.Character
		if aura and char then
			for _, limbGroup in ipairs(aura:GetChildren()) do
				local part = char:FindFirstChild(limbGroup.Name)
				if part and part:IsA("BasePart") then
					for _, item in ipairs(limbGroup:GetChildren()) do
						n = n + mountItem(item, part, SKIN_TAG)
					end
				end
			end
		end
	end

	-- say exactly what happened, so a skin that "does nothing" is diagnosable
	-- instead of silent
	local hp = holder and holder:GetFullName() or "NOT FOUND"
	warn(("[XRust] skin '%s': holder=%s  attached=%d parts  ball=%s"):format(name, hp, n, ball:GetFullName()))
	if n == 0 then
		Library:Notify("Skin", "'" .. name .. "' had no parts to attach — see console.", 4)
	else
		Library:Notify("Skin", ("Applied %s (%d parts)."):format(name, n), 2, "good")
	end
end

-- Enabled first — it's the switch, it belongs at the top.
skP:AddToggle({ Text = "Enabled", Flag = "skin_enabled", Callback = function(on)
	F.Skin.enabled = on
	rememberDefaults()
	if on then
		applyPreset(F.Skin.preset)
	else
		clearSkinClones()
		restoreSkin()
	end
end })

-- ONE control. The name drives both halves of a cosmetic: its texture from the
-- catalogue and its VFX prefab from Assets.Ball. Type to filter — 452 entries
-- is not a list you scroll.
skP:AddDropdown({ Text = "Ball", Flag = "skin_name", Options = skinNames(), Default = "None", Search = true,
	Callback = function(v)
		F.Skin.skin = v
		F.Skin.preset = v          -- same name feeds the prefab lookup
		if F.Skin.enabled then applyPreset(v) end
		if v ~= "None" and not skinTexture(v) and not (skinFolder() and skinFolder():FindFirstChild(v)) then
			Library:Notify("Skin", "'" .. v .. "' has neither a texture nor a prefab.", 3)
		end
	end })
skP:AddToggle({ Text = "Include Aura", Flag = "skin_aura", Callback = function(on)
	F.Skin.aura = on
	if F.Skin.enabled then applyPreset(F.Skin.preset) end
end })
skP:AddButton({ Text = "Re-apply", Callback = function()
	if F.Skin.enabled then applyPreset(F.Skin.preset) else Library:Notify("Skin", "Enable it first.", 2) end
end })
skP:AddToggle({ Text = "Tint Ball", Flag = "skin_usecolor", Callback = function(on) F.Skin.useColor = on end })
skP:AddColorPicker({ Text = "Tint", Flag = "skin_color", Default = Color3.fromRGB(255, 255, 255),
	Callback = function(c) F.Skin.color = c end })
skP:AddDropdown({ Text = "Material", Flag = "skin_mat",
	Options = { "Fabric", "Neon", "Plastic", "SmoothPlastic", "Metal", "Marble", "Glass", "ForceField" },
	Default = "Fabric", Callback = function(v) F.Skin.material = v end })
skP:AddButton({ Text = "Reset To Default", Callback = function()
	restoreSkin()
	Library:Notify("Skin", "Ball restored.", 2, "good")
end })

-- ── Green Effect ──────────────────────────────────────────────────────
-- The game fires these through VisualService.RE.Effects when you green, and
-- the templates are all sitting in ReplicatedStorage.Assets.Effects (484 of
-- them). We can't make the SERVER play one you don't own, but we can clone the
-- template and play it on ourselves the moment Auto Green lands — so you see
-- any effect you like on every green. Local only, same as the skin.
F.GFX = { enabled = false, name = "None", life = 4, live = {} }

local function effectFolder()
	local a = RS:FindFirstChild("Assets")
	return a and a:FindFirstChild("Effects")
end
local function effectNames()
	local out = { "None" }
	local f = effectFolder()
	if f then
		for _, d in ipairs(f:GetChildren()) do table.insert(out, d.Name) end
		table.sort(out)
	end
	return out
end

-- Play an effect template at our character. Templates are built to be dropped
-- in and left alone: the particles emit on their own, so anchoring everything
-- and deleting it after `life` is enough. Anything not anchored would fall.
local function playEffect(name)
	if name == "None" then
		Library:Notify("Effect", "Pick an effect first.", 2)
		return
	end
	local f = effectFolder()
	if not f then
		Library:Notify("Effect", "Assets.Effects missing.", 3)
		return
	end
	local tpl = f:FindFirstChild(name)
	if not tpl then
		Library:Notify("Effect", "'" .. name .. "' not in Assets.Effects.", 3)
		return
	end
	local myc = getChar()
	if not myc then
		Library:Notify("Effect", "No character.", 3)
		return
	end

	local clone = tpl:Clone()
	clone.Name = SKIN_TAG .. "_FX"
	local base = myc.HumanoidRootPart.CFrame

	-- Assets.Effects entries are FOLDERS — no CFrame, no GetPivot. The old code
	-- did `clone:IsA("Model") and clone:GetPivot() or clone.CFrame`, which throws
	-- on a Folder; the pcall swallowed it and pivot fell back to `base`. Then
	--     base * base:ToObjectSpace(part.CFrame)  ==  part.CFrame
	-- so every part stayed at its ReplicatedStorage coordinates. The emitters
	-- were enabled and firing the whole time — thousands of studs from you.
	-- Derive the origin from the PARTS instead, which works for any container.
	local origin
	do
		if clone:IsA("BasePart") then
			origin = clone.CFrame
		elseif clone:IsA("Model") then
			local ok, cf = pcall(function() return clone:GetPivot() end)
			if ok and cf then origin = cf end
		end
		if not origin then
			local sum, n = Vector3.zero, 0
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then sum = sum + d.Position; n = n + 1 end
			end
			if n > 0 then origin = CFrame.new(sum / n) end
		end
	end

	local parts = {}
	if clone:IsA("BasePart") then table.insert(parts, clone) end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		if origin then p.CFrame = base * origin:ToObjectSpace(p.CFrame) end
	end

	clone.Parent = Workspace

	-- An emitter with no BasePart above it has no position and cannot render —
	-- that's BlueFire's "7 emitters, 0 parts". Give those a host at the player.
	local host
	local function getHost()
		if host and host.Parent then return host end
		host = Instance.new("Part")
		host.Name = "Host"
		host.Anchored = true
		host.CanCollide, host.CanQuery, host.CanTouch = false, false, false
		host.Transparency = 1
		host.Size = Vector3.new(0.2, 0.2, 0.2)
		host.CFrame = base
		host.Parent = clone
		return host
	end
	local function positioned(inst)
		local p = inst.Parent
		while p and p ~= clone do
			if p:IsA("BasePart") then return true end
			p = p.Parent
		end
		return false
	end
	-- collect first: reparenting while walking GetDescendants is asking for it
	local orphans = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and not positioned(d) then
			table.insert(orphans, d)
		end
	end
	for _, d in ipairs(orphans) do
		if d:IsA("ParticleEmitter") then pcall(function() d.Parent = getHost() end) end
	end

	-- Templates ship with their emitters DISABLED — the game's own effect script
	-- turns them on. Without this the clone is a correctly-placed, completely
	-- invisible model, which is exactly what "the green effect changer doesn't
	-- work" looked like. Rate==0 emitters are one-shot bursts, so they need an
	-- explicit :Emit() rather than Enabled.
	local emitted = 0
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			-- Enable AND burst. The game plays these as one-shots, so a Rate>0
			-- emitter left to trickle looks like nothing happened; :Emit gives
			-- the visible pop, Enabled carries the tail.
			d.Enabled = true
			pcall(function() d:Emit(math.clamp(math.floor((d.Rate > 0 and d.Rate or 30) * 0.5), 5, 80)) end)
			emitted = emitted + 1
		elseif d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = true
			emitted = emitted + 1
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Enabled = true
		elseif d:IsA("Sound") then
			pcall(function() d:Play() end)
		end
	end
	-- Report what actually got built. An effect that "does nothing" is either
	-- geometry with no emitters, or emitters that fired off-screen — the counts
	-- tell which without more guessing.
	local partCount = 0
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then partCount = partCount + 1 end
	end
	if clone:IsA("BasePart") then partCount = partCount + 1 end
	warn(("[XRust] effect '%s': %d emitters, %d parts | origin=%s -> %s | class=%s"):format(
		name, emitted, partCount,
		origin and tostring(origin.Position) or "NONE (parts left where they were)",
		tostring(base.Position), tpl.ClassName))
	if emitted == 0 and partCount == 0 then
		Library:Notify("Effect", "'" .. name .. "' cloned but is empty.", 4)
	else
		Library:Notify("Effect", ("%s — %d emitters, %d parts"):format(name, emitted, partCount), 3, "good")
	end

	table.insert(F.GFX.live, clone)

	task.delay(F.GFX.life, function()
		pcall(function() clone:Destroy() end)
		for i, v in ipairs(F.GFX.live) do
			if v == clone then table.remove(F.GFX.live, i); break end
		end
	end)
end

F.GFX.play = playEffect

-- ── green detector ────────────────────────────────────────────────────
-- Fire the moment the meter READS FULL, not on release.
--
-- The previous version armed at full and waited for the bar to drop back /
-- vanish to call that "the release". That never came: the game hides the
-- Shooting frame rather than emptying the bar, so Size.Y stayed at 1, the drop
-- was never seen, and the arm expired silently. Full == green, so just fire
-- there — a fraction early, and impossible to miss. A great never reaches full,
-- so it can't false-fire.
local gfxArmed, gfxLastPlay = false, 0

local function gfxBar()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local vis = pg and pg:FindFirstChild("Visual")
	local sh = vis and vis:FindFirstChild("Shooting")
	return sh and sh:FindFirstChild("Bar")
end

local function fireGreenEffect()
	if os.clock() - gfxLastPlay < 0.5 then return end   -- one per shot
	gfxLastPlay = os.clock()
	pcall(playEffect, F.GFX.name)
end

Library:StartLoop("gfxwatch", RunService.Heartbeat, function()
	if Library.Destroyed or not F.GFX.enabled or F.GFX.name == "None" then return end
	local bar = gfxBar()
	if not bar then gfxArmed = false; return end

	local y = bar.Size.Y.Scale
	if y >= 0.98 then
		if not gfxArmed then
			gfxArmed = true
			warn(("[XRust] green detected (bar=%.3f) -> %s"):format(y, tostring(F.GFX.name)))
			fireGreenEffect()
		end
	elseif y < 0.5 then
		gfxArmed = false   -- rearm for the next shot
	end
end)

-- ── Streak Effect ─────────────────────────────────────────────────────
-- The live dump showed STREAK_EFFECT_PART + BodyFlame/EyeFlame parented to
-- Head/LowerTorso/legs while on a streak — that's Assets.StreakEffects (12 of
-- them) applied to your character. Same clone trick as the aura.
F.Streak = { enabled = false, name = "None" }

local function streakFolder()
	local a = RS:FindFirstChild("Assets")
	return a and a:FindFirstChild("StreakEffects")
end
local function streakNames()
	local out = { "None" }
	local f = streakFolder()
	if f then
		for _, d in ipairs(f:GetChildren()) do table.insert(out, d.Name) end
		table.sort(out)
	end
	return out
end

local STREAK_TAG = "XRUST_STREAK"
local function clearStreak()
	local c = LocalPlayer.Character
	if not c then return end
	for _, d in ipairs(c:GetDescendants()) do
		if d.Name == STREAK_TAG then pcall(function() d:Destroy() end) end
	end
end

local function applyStreak(name)
	clearStreak()
	if name == "None" then return end
	local f = streakFolder()
	local tpl = f and f:FindFirstChild(name)
	local char = LocalPlayer.Character
	if not (tpl and char) then Library:Notify("Streak", "Not found / no character.", 3); return end

	local n = 0
	-- children named after a limb get mounted there; anything loose goes on the
	-- torso so it's at least visible
	for _, group in ipairs(tpl:GetChildren()) do
		local limb = char:FindFirstChild(group.Name)
		if limb and limb:IsA("BasePart") then
			-- mountItem handles Attachments too, which is what EyeFlame rides on
			for _, item in ipairs(group:GetChildren()) do
				n = n + mountItem(item, limb, STREAK_TAG)
			end
		elseif group:IsA("ParticleEmitter") or group:IsA("Beam") then
			local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			if torso then n = n + attachLoose(group, torso, STREAK_TAG) end
		end
	end
	warn(("[XRust] streak '%s': %d parts"):format(name, n))
	Library:Notify("Streak", n > 0 and ("Applied " .. name) or "Nothing to attach — see console.", 3, n > 0 and "good" or nil)
end

skFX:AddToggle({ Text = "Custom Streak", Flag = "streak_enabled", Callback = function(on)
	F.Streak.enabled = on
	if on then applyStreak(F.Streak.name) else clearStreak() end
end })
skFX:AddDropdown({ Text = "Streak Effect", Flag = "streak_name", Options = streakNames(), Default = "None",
	Callback = function(v)
		F.Streak.name = v
		if F.Streak.enabled then applyStreak(v) end
	end })

skFX:AddToggle({ Text = "Custom Green Effect", Flag = "gfx_enabled", Callback = function(on) F.GFX.enabled = on end })
skFX:AddDropdown({ Text = "Green Effect", Flag = "gfx_name", Options = effectNames(), Default = "None",
	Callback = function(v) F.GFX.name = v end })
skFX:AddSlider({ Text = "Effect Lifetime", Flag = "gfx_life", Min = 1, Max = 10, Decimals = 1, Default = 4,
	Suffix = "s", Callback = function(v) F.GFX.life = v end })
skFX:AddButton({ Text = "Preview", Callback = function()
	if F.GFX.name == "None" then Library:Notify("Effect", "Pick one first.", 2); return end
	playEffect(F.GFX.name)
end })

-- THE BALL SKIN. Confirmed from a live dump with a skin equipped: the ball's
-- look is one property — Attach.Mesh.TextureId on the Tool you're holding.
--   default ball     : 14554890555
--   an equipped skin : 102849528147022
-- Entries in Assets.Ball are mostly EFFECTS (particles + a character aura), not
-- textures, which is why applying one never retextured the ball. Setting the id
-- here does. Equip a skin you own and hit "Copy Current IDs" to harvest more.
-- The raw-id panel is gone: the Ball dropdown covers all 452 skins by name, so
-- typing texture ids by hand was only ever a workaround for not having the
-- catalogue. The one genuinely useful leftover is the manual override, kept on
-- the Ball panel for anything the catalogue doesn't list.
skP:AddTextbox({ Text = "Texture ID", Flag = "skin_tex", Placeholder = "override",
	Callback = function(v) F.Skin.texture = v end })

local skinBall = nil
Library:StartLoop("skin", RunService.Heartbeat, function()
	if not F.Skin.enabled or Library.Destroyed then return end
	local m, b = ballMesh()
	if not (m and b) then return end
	rememberDefaults()

	-- The ball you hold is a DIFFERENT instance from the one on the rack, and
	-- the game hands you a new one each possession. Re-apply whenever it
	-- changes, otherwise the skin sits on whatever ball happened to be found
	-- when you first ticked the box.
	if F.Skin.preset ~= "None" and b ~= skinBall then
		skinBall = b
		if not b:FindFirstChild(SKIN_TAG) then
			task.spawn(function() pcall(applyPreset, F.Skin.preset) end)
		end
	end

	-- Catalogue skin wins; the manual id box is the fallback for anything not
	-- in Items.Skins. Re-asserted every frame because the game rewrites
	-- TextureId whenever it hands you a fresh ball.
	local tex = skinTexture(F.Skin.skin) or texUrl(F.Skin.texture)
	if tex and m.TextureId ~= tex then pcall(function() m.TextureId = tex end) end

	if F.Skin.useColor and b.Color ~= F.Skin.color then
		pcall(function() b.Color = F.Skin.color end)
	end
	local mat = Enum.Material[F.Skin.material]
	if mat and b.Material ~= mat then pcall(function() b.Material = mat end) end
end)

--=====================================================================
--  GUARDING CATEGORY
--=====================================================================
-- (GuardCat declared at the top)
local guardPage = GuardCat:AddTab("Auto Guard")
local guardP  = guardPage:AddPanel("Auto Guard")
local guardP2 = guardPage:AddPanel("Settings")

-- Two ways to stay on your man:
--   Teleport - snap to the spot in front of them every frame. Perfect, and
--              obviously not human.
--   Legs     - actually run there using the Humanoid, so it's your character
--              moving under its own power. Slower, can be shaken off, looks
--              like someone with very good footwork.
F.Guard = { enabled = false, mode = "Legs", dist = 5, ballOnly = false, predict = 0.15,
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
		local h = getHumanoid()
		-- hand control back: stop walking and re-enable the Humanoid's own
		-- rotation, or the character stays frozen facing the last target
		if h then h:Move(Vector3.zero, false); h.AutoRotate = true end
	end
end })
guardP:AddToggle({ Text = "Ball Carrier Only", Flag = "guard_ballonly", Callback = function(on) F.Guard.ballOnly = on end })
guardP:AddToggle({ Text = "Face Target", Flag = "guard_face", Callback = function(on) F.Guard.faceTarget = on end })
guardP:AddToggle({ Text = "Highlight Target", Flag = "guard_hl", Callback = function(on)
	F.Guard.espTarget = on
	if not on and F.Guard.hl then F.Guard.hl.Enabled = false end
end })

guardP2:AddDropdown({ Text = "Mode", Flag = "guard_mode", Options = { "Legs", "Teleport" }, Default = "Legs",
	Callback = function(v)
		F.Guard.mode = v
		local h = getHumanoid()
		if h then h:Move(Vector3.zero, false) end
	end })
guardP2:AddSlider({ Text = "Distance", Flag = "guard_dist", Min = 2, Max = 12, Decimals = 1, Default = 5,
	Callback = function(v) F.Guard.dist = v end })
guardP2:AddSlider({ Text = "Prediction", Flag = "guard_predict", Min = 0, Max = 0.6, Decimals = 2, Default = 0.15,
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

	-- lead the target so we end up where they're heading, not where they were
	local lead = tHrp.AssemblyLinearVelocity * F.Guard.predict
	local goalPos = tHrp.Position + lead + (tHrp.CFrame.LookVector * F.Guard.dist)
	local hrp = myc.HumanoidRootPart

	if F.Guard.mode == "Legs" then
		-- Real movement: no CFrame writes at all, just Humanoid:Move, so the
		-- character walks under its own power and can be beaten off the dribble.
		--
		-- Two things that made the first version bad:
		--  * it fought the game's own movement by also writing hrp.CFrame every
		--    frame to face the target — that cancels your input and locks you in
		--    place. Facing is now done via Humanoid.AutoRotate + the walk vector.
		--  * a hard 1.5 stud stop meant it stuttered on the spot at the boundary.
		--    A deadband plus overshoot damping keeps it smooth.
		local hum = myc:FindFirstChildOfClass("Humanoid")
		if hum then
			local flat = Vector3.new(goalPos.X - hrp.Position.X, 0, goalPos.Z - hrp.Position.Z)
			local d = flat.Magnitude
			if d > 0.8 then
				-- ease off as we arrive so we settle instead of oscillating
				local scale = math.clamp(d / 4, 0.25, 1)
				hum:Move(flat.Unit * scale, false)
			else
				hum:Move(Vector3.zero, false)
			end
			-- face them without touching CFrame: let the Humanoid rotate itself
			if F.Guard.faceTarget then
				hum.AutoRotate = false
				local look = Vector3.new(tHrp.Position.X, hrp.Position.Y, tHrp.Position.Z)
				if (look - hrp.Position).Magnitude > 0.1 then
					local want = CFrame.new(hrp.Position, look)
					-- rotate only; position stays wherever the legs put us
					hrp.CFrame = CFrame.new(hrp.Position) * (want - want.Position)
				end
			else
				hum.AutoRotate = true
			end
		end
	else
		local goal = F.Guard.faceTarget and CFrame.new(goalPos, tHrp.Position + lead) or CFrame.new(goalPos)
		if F.Guard.smooth <= 0 then
			hrp.CFrame = goal
		else
			hrp.CFrame = hrp.CFrame:Lerp(goal, math.clamp(dt * (21 - F.Guard.smooth), 0, 1))
		end
	end
end)

--== Auto Rebound ==--
local rebPage = GuardCat:AddTab("Auto Rebound")
local rebP  = rebPage:AddPanel("Auto Rebound")
local rebP2 = rebPage:AddPanel("Settings")

-- Goes for the loose ball. Only fires when the ball is genuinely loose (nobody
-- is holding it) and it's within range, so it doesn't yank you across the map
-- mid-possession.
F.Reb = { enabled = false, mode = "Legs", range = 60, height = 3, onlyLoose = true, cooldown = 0.4, last = 0 }

local function ballIsLoose()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("Basketball") then return false end
	end
	return true
end

rebP:AddToggle({ Text = "Enabled", Flag = "reb_enabled", Bind = true, BindNoToggle = true, Callback = function(on)
	F.Reb.enabled = on
	if not on then
		local h = getHumanoid()
		if h then h:Move(Vector3.zero, false) end
	end
end })
rebP:AddToggle({ Text = "Only When Loose", Flag = "reb_loose", Callback = function(on) F.Reb.onlyLoose = on end })

rebP2:AddDropdown({ Text = "Mode", Flag = "reb_mode", Options = { "Legs", "Teleport" }, Default = "Legs",
	Callback = function(v) F.Reb.mode = v end })
rebP2:AddSlider({ Text = "Range", Flag = "reb_range", Min = 10, Max = 200, Default = 60,
	Suffix = "m", Callback = function(v) F.Reb.range = v end })
rebP2:AddSlider({ Text = "Height Offset", Flag = "reb_height", Min = 0, Max = 10, Decimals = 1, Default = 3,
	Callback = function(v) F.Reb.height = v end })

Library:StartLoop("rebound", RunService.RenderStepped, function()
	if not F.Reb.enabled or Library.Destroyed then return end
	local opt = Library.Options["reb_enabled"]
	local key = opt and opt.GetKey and opt:GetKey()
	if key and not isDown(key) then return end
	if ballHeld() then return end                       -- we already have it
	if F.Reb.onlyLoose and not ballIsLoose() then return end

	local ball = findBall()
	local myc = getChar()
	if not (ball and myc) then return end
	-- Ignore balls sitting on a court's Rack (Courts.<name>.Rack.Basketball).
	-- Those are spares that never move, and chasing one is why rebound looked
	-- broken: it locked onto a rack ball instead of the live one.
	if isRacked(ball) then return end
	local hrp = myc.HumanoidRootPart
	if (ball.Position - hrp.Position).Magnitude > F.Reb.range then return end

	if F.Reb.mode == "Legs" then
		local hum = myc:FindFirstChildOfClass("Humanoid")
		if hum then
			local flat = Vector3.new(ball.Position.X - hrp.Position.X, 0, ball.Position.Z - hrp.Position.Z)
			if flat.Magnitude > 1 then hum:Move(flat.Unit, false) else hum:Move(Vector3.zero, false) end
		end
	else
		if os.clock() < F.Reb.last then return end
		F.Reb.last = os.clock() + F.Reb.cooldown
		hrp.CFrame = CFrame.new(ball.Position - Vector3.new(0, F.Reb.height, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end)

--=====================================================================
--  VISUALS CATEGORY
--=====================================================================
-- (VisCat declared at the top)

--== Player ESP ==--
local espPage = VisCat:AddTab("Player ESP")
local espP  = espPage:AddPanel("Players")
local espP2 = espPage:AddPanel("Settings")

F.ESP = { enabled = false, box = false, name = false, dist = false, chams = false, tracer = false,
	teamCheck = false, color = COLORS.Red, teamColor = false, maxDist = 300, objs = {} }

local function espColorFor(p)
	if F.ESP.teamColor and p.Team then return p.TeamColor.Color end
	return F.ESP.color
end

espP:AddToggle({ Text = "Enabled", Flag = "esp_enabled", Callback = function(on)
	F.ESP.enabled = on
	if not on then
		for _, o in pairs(F.ESP.objs) do
			pcall(function()
				if o.hl then o.hl.Enabled = false end
				if o.bb then o.bb.Enabled = false end
				if o.box then o.box.Visible = false end
				if o.tracer then o.tracer.Visible = false end
			end)
		end
	end
end })
espP:AddToggle({ Text = "Box", Flag = "esp_box", Callback = function(on) F.ESP.box = on end })
espP:AddToggle({ Text = "Name", Flag = "esp_name", Callback = function(on) F.ESP.name = on end })
espP:AddToggle({ Text = "Distance", Flag = "esp_dist", Callback = function(on) F.ESP.dist = on end })
espP:AddToggle({ Text = "Chams", Flag = "esp_chams", Callback = function(on) F.ESP.chams = on end })
espP:AddToggle({ Text = "Tracers", Flag = "esp_tracer", Callback = function(on) F.ESP.tracer = on end })

espP2:AddToggle({ Text = "Team Check", Flag = "esp_team", Callback = function(on) F.ESP.teamCheck = on end })
espP2:AddToggle({ Text = "Use Team Color", Flag = "esp_teamcol", Callback = function(on) F.ESP.teamColor = on end })
espP2:AddSlider({ Text = "Max Distance", Flag = "esp_maxdist", Min = 50, Max = 1000, Default = 300,
	Suffix = "m", Callback = function(v) F.ESP.maxDist = v end })
espP2:AddColorPicker({ Text = "ESP Color", Flag = "esp_color", Default = COLORS.Red,
	Callback = function(c) F.ESP.color = c end })

local hasDrawing = (Drawing ~= nil and Drawing.new ~= nil)

local function espObj(p)
	local o = F.ESP.objs[p]
	if o then return o end
	o = {}
	if hasDrawing then
		o.box = Drawing.new("Square"); o.box.Thickness = 1; o.box.Filled = false; o.box.Visible = false
		o.tracer = Drawing.new("Line"); o.tracer.Thickness = 1; o.tracer.Visible = false
	end
	F.ESP.objs[p] = o
	return o
end

local function espClear(p)
	local o = F.ESP.objs[p]
	if not o then return end
	pcall(function()
		if o.box then o.box:Remove() end
		if o.tracer then o.tracer:Remove() end
		if o.hl then o.hl:Destroy() end
		if o.bb then o.bb:Destroy() end
	end)
	F.ESP.objs[p] = nil
end

Library:Connect(Players.PlayerRemoving, function(p) espClear(p) end)

Library:StartLoop("esp", RunService.RenderStepped, function()
	if Library.Destroyed then return end
	if not F.ESP.enabled then return end
	local myc = getChar()
	local myPos = myc and myc.HumanoidRootPart.Position

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local o = espObj(p)
			local show = hrp and hum and hum.Health > 0
			if show and F.ESP.teamCheck and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then show = false end
			if show and myPos and (hrp.Position - myPos).Magnitude > F.ESP.maxDist then show = false end

			if show then
				local col = espColorFor(p)
				local sp, on = Camera:WorldToViewportPoint(hrp.Position)

				-- box + tracer (Drawing, screen-space)
				if o.box then
					-- Project the character's actual head-to-foot extent instead of
					-- guessing from depth. The old `1800 / sp.Z` was a made-up
					-- constant and drew a postage stamp at any real distance.
					local head = char:FindFirstChild("Head")
					local top = (head and head.Position.Y or hrp.Position.Y + 2.5) + 0.6
					local bottom = hrp.Position.Y - 3.2
					local tp = Camera:WorldToViewportPoint(Vector3.new(hrp.Position.X, top, hrp.Position.Z))
					local bp = Camera:WorldToViewportPoint(Vector3.new(hrp.Position.X, bottom, hrp.Position.Z))
					local h = math.abs(bp.Y - tp.Y)
					if F.ESP.box and on and h > 1 then
						local w = h * 0.62
						o.box.Size = Vector2.new(w, h)
						o.box.Position = Vector2.new(sp.X - w / 2, math.min(tp.Y, bp.Y))
						o.box.Color = col
						o.box.Visible = true
					else
						o.box.Visible = false
					end
				end
				if o.tracer then
					if F.ESP.tracer and on then
						local vp = Camera.ViewportSize
						o.tracer.From = Vector2.new(vp.X / 2, vp.Y)
						o.tracer.To = Vector2.new(sp.X, sp.Y)
						o.tracer.Color = col
						o.tracer.Visible = true
					else
						o.tracer.Visible = false
					end
				end

				-- chams
				if F.ESP.chams then
					if not o.hl or o.hl.Adornee ~= char then
						pcall(function() if o.hl then o.hl:Destroy() end end)
						o.hl = Instance.new("Highlight")
						o.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						o.hl.FillTransparency = 0.55
						o.hl.Adornee = char
						o.hl.Parent = char
					end
					o.hl.FillColor = col
					o.hl.OutlineColor = col
					o.hl.Enabled = true
				elseif o.hl then
					o.hl.Enabled = false
				end

				-- name / distance billboard
				if F.ESP.name or F.ESP.dist then
					if not o.bb or o.bb.Adornee ~= hrp then
						pcall(function() if o.bb then o.bb:Destroy() end end)
						o.bb = Instance.new("BillboardGui")
						o.bb.Size = UDim2.new(0, 150, 0, 16)
						o.bb.StudsOffset = Vector3.new(0, 3.2, 0)
						o.bb.AlwaysOnTop = true
						o.bb.Adornee = hrp
						o.bb.Parent = hrp
						o.lbl = create("TextLabel", { Parent = o.bb, BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 1, 0), Font = FONT, TextSize = 12, TextStrokeTransparency = 0.4 })
					end
					local txt = ""
					if F.ESP.name then txt = p.DisplayName or p.Name end
					if F.ESP.dist and myPos then
						local d = math.floor((hrp.Position - myPos).Magnitude)
						txt = txt ~= "" and (txt .. "  [" .. d .. "m]") or (d .. "m")
					end
					o.lbl.Text = txt
					o.lbl.TextColor3 = col
					o.bb.Enabled = true
				elseif o.bb then
					o.bb.Enabled = false
				end
			else
				if o.box then o.box.Visible = false end
				if o.tracer then o.tracer.Visible = false end
				if o.hl then o.hl.Enabled = false end
				if o.bb then o.bb.Enabled = false end
			end
		end
	end
end)

--== World ==--
local worldPage = VisCat:AddTab("World")
local wP  = worldPage:AddPanel("Lighting")
local wP2 = worldPage:AddPanel("Camera")

F.World = { fullbright = false, ambient = Color3.fromRGB(70, 70, 70), useAmbient = false,
	brightness = 2, time = 14, useTime = false, fog = false, fogEnd = 100000, fogColor = Color3.fromRGB(180, 180, 190),
	fov = 70, useFov = false, saved = nil }

local function saveLighting()
	if F.World.saved then return end
	F.World.saved = {
		Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
		FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
		GlobalShadows = Lighting.GlobalShadows,
	}
end
local function restoreLighting()
	if not F.World.saved then return end
	for k, v in pairs(F.World.saved) do pcall(function() Lighting[k] = v end) end
end

wP:AddToggle({ Text = "Fullbright", Flag = "w_fullbright", Callback = function(on)
	F.World.fullbright = on
	saveLighting()
	if on then
		Lighting.Ambient = Color3.fromRGB(255, 255, 255)
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		Lighting.Brightness = 3
		Lighting.GlobalShadows = false
	else
		restoreLighting()
	end
end })
wP:AddToggle({ Text = "Custom Ambient", Flag = "w_useambient", Callback = function(on)
	F.World.useAmbient = on
	saveLighting()
	if on then
		Lighting.Ambient = F.World.ambient
		Lighting.OutdoorAmbient = F.World.ambient
	elseif not F.World.fullbright then
		restoreLighting()
	end
end })
wP:AddColorPicker({ Text = "Ambient Color", Flag = "w_ambient", Default = Color3.fromRGB(70, 70, 70),
	Callback = function(c)
		F.World.ambient = c
		if F.World.useAmbient then Lighting.Ambient = c; Lighting.OutdoorAmbient = c end
	end })
wP:AddSlider({ Text = "Brightness", Flag = "w_bright", Min = 0, Max = 8, Decimals = 1, Default = 2,
	Callback = function(v)
		F.World.brightness = v
		saveLighting()
		Lighting.Brightness = v
	end })
wP:AddToggle({ Text = "Custom Time", Flag = "w_usetime", Callback = function(on)
	F.World.useTime = on
	saveLighting()
	if on then Lighting.ClockTime = F.World.time else restoreLighting() end
end })
wP:AddSlider({ Text = "Time Of Day", Flag = "w_time", Min = 0, Max = 24, Decimals = 1, Default = 14,
	Suffix = "h", Callback = function(v)
		F.World.time = v
		if F.World.useTime then Lighting.ClockTime = v end
	end })
wP:AddToggle({ Text = "No Fog", Flag = "w_nofog", Callback = function(on)
	F.World.fog = on
	saveLighting()
	if on then
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
	else
		restoreLighting()
	end
end })

wP2:AddToggle({ Text = "Custom FOV", Flag = "w_usefov", Callback = function(on)
	F.World.useFov = on
	if not on and Camera then Camera.FieldOfView = 70 end
end })
wP2:AddSlider({ Text = "Field Of View", Flag = "w_fov", Min = 40, Max = 120, Default = 70,
	Callback = function(v)
		F.World.fov = v
		if F.World.useFov and Camera then Camera.FieldOfView = v end
	end })

-- FOV has to be re-applied: the game resets it on respawn/camera changes
Library:StartLoop("world", RunService.RenderStepped, function()
	if Library.Destroyed then return end
	if F.World.useFov and Camera and Camera.FieldOfView ~= F.World.fov then
		Camera.FieldOfView = F.World.fov
	end
end)

--=====================================================================
--  CONFIG CATEGORY
--=====================================================================
-- (ConfCat declared at the top)
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
-- (PLCat declared at the top)
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
	F.Ball.trail, F.Ball.traj, F.Ball.glow, F.Ball.particles = false, false, false, false
	F.Ball.rainbow, F.Ball.landing, F.Ball.hoops = false, false, false
	F.ESP.enabled = false
	F.Skin.enabled = false
	pcall(function()
		-- player ESP owns Drawing objects and instances parented into other
		-- characters; both outlive the ScreenGui if not removed by hand
		for p in pairs(F.ESP.objs) do espClear(p) end
		F.ESP.objs = {}
		restoreLighting()
		if F.World.useFov and Camera then Camera.FieldOfView = 70 end
		-- skin clones are parented into the ball and our character, and green
		-- effects into workspace — all of it survives the menu unless stripped
		clearSkinClones()
		restoreSkin()
		F.GFX.enabled = false
		for _, fx in ipairs(F.GFX.live) do pcall(function() fx:Destroy() end) end
		F.GFX.live = {}
		F.Streak.enabled = false
		clearStreak()
	end)
	pcall(function()
		-- the ball visuals parent real instances into the ball / workspace, and
		-- the trajectory spawns parts every frame — all of it has to go or it
		-- outlives the menu
		if F.Ball.hl then F.Ball.hl:Destroy() end
		if F.Ball.bb then F.Ball.bb:Destroy() end
		if F.Ball.trailObj then F.Ball.trailObj:Destroy() end
		if F.Ball.light then F.Ball.light:Destroy() end
		if F.Ball.emitter then F.Ball.emitter:Destroy() end
		if F.Ball.landRing then F.Ball.landRing:Destroy() end
		for _, p in ipairs(F.Ball.trajParts) do p:Destroy() end
		F.Ball.trajParts = {}
		for _, h in pairs(F.Ball.hoopHls) do h:Destroy() end
		F.Ball.hoopHls = {}
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
