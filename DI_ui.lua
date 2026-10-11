--[[
	DynamicIsland.lua  -  UI kiểu Dynamic Island (iPhone 14 Pro) cho Roblox
	-------------------------------------------------------------------------
	• Viên thuốc đen 126x37, bo tròn hoàn toàn, nằm giữa mép trên màn hình
	• 4 trạng thái: Idle / Activity (compact) / Notify (banner) / Expanded (mở rộng)
	• Chuyển động bằng SPRING VẬT LÝ tự viết (response/damping như SwiftUI),
	  chiều rộng và chiều cao có độ trễ khác nhau + overshoot nhẹ như iOS thật
	• Nội dung đổi lớp bằng fade + scale, bấm nhấn co lại, vuốt lên để đóng
	• Chỉ chạy RenderStepped khi đang animation, đứng yên = 0 chi phí

	CÁCH DÙNG
	    local Island = loadstring(game:HttpGet("LINK_RAW_CUA_BAN"))()
	    -- hoặc: local Island = loadstring(readfile("DynamicIsland.lua"))()

	    local island = Island.new()                     -- có thể truyền { Top = 11, Scale = 1 }

	    island:Notify({                                 -- banner mở ra rồi tự thu lại
	        Title = "Auto Farm", Text = "Đã bật Level Farm",
	        Color = Island.Colors.Green, Duration = 3,
	        Callback = function() print("bấm vào banner") end,
	    })

	    island:SetActivity({                            -- trạng thái compact luôn hiện
	        Title = "Auto Farm", Text = "Level Farm • Bandit",
	        Color = Island.Colors.Green, Right = "Lv 120",
	        Progress = 0.35,
	        Buttons = {
	            { Text = "Dừng", Style = "destructive", Callback = function() end },
	            { Text = "Ẩn",   Style = "default",     Callback = function() island:Collapse() end },
	        },
	    })
	    island:UpdateActivity({ Right = "Lv 121", Progress = 0.6 })  -- cập nhật trực tiếp
	    island:Expand() / island:Collapse() / island:Toggle()
	    island:ClearActivity()
	    island:Hide() / island:Show()
	    island:Destroy()

	Bấm vào đảo (khi có Activity) = mở rộng / thu lại.  Vuốt lên = đóng.
	Icon: Icon = "rbxassetid://123" (hoặc số id) hoặc Glyph = "⚡"; không có thì lấy chữ cái đầu của Title.
	Chạy thử nhanh: getgenv().DynamicIslandDemo = true trước khi load file này.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

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
	LeadW = 34, -- vùng icon bên trái ở trạng thái compact
	MinTrailW = 34, -- vùng chữ bên phải ở trạng thái compact
}

-- Spring theo kiểu SwiftUI: response (giây) + dampingFraction
local SPRING_OPEN = { w = { 0.46, 0.70 }, h = { 0.50, 0.74 } } -- mở rộng: nảy rõ, chiều cao trễ hơn
local SPRING_CLOSE = { w = { 0.40, 0.80 }, h = { 0.42, 0.82 } } -- thu lại: gọn, nảy ít

local WHITE = Color3.new(1, 1, 1)
local BTN_BG = Color3.fromRGB(58, 58, 60)

----------------------------------------------------------------------
-- Spring (tích phân semi-implicit Euler, chia bước nhỏ để ổn định)
----------------------------------------------------------------------
local Spring = {}
Spring.__index = Spring

function Spring.new(value, response, damping)
	local s = setmetatable({ p = value, v = 0, t = value }, Spring)
	s:SetParams(response, damping)
	return s
end

function Spring:SetParams(response, damping)
	self.k = (2 * math.pi / response) ^ 2
	self.c = 4 * math.pi * damping / response
end

function Spring:Step(dt)
	local steps = math.clamp(math.ceil(dt / (1 / 240)), 1, 12)
	local h = dt / steps
	for _ = 1, steps do
		local a = -self.k * (self.p - self.t) - self.c * self.v
		self.v = self.v + a * h
		self.p = self.p + self.v * h
	end
	return self.p
end

function Spring:Settled()
	return math.abs(self.p - self.t) < 0.05 and math.abs(self.v) < 0.5
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

-- Icon: ô bo góc kiểu app icon (squircle xấp xỉ), chứa ảnh hoặc chữ
local function newIcon(parent, size, position, radius)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(size, size)
	frame.Position = position
	frame.BackgroundColor3 = Island.Colors.Blue
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = frame

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Size = UDim2.fromScale(1, 1)
	img.Visible = false
	img.Parent = frame
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(radius, 0)
	imgCorner.Parent = img

	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Island.Fonts.Bold
	glyph.TextSize = math.floor(size * 0.52)
	glyph.TextColor3 = WHITE
	glyph.Text = ""
	glyph.Parent = frame

	return { frame = frame, img = img, glyph = glyph }
end

local function setIcon(icon, spec, fallbackText)
	spec = spec or {}
	icon.frame.BackgroundColor3 = spec.Color or Island.Colors.Blue
	if spec.Icon then
		icon.img.Image = assetUrl(spec.Icon)
		icon.img.Visible = true
		icon.glyph.Visible = false
		if spec.Color then
			icon.frame.BackgroundTransparency = 0
			icon.img.Size = UDim2.fromScale(0.62, 0.62)
			icon.img.Position = UDim2.fromScale(0.19, 0.19)
		else
			icon.frame.BackgroundTransparency = 1
			icon.img.Size = UDim2.fromScale(1, 1)
			icon.img.Position = UDim2.fromScale(0, 0)
		end
	else
		icon.frame.BackgroundTransparency = 0
		icon.img.Visible = false
		icon.glyph.Visible = true
		icon.glyph.Text = spec.Glyph or firstChar(fallbackText)
	end
end

local function newLayer(parent, name)
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Visible = false
	group.ZIndex = 2
	group.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = group

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = group

	return { group = group, scale = scale, content = content, w = 0, h = 0 }
end

-- Layer luôn bám mép trên của đảo; scale quanh tâm của chính layer
local function setLayerSize(layer, w, h)
	layer.w, layer.h = w, h
	layer.group.Size = UDim2.fromOffset(w, h)
	layer.group.Position = UDim2.new(0.5, 0, 0, h / 2)
end

local function buildHeader(parent, width, y)
	local icon = newIcon(parent, M.IconBig, UDim2.fromOffset(M.Margin, y), 0.24)
	local x = M.Margin + M.IconBig + 12
	local tw = math.max(20, width - x - M.Margin)

	local title = newLabel(parent, Island.Fonts.Bold, 15, WHITE, 0)
	title.Position = UDim2.fromOffset(x, y + 1)
	title.Size = UDim2.fromOffset(tw, 20)

	local text = newLabel(parent, Island.Fonts.Regular, 13, WHITE, 0.42)
	text.Position = UDim2.fromOffset(x, y + 23)
	text.Size = UDim2.fromOffset(tw, 18)

	return { icon = icon, title = title, text = text }
end

local function newButton(parent, spec, accent, size, position)
	local style = spec.Style or "default"
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.Selectable = false
	btn.BorderSizePixel = 0
	btn.Size = size
	btn.Position = position
	btn.Font = Island.Fonts.Bold
	btn.TextSize = 15
	btn.Text = spec.Text or "OK"
	btn.ZIndex = 3
	if style == "prominent" then
		btn.BackgroundColor3 = spec.Color or accent
		btn.TextColor3 = WHITE
	elseif style == "destructive" then
		btn.BackgroundColor3 = BTN_BG
		btn.TextColor3 = Island.Colors.Red
	else
		btn.BackgroundColor3 = BTN_BG
		btn.TextColor3 = WHITE
	end
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = btn

	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end
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

	self._cfg = {
		Top = config.Top or 11,
		Scale = config.Scale, -- nil = tự co theo màn hình
		Intro = config.Intro ~= false,
		OnTap = config.OnTap,
	}
	self._conns = {}
	self._queue = {}
	self._layers = {}
	self._shown = nil
	self._layerToken = 0
	self._activity = nil
	self._expanded = false
	self._hidden = false
	self._notify = nil
	self._destroyed = false
	self._expSig = nil
	self._activityW = M.IdleW + M.LeadW + M.MinTrailW
	self._expW, self._expH = M.ExpandedW, M.BannerH

	self:_build()
	self:_connect()
	self:_render(false)
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

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, self._cfg.Top)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = gui
	self._holder = holder

	local scale = Instance.new("UIScale")
	scale.Scale = self:_autoScale()
	scale.Parent = holder
	self._scale = scale

	local island = Instance.new("Frame")
	island.Name = "Island"
	island.AnchorPoint = Vector2.new(0.5, 0)
	island.Position = UDim2.fromOffset(0, 0)
	island.BackgroundColor3 = Color3.new(0, 0, 0)
	island.BorderSizePixel = 0
	island.ClipsDescendants = true
	island.Parent = holder
	self._island = island

	local corner = Instance.new("UICorner")
	corner.Parent = island
	self._corner = corner

	local press = Instance.new("UIScale")
	press.Scale = 1
	press.Parent = island
	self._pressScale = press

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Selectable = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 1
	hit.Parent = island
	self._hit = hit

	-- Layer Activity (compact): icon trái + chữ phải
	local act = newLayer(island, "Activity")
	self._layers.Activity = act
	act.icon = newIcon(act.content, M.IconSmall, UDim2.new(0, 12, 0.5, 0), 0.5)
	act.icon.frame.AnchorPoint = Vector2.new(0, 0.5)
	act.right = newLabel(act.content, Island.Fonts.Bold, 14, WHITE, 0)
	act.right.AnchorPoint = Vector2.new(1, 0.5)
	act.right.TextXAlignment = Enum.TextXAlignment.Right

	-- Layer Notify (banner)
	local nt = newLayer(island, "Notify")
	self._layers.Notify = nt
	nt.header = buildHeader(nt.content, M.BannerW, 20)

	-- Layer Expanded
	local ex = newLayer(island, "Expanded")
	self._layers.Expanded = ex

	-- Trạng thái đầu: nhỏ rồi nảy ra cho đúng chất iOS
	local w0, h0 = M.IdleW, M.IdleH
	if self._cfg.Intro then
		w0, h0 = 26, 16
	end
	self.sw = Spring.new(w0, SPRING_OPEN.w[1], SPRING_OPEN.w[2])
	self.sh = Spring.new(h0, SPRING_OPEN.h[1], SPRING_OPEN.h[2])
	self._tw, self._th = w0, h0
	self:_apply(w0, h0)
