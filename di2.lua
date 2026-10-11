--[[
	DynamicIsland.lua  v4.1  -  Dynamic Island + Liquid Glass chân thực (Night Hub / high-quality)
	-------------------------------------------------------------------------------
	MỚI Ở v4.1 (nâng chất lượng liquid ~400Hz)
	• Spring substep ~400Hz – chuyển động mượt, không rung khi FPS thấp.
	• Viền kính 8 lớp + depth 16 lớp – độ dày kính rõ, mép sáng mượt.
	• RealBlur: Slices 20, Inset 3, InFocusRadius 60 – blur nền mạnh, sát góc bo.
	• Liquid loop mỗi frame: multi-freq rim drift, depth pulse, edge breath, body micro-breath, tint pulse.
	• Frosted tối hơn, đục vừa (transparency ~0.22) để nền mờ hiện rõ qua kính.

	MỚI Ở v4 (khớp ảnh Night Hub – kính đục mờ thật + liquid sống)
	• Style Frosted tone Night Hub + AlwaysLiquid + RealBlur mạnh.

	MỚI Ở v3 (sửa tràn viền + kính chân thực hơn)
	• HẾT TRÀN VIỀN: viền sáng là UIStroke nằm TRONG thân (CanvasGroup cắt đúng góc bo).
	• Vùng mờ nền thật thu vào Inset, lát góc không lòi ra ngoài.
	• Kính: viền nhiều lớp, quầng ngón tay 16 vòng.

	CÁCH DÙNG (API giữ nguyên)
	    local Island = loadstring(game:HttpGet("LINK_RAW_CUA_BAN"))()
	    local island = Island.new({
	        Top = 11, Scale = nil,
	        Style = "Frosted",              -- "Frosted" = kính xám đục Night Hub | "Dark" = kính đen iOS
	        RealBlur = true,                -- hoặc { NearIntensity = 1.15, Inset = 4, Slices = 12, ... }
	        Glass = true,
	        Transparency = nil,             -- nil = theo Style (Frosted ~0.32 đục vừa)
	        AlwaysLiquid = true,            -- true = luôn RenderStepped cho liquid sống (mặc định)
	    })

	    island:Notify({ Title = "Auto Farm", Text = "Đã bật Level Farm",
	        Color = Island.Colors.Green, Duration = 3 })
	    island:SetActivity({ Title = "Auto Farm", Text = "Level Farm • 89%",
	        Color = Island.Colors.Green, Right = "Lv 132", Progress = 0.89,
	        Buttons = {
	            { Text = "Dừng", Style = "destructive", Callback = function() end },
	            { Text = "Tạm dừng", Style = "default", Callback = function() end },
	            { Text = "Thu gọn", Style = "prominent", Callback = function() island:Collapse() end },
	        } })
	    island:UpdateActivity({ Right = "Lv 133", Progress = 0.92 })
	    island:Expand() / :Collapse() / :Toggle() / :ClearActivity()
	    island:Hide() / :Show() / :SetGlass(true|false) / :SetBlur(true|false|{...}) / :SetTop(px) / :SetScale(s) / :Destroy()

	Bấm đảo (có Activity) = mở/thu. Vuốt lên = đóng.
	Icon: Icon = "rbxassetid://..." hoặc Glyph = "A"; không có thì chữ cái đầu Title.
	Demo: getgenv().DynamicIslandDemo = true trước khi load.

	GIỚI HẠN ROBLOX
	• Không có backdrop-blur GUI thật. RealBlur = Part + DepthOfField → chỉ mờ cảnh 3D, cần Quality ≥ 8.
	• UICorner không phải continuous squircle. DepthOfField có thể lem nhẹ → tăng Inset nếu cần.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")

local Island = {}
Island.__index = Island

----------------------------------------------------------------------
-- Cấu hình chung
----------------------------------------------------------------------
Island.Colors = {
	Blue = Color3.fromRGB(10, 132, 255),
	Green = Color3.fromRGB(48, 209, 88),
	Orange = Color3.fromRGB(255, 159, 10),
	Red = Color3.fromRGB(255, 69, 58),
	Yellow = Color3.fromRGB(255, 214, 10),
	Purple = Color3.fromRGB(191, 90, 242),
	Pink = Color3.fromRGB(255, 55, 95),
	Teal = Color3.fromRGB(64, 200, 224),
	Gray = Color3.fromRGB(142, 142, 147),
}

-- Muốn đổi font: Island.Fonts.Bold = Enum.Font.Montserrat ... (đặt trước khi Island.new)
Island.Fonts = {
	Regular = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

-- Số đo lấy theo iPhone 14 Pro (đơn vị point, UIScale lo phần phóng to/thu nhỏ)
local M = {
	IdleW = 126,
	IdleH = 37,
	MaxCorner = 44,
	BannerW = 371,
	BannerH = 84,
	ExpandedW = 371,
	Margin = 18,
	IconBig = 44,
	IconSmall = 22,
	LeadW = 34, -- vùng icon mỗi bên ở trạng thái compact
}
local HEADER_X = M.Margin + M.IconBig + 12

-- Vị trí/kích thước/độ bo của icon dùng chung cho từng trạng thái (toạ độ trong thân đảo)
local ICON_BIG = { x = M.Margin, y = 20, s = M.IconBig, r = 0.24 }
local ICON_SMALL = { x = 12, y = (M.IdleH - M.IconSmall) / 2, s = M.IconSmall, r = 0.5 }

-- Spring theo kiểu SwiftUI: { response (giây), dampingFraction }
local SPRING_OPEN = { w = { 0.46, 0.70 }, h = { 0.50, 0.74 }, icon = { 0.46, 0.72 } } -- mở: nảy rõ, chiều cao trễ hơn
local SPRING_CLOSE = { w = { 0.40, 0.80 }, h = { 0.42, 0.82 }, icon = { 0.40, 0.84 } } -- thu: gọn, nảy ít

-- Góc xoay của viền sáng theo trạng thái (ánh sáng "trượt" quanh viền khi đảo đổi dạng)
local RIM_ANGLE = { idle = 40, activity = 58, notify = 72, expanded = 100, hidden = 40 }

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
-- Hai phong cách kính. Frosted = kính xám đục Night Hub (nên đi cùng RealBlur), Dark = kính đen iOS
-- Tone Frosted: xám lạnh đục vừa, hơi tối để nền mờ hiện rõ qua kính
local STYLES = {
	Frosted = { base = Color3.fromRGB(38, 42, 48), transparency = 0.22, depthAlpha = 0.055, sheenTop = 0.90 },
	Dark = { base = Color3.fromRGB(22, 24, 28), transparency = 0.08, depthAlpha = 0.09, sheenTop = 0.94 },
}
-- Mờ nền thật: Part + DepthOfField – chất lượng cao (nhiều lát, blur mạnh)
local BLUR_DEFAULTS = {
	Transparency = 0.990,
	Distance = nil,
	FocusDistance = nil,
	InFocusRadius = 60, -- vùng nét nhỏ → blur mạnh quanh đảo
	NearIntensity = 1, -- max blur (0..1)
	Slices = 20, -- rất nhiều lát → góc bo mượt, gần continuous
	Inset = 3, -- thu chặt, blur sát viền kính
}
-- Quầng sáng ngón tay: nhiều vòng cực nhạt → radial mượt như liquid
local GLOW_N, GLOW_D, GLOW_A = 24, 200, 0.011
-- Viền kính 8 lớp: mép sắc trắng → mờ dần vào trong (độ dày kính thật)
local EDGE_LAYERS = {
	{ t = 0.6, lo = 0.12, mid = 0.82 },
	{ t = 1.3, lo = 0.28, mid = 0.90 },
	{ t = 2.4, lo = 0.48, mid = 0.94 },
	{ t = 3.8, lo = 0.65, mid = 0.96 },
	{ t = 5.5, lo = 0.78, mid = 0.98 },
	{ t = 7.5, lo = 0.88, mid = 0.99 },
	{ t = 10.0, lo = 0.93, mid = 0.995 },
	{ t = 13.0, lo = 0.97, mid = 1.00 },
}
-- Chiều sâu kính: nhiều lớp mỏng chồng → giữa tối, mép sáng mờ (frosted dày)
local DEPTH_N, DEPTH_STEP = 16, 1.15

----------------------------------------------------------------------
-- Spring (tích phân semi-implicit Euler, chia bước nhỏ để ổn định)
----------------------------------------------------------------------
local Spring = {}
Spring.__index = Spring

function Spring.new(value, response, damping, eps)
	local s = setmetatable({ p = value, v = 0, t = value, eps = eps or 0.05 }, Spring)
	s:SetParams(response, damping)
	return s
end

function Spring:SetParams(response, damping)
	self.k = (2 * math.pi / response) ^ 2
	self.c = 4 * math.pi * damping / response
end

function Spring:Step(dt)
	-- Substep ~400Hz equivalent để spring mượt, không rung khi FPS thấp
	local steps = math.clamp(math.ceil(dt / (1 / 400)), 1, 24)
	local h = dt / steps
	for _ = 1, steps do
		local a = -self.k * (self.p - self.t) - self.c * self.v
		self.v = self.v + a * h
		self.p = self.p + self.v * h
	end
	return self.p
end

function Spring:Settled()
	return math.abs(self.p - self.t) < self.eps and math.abs(self.v) < self.eps * 10
end

function Spring:Snap(value)
	self.p, self.t, self.v = value, value, 0
end

----------------------------------------------------------------------
-- Tiện ích
----------------------------------------------------------------------
local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function numSeq(points)
	local kps = {}
	for i, p in ipairs(points) do
		kps[i] = NumberSequenceKeypoint.new(p[1], p[2])
	end
	return NumberSequence.new(kps)
end

local function addGradient(parent, rotation, points, color)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = numSeq(points)
	if color then
		g.Color = ColorSequence.new(color)
	end
	g.Parent = parent
	return g
end

local function assetUrl(v)
	if typeof(v) == "number" then
		return "rbxassetid://" .. tostring(v)
	end
	if type(v) == "string" and v:match("^%d+$") then
		return "rbxassetid://" .. v
	end
	return v
end

local function firstChar(s)
	if type(s) ~= "string" or s == "" then
		return "•"
	end
	local ok, ch = pcall(function()
		return utf8.char(utf8.codepoint(s, 1))
	end)
	return ok and ch:upper() or "•"
end

local function textWidth(text, size, font)
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100)).X
	end)
	if ok and v then
		return v
	end
	return #text * size * 0.58