end

function Island:_apply(w, h)
	w = math.max(w, 1)
	h = math.max(h, 1)
	self._island.Size = UDim2.fromOffset(w, h)
	self._corner.CornerRadius = UDim.new(0, math.min(h / 2, M.MaxCorner))
end

----------------------------------------------------------------------
-- Cử chỉ: bấm, nhấn giữ co lại, vuốt lên để đóng
----------------------------------------------------------------------
function Island:_connect()
	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	table.insert(
		self._conns,
		self._hit.InputBegan:Connect(function(input)
			if not isPointer(input) then
				return
			end
			self._press = { input = input, pos = input.Position }
			tween(self._pressScale, 0.16, { Scale = 0.955 }, Enum.EasingStyle.Quad)
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
-- Layer: đổi lớp nội dung (fade + scale, lớp mới vào chậm hơn một nhịp)
----------------------------------------------------------------------
function Island:_showLayer(name)
	if self._shown == name then
		return
	end
	self._shown = name
	self._layerToken = self._layerToken + 1
	local token = self._layerToken

	for key, layer in pairs(self._layers) do
		if key ~= name and layer.group.Visible then
			tween(layer.group, 0.16, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
			tween(layer.scale, 0.22, { Scale = 0.88 }, Enum.EasingStyle.Quad)
			task.delay(0.24, function()
				if not self._destroyed and self._shown ~= key then
					layer.group.Visible = false
				end
			end)
		end
	end

	if name then
		local layer = self._layers[name]
		task.delay(0.07, function()
			if self._destroyed or self._layerToken ~= token then
				return
			end
			layer.scale.Scale = 0.88
			layer.group.GroupTransparency = 1
			layer.group.Visible = true
			tween(layer.group, 0.34, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
			tween(layer.scale, 0.52, { Scale = 1 }, Enum.EasingStyle.Quint)
		end)
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
	setIcon(layer.icon, a, a.Title)
	local right = a.Right or ""
	layer.right.Text = right
	layer.right.TextColor3 = a.RightColor or a.Color or WHITE
	local rw = right ~= "" and math.ceil(textWidth(right, 14, Island.Fonts.Bold)) + 18 or 0
	rw = math.max(M.MinTrailW, rw)
	local w = math.min(M.IdleW + M.LeadW + rw, self:_maxWidth())
	self._activityW = w
	setLayerSize(layer, w, M.IdleH)
	layer.right.Position = UDim2.new(1, -14, 0.5, 0)
	layer.right.Size = UDim2.fromOffset(math.max(10, rw - 4), 18)
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
		layer.header = buildHeader(c, ew, 20)
		local y = 20 + M.IconBig
		layer.fill = nil
		if hasProgress then
			y = y + 14
			local track = Instance.new("Frame")
			track.BorderSizePixel = 0
			track.BackgroundColor3 = WHITE
			track.BackgroundTransparency = 0.82
			track.Position = UDim2.fromOffset(M.Margin, y)
			track.Size = UDim2.fromOffset(ew - M.Margin * 2, 6)
			track.Parent = c
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(0.5, 0)
			tc.Parent = track
			local fill = Instance.new("Frame")
			fill.BorderSizePixel = 0
			fill.Size = UDim2.fromScale(0, 1)
			fill.Parent = track
			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(0.5, 0)
			fc.Parent = fill
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
					c,
					spec,
					a.Color or Island.Colors.Blue,
					UDim2.fromOffset(bw, 40),
					UDim2.fromOffset(M.Margin + (i - 1) * (bw + gap), y)
				)
			end
			y = y + 40
		end
		self._expW, self._expH = ew, y + 20
		setLayerSize(layer, ew, self._expH)
	end

	setIcon(layer.header.icon, a, a.Title)
	layer.header.title.Text = a.Title or "Activity"
	layer.header.text.Text = a.Text or ""
	if layer.fill then
		layer.fill.BackgroundColor3 = a.Color or Island.Colors.Blue
		local p = math.clamp(a.Progress or 0, 0, 1)
		tween(layer.fill, 0.4, { Size = UDim2.fromScale(p, 1) }, Enum.EasingStyle.Quint)
	end
end

function Island:_fillNotify(o)
	local layer = self._layers.Notify
	local w = math.min(o.Width or M.BannerW, self:_maxWidth())
	if layer.w ~= w then
		layer.content:ClearAllChildren()
		layer.header = buildHeader(layer.content, w, 20)
	end
	setLayerSize(layer, w, M.BannerH)
	setIcon(layer.header.icon, o, o.Title)
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

function Island:_render(instant)
	if self._destroyed then
		return
	end
	local state = self:_state()
	local w, h, layerName = M.IdleW, M.IdleH, nil

	if state == "hidden" then
		w, h = 0, 0
	elseif state == "notify" then
		local layer = self._layers.Notify
		w, h, layerName = layer.w, M.BannerH, "Notify"
	elseif state == "expanded" then
		self:_syncExpanded()
		w, h, layerName = self._expW, self._expH, "Expanded"
	elseif state == "activity" then
		self:_syncActivity()
		w, h, layerName = self._activityW, M.IdleH, "Activity"
	end

	if state ~= "hidden" then
		self._gui.Enabled = true
	end

	local grow = (w * h) > (self._tw * self._th)
	local preset = grow and SPRING_OPEN or SPRING_CLOSE
	self.sw:SetParams(preset.w[1], preset.w[2])
	self.sh:SetParams(preset.h[1], preset.h[2])
	self.sw.t, self.sh.t = w, h
	self._tw, self._th = w, h

	if instant then
		self.sw.p, self.sw.v, self.sh.p, self.sh.v = w, 0, h, 0
		self:_apply(w, h)
	end
	self:_showLayer(layerName)
	self:_startLoop()
end

function Island:_startLoop()
	if self._loop or self._destroyed then
		return
	end
	self._loop = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		local w = self.sw:Step(dt)
		local h = self.sh:Step(dt)
		self:_apply(w, h)
		if self.sw:Settled() and self.sh:Settled() then
			self.sw.p, self.sw.v, self.sh.p, self.sh.v = self.sw.t, 0, self.sh.t, 0
			self:_apply(self.sw.p, self.sh.p)
			self._loop:Disconnect()
			self._loop = nil
			if self._hidden then
				self._gui.Enabled = false
			end
		end
	end)
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
	self:_syncActivity()
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
	self:_syncActivity()
	if self._expanded then
		self:_syncExpanded()
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

function Island:SetTop(px)
	self._cfg.Top = px
	self._holder.Position = UDim2.new(0.5, 0, 0, px)
end

function Island:SetScale(s)
	self._cfg.Scale = s
	self._scale.Scale = self:_autoScale()
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
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self._conns = {}
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
	local island = Island.new()
	task.spawn(function()
		task.wait(1.2)
		island:Notify({
			Title = "Dynamic Island",
			Text = "Thông báo đẹp như iOS",
			Color = Island.Colors.Blue,
			Duration = 3,
		})
		task.wait(5)
		island:SetActivity({
			Title = "Auto Farm",
			Text = "Level Farm • Bandit",
			Color = Island.Colors.Green,
			Right = "Lv 120",
			Progress = 0.25,
			Buttons = {
				{ Text = "Dừng", Style = "destructive", Callback = function() island:ClearActivity() end },
				{ Text = "Thu gọn", Callback = function() island:Collapse() end },
			},
		})
		task.wait(2)
		island:Expand()
		for i = 1, 6 do
			task.wait(0.8)
			island:UpdateActivity({ Progress = 0.25 + i * 0.12, Right = "Lv " .. (120 + i) })
		end
		task.wait(1)
		island:Collapse()
	end)
end

return Island