end

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(800, 400)
end

local function mount(gui)
	local ok = pcall(function()
		if typeof(gethui) == "function" then
			gui.Parent = gethui()
		else
			error("no gethui")
		end
	end)
	if ok and gui.Parent then
		return
	end
	ok = pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
	if ok and gui.Parent then
		return
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function newLabel(parent, font, size, color, transparency)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextTransparency = transparency or 0
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = ""
	l.Parent = parent
	return l
end

-- Đổi chữ kiểu content transition của iOS: chữ mới trượt lên + hiện dần
local function rollText(label, text, basePos, baseTrans)
	if label.Text == text then
		return
	end
	local first = (label.Text == "")
	label.Text = text
	if first then
		label.Position = basePos
		label.TextTransparency = baseTrans
		return
	end
	label.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale, basePos.Y.Offset + 8)
	label.TextTransparency = 1
	tween(label, 0.42, { Position = basePos, TextTransparency = baseTrans }, Enum.EasingStyle.Quint)
end

----------------------------------------------------------------------
-- Icon dùng chung (một icon duy nhất, spring giữa các trạng thái)
----------------------------------------------------------------------
local function newIcon(parent)
	local group = mk("CanvasGroup", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundColor3 = Island.Colors.Blue,
		GroupTransparency = 1,
		ZIndex = 4,
	}, parent)
	local corner = mk("UICorner", { CornerRadius = UDim.new(0.24, 0) }, group)
	local scale = mk("UIScale", { Scale = 1 }, group)
	local img = mk("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, group)
	local glyph = mk("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Font = Island.Fonts.Bold,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = "",
	}, group)
	return { group = group, corner = corner, scale = scale, img = img, glyph = glyph }
end

local function setIcon(icon, spec, fallbackText)
	spec = spec or {}
	icon.group.BackgroundColor3 = spec.Color or Island.Colors.Blue
	if spec.Icon then
		icon.img.Image = assetUrl(spec.Icon)
		icon.img.Visible = true
		icon.glyph.Visible = false
		if spec.Color then
			icon.group.BackgroundTransparency = 0
			icon.img.Size = UDim2.fromScale(0.62, 0.62)
			icon.img.Position = UDim2.fromScale(0.19, 0.19)
		else
			icon.group.BackgroundTransparency = 1
			icon.img.Size = UDim2.fromScale(1, 1)
			icon.img.Position = UDim2.fromScale(0, 0)
		end
	else
		icon.group.BackgroundTransparency = 0
		icon.img.Visible = false
		icon.glyph.Visible = true
		icon.glyph.Text = spec.Glyph or firstChar(fallbackText)
	end
end

----------------------------------------------------------------------
-- Layer (lớp nội dung) và part (tầng nội dung để stagger)
----------------------------------------------------------------------
local function newLayer(parent, name)
	local group = mk("CanvasGroup", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 2,
	}, parent)
	local scale = mk("UIScale", { Scale = 0.9 }, group)
	local content = mk("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, group)
	return { group = group, scale = scale, content = content, w = 0, h = 0, parts = {} }
end

-- Layer luôn bám mép trên của đảo; scale quanh tâm của chính layer
local function setLayerSize(layer, w, h)
	layer.w, layer.h = w, h
	layer.group.Size = UDim2.fromOffset(w, h)
	layer.group.Position = UDim2.new(0.5, 0, 0, h / 2)
end

local function newPart(parent)
	local group = mk("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, parent)
	local scale = mk("UIScale", { Scale = 0.9 }, group)
	return { group = group, scale = scale }
end

-- Các tầng nội dung hiện lần lượt: trượt lên + scale + fade, tầng sau trễ hơn một nhịp
local function revealParts(layer, animate, token, isAlive)
	for i, part in ipairs(layer.parts) do
		if animate then
			part.group.GroupTransparency = 1
			part.scale.Scale = 0.9 - 0.025 * (i - 1)
			part.group.Position = UDim2.new(0.5, 0, 0.5, 7)
			task.delay(0.03 + (i - 1) * 0.09, function()
				if not isAlive(token) or not part.group.Parent then
					return
				end
				tween(part.group, 0.32, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
				tween(part.group, 0.55, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
				tween(part.scale, 0.6, { Scale = 1 }, Enum.EasingStyle.Quint)
			end)
		else
			part.group.GroupTransparency = 0
			part.scale.Scale = 1
			part.group.Position = UDim2.fromScale(0.5, 0.5)
		end
	end
end

local function buildHeader(parent, y)
	local title = newLabel(parent, Island.Fonts.Bold, 15, WHITE, 0)
	title.Position = UDim2.fromOffset(HEADER_X, y + 1)
	title.Size = UDim2.fromOffset(100, 20)
	local text = newLabel(parent, Island.Fonts.Regular, 13, WHITE, 0.42)
	text.Position = UDim2.fromOffset(HEADER_X, y + 23)
	text.Size = UDim2.fromOffset(100, 18)
	return { title = title, text = text, titlePos = title.Position, textPos = text.Position }
end

local function newButton(parent, spec, accent, size, position)
	local style = spec.Style or "default"
	local btn = mk("TextButton", {
		AutoButtonColor = false,
		Selectable = false,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Font = Island.Fonts.Bold,
		TextSize = 15,
		Text = spec.Text or "OK",
		ZIndex = 3,
	}, parent)
	if style == "prominent" then
		btn.BackgroundColor3 = spec.Color or accent
		btn.BackgroundTransparency = 0
		btn.TextColor3 = WHITE
	elseif style == "destructive" then
		btn.BackgroundColor3 = WHITE
		btn.BackgroundTransparency = 0.9
		btn.TextColor3 = Island.Colors.Red
	else
		btn.BackgroundColor3 = WHITE
		btn.BackgroundTransparency = 0.9
		btn.TextColor3 = WHITE
	end

	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, btn)
	-- Viền kính mảnh quanh nút
	local stroke = mk("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0 }, btn)
	addGradient(stroke, 90, { { 0, 0.78 }, { 0.5, 0.95 }, { 1, 0.9 } })
	-- Vệt sáng nửa trên của nút
	local shine = mk("Frame", {
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Active = false,
	}, btn)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	addGradient(shine, 90, { { 0, 0.88 }, { 0.55, 1 }, { 1, 1 } })

	local scale = mk("UIScale", { Scale = 1 }, btn)
	btn.InputBegan:Connect(function(input)
		if isPointer(input) then
			tween(scale, 0.12, { Scale = 0.94 }, Enum.EasingStyle.Quad)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if isPointer(input) then
			tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	btn.Activated:Connect(function()
		if spec.Callback then
			task.spawn(pcall, spec.Callback)
		end
	end)
	return btn
end

----------------------------------------------------------------------
-- Dựng UI
----------------------------------------------------------------------
function Island.new(config)
	config = config or {}
	local self = setmetatable({}, Island)

	local styleName = config.Style == "Dark" and "Dark" or "Frosted"
	local style = STYLES[styleName]
	self._style = style

	self._cfg = {
		Style = styleName,
		RealBlur = config.RealBlur ~= false and (config.RealBlur or true) or false,
		Top = config.Top or 11,
		Scale = config.Scale, -- nil = tự co theo màn hình
		Intro = config.Intro ~= false,
		OnTap = config.OnTap,
		Glass = config.Glass ~= false,
		Transparency = config.Transparency or style.transparency,
		AlwaysLiquid = config.AlwaysLiquid ~= false, -- mặc định luôn liquid loop
	}
	self._glass = self._cfg.Glass
	self._conns = {}
	self._queue = {}
	self._layers = {}
	self._glassItems = {}
	self._shown = nil
	self._layerToken = 0
	self._iconToken = 0
	self._iconOn = false
	self._iconSig = nil
	self._lastState = nil
	self._activity = nil
	self._expanded = false
	self._hidden = false
	self._notify = nil
	self._destroyed = false
	self._expSig = nil
	self._activityW = M.IdleW + M.LeadW * 2
	self._expW, self._expH = M.ExpandedW, M.BannerH
	self._liquidT = 0 -- thời gian tích luỹ cho liquid breathing / rim drift

	self:_build()
	self:_connect()
	self:_render(false)
	self:_blurInit()
	self:_startLiquidLoop() -- luôn chạy nếu AlwaysLiquid
	return self
end

function Island:_autoScale()
	if self._cfg.Scale then
		return self._cfg.Scale
	end
	return math.clamp(viewport().Y / 430, 0.82, 1.1)
end

function Island:_maxWidth()
	local vx = viewport().X
	return math.max(M.IdleW, math.min(M.ExpandedW, vx / self._scale.Scale - 24))
end

function Island:_build()
	local glass = self._glass

	local gui = Instance.new("ScreenGui")
	gui.Name = "DynamicIsland"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)
	mount(gui)
	self._gui = gui

	local holder = mk("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, self._cfg.Top),
		Size = UDim2.fromOffset(0, 0),
	}, gui)
	self._holder = holder
	self._scale = mk("UIScale", { Scale = self:_autoScale() }, holder)

	-- Shell: khung kích thước đảo (không cắt), chứa thân (viền sáng nằm trong thân)
	local shell = mk("Frame", {
		Name = "Shell",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, holder)
	self._shell = shell
	self._pressScale = mk("UIScale", { Scale = 1 }, shell)

	-- Vùng bấm rộng hơn đảo 8px mỗi phía cho dễ chạm (nằm dưới thân nên nút bên trong vẫn ăn input trước)
	self._hit = mk("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 16, 1, 16),
		ZIndex = 0,
	}, shell)

	-- Thân đảo: CanvasGroup để nội dung bị cắt đúng theo góc bo
	local body = mk("CanvasGroup", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = glass and self._style.base or BLACK,
		BackgroundTransparency = glass and self._cfg.Transparency or 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, shell)
	self._body = body
	self._bodyCorner = mk("UICorner", {}, body)

	local function glassItem(obj)
		obj.Visible = glass
		table.insert(self._glassItems, obj)
		return obj
	end

	-- Bỏ lớp sheen/specular phản chiếu: tránh vệt sáng bị lệch khi phóng to.

	-- 2) Màu activity hắt lên kính (từ phía icon)
	self._tint = glassItem(mk("Frame", {
		Name = "Tint",
		BackgroundColor3 = Island.Colors.Blue,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, body))
	addGradient(self._tint, 0, { { 0, 0.78 }, { 0.5, 0.95 }, { 1, 1 } })

	-- 3) Quầng sáng chạy theo ngón tay (xấp xỉ radial bằng các vòng tròn chồng nhau)
	local glow = glassItem(mk("CanvasGroup", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(170, 170),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 1,
	}, body))
	-- 16 vòng tròn rất nhạt chồng nhau -> chuyển mờ mượt như radial gradient (trước chỉ 4 vòng nên lộ vành đồng tâm)
	for i = 1, GLOW_N do
		local d = GLOW_D * (1 - 0.94 * (i - 1) / GLOW_N)
		local circle = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(d, d),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1 - GLOW_A,
			BorderSizePixel = 0,
		}, glow)
		mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, circle)
	end
	self._glow = glow

	-- Không tạo lớp specular/reflection; giữ tint, glow, depth và viền kính.

	-- 4) Chiều sâu kính: lặp N frame đen nhạt thu dần vào trong -> giữa tối, mép sáng mờ (frosted)
	self._depth = {}
	for i = 1, DEPTH_N do
		local f = mk("Frame", {
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 1 - self._style.depthAlpha,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * i * DEPTH_STEP, 1, -2 * i * DEPTH_STEP),
			ZIndex = 0,
			Visible = glass,
		}, body)
		local c = mk("UICorner", {}, f)
		table.insert(self._depth, { frame = f, corner = c, inset = i * DEPTH_STEP })
	end

	-- 6) Vệt sáng quét ngang khi đổi trạng thái
	self._glint = glassItem(mk("Frame", {
		Name = "Glint",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, body))
	self._glintGrad = addGradient(self._glint, 20, { { 0, 1 }, { 0.4, 1 }, { 0.5, 0.82 }, { 0.6, 1 }, { 1, 1 } })
	self._glintGrad.Offset = Vector2.new(-1, 0)
	self._glint.Visible = false -- tắt vệt phản chiếu quét ngang

	-- Viền kính (rim light): chồng nhiều UIStroke bám mép và dày vào trong -> sắc ở mép, mờ dần vào trong như độ dày của kính.
	-- Nằm TRONG body (CanvasGroup) nên bị cắt đúng đường bo, không thể tràn ra ngoài.
	self._edges = {}
	for i, L in ipairs(EDGE_LAYERS) do
		local f = mk("Frame", {
			Name = "Edge" .. i,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * L.t, 1, -2 * L.t),
			ZIndex = 5,
			Visible = glass,
		}, body)
		local c = mk("UICorner", {}, f)
		local s = mk("UIStroke", { Color = WHITE, Thickness = L.t, Transparency = 0 }, f)
		local near = L.lo + (L.mid - L.lo) * 0.8
		local g = addGradient(s, RIM_ANGLE.idle, { { 0, L.lo }, { 0.2, near }, { 0.5, L.mid }, { 0.8, near }, { 1, L.lo } })
		table.insert(self._edges, { frame = f, corner = c, stroke = s, grad = g, t = L.t })
	end

	-- Layer Activity (compact): chỉ còn chữ bên phải (icon là icon dùng chung)
	local act = newLayer(body, "Activity")
	self._layers.Activity = act
	act.right = newLabel(act.content, Island.Fonts.Bold, 14, WHITE, 0)
	act.right.AnchorPoint = Vector2.new(1, 0.5)
	act.right.TextXAlignment = Enum.TextXAlignment.Right
	act.right.Position = UDim2.new(1, -14, 0.5, 0)

	-- Layer Notify (banner)
	local nt = newLayer(body, "Notify")
	self._layers.Notify = nt
	nt.header = buildHeader(nt.content, 20)

	-- Layer Expanded (dựng lại khi cấu trúc đổi, xem _syncExpanded)
	self._layers.Expanded = newLayer(body, "Expanded")

	-- Icon dùng chung
	self._icon = newIcon(body)

	-- Springs: w, h (thân), ix/iy/is/ir (icon), oy (kéo dọc)
	local w0, h0 = M.IdleW, M.IdleH
	if self._cfg.Intro then
		w0, h0 = 26, 16 -- nhỏ rồi nảy ra cho đúng chất iOS
	end
	self._sp = {
		w = Spring.new(w0, SPRING_OPEN.w[1], SPRING_OPEN.w[2]),
		h = Spring.new(h0, SPRING_OPEN.h[1], SPRING_OPEN.h[2]),
		ix = Spring.new(ICON_SMALL.x + ICON_SMALL.s / 2, SPRING_OPEN.icon[1], SPRING_OPEN.icon[2]),
		iy = Spring.new(ICON_SMALL.y + ICON_SMALL.s / 2, SPRING_OPEN.icon[1], SPRING_OPEN.icon[2]),
		is = Spring.new(ICON_SMALL.s, SPRING_OPEN.icon[1], SPRING_OPEN.icon[2]),
		ir = Spring.new(ICON_SMALL.r, SPRING_OPEN.icon[1], SPRING_OPEN.icon[2], 0.0005),
		oy = Spring.new(0, 0.28, 0.82),
	}
	self._springs = { self._sp.w, self._sp.h, self._sp.ix, self._sp.iy, self._sp.is, self._sp.ir, self._sp.oy }
	self._tw, self._th = w0, h0
	self:_apply()
end

-- Đẩy giá trị spring lên GUI (gọi mỗi khung hình khi đang animation)
function Island:_apply()
	local sp = self._sp
	local w = math.max(sp.w.p, 1)
	local h = math.max(sp.h.p, 1)
	local r = math.min(h / 2, M.MaxCorner)
	self._r = r

	self._shell.Size = UDim2.fromOffset(w, h)
	self._shell.Position = UDim2.fromOffset(0, sp.oy.p)
	self._bodyCorner.CornerRadius = UDim.new(0, r)

	local k = math.clamp(h / 16, 0, 1) -- viền mỏng dần khi đảo thu về 0
	-- Viền kính: mỗi lớp là UIStroke dày VÀO TRONG thân (khung thụt t, stroke dày t nằm ngoài khung thụt = đúng mép thân)
	for _, e in ipairs(self._edges) do
		local t = math.min(e.t * k, h / 2 - 0.5, w / 2 - 0.5)
		local on = self._glass and t > 0.2
		e.frame.Visible = on
		if on then
			e.frame.Size = UDim2.new(1, -2 * t, 1, -2 * t)
			e.corner.CornerRadius = UDim.new(0, math.max(r - t, 0))
			e.stroke.Thickness = t
		end
	end
	for _, d in ipairs(self._depth) do
		local fits = self._glass and (h - 2 * d.inset) > 2 and (w - 2 * d.inset) > 2
		d.frame.Visible = fits
		if fits then
			d.corner.CornerRadius = UDim.new(0, math.max(r - d.inset, 0))
		end
	end

	local ic = self._icon
	local s = math.max(sp.is.p, 1)
	ic.group.Position = UDim2.fromOffset(sp.ix.p, sp.iy.p)
	ic.group.Size = UDim2.fromOffset(s, s)
	ic.corner.CornerRadius = UDim.new(math.clamp(sp.ir.p, 0, 0.5), 0)
	ic.glyph.TextSize = math.max(4, math.floor(s * 0.52))
end

----------------------------------------------------------------------
-- Cử chỉ: bấm, nhấn giữ co lại, kéo (dây cao su), vuốt lên để đóng
----------------------------------------------------------------------
function Island:_glowAt(px)
	if not self._glass then
		return
	end
	local body = self._body
	local size = body.AbsoluteSize.X
	if size <= 0 then
		return
	end
	local frac = math.clamp((px - body.AbsolutePosition.X) / size, 0, 1)
	self._glow.Position = UDim2.fromOffset(frac * self._sp.w.p, self._sp.h.p * 0.35)
end

function Island:_glowShow(on)
	if not self._glass then
		return
	end
	tween(self._glow, on and 0.18 or 0.45, { GroupTransparency = on and 0.15 or 1 }, Enum.EasingStyle.Quad)
end

function Island:_connect()
	table.insert(
		self._conns,
		self._hit.InputBegan:Connect(function(input)
			if not isPointer(input) then
				return
			end
			self._press = { input = input, pos = input.Position }
			tween(self._pressScale, 0.16, { Scale = 0.955 }, Enum.EasingStyle.Quad)
			self:_glowAt(input.Position.X)
			self:_glowShow(true)
		end)
	)

	-- Kéo: lên thì bám tay, xuống thì giãn như dây cao su
	table.insert(
		self._conns,
		UserInputService.InputChanged:Connect(function(input)
			local p = self._press
			if not p then
				return
			end
			local isMouse = p.input.UserInputType == Enum.UserInputType.MouseButton1
			if isMouse then
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
			elseif input ~= p.input then
				return
			end
			local dy = input.Position.Y - p.pos.Y
			local oy
			if dy < 0 then
				oy = math.max(dy * 0.6, -48)
			else
				oy = 14 * (1 - math.exp(-dy / 60))
			end
			self._sp.oy.t = oy
			self:_glowAt(input.Position.X)
			self:_startLoop()
		end)
	)

	table.insert(
		self._conns,
		UserInputService.InputEnded:Connect(function(input)
			local p = self._press
			if not p then
				return
			end
			local isMouse = p.input.UserInputType == Enum.UserInputType.MouseButton1
			local same = (isMouse and input.UserInputType == Enum.UserInputType.MouseButton1)
				or (not isMouse and input == p.input)
			if not same then
				return
			end
			self._press = nil
			tween(self._pressScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			self:_glowShow(false)
			self._sp.oy.t = 0
			self:_startLoop()
			local d = input.Position - p.pos
			if d.Y < -16 and math.abs(d.Y) > math.abs(d.X) then
				self:_onSwipeUp()
			elseif d.Magnitude < 14 then
				self:_onTap()
			end
		end)
	)

	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			table.insert(
				self._conns,
				cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					if self._destroyed then
						return
					end
					self._scale.Scale = self:_autoScale()
					self._expSig = nil
					self:_render(false)
				end)
			)
		end
	end)
end

function Island:_onTap()
	if self._notify then
		local cb = self._notify.Callback
		self:DismissNotification()
		if cb then
			task.spawn(pcall, cb)
		end
	elseif self._activity then
		self:Toggle()
	elseif self._cfg.OnTap then
		task.spawn(pcall, self._cfg.OnTap)
	end
end

function Island:_onSwipeUp()
	if self._notify then
		self:DismissNotification()
	elseif self._expanded then
		self:Collapse()
	end
end

----------------------------------------------------------------------
-- Layer: đổi lớp nội dung (lớp cũ biến mất nhanh, lớp mới vào chậm hơn một nhịp)
----------------------------------------------------------------------
function Island:_alive(token)
	return not self._destroyed and self._layerToken == token
end

function Island:_showLayer(name)
	if self._shown == name then
		return
	end
	self._shown = name
	self._layerToken = self._layerToken + 1
	local token = self._layerToken

	for key, layer in pairs(self._layers) do
		if key ~= name and layer.group.Visible then
			tween(layer.group, 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
			tween(layer.scale, 0.2, { Scale = 0.9 }, Enum.EasingStyle.Quad)
			task.delay(0.24, function()
				if not self._destroyed and self._shown ~= key then
					layer.group.Visible = false
				end
			end)
		end
	end

	if name then
		local layer = self._layers[name]
		task.delay(0.08, function()
			if not self:_alive(token) then
				return
			end
			layer.scale.Scale = 0.9
			layer.group.GroupTransparency = 1
			revealParts(layer, true, token, function(t)
				return self:_alive(t)
			end)
			layer.group.Visible = true
			tween(layer.group, 0.3, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
			tween(layer.scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Quint)
		end)
	end
end

----------------------------------------------------------------------
-- Icon dùng chung: hiện/ẩn, pop khi đổi nội dung
----------------------------------------------------------------------
function Island:_setIconVisible(on, instant)
	if self._iconOn == on and not instant then
		return
	end
	self._iconOn = on
	self._iconToken = self._iconToken + 1
	local token = self._iconToken
	local group = self._icon.group
	if instant then
		group.GroupTransparency = on and 0 or 1
		return
	end
	if on then
		task.delay(0.1, function()
			if self._destroyed or self._iconToken ~= token then
				return
			end
			tween(group, 0.3, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
		end)
	else
		tween(group, 0.15, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
	end
end

function Island:_syncIcon(spec)
	if not spec then
		return
	end
	local sig = table.concat({
		tostring(spec.Icon),
		tostring(spec.Color),
		tostring(spec.Glyph),
		tostring(spec.Title),
	}, "|")
	setIcon(self._icon, spec, spec.Title)
	if sig ~= self._iconSig then
		local hadIcon = self._iconSig ~= nil
		self._iconSig = sig
		if hadIcon and self._iconOn then
			self._icon.scale.Scale = 0.72
			tween(self._icon.scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
end

----------------------------------------------------------------------
-- Đồng bộ nội dung các layer
----------------------------------------------------------------------
function Island:_syncActivity()
	local a = self._activity
	if not a then
		return
	end
	local layer = self._layers.Activity
	local right = a.Right or ""
	layer.right.TextColor3 = a.RightColor or a.Color or WHITE
	local rw = right ~= "" and math.ceil(textWidth(right, 14, Island.Fonts.Bold)) + 18 or 0
	-- Đối xứng quanh tâm như đảo thật: hai bên rộng bằng nhau
	local side = math.max(M.LeadW, rw)
	local w = math.min(M.IdleW + side * 2, self:_maxWidth())
	self._activityW = w
	setLayerSize(layer, w, M.IdleH)
	layer.right.Size = UDim2.fromOffset(math.max(10, rw - 4), 18)
	rollText(layer.right, right, UDim2.new(1, -14, 0.5, 0), 0)
end

function Island:_syncExpanded()
	local a = self._activity
	if not a then
		return
	end
	local layer = self._layers.Expanded
	local ew = math.min(M.ExpandedW, self:_maxWidth())
	local hasProgress = a.Progress ~= nil
	local buttons = (a.Buttons and #a.Buttons > 0) and a.Buttons or nil
	local sig = table.concat({ tostring(ew), tostring(hasProgress), tostring(buttons and #buttons or 0) }, "|")

	if sig ~= self._expSig then
		self._expSig = sig
		layer.content:ClearAllChildren()
		local c = layer.content

		-- Tầng 1: header (tiêu đề, mô tả, giá trị bên phải)
		local head = newPart(c)
		layer.header = buildHeader(head.group, 20)
		layer.right = newLabel(head.group, Island.Fonts.Bold, 17, WHITE, 0)
		layer.right.AnchorPoint = Vector2.new(1, 0.5)
		layer.right.TextXAlignment = Enum.TextXAlignment.Right

		-- Tầng 2: progress + nút bấm
		local foot = newPart(c)
		local y = 20 + M.IconBig
		layer.fill = nil
		if hasProgress then
			y = y + 14
			local track = mk("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.82,
				Position = UDim2.fromOffset(M.Margin, y),
				Size = UDim2.fromOffset(ew - M.Margin * 2, 6),
			}, foot.group)
			mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
			local fill = mk("Frame", {
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0, 1),
			}, track)
			mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
			-- Thanh tiến trình bóng kính: sáng ở đầu, đậm dần
			addGradient(fill, 0, { { 0, 0.18 }, { 1, 0 } })
			layer.fill = fill
			y = y + 6
		end
		if buttons then
			y = y + 14
			local n = #buttons
			local gap = 10
			local bw = (ew - M.Margin * 2 - gap * (n - 1)) / n
			for i, spec in ipairs(buttons) do
				newButton(
					foot.group,
					spec,
					a.Color or Island.Colors.Blue,
					UDim2.fromOffset(bw, 40),
					UDim2.fromOffset(M.Margin + (i - 1) * (bw + gap), y)
				)
			end
			y = y + 40
		end
		layer.parts = { head, foot }
		self._expW, self._expH = ew, y + 20
		setLayerSize(layer, ew, self._expH)

		-- Layer đang hiện mà phải dựng lại thì cho hiện luôn, không bắt animate lại từ đầu
		if self._shown == "Expanded" and layer.group.Visible then
			revealParts(layer, false)
		end
	end

	local right = a.Right or ""
	local rw = right ~= "" and math.ceil(textWidth(right, 17, Island.Fonts.Bold)) + 4 or 0
	local rightPos = UDim2.new(0, ew - M.Margin, 0, 42)
	layer.right.Size = UDim2.fromOffset(math.max(rw, 1), 22)
	layer.right.TextColor3 = a.RightColor or a.Color or WHITE
	rollText(layer.right, right, rightPos, 0)

	local tw = math.max(20, ew - HEADER_X - M.Margin - (rw > 0 and rw + 10 or 0))
	layer.header.title.Size = UDim2.fromOffset(tw, 20)
	layer.header.text.Size = UDim2.fromOffset(tw, 18)
	rollText(layer.header.title, a.Title or "Activity", layer.header.titlePos, 0)
	rollText(layer.header.text, a.Text or "", layer.header.textPos, 0.42)

	if layer.fill then
		layer.fill.BackgroundColor3 = a.Color or Island.Colors.Blue
		local p = math.clamp(a.Progress or 0, 0, 1)
		tween(layer.fill, 0.5, { Size = UDim2.fromScale(p, 1) }, Enum.EasingStyle.Quint)
	end
end

function Island:_fillNotify(o)
	local layer = self._layers.Notify
	local w = math.min(o.Width or M.BannerW, self:_maxWidth())
	setLayerSize(layer, w, M.BannerH)
	local tw = math.max(20, w - HEADER_X - M.Margin)
	layer.header.title.Size = UDim2.fromOffset(tw, 20)
	layer.header.text.Size = UDim2.fromOffset(tw, 18)
	layer.header.title.Text = o.Title or ""
	layer.header.text.Text = o.Text or ""
end

----------------------------------------------------------------------
-- Máy trạng thái + render
----------------------------------------------------------------------
function Island:_state()
	if self._hidden then
		return "hidden"
	end
	if self._notify then
		return "notify"
	end
	if self._activity and self._expanded then
		return "expanded"
	end
	if self._activity then
		return "activity"
	end
	return "idle"
end

-- Vệt sáng quét + xoay viền sáng mỗi khi đổi trạng thái
function Island:_glassTransition(state)
	if not self._glass then
		return
	end
	self._glintGrad.Offset = Vector2.new(-1, 0)
	self._glint.Visible = false -- tắt vệt phản chiếu quét ngang
	tween(self._glintGrad, 0.95, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local ang = RIM_ANGLE[state] or 40
	for _, e in ipairs(self._edges) do
		tween(e.grad, 0.9, { Rotation = ang }, Enum.EasingStyle.Quint)
	end
end

function Island:_render(instant)
	if self._destroyed then
		return
	end
	local state = self:_state()
	local w, h, layerName = M.IdleW, M.IdleH, nil
	local spec, icon = nil, nil

	if state == "hidden" then
		w, h = 0, 0
	elseif state == "notify" then
		local layer = self._layers.Notify
		w, h, layerName = layer.w, M.BannerH, "Notify"
		spec, icon = self._notify, ICON_BIG
	elseif state == "expanded" then
		self:_syncExpanded()
		w, h, layerName = self._expW, self._expH, "Expanded"
		spec, icon = self._activity, ICON_BIG
	elseif state == "activity" then
		self:_syncActivity()
		w, h, layerName = self._activityW, M.IdleH, "Activity"
		spec, icon = self._activity, ICON_SMALL
	end

	if state ~= "hidden" then
		self._gui.Enabled = true
	end

	local sp = self._sp
	local grow = (w * h) > (self._tw * self._th)
	local preset = grow and SPRING_OPEN or SPRING_CLOSE
	sp.w:SetParams(preset.w[1], preset.w[2])
	sp.h:SetParams(preset.h[1], preset.h[2])
	for _, key in ipairs({ "ix", "iy", "is", "ir" }) do
		sp[key]:SetParams(preset.icon[1], preset.icon[2])
	end
	sp.w.t, sp.h.t = w, h
	self._tw, self._th = w, h

	-- Icon dùng chung: đang ẩn thì đặt sẵn đúng chỗ rồi mới hiện; đang hiện thì bay bằng spring
	if icon then
		local tx, ty = icon.x + icon.s / 2, icon.y + icon.s / 2
		if not self._iconOn then
			sp.ix:Snap(tx)
			sp.iy:Snap(ty)
			sp.is:Snap(icon.s)
			sp.ir:Snap(icon.r)
			self:_syncIcon(spec)
			self:_setIconVisible(true, instant)
		else
			sp.ix.t, sp.iy.t, sp.is.t, sp.ir.t = tx, ty, icon.s, icon.r
			self:_syncIcon(spec)
		end
	else
		self:_setIconVisible(false, instant)
	end

	-- Ánh màu activity hắt lên kính
	if self._glass then
		local accent = spec and spec.Color
		if accent then
			tween(self._tint, 0.5, { BackgroundColor3 = accent, BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
		else
			tween(self._tint, 0.4, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		end
	end

	if instant then
		for _, s in ipairs(self._springs) do
			s:Snap(s.t)
		end
		self:_apply()
	end

	if self._lastState ~= state then
		if self._lastState ~= nil then
			self:_glassTransition(state)
		end
		self._lastState = state
	end

	self:_showLayer(layerName)
	self:_startLoop()
end

function Island:_startLoop()
	-- Khi AlwaysLiquid đã chạy liquid loop thì không cần loop riêng;
	-- chỉ đánh dấu cần spring step (liquid loop sẽ xử lý).
	if self._cfg.AlwaysLiquid and self._liquidLoop then
		self._needSpring = true
		return
	end
	if self._loop or self._destroyed then
		return
	end
	self._loop = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		local settled = true
		for _, s in ipairs(self._springs) do
			s:Step(dt)
			if not s:Settled() then
				settled = false
			end
		end
		self:_apply()
		if settled then
			for _, s in ipairs(self._springs) do
				s:Snap(s.t)
			end
			self:_apply()
			self._loop:Disconnect()
			self._loop = nil
			if self._hidden then
				self._gui.Enabled = false
			end
		end
	end)
end

-- Liquid loop liên tục: breathing + rim drift + depth pulse (tận dụng tối đa RenderStepped)
function Island:_startLiquidLoop()
	if not self._cfg.AlwaysLiquid or self._liquidLoop or self._destroyed then
		return
	end
	self._needSpring = true
	self._liquidLoop = RunService.RenderStepped:Connect(function(dt)
		if self._destroyed then
			return
		end
		dt = math.min(dt, 1 / 20)
		self._liquidT = self._liquidT + dt

		-- Spring step khi đang animate hoặc vừa đổi state
		local settled = true
		if self._needSpring then
			for _, s in ipairs(self._springs) do
				s:Step(dt)
				if not s:Settled() then
					settled = false
				end
			end
			if settled then
				for _, s in ipairs(self._springs) do
					s:Snap(s.t)
				end
				self._needSpring = false
				if self._hidden then
					self._gui.Enabled = false
				end
			end
		end

		self:_applyLiquid(dt)
		self:_apply()
	end)
end

function Island:_applyLiquid(dt)
	if not self._glass or self._hidden then
		return
	end
	local t = self._liquidT

	-- Breathing nhẹ thân kính (~0.5%)
	local breath = 1 + 0.0045 * math.sin(t * 1.05) + 0.0015 * math.sin(t * 2.3 + 0.4)
	if self._pressScale and not self._press then
		local cur = self._pressScale.Scale
		if math.abs(cur - 1) < 0.025 then
			self._pressScale.Scale = breath
		end
	end

	-- Rim light trôi mượt quanh viền (nhiều tần số → liquid không đều)
	local baseAng = RIM_ANGLE[self._lastState or "idle"] or 40
	local drift = 18 * math.sin(t * 0.48)
		+ 9 * math.sin(t * 0.95 + 0.6)
		+ 4 * math.sin(t * 1.7 + 1.2)
	local ang = baseAng + drift
	for i, e in ipairs(self._edges) do
		if e.grad then
			-- mỗi lớp lệch nhẹ → cảm giác độ dày kính
			e.grad.Rotation = ang + (i - 1) * 2.5
		end
	end

	-- Edge stroke transparency breathing (mép sáng sống)
	local edgePulse = 0.04 * (0.5 + 0.5 * math.sin(t * 1.25))
	for i, e in ipairs(self._edges) do
		if e.stroke and e.frame and e.frame.Visible then
			local L = EDGE_LAYERS[i]
			if L then
				-- chỉ điều chỉnh nhẹ, giữ gradient chính
				e.stroke.Transparency = math.clamp(edgePulse * (i / #self._edges), 0, 0.15)
			end
		end
	end

	-- Depth layers pulse (chiều sâu kính sống, lớp trong pulse mạnh hơn)
	local depthPulse = 0.018 * (0.5 + 0.5 * math.sin(t * 0.85))
		+ 0.008 * (0.5 + 0.5 * math.sin(t * 1.6 + 0.3))
	for i, d in ipairs(self._depth) do
		if d.frame and d.frame.Visible then
			local base = 1 - self._style.depthAlpha
			local factor = 1 - (i - 1) / math.max(DEPTH_N, 1)
			d.frame.BackgroundTransparency = math.clamp(
				base - depthPulse * factor,
				0.82,
				0.995
			)
		end
	end

	-- Tint soft pulse khi có accent (ánh màu hắt lên kính)
	if self._tint and self._tint.BackgroundTransparency < 0.95 then
		local a = 0.03 + 0.035 * math.sin(t * 1.35) + 0.015 * math.sin(t * 2.1 + 0.8)
		self._tint.BackgroundTransparency = math.clamp(a, 0, 0.12)
	end

	-- Body base transparency micro-breath (kính “thở”)
	if self._body and self._glass then
		local baseT = self._cfg.Transparency or self._style.transparency
		local micro = 0.012 * math.sin(t * 0.7)
		self._body.BackgroundTransparency = math.clamp(baseT + micro, 0.05, 0.55)
	end
end

----------------------------------------------------------------------
-- Mờ nền thật (RealBlur): Part vật liệu Glass gần như vô hình đặt sát camera + DepthOfField trong Lighting.
-- Part được ghép từ 1 khối giữa + vài lát dọc mỗi bên để xấp xỉ góc bo, và bám theo đảo mỗi khung hình.
-- Giới hạn: chỉ làm mờ cảnh 3D (không mờ ScreenGui khác), cần đồ hoạ >= 8, không dùng chung DepthOfField khác,
-- Gui trong không gian 3D (Billboard/SurfaceGui) bị ẩn. Nếu không chạy được, đảo vẫn là kính xám mờ đục.
----------------------------------------------------------------------
local function graphicsOk()
	local ok, v = pcall(function()
		return settings().Rendering.QualityLevel.Value
	end)
	if not ok or type(v) ~= "number" then
		return true
	end
	return v == 0 or v >= 8
end

function Island:_blurInit()
	local opt = self._cfg.RealBlur
	if not opt or self._dof then
		return
	end
	local b = {}
	for k, v in pairs(BLUR_DEFAULTS) do
		b[k] = v
	end
	if type(opt) == "table" then
		for k, v in pairs(opt) do
			b[k] = v
		end
	end
	self._blurCfg = b
	if not graphicsOk() then
		return
	end

	local ok = pcall(function()
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "DynamicIslandBlur"
		dof.FarIntensity = 0
		dof.NearIntensity = math.clamp(b.NearIntensity or 1, 0, 1)
		dof.InFocusRadius = b.InFocusRadius or 80
		dof.FocusDistance = 0.4
		dof.Enabled = false
		dof.Parent = Lighting
		self._dof = dof

		local folder = Instance.new("Folder")
		folder.Name = "DynamicIslandBlurParts"
		self._blurFolder = folder
		self._blurParts = {}
		for i = 1, b.Slices * 2 + 1 do
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic -- không phản chiếu mặt trời / môi trường
			part.Reflectance = 0
			part.Color = Color3.fromRGB(185, 190, 200)
			part.Transparency = math.clamp(b.Transparency, 0.975, 0.995)
			part.Size = Vector3.new(0.01, 0.01, 0.005)
			part.Parent = folder
			self._blurParts[i] = { part = part, cf = CFrame.new() }
		end
	end)
	if not ok then
		self:_blurCleanup()
		return
	end

	self._blurOn = false
	self._blurKey = nil
	self._blurName = "DynamicIslandBlur" .. tostring(math.random(1, 1000000))
	local function step()
		self:_blurStep()
	end
	local bound = pcall(function()
		RunService:BindToRenderStep(self._blurName, Enum.RenderPriority.Camera.Value + 1, step)
	end)
	if bound then
		self._blurBound = true
	else
		self._blurConn = RunService.RenderStepped:Connect(step)
	end
end

function Island:_blurSetActive(on)
	if self._blurOn == on or not self._dof then
		return
	end
	self._blurOn = on
	self._dof.Enabled = on
	if not on then
		self._blurFolder.Parent = nil
		self._blurKey = nil
	end
end

function Island:_blurStep()
	if self._destroyed or not self._dof then
		return
	end
	local cam = workspace.CurrentCamera
	local body = self._body
	local as = body.AbsoluteSize
	local want = cam ~= nil and self._glass and not self._hidden and self._gui.Enabled and as.X > 4 and as.Y > 4
	if not want then
		self:_blurSetActive(false)
		return
	end
	self:_blurSetActive(true)
	if self._blurFolder.Parent ~= cam then
		self._blurFolder.Parent = cam
	end

	local b = self._blurCfg
	local ap, V, fov = body.AbsolutePosition, cam.ViewportSize, cam.FieldOfView
	local okz, z = pcall(function()
		return cam.NearPlaneZ
	end)
	local near = (okz and type(z) == "number") and math.abs(z) or 0.1
	local d = b.Distance or math.max(0.2, near * 2)
	local focus = b.FocusDistance or d * 2.2
	if self._dofFocus ~= focus then
		self._dofFocus = focus
		self._dof.FocusDistance = focus
	end
	-- đồng bộ NearIntensity (có thể chỉnh runtime qua SetBlur)
	local ni = math.clamp(b.NearIntensity or 1, 0, 1)
	if self._dof.NearIntensity ~= ni then
		self._dof.NearIntensity = ni
	end

	-- Lens breathing: cập nhật hình học mỗi frame (organic, multi-frequency)
	-- Inset + reserve giữ mép vùng lens nằm bên trong thân đảo.
	local t = os.clock()
	local pulse = 1.008
		+ 0.010 * (0.5 + 0.5 * math.sin(t * 1.2))
		+ 0.004 * (0.5 + 0.5 * math.sin(t * 2.4 + 0.5))
	local rpx = (self._r or 0) * (as.X / math.max(self._sp.w.p, 1))
	local k = self._blurKey
	local changed = not k
		or k.x ~= ap.X or k.y ~= ap.Y or k.w ~= as.X or k.h ~= as.Y
		or k.r ~= rpx or k.vx ~= V.X or k.vy ~= V.Y or k.fov ~= fov or k.d ~= d
		or not k.pulse or math.abs(k.pulse - pulse) >= 0.0005
	if changed then
		self._blurKey = { x = ap.X, y = ap.Y, w = as.X, h = as.Y, r = rpx, vx = V.X, vy = V.Y, fov = fov, d = d, pulse = pulse }
		local s = (2 * d * math.tan(math.rad(fov) / 2)) / V.Y
		local baseInset = math.min(b.Inset or 0, as.X / 4, as.Y / 4)
		local reserve = math.min(math.min(as.X, as.Y) * 0.035, 10)
		local ins = math.min(baseInset + reserve, as.X / 4, as.Y / 4)
		local baseW, baseH = as.X - 2 * ins, as.Y - 2 * ins
		local w, h = baseW * pulse, baseH * pulse
		local r = math.max(math.min((rpx - ins) * pulse, w / 2, h / 2), 0)
		local K = b.Slices
		local cx, cy = ap.X + as.X / 2, ap.Y + as.Y / 2
		local parts = self._blurParts
		local function place(i, px, py, pw, ph)
			local e = parts[i]
			e.part.Size = Vector3.new(math.max(pw * s, 0.001), math.max(ph * s, 0.001), 0.005)
			e.cf = CFrame.new((px - V.X / 2) * s, -(py - V.Y / 2) * s, -d)
		end
		place(1, cx, cy, w - 2 * r, h)
		for j = 1, K do
			local xc = (j - 0.5) * r / K
			local dx = r - (j - 1) * r / K
			local inset = r - math.sqrt(math.max(r * r - dx * dx, 0))
			local sh = h - 2 * inset
			place(1 + j, cx - w / 2 + xc, cy, r / K + 0.3, sh)
			place(1 + K + j, cx + w / 2 - xc, cy, r / K + 0.3, sh)
		end
	end

	local camCF = cam.CFrame
	if changed or camCF ~= self._blurCamCF then
		self._blurCamCF = camCF
		for _, e in ipairs(self._blurParts) do
			e.part.CFrame = camCF * e.cf
		end
	end
end

function Island:_blurCleanup()
	if self._blurBound then
		self._blurBound = false
		pcall(function()
			RunService:UnbindFromRenderStep(self._blurName)
		end)
	end
	if self._blurConn then
		self._blurConn:Disconnect()
		self._blurConn = nil
	end
	if self._blurFolder then
		self._blurFolder:Destroy()
		self._blurFolder = nil
	end
	if self._dof then
		self._dof:Destroy()
		self._dof = nil
	end
	self._blurParts = nil
	self._blurOn = false
	self._blurKey = nil
end

-- Bật/tắt mờ nền thật khi đang chạy. on = true/false hoặc bảng thông số (xem BLUR_DEFAULTS)
function Island:SetBlur(on)
	self:_blurCleanup()
	self._cfg.RealBlur = on and (on == true and true or on) or false
	if self._cfg.RealBlur then
		self:_blurInit()
	end
end

----------------------------------------------------------------------
-- API công khai
----------------------------------------------------------------------
function Island:SetActivity(data)
	self._activity = {}
	for k, v in pairs(data or {}) do
		self._activity[k] = v
	end
	self._expSig = nil
	self:_render(false)
end

function Island:UpdateActivity(patch)
	if not self._activity then
		self:SetActivity(patch)
		return
	end
	for k, v in pairs(patch or {}) do
		self._activity[k] = v
	end
	self:_render(false)
end

function Island:ClearActivity()
	self._activity = nil
	self._expanded = false
	self._expSig = nil
	self:_render(false)
end

function Island:Expand()
	if self._activity and not self._expanded then
		self._expanded = true
		self:_render(false)
	end
end

function Island:Collapse()
	if self._expanded then
		self._expanded = false
		self:_render(false)
	end
end

function Island:Toggle()
	if self._expanded then
		self:Collapse()
	else
		self:Expand()
	end
end

function Island:Notify(opts)
	if self._destroyed then
		return
	end
	table.insert(self._queue, opts or {})
	if self._pumping then
		return
	end
	self._pumping = true
	task.spawn(function()
		while #self._queue > 0 and not self._destroyed do
			local o = table.remove(self._queue, 1)
			local token = {}
			self._notifyToken = token
			self._notify = o
			self:_fillNotify(o)
			self:_render(false)

			local t0 = os.clock()
			local dur = o.Duration or 3.5
			while os.clock() - t0 < dur and self._notifyToken == token and not self._destroyed do
				task.wait(0.05)
			end
			if self._notifyToken == token then
				self._notifyToken = nil
				self._notify = nil
			end
			self:_render(false)
			task.wait(0.6)
		end
		self._pumping = false
	end)
end

function Island:DismissNotification()
	if self._notify then
		self._notifyToken = nil
		self._notify = nil
		self:_render(false)
	end
end

function Island:Hide()
	self._hidden = true
	self:_render(false)
end

function Island:Show()
	self._hidden = false
	self._gui.Enabled = true
	self:_render(false)
end

-- Bật/tắt chế độ kính khi đang chạy (tắt = đen đặc 100% như iPhone thật)
function Island:SetGlass(on)
	self._glass = on and true or false
	self._cfg.Glass = self._glass
	self._body.BackgroundColor3 = self._glass and self._style.base or BLACK
	self._body.BackgroundTransparency = self._glass and self._cfg.Transparency or 0
	for _, obj in ipairs(self._glassItems) do
		obj.Visible = self._glass
	end
	self:_render(false)
end

function Island:SetTop(px)
	self._cfg.Top = px
	self._holder.Position = UDim2.new(0.5, 0, 0, px)
end

function Island:SetScale(s)
	self._cfg.Scale = s
	self._scale.Scale = self:_autoScale()
	self._expSig = nil
	self:_render(false)
end

function Island:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	if self._liquidLoop then
		self._liquidLoop:Disconnect()
		self._liquidLoop = nil
	end
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self._conns = {}
	self:_blurCleanup()
	if self._gui then
		self._gui:Destroy()
	end
end

----------------------------------------------------------------------
-- Demo: getgenv().DynamicIslandDemo = true
----------------------------------------------------------------------
local okEnv, env = pcall(function()
	return getgenv and getgenv()
end)
if okEnv and env and env.DynamicIslandDemo then
	env.DynamicIslandDemo = nil
	local island = Island.new({
		Style = "Frosted",
		RealBlur = true,
		AlwaysLiquid = true,
	})
	task.spawn(function()
		task.wait(1.0)
		island:Notify({
			Title = "Dynamic Island",
			Text = "Liquid glass Night Hub style sẵn sàng",
			Color = Island.Colors.Blue,
			Duration = 2.8,
		})
		task.wait(4)
		island:SetActivity({
			Title = "Auto Farm",
			Text = "Level Farm • 89%",
			Color = Island.Colors.Green,
			Right = "Lv 132",
			Progress = 0.89,
			Buttons = {
				{ Text = "Dừng", Style = "destructive", Callback = function() island:ClearActivity() end },
				{ Text = "Tạm dừng", Style = "default", Callback = function() end },
				{ Text = "Thu gọn", Style = "prominent", Callback = function() island:Collapse() end },
			},
		})
		task.wait(1.5)
		island:Expand()
		for i = 1, 5 do
			task.wait(0.7)
			local p = math.min(0.89 + i * 0.02, 1)
			island:UpdateActivity({ Progress = p, Right = "Lv " .. (132 + i), Text = "Level Farm • " .. math.floor(p * 100) .. "%" })
		end
		task.wait(1.2)
		island:Collapse()
	end)
end

return Island
