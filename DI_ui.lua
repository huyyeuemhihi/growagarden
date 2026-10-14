--[[
	DynamicIsland.lua v6.0 — Dynamic Island (iPhone 14 Pro) + Engine LIQUID GLASS 100% chuẩn
	boatbomber / boatbeaker (GlassmorphicUI 1.0.0 & boatbomber.com/blog/liquid-glass)
	-----------------------------------------------------------------------------------------
	ĐIỂM MỚI Ở v6.0 (Tái cấu trúc 100% theo đúng kiến trúc & toán học của GlassmorphicUI):
	1. Một ảnh EditableImage (GlassPane) hợp nhất duy nhất cho toàn bộ 5 giai đoạn:
	   Bake Geometry -> Sample Screen -> Reco[span_117](start_span)[span_117](end_span)nstruct (Catmull-Rom 4x4 + Chromatic Aberration)
	   -> Frost Blur (Two-Leve[span_15](start_span)[span_15](end_span)[span_18](start_span)[span_18](end_span)l Fractional Mix + Premultiplied Alpha) -> Rim Lighting (Fresnel + Glare).
	2. Hình học Siêu Elip (SuperEllipseFactor = 3, miền 2..7) kết hợp Họ Đường Đồng Mức Tan Chảy
	   (Blended/Melted Contour Family): bán kính góc R(d) và số mũ siêu elip n(d) biến thiên
	   mượt từ biên vào tâm, xóa bỏ hoàn toàn nếp gấp chéo 90 độ ở góc (corner diagonal crease).
	3. Đóng băng hình học (Geometry Baking) và lưu cache dùng chung cho các cửa sổ cùng hình dạng:
	   lưu sẵn byte mặt nạ alpha, vector dịch chuyển khúc xạ (dispX, dispY) đã tái tỷ lệ hồ sơ
	   biến dạng (distortion profile rescaling) theo định luật Snell, và độ sáng viền (Fresnel + Glare).
	4. Tán sắc (Chromatic Aberration) đúng chuẩn README GlassmorphicUI: nhân vector dịch chuyển với
	   (1 + s) cho kênh Đỏ, 1.0 cho Xanh lá, (1 - s) cho Xanh dương; tự động gộp còn 1 lần đọc
	   Catmull-Rom 16-tap ở vùng nội tâm phẳng (disp == 0) hoặc khi tắt tán sắc.
	5. Lấy mẫu màn hình (Screen Sampler) trên lưới thô ~1/5 độ phân giải có Biến Dạng Mật Độ
	   (Density Warp) tập trung ô lấy mẫu vào đúng dải đáp khúc xạ viền trong (inner rim hot zone):
	   • Duyệt cây giao diện 2D (BasePlayerGui:GetGuiObjectsAtPosition) từ trước ra sau: lấy màu
	     Frame, TextLabel/TextButton, ImageLabel/ImageButton và hỗ trợ kính chồng kính (glass-over-glass).
	   • Bắn tia 3D (ViewportPointToRay / ScreenPointToRay) vào workspace có chiếu sáng mặt trời,
	     màu vật liệu Terrain/Water, sương mù Lighting (Fog/Atmosphere) và màu bầu trời.
	   • Làm mới cuốn chiếu (Rolling Refresh) trong ngân sách 5 ms/frame và tự động chuyển sang
	     trạng thái nghỉ ("idle") khi cảnh nền hội tụ (changedCells == 0).
	6. Frost Blur chuẩn: nội suy tuyến tính giữa 2 mức bán kính nguyên kề nhau (Two-Level Mix) để
	   tránh nhảy bậc (popping); bảo vệ biên trong suốt bằng màu Tint cửa sổ + Premultiplied Alpha.
	7. Chiếu sáng viền cộng SAU Frost Blur: Fresnel lũy thừa bậc 5 (d^5) + Glare hai vệt đối xứng
	   cực theo góc GlareAngle (-50 độ), điều chỉnh vệt đối diện bằng GlareOppositeSide (50%)
	   và độ hội tụ bằng GlareConvergence (90).
	8. Tích hợp đầy đủ API chuẩn của thư viện GlassmorphicUI (Island.GlassmorphicUI):
	   new(), addGlassBackground(), applyGlassToImageLabel(), forceUpdate(), pauseUpdates(),
	   resumeUpdates(), setDefaultBlurRadius(), getDebugStats() + hỗ trợ CollectionService tag "GlassmorphicUI".
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local Island = {}
Island.__index = Island

----------------------------------------------------------------------
-- Cấu hình chung Dynamic Island
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

Island.Fonts = {
	Regular = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

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
	LeadW = 34,
}
local HEADER_X = M.Margin + M.IconBig + 12

local ICON_BIG = { x = M.Margin, y = 20, s = M.IconBig, r = 0.24 }
local ICON_SMALL = { x = 12, y = (M.IdleH - M.IconSmall) / 2, s = M.IconSmall, r = 0.5 }

local SPRING_OPEN = { w = { 0.46, 0.70 }, h = { 0.50, 0.74 }, icon = { 0.46, 0.72 } }
local SPRING_CLOSE = { w = { 0.40, 0.80 }, h = { 0.42, 0.82 }, icon = { 0.40, 0.84 } }

-- Góc xoay trục Glare theo từng trạng thái đảo (mặc định chuẩn GlassmorphicUI là -50 độ)
local RIM_ANGLE = { idle = -50, activity = -38, notify = -24, expanded = 15, hidden = -50 }

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local STYLES = {
	Frosted = { base = Color3.fromRGB(66, 64, 68), transparency = 0.82, depthAlpha = 0.035, sheenTop = 0.84 },
	Dark = { base = Color3.fromRGB(30, 32, 38), transparency = 0.65, depthAlpha = 0.07, sheenTop = 0.9 },
}

local BLUR_DEFAULTS = {
	Transparency = 0.985,
	Distance = nil,
	FocusDistance = nil,
	InFocusRadius = 100,
	NearIntensity = 1,
	Slices = 8,
	Inset = 6,
}

local GLOW_N, GLOW_D, GLOW_A = 16, 170, 0.0157
local EDGE_LAYERS = {
	{ t = 1.1, lo = 0.28, mid = 0.90 },
	{ t = 2.6, lo = 0.80, mid = 0.97 },
	{ t = 5, lo = 0.90, mid = 0.99 },
	{ t = 8.5, lo = 0.95, mid = 1 },
}
local DEPTH_N, DEPTH_STEP = 8, 2

----------------------------------------------------------------------
-- Bộ tích phân lò xo (Spring)
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
	return math.abs(self.p - self.t) < self.eps and math.abs(self.v) < self.eps * 10
end

function Spring:Snap(value)
	self.p, self.t, self.v = value, value, 0
end

----------------------------------------------------------------------
-- Tiện ích cơ bản
----------------------------------------------------------------------
local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max
local sin, cos, atan, asin, rad = math.sin, math.cos, math.atan, math.asin, math.rad

local function clampN(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

local function smooth01(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function newArray(n, v)
	if table.create then
		return table.create(n, v)
	end
	local t = {}
	for i = 1, n do
		t[i] = v
	end
	return t
end

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
	local lp = Players.LocalPlayer
	if lp then
		gui.Parent = lp:WaitForChild("PlayerGui")
	end
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
-- Icon, Layer, Part, Button cho Dynamic Island
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
	local stroke = mk("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0 }, btn)
	addGradient(stroke, 90, { { 0, 0.78 }, { 0.5, 0.95 }, { 1, 0.9 } })
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
-- LÕI TOÁN HỌC LIQUID GLASS (100% CHUẨN BOATBOMBER / GLASSMORPHICUI)
----------------------------------------------------------------------
--[[CORE_BEGIN]]

-- Giải quyết giá trị UDim hoặc number theo trục ngắn nhất (minAxis) của cửa sổ
local function resolveUDim(val, minAxis, minVal, maxVal)
	local px
	if typeof(val) == "UDim" then
		px = val.Scale * minAxis + val.Offset
	elseif type(val) == "number" then
		px = val
	else
		px = 0
	end
	return clampN(px, minVal or 0, maxVal or minAxis)
end

-- Hàm khoảng cách có dấu (SDF) cho hình chữ nhật bo góc Siêu Elip (Superellipse)
-- p >= 2 (p = 2 là đường tròn, p = 3..7 là squircle siêu elip)
local function superellipseSDF(dx, dy, hx, hy, r, p)
	local clR = min(r, hx, hy)
	local ex, ey = hx - clR, hy - clR
	local qx, qy = abs(dx) - ex, abs(dy) - ey
	local ax, ay = qx > 0 and qx or 0, qy > 0 and qy or 0
	local dc
	if ax > 0 and ay > 0 then
		if abs(p - 2) < 0.01 then
			dc = sqrt(ax * ax + ay * ay)
		else
			dc = (ax ^ p + ay ^ p) ^ (1 / p)
		end
	else
		dc = ax + ay
	end
	local inside = min(max(qx, qy), 0)
	return dc + inside - clR
end

-- Họ đường đồng mức tan chảy (Blended / Melted Contour Family):
-- Tại độ sâu chuẩn hóa t = s / T (0 ở mép, 1 ở biên trong của mặt vát),
-- bán kính góc R(t) mở rộng mượt về phía bán kính nội tâm và số mũ p(t) giãn mượt về 2.
-- Kết hợp trường điều hòa nội tâm giúp pháp tuyến (nx, ny) liên tục C1, KHÔNG BAO GIỜ có nếp gấp 90 độ ở góc!
local function meltedContourNormal(dx, dy, hx, hy, R0, p0, T, s0)
	local minHalf = min(hx, hy)
	local t = T > 0 and clampN(s0 / T, 0, 1) or 0
	local m = smooth01(t)
	local targetR = min(minHalf, max(R0, R0 + T * 0.85))
	local Rt = R0 + (targetR - R0) * m
	local pt = p0 + (2 - p0) * m

	local ex, ey = max(hx - Rt, 0), max(hy - Rt, 0)
	local ax, ay = abs(dx) - ex, abs(dy) - ey
	local sx = dx < 0 and -1 or (dx > 0 and 1 or 0)
	local sy = dy < 0 and -1 or (dy > 0 and 1 or 0)

	local gx, gy
	if ax > 0 and ay > 0 then
		-- Vùng góc siêu elip tan chảy: đạo hàm giải tích của (ax^pt + ay^pt)^(1/pt)
		gx = sx * (ax ^ (pt - 1))
		gy = sy * (ay ^ (pt - 1))
	else
		-- Để tránh đạo hàm đảo hướng đột ngột 90 độ khi ax <= 0 hoặc ay <= 0 (nguyên nhân tạo nếp gấp),
		-- ta pha trộn mượt giữa khoảng cách cạnh và trường elip điều hòa từ tâm.
		local soft = max(Rt, T, 4) * 0.35
		local wx = math.exp(ax / soft)
		local wy = math.exp(ay / soft)
		gx = sx * (wx + 0.15 * abs(dx) / max(hx, 1))
		gy = sy * (wy + 0.15 * abs(dy) / max(hy, 1))
	end

	local len = sqrt(gx * gx + gy * gy)
	if len > 1e-6 then
		return gx / len, gy / len
	end
	return 0, -1
end

-- Bảng độ lệch khúc xạ theo định luật Snell có TÁI TỶ LỆ HỒ SƠ BIẾN DẠNG (Distortion Profile Rescaling):
-- Giữ toàn bộ điểm đáp nằm gọn trong cửa sổ kính mà không cần kẹp cứng (hard clamping) gây bệt mép.
local function buildSnellProfile(T, ior, minAxis, N)
	local D = newArray(N + 1, 0)
	if T <= 0 or ior <= 1.0001 then
		return D
	end
	local rawMax = 0
	for k = 0, N do
		local u = k / N
		local x = u < (0.25 / N) and (0.25 / N) or u
		local om = 1 - x
		local p4 = om * om * om * om
		-- Mặt vát lồi trơn: độ cao z(u) và độ dốc dz/du tắt mượt về 0 tại u = 1
		local z = (1 - p4) ^ 0.25
		local dz = om * om * om * ((1 - p4) ^ -0.75)
		local th1 = atan(dz)
		local sin2 = clampN(sin(th1) / ior, -0.9999, 0.9999)
		local th2 = asin(sin2)
		-- Độ lệch tia sau khi đi qua bề dày kính
		local disp = (T * (0.65 * z + 0.35)) * math.tan(th1 - th2) * (1 - u * u)
		D[k + 1] = disp
		if disp > rawMax then
			rawMax = disp
		end
	end
	-- Tái tỷ lệ đồng đều (Distortion Profile Rescaling) để điểm lấy mẫu không vượt khỏi biên đối diện
	local strength = (ior - 1) / 3 -- chuẩn hóa trên miền ior 1..4
	local targetMax = min(T * (0.45 + 0.95 * strength), minAxis * 0.42)
	if rawMax > 1e-5 then
		local desired = targetMax / rawMax
		local scale = min(desired, (minAxis * 0.44) / rawMax)
		for k = 1, N + 1 do
			D[k] = D[k] * scale
		end
	end
	return D
end

local function evalProfile(D, N, u)
	local f = clampN(u, 0, 1) * N
	local k = floor(f)
	if k >= N then
		return D[N + 1]
	end
	local t = f - k
	return D[k + 1] + (D[k + 2] - D[k + 1]) * t
end

-- GIAI ĐOẠN 1: ĐÓNG BĂNG HÌNH HỌC (BAKE THE GEOMETRY)
-- Tính trước trên từng điểm ảnh đầu ra (LW x LH):
--   • maskA[idx]   : byte alpha khử răng cưa (0..255) của hình siêu elip
--   • dispX[idx]   : độ dịch chuyển khúc xạ trục X (đơn vị px cửa sổ)
--   • dispY[idx]   : độ dịch chuyển khúc xạ trục Y (đơn vị px cửa sổ)
--   • rimLight[idx]: độ sáng viền (Fresnel bậc 5 + Glare 2 phía đối xứng cực) cộng SAU khi làm mờ Frost
local function bakeGeometry(G, step)
	local W, H, LW, LH = G.W, G.H, G.LW, G.LH
	local R0 = clampN(G.CornerRadius, 0, min(W, H) / 2)
	local p0 = clampN(G.SuperEllipseFactor or 3, 2, 7)
	local T = clampN(G.Thickness, 0, min(W, H) / 2)
	local ior = clampN(G.RefractionFactor or 2.1, 1, 4)

	local Fs = clampN(G.FresnelSize or 0, 0, min(W, H) / 2)
	local Fi = clampN((G.FresnelIntensity or 25) / 100, 0, 1)
	local Fh = clampN((G.FresnelHardness or 40) / 100, 0, 1)
	-- Fresnel sử dụng đường dốc lũy thừa bậc 5 (5th-power ramp) theo đúng bài blog
	local Fexp = 5 * (0.45 + 1.1 * Fh)

	local Gs = clampN(G.GlareSize or 0, 0, min(W, H) / 2)
	local Gi = clampN((G.GlareIntensity or 70) / 100, 0, 1.2)
	local Gh = clampN((G.GlareHardness or 40) / 100, 0, 1)
	local Gc = clampN((G.GlareConvergence or 90) / 100, 0, 1)
	local Go = clampN((G.GlareOppositeSide or 50) / 100, 0, 1)
	local Gangle = rad(G.GlareAngle or -50)
	local axG, ayG = cos(Gangle), sin(Gangle)
	local GexpRadial = 1 + 4 * Gh
	local GexpAngular = 1 + 14 * Gc * Gc

	local N = LW * LH
	local maskA = newArray(N, 0)
	local dispX = newArray(N, 0)
	local dispY = newArray(N, 0)
	local rimLight = newArray(N, 0)

	local profN = 64
	local snellD = buildSnellProfile(T, ior, min(W, H), profN)
	local hx, hy = W * 0.5, H * 0.5
	local stepX, stepY = W / LW, H / LH
	local aaScale = 1 / max(0.5 * (stepX + stepY), 0.5)
	local maxReach = max(T, Fs, Gs)

	for y = 0, LH - 1 do
		local py = (y + 0.5) * stepY
		local dy = py - hy
		local rowBase = y * LW
		for x = 0, LW - 1 do
			local px = (x + 0.5) * stepX
			local dx = px - hx
			local d = superellipseSDF(dx, dy, hx, hy, R0, p0)
			local cov = clampN(0.5 - d * aaScale, 0, 1)
			if cov > 0 then
				local idx = rowBase + x + 1
				maskA[idx] = floor(cov * 255 + 0.5)
				local s0 = d < 0 and -d or 0
				if s0 < maxReach then
					local nx, ny = meltedContourNormal(dx, dy, hx, hy, R0, p0, max(T, 1), s0)
					-- 1) Vector dịch chuyển khúc xạ (hướng vào nội tâm mặt kính: -nx, -ny)
					if T > 0 and s0 < T and ior > 1.0001 then
						local mag = evalProfile(snellD, profN, s0 / T)
						dispX[idx] = -nx * mag
						dispY[idx] = -ny * mag
					end
					-- 2) Độ sáng viền (Fresnel bậc 5 + Glare 2 phía đối xứng cực)
					local rimVal = 0
					if Fs > 0 and Fi > 0 and s0 < Fs then
						local uF = 1 - s0 / Fs
						rimVal = rimVal + Fi * (uF ^ Fexp)
					end
					if Gs > 0 and Gi > 0 and s0 < Gs then
						local uG = 1 - s0 / Gs
						local align = nx * axG + ny * ayG
						local dirK
						if align >= 0 then
							dirK = align ^ GexpAngular
						else
							dirK = Go * ((-align) ^ GexpAngular)
						end
						rimVal = rimVal + Gi * dirK * (uG ^ GexpRadial)
					end
					if rimVal > 1 then
						rimVal = 1
					end
					rimLight[idx] = rimVal
				end
			end
		end
		if step then
			step()
		end
	end

	return {
		W = W, H = H, LW = LW, LH = LH,
		maskA = maskA, dispX = dispX, dispY = dispY, rimLight = rimLight,
	}
end

-- BIẾN DẠNG MẬT ĐỘ LƯỚI LẤY MẪU (DENSITY WARP):
-- Tập trung mật độ ô lưới vào vùng rìa trong (inner rim landing zone) nơi khúc xạ phóng đại nền.
local PI2 = 2 * math.pi
local function warpCoord01(u, beta)
	if beta <= 0 then
		return u
	end
	return u - beta * sin(PI2 * u) / PI2
end

local function buildWarpLUT(len, gridCount, beta)
	local centers = newArray(gridCount, 0)
	for i = 0, gridCount - 1 do
		centers[i + 1] = len * warpCoord01((i + 0.5) / gridCount, beta)
	end
	local lutSize = ceil(len) + 2
	local lut = newArray(lutSize, 0)
	local k = 1
	for p = 0, lutSize - 1 do
		while k < gridCount - 1 and p >= centers[k + 1] do
			k = k + 1
		end
		local g
		if p <= centers[1] then
			g = 0
		elseif p >= centers[gridCount] then
			g = gridCount - 1
		else
			local span = centers[k + 1] - centers[k]
			g = (k - 1) + (span > 1e-6 and (p - centers[k]) / span or 0)
		end
		lut[p + 1] = g
	end
	return lut, centers
end

local function evalWarpLUT(lut, maxIdx, pos)
	if pos <= 0 then
		return lut[1]
	end
	local p = floor(pos)
	if p >= maxIdx then
		return lut[maxIdx + 1]
	end
	local f = pos - p
	local a = lut[p + 1]
	local b = lut[p + 2] or a
	return a + (b - a) * f
end

-- Nội suy Bicubic Catmull-Rom 4x4 (16 taps)
local function catmullRomWeights(t)
	local t2 = t * t
	local t3 = t2 * t
	return (-t3 + 2 * t2 - t) * 0.5, (3 * t3 - 5 * t2 + 2) * 0.5, (-3 * t3 + 4 * t2 + t) * 0.5, (t3 - t2) * 0.5
end

local function sampleBicubic1(arr, gw, gh, gx, gy)
	gx = clampN(gx, 0, gw - 1)
	gy = clampN(gy, 0, gh - 1)
	local x0, y0 = floor(gx), floor(gy)
	local a0, a1, a2, a3 = catmullRomWeights(gx - x0)
	local b0, b1, b2, b3 = catmullRomWeights(gy - y0)

	local xm = x0 > 0 and (x0 - 1) or 0
	local xp = x0 + 1 < gw and (x0 + 1) or (gw - 1)
	local xq = x0 + 2 < gw and (x0 + 2) or (gw - 1)

	local ym = y0 > 0 and (y0 - 1) or 0
	local yp = y0 + 1 < gh and (y0 + 1) or (gh - 1)
	local yq = y0 + 2 < gh and (y0 + 2) or (gh - 1)

	local o = ym * gw + 1
	local r0 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = y0 * gw + 1
	local r1 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = yp * gw + 1
	local r2 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = yq * gw + 1
	local r3 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3

	return clampN(r0 * b0 + r1 * b1 + r2 * b2 + r3 * b3, 0, 1)
end

-- Box blur 1 trục trượt tổng (sliding sum O(1) mỗi điểm ảnh)
local function boxBlur1D(src, dst, lines, len, rad, stepA, stepB, step)
	if rad < 1 then
		for i = 1, #src do
			dst[i] = src[i]
		end
		return
	end
	local inv = 1 / (2 * rad + 1)
	local last = len - 1
	for line = 0, lines - 1 do
		local base = line * stepB + 1
		local sum = 0
		for k = -rad, rad do
			local idx = k < 0 and 0 or (k > last and last or k)
			sum = sum + src[base + idx * stepA]
		end
		for pos = 0, last do
			dst[base + pos * stepA] = sum * inv
			local addIdx = pos + rad + 1
			if addIdx > last then
				addIdx = last
			end
			local subIdx = pos - rad
			if subIdx < 0 then
				subIdx = 0
			end
			sum = sum + src[base + addIdx * stepA] - src[base + subIdx * stepA]
		end
		if step then
			step()
		end
	end
end

-- Làm mờ 2 lượt tách trục (H + V) cho một mức bán kính nguyên rInt
local function runBlurLevel(R, G, B, A, LW, LH, rInt, step)
	local N = LW * LH
	local oR, oG, oB, oA = newArray(N, 0), newArray(N, 0), newArray(N, 0), newArray(N, 0)
	if rInt < 1 then
		for i = 1, N do
			oR[i], oG[i], oB[i], oA[i] = R[i], G[i], B[i], A[i]
		end
		return oR, oG, oB, oA
	end
	local tmp = newArray(N, 0)
	local r1 = max(1, floor(rInt * 0.65 + 0.5))
	local r2 = max(1, rInt - floor(r1 * 0.5))
	local function blurChannel(src, dst)
		boxBlur1D(src, tmp, LH, LW, r1, 1, LW, step)
		boxBlur1D(tmp, dst, LW, LH, r1, LW, 1, step)
		boxBlur1D(dst, tmp, LH, LW, r2, 1, LW, step)
		boxBlur1D(tmp, dst, LW, LH, r2, LW, 1, step)
	end
	blurChannel(R, oR)
	blurChannel(G, oG)
	blurChannel(B, oB)
	blurChannel(A, oA)
	return oR, oG, oB, oA
end

-- GIAI ĐOẠN 3, 4 & 5: TÁI DỰNG (RECONSTRUCT) + LÀM MỜ FROST HAI MỨC + CHIẾU SÁNG VIỀN (RIM LIGHTING)
-- Xuất ra một buffer RGBA8 duy nhất cho GlassPane
local function reconstructFrostAndLight(job, step)
	local geom = job.geom
	local W, H, LW, LH = geom.W, geom.H, geom.LW, geom.LH
	local N = LW * LH
	local maskA, dispX, dispY, rimLight = geom.maskA, geom.dispX, geom.dispY, geom.rimLight

	local gw, gh = job.gw, job.gh
	local gr, gg, gb = job.gr, job.gg, job.gb
	local lutX, lutY = job.lutX, job.lutY
	local maxLutX, maxLutY = #lutX - 1, #lutY - 1

	local ca = clampN(job.ChromaticAberration or 0.2, 0, 1)
	local tintR, tintG, tintB = job.tintR, job.tintG, job.tintB
	local tintMix = clampN(job.tintMix or 0, 0, 1)
	local paneAlpha = clampN(job.paneAlpha or 1, 0, 1)

	-- Mảng màu Premultiplied Alpha để bảo vệ viền trong suốt không bị lem màu tối vào trong khi Frost Blur
	local pR, pG, pB, pA = newArray(N, 0), newArray(N, 0), newArray(N, 0), newArray(N, 0)
	local stepX, stepY = W / LW, H / LH
	local maxX, maxY = W - 0.5, H - 0.5

	-- Giai đoạn 3: Reconstruct the Output (Tra cứu dịch chuyển + Tán sắc 1±s + Bicubic Catmull-Rom + Tint)
	for y = 0, LH - 1 do
		local py = (y + 0.5) * stepY
		local rowBase = y * LW
		for x = 0, LW - 1 do
			local idx = rowBase + x + 1
			local a8 = maskA[idx]
			if a8 > 0 then
				local px = (x + 0.5) * stepX
				local dx, dy = dispX[idx], dispY[idx]
				local cr, cg, cb
				if (dx == 0 and dy == 0) or ca == 0 then
					-- Vùng phẳng nội tâm hoặc tắt tán sắc: chỉ đọc Catmull-Rom 1 lần duy nhất!
					local sx = clampN(px + dx, 0.5, maxX)
					local sy = clampN(py + dy, 0.5, maxY)
					local u = evalWarpLUT(lutX, maxLutX, sx)
					local v = evalWarpLUT(lutY, maxLutY, sy)
					cr = sampleBicubic1(gr, gw, gh, u, v)
					cg = sampleBicubic1(gg, gw, gh, u, v)
					cb = sampleBicubic1(gb, gw, gh, u, v)
				else
					-- Chuẩn GlassmorphicUI: Đỏ lấy mẫu xa hơn (1 + ca), Xanh dương ngắn hơn (1 - ca) so với Xanh lá
					local scaleR = 1 + ca
					local scaleB = 1 - ca

					local sxR = clampN(px + dx * scaleR, 0.5, maxX)
					local syR = clampN(py + dy * scaleR, 0.5, maxY)
					cr = sampleBicubic1(gr, gw, gh, evalWarpLUT(lutX, maxLutX, sxR), evalWarpLUT(lutY, maxLutY, syR))

					local sxG = clampN(px + dx, 0.5, maxX)
					local syG = clampN(py + dy, 0.5, maxY)
					cg = sampleBicubic1(gg, gw, gh, evalWarpLUT(lutX, maxLutX, sxG), evalWarpLUT(lutY, maxLutY, syG))

					local sxB = clampN(px + dx * scaleB, 0.5, maxX)
					local syB = clampN(py + dy * scaleB, 0.5, maxY)
					cb = sampleBicubic1(gb, gw, gh, evalWarpLUT(lutX, maxLutX, sxB), evalWarpLUT(lutY, maxLutY, syB))
				end

				-- Trộn màu Tint cửa sổ (BackgroundColor3)
				if tintMix > 0 then
					cr = cr + (tintR - cr) * tintMix
					cg = cg + (tintG - cg) * tintMix
					cb = cb + (tintB - cb) * tintMix
				end

				-- Nhân trước với Alpha mặt nạ (Premultiplied Alpha)
				local aNorm = a8 / 255
				pR[idx] = cr * aNorm
				pG[idx] = cg * aNorm
				pB[idx] = cb * aNorm
				pA[idx] = aNorm
			end
		end
		if step then
			step()
		end
	end

	-- Giai đoạn 4: Frost Blur (Gaussian sigma = BlurRadius / 3, Nội suy Hai Mức Nguyên liên tiếp)
	local blurPx = max(job.BlurRadius or 1, 1)
	local sigmaOut = (blurPx / 3) / max(0.5 * (stepX + stepY), 1)
	local fR, fG, fB, fA
	if blurPx <= 1.05 or sigmaOut < 0.35 then
		fR, fG, fB, fA = pR, pG, pB, pA
	else
		local rFloat = clampN(sigmaOut * 1.45, 0, min(LW, LH) * 0.35)
		local rLow = floor(rFloat)
		local rHigh = ceil(rFloat)
		local frac = rFloat - rLow
		local lR, lG, lB, lA = runBlurLevel(pR, pG, pB, pA, LW, LH, rLow, step)
		if rHigh == rLow or frac < 0.02 then
			fR, fG, fB, fA = lR, lG, lB, lA
		else
			local hR, hG, hB, hA = runBlurLevel(pR, pG, pB, pA, LW, LH, rHigh, step)
			fR, fG, fB, fA = lR, lG, lB, lA
			for i = 1, N do
				fR[i] = lR[i] + (hR[i] - lR[i]) * frac
				fG[i] = lG[i] + (hG[i] - lG[i]) * frac
				fB[i] = lB[i] + (hB[i] - lB[i]) * frac
				fA[i] = lA[i] + (hA[i] - lA[i]) * frac
			end
		end
	end

	-- Giai đoạn 5: Khôi phục Premultiplied Alpha + Phủ lớp sáng viền (Fresnel + Glare) + Đóng gói RGBA8
	local buf = buffer.create(N * 4)
	-- Điểm ảnh ngoài mặt nạ (alpha = 0) mang màu tint cửa sổ với alpha = 0 theo đúng bài blog
	local clearR8 = floor(clampN(tintR, 0, 1) * 255 + 0.5)
	local clearG8 = floor(clampN(tintG, 0, 1) * 255 + 0.5)
	local clearB8 = floor(clampN(tintB, 0, 1) * 255 + 0.5)
	local clearU32 = clearR8 + clearG8 * 256 + clearB8 * 65536

	for y = 0, LH - 1 do
		local rowBase = y * LW
		for x = 0, LW - 1 do
			local idx = rowBase + x + 1
			local a8 = maskA[idx]
			if a8 == 0 then
				buffer.writeu32(buf, (idx - 1) * 4, clearU32)
			else
				local wA = fA[idx]
				local cr, cg, cb
				if wA > 1e-4 then
					local invA = 1 / wA
					cr = fR[idx] * invA
					cg = fG[idx] * invA
					cb = fB[idx] * invA
				else
					cr, cg, cb = tintR, tintG, tintB
				end
				-- Cộng ánh sáng viền (Fresnel + Glare) lên trên lớp Frost
				local rim = rimLight[idx]
				if rim > 0 then
					cr = cr + (1 - cr) * rim
					cg = cg + (1 - cg) * rim
					cb = cb + (1 - cb) * rim
				end
				-- Độ đục cuối cùng: viền sáng (Fresnel/Glare) tăng độ đục tại mép kính
				local outA = clampN((a8 / 255) * clampN(paneAlpha + rim * (1 - paneAlpha), 0, 1), 0, 1)
				local r8 = floor(clampN(cr, 0, 1) * 255 + 0.5)
				local g8 = floor(clampN(cg, 0, 1) * 255 + 0.5)
				local b8 = floor(clampN(cb, 0, 1) * 255 + 0.5)
				local alpha8 = floor(outA * 255 + 0.5)
				buffer.writeu32(buf, (idx - 1) * 4, r8 + g8 * 256 + b8 * 65536 + alpha8 * 16777216)
			end
		end
		if step then
			step()
		end
	end

	return buf, LW, LH
end
--[[CORE_END]]

----------------------------------------------------------------------
-- HỆ THỐNG GLASSMORPHICUI & LIQUID ENGINE (QUẢN LÝ CỬA SỐ, CACHE, SAMPLER)
----------------------------------------------------------------------
-- Đúng 17 thuộc tính chuẩn của boatbeaker/GlassmorphicUI 1.0.0 + mở rộng tương thích DynamicIsland
local GLASS_DEFAULTS = {
	Thickness = UDim.new(0.15, 0),       -- UDim hoặc số px (1px..minAxis)
	RefractionFactor = 2.1,              -- 1..4 (1 = tắt khúc xạ)
	ChromaticAberration = 0.2,           -- 0..1 (Đỏ +20%, Xanh dương -20%)
	CornerRadius = UDim.new(0.8, 0),     -- UDim hoặc số px (0..minAxis)
	SuperEllipseFactor = 3,              -- 2..7 (2 = tròn, 3 = squircle mặc định)
	FresnelSize = UDim.new(0.1, 0),      -- UDim hoặc số px
	FresnelHardness = 40,                -- 0..100
	FresnelIntensity = 25,               -- 0..100
	GlareSize = UDim.new(0.2, 0),        -- UDim hoặc số px
	GlareHardness = 40,                  -- 0..100
	GlareIntensity = 70,                 -- 0..120
	GlareConvergence = 90,               -- 0..100
	GlareOppositeSide = 50,              -- 0..100 (cường độ % vệt lóa đối diện)
	GlareAngle = -50,                    -- -180..180 độ
	BlurRadius = UDim.new(0.06, 0),      -- UDim hoặc số px (sigma = BlurRadius / 3)
	Transparency = 0.85,                 -- 0..1 (0 = đặc hoàn toàn, bỏ qua lấy mẫu nền)
	MaxOutputResolution = 1024,          -- 16..1024
	-- Tham số phụ trợ vận hành
	SamplerWarp = 0.45,                  -- Độ nén mật độ lưới ở rìa trong
	SamplingBudget = 5,                  -- 5 ms/frame cho lấy mẫu màn hình (chuẩn blog)
	RenderingBudget = 8,                 -- 8 ms/frame cho tái dựng + frost + rim (chuẩn blog)
	Opacity = 0.94,                      -- Độ đục tổng thể của tấm kính hiển thị
	TintMix = 0.12,                      -- Tỷ lệ pha màu nền cửa sổ vào kính
}

local DEFAULT_BLUR_UDIM = GLASS_DEFAULTS.BlurRadius

-- Bộ đệm (Cache) hình học dùng chung giữa các cửa sổ có cùng hình dạng và thuộc tính
local GEOM_CACHE = {}
local GEOM_CACHE_COUNT = 0
local GEOM_CACHE_MAX = 18

local function getGeometryKey(G)
	return string.format(
		"%d_%d_%d_%d_%.1f_%.2f_%.1f_%.2f_%.1f_%d_%d_%.1f_%d_%d_%d_%d_%.1f",
		G.W, G.H, G.LW, G.LH,
		G.CornerRadius, G.SuperEllipseFactor,
		G.Thickness, G.RefractionFactor,
		G.FresnelSize, G.FresnelHardness, G.FresnelIntensity,
		G.GlareSize, G.GlareHardness, G.GlareIntensity,
		G.GlareConvergence, G.GlareOppositeSide, G.GlareAngle
	)
end

local function evictGeometryCache()
	while GEOM_CACHE_COUNT > GEOM_CACHE_MAX do
		local oldestKey, oldestTime
		for k, entry in pairs(GEOM_CACHE) do
			if not oldestTime or entry.lastUsed < oldestTime then
				oldestKey, oldestTime = k, entry.lastUsed
			end
		end
		if not oldestKey then
			break
		end
		GEOM_CACHE[oldestKey] = nil
		GEOM_CACHE_COUNT = GEOM_CACHE_COUNT - 1
	end
end

-- Đăng ký tất cả các cửa sổ kính đang hoạt động để hỗ trợ "kính chồng lên kính" (glass-over-glass)
local ACTIVE_PANES = {}

local DAY_TOP, DAY_HOR = { 0.36, 0.56, 0.88 }, { 0.74, 0.84, 0.94 }
local NIGHT_TOP, NIGHT_HOR = { 0.02, 0.03, 0.08 }, { 0.07, 0.09, 0.15 }
local SUNSET = { 0.95, 0.50, 0.30 }
local RAY_LEN = 2500

local Liquid = {}
Liquid.__index = Liquid

function Liquid.new(isl, hostGuiObject, opts)
	local P = {}
	for k, v in pairs(GLASS_DEFAULTS) do
		P[k] = v
	end
	P.BlurRadius = DEFAULT_BLUR_UDIM
	if type(opts) == "table" then
		for k, v in pairs(opts) do
			P[k] = v
		end
	end

	local self = setmetatable({}, Liquid)
	self.isl = isl
	self.body = hostGuiObject
	self.P = P
	self.shape = { w = 0, h = 0, r = 0 }
	self.shapeKey = ""
	self.lastChange = os.clock()
	self.enabled = true
	self.paused = false
	self.firstRenderDone = false
	self.failed = false
	self.destroyed = false
	self.scaleCap = 1 -- Tự động giảm một nửa nếu EditableImage hết bộ nhớ
	self.framesSinceReconstruct = 0
	self.samplesReceived = 0
	self.executionPath = "idle"
	self.attrConns = {}

	-- Lớp hiển thị duy nhất: GlassPane (chứa toàn bộ khúc xạ + frost + fresnel + glare + mặt nạ siêu elip)
	self.pane = mk("ImageLabel", {
		Name = "GlassPane",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		ScaleType = Enum.ScaleType.Stretch,
	}, hostGuiObject)

	-- Kiểm tra khả năng tạo EditableImage của client hiện tại
	local probe = self:_newImage(2, 2)
	local okShow = probe ~= nil and self:_show(self.pane, probe)
	if probe then
		pcall(function()
			probe:Destroy()
		end)
	end
	pcall(function()
		self.pane.ImageContent = Content.none
	end)
	if not okShow then
		self.pane:Destroy()
		error("EditableImage/Content.fromObject không khả dụng trên thiết bị này")
	end

	self:_bindAttributes()
	ACTIVE_PANES[self] = true
	return self
end

-- Đồng bộ các thuộc tính Roblox Attribute trên GuiObject theo đúng chuẩn GlassmorphicUI
function Liquid:_bindAttributes()
	local host = self.body
	if not host then
		return
	end
	local attrNames = {
		"Thickness", "RefractionFactor", "ChromaticAberration",
		"CornerRadius", "SuperEllipseFactor",
		"FresnelSize", "FresnelHardness", "FresnelIntensity",
		"GlareSize", "GlareHardness", "GlareIntensity",
		"GlareConvergence", "GlareOppositeSide", "GlareAngle",
		"BlurRadius", "Transparency", "MaxOutputResolution",
	}
	local function readAttr(name)
		local val = host:GetAttribute(name)
		if val == nil then
			return
		end
		local def = GLASS_DEFAULTS[name]
		if name == "Transparency" or name == "MaxOutputResolution" or type(def) == "number" then
			if type(val) == "number" then
				self.P[name] = val
				self.geomDirty = true
				self.reconstructDirty = true
			end
		elseif typeof(def) == "UDim" then
			if typeof(val) == "UDim" or type(val) == "number" then
				self.P[name] = val
				self.geomDirty = true
				self.reconstructDirty = true
			end
		end
	end
	for _, name in ipairs(attrNames) do
		readAttr(name)
		table.insert(self.attrConns, host:GetAttributeChangedSignal(name):Connect(function()
			readAttr(name)
		end))
	end
	table.insert(self.attrConns, host:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		self.reconstructDirty = true
	end))
end

function Liquid:_newImage(w, h)
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	end)
	if ok and img then
		return img
	end
	return nil
end

function Liquid:_show(label, img)
	return (pcall(function()
		label.ImageContent = Content.fromObject(img)
	end))
end

function Liquid:_write(img, w, h, buf)
	return (pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	end))
end

function Liquid:_fail(reason)
	if self.failed or self.destroyed then
		return
	end
	self.failed = true
	ACTIVE_PANES[self] = nil
	warn("[DynamicIsland] Liquid glass tắt, chuyển về kính cổ điển: " .. tostring(reason))
	if self.isl and self.isl._lgFailed then
		self.isl:_lgFailed()
	end
end

function Liquid:_newJob(fn)
	local job = { deadline = 0 }
	local function step()
		if os.clock() >= job.deadline then
			coroutine.yield()
		end
	end
	job.co = coroutine.create(function()
		return fn(step)
	end)
	return job
end

function Liquid:_resume(job, deadline)
	job.deadline = deadline
	local ok, a, b, c = coroutine.resume(job.co)
	if not ok then
		self:_fail(a)
		return true
	end
	if coroutine.status(job.co) == "dead" then
		return true, a, b, c
	end
	return false
end

-- Giải quyết thông số hình học & độ phân giải đầu ra từ kích thước hiện tại
function Liquid:_resolveSpec()
	local sh = self.shape
	local W = max(floor(sh.w + 0.5), 4)
	local H = max(floor(sh.h + 0.5), 4)
	local minAxis = min(W, H)
	local maxAxis = max(W, H)
	local P = self.P

	local maxRes = clampN(floor(P.MaxOutputResolution or 1024), 16, 1024)
	-- Giữ mật độ điểm ảnh sắc nét cho mặt kính nhưng tôn trọng MaxOutputResolution và bộ nhớ
	local budgetPixels = 16000 * self.scaleCap
	local dsArea = sqrt((W * H) / max(budgetPixels, 256))
	local dsMax = maxAxis / maxRes
	local ds = max(1, dsArea, dsMax)
	local LW = clampN(ceil(W / ds), 4, maxRes)
	local LH = clampN(ceil(H / ds), 4, maxRes)

	local cornerR = sh.r > 0 and sh.r or resolveUDim(P.CornerRadius, minAxis, 0, minAxis * 0.5)
	local thickness = resolveUDim(P.Thickness, minAxis, 1, minAxis * 0.5)
	local fresnelSz = resolveUDim(P.FresnelSize, minAxis, 0, minAxis * 0.5)
	local glareSz = resolveUDim(P.GlareSize, minAxis, 0, minAxis * 0.5)
	local blurRad = resolveUDim(P.BlurRadius or DEFAULT_BLUR_UDIM, minAxis, 1, minAxis)

	return {
		W = W, H = H, LW = LW, LH = LH,
		CornerRadius = cornerR,
		SuperEllipseFactor = clampN(P.SuperEllipseFactor or 3, 2, 7),
		Thickness = thickness,
		RefractionFactor = clampN(P.RefractionFactor or 2.1, 1, 4),
		ChromaticAberration = clampN(P.ChromaticAberration or 0.2, 0, 1),
		FresnelSize = fresnelSz,
		FresnelHardness = clampN(P.FresnelHardness or 40, 0, 100),
		FresnelIntensity = clampN(P.FresnelIntensity or 25, 0, 100),
		GlareSize = glareSz,
		GlareHardness = clampN(P.GlareHardness or 40, 0, 100),
		GlareIntensity = clampN(P.GlareIntensity or 70, 0, 120),
		GlareConvergence = clampN(P.GlareConvergence or 90, 0, 100),
		GlareOppositeSide = clampN(P.GlareOppositeSide or 50, 0, 100),
		GlareAngle = clampN(P.GlareAngle or -50, -180, 180),
		BlurRadius = blurRad,
	}
end

function Liquid:NoteShape(w, h, r)
	local sh = self.shape
	sh.w, sh.h, sh.r = w, h, r or 0
	local key = string.format("%d_%d_%d", floor(w + 0.5), floor(h + 0.5), floor((r or 0) * 2 + 0.5))
	if key ~= self.shapeKey then
		self.shapeKey = key
		self.lastChange = os.clock()
		self.geomDirty = true
		self.reconstructDirty = true
		self.geomJob = nil
		self.reconstructJob = nil
	end
end

function Liquid:SetGlareAngle(deg)
	if abs((self.P.GlareAngle or -50) - deg) > 0.5 then
		self.P.GlareAngle = deg
		self.geomDirty = true
		self.reconstructDirty = true
	end
end

----------------------------------------------------------------------
-- LẤY MẪU MÀN HÌNH (SCREEN SAMPLER): 2D UI TREE WALK + 3D RAYCAST
----------------------------------------------------------------------
-- Lưới nguồn có độ phân giải ~1/5 độ phân giải đầu ra (1 ô lưới cho mỗi 5x5 px) theo đúng bài blog
function Liquid:_ensureGrid(W, H)
	local gw = clampN(ceil(W / 5), 8, 72)
	local gh = clampN(ceil(H / 5), 5, 52)
	local beta = clampN(self.P.SamplerWarp or 0.45, 0, 0.85)
	if self.gr and self.gw == gw and self.gh == gh and self.lutW == W and self.lutH == H and self.lutBeta == beta then
		return
	end
	local baseColor = (self.isl and self.isl._style and self.isl._style.base) or self.body.BackgroundColor3
	local n = gw * gh
	local nr, ng, nb = newArray(n, baseColor.R), newArray(n, baseColor.G), newArray(n, baseColor.B)
	local ogw, ogh, gr, gg, gb = self.gw, self.gh, self.gr, self.gg, self.gb
	if gr and ogw and ogh then
		for j = 0, gh - 1 do
			for i = 0, gw - 1 do
				local oi = clampN(floor((i + 0.5) / gw * ogw), 0, ogw - 1)
				local oj = clampN(floor((j + 0.5) / gh * ogh), 0, ogh - 1)
				local ok = oj * ogw + oi + 1
				local d = j * gw + i + 1
				nr[d], ng[d], nb[d] = gr[ok], gg[ok], gb[ok]
			end
		end
	end
	self.gw, self.gh = gw, gh
	self.gr, self.gg, self.gb = nr, ng, nb
	self.lutX, self.centersX = buildWarpLUT(W, gw, beta)
	self.lutY, self.centersY = buildWarpLUT(H, gh, beta)
	self.lutW, self.lutH, self.lutBeta = W, H, beta
	self.gridFresh = (gr == nil)
	self.sampleCursor = 0
	self.passChangedCells = 0
end

function Liquid:_skySnapshot()
	local P = self.P
	local sun, sunY = Vector3.new(0.3, 0.8, 0.2).Unit, 0.6
	pcall(function()
		sun = Lighting:GetSunDirection()
		sunY = sun.Y
	end)
	local day = smooth01((sunY + 0.15) / 0.4)
	local topR, topG, topB = lerp(NIGHT_TOP[1], DAY_TOP[1], day), lerp(NIGHT_TOP[2], DAY_TOP[2], day), lerp(NIGHT_TOP[3], DAY_TOP[3], day)
	local horR, horG, horB = lerp(NIGHT_HOR[1], DAY_HOR[1], day), lerp(NIGHT_HOR[2], DAY_HOR[2], day), lerp(NIGHT_HOR[3], DAY_HOR[3], day)
	local warm = clampN(1 - abs(sunY - 0.02) / 0.25, 0, 1) * 0.55
	horR, horG, horB = lerp(horR, SUNSET[1], warm), lerp(horG, SUNSET[2], warm), lerp(horB, SUNSET[3], warm)

	local fogC = Lighting.FogColor
	local fogStart, fogEnd = Lighting.FogStart, Lighting.FogEnd
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		local c = atmo.Color
		horR, horG, horB = lerp(horR, c.R, 0.35), lerp(horG, c.G, 0.35), lerp(horB, c.B, 0.35)
		fogC = c
	end
	if type(P.Sky) == "table" then
		local t, h = P.Sky.Top, P.Sky.Horizon
		if typeof(t) == "Color3" then
			topR, topG, topB = t.R, t.G, t.B
		end
		if typeof(h) == "Color3" then
			horR, horG, horB = h.R, h.G, h.B
		end
	end
	return {
		sun = sun,
		amb = 0.24 + 0.42 * day,
		topR = topR, topG = topG, topB = topB,
		horR = horR, horG = horG, horB = horB,
		fogR = fogC.R, fogG = fogC.G, fogB = fogC.B,
		fogStart = fogStart or 0,
		fogEnd = max(fogEnd or 1000, 50),
	}
end

function Liquid:_skyColor(dir)
	local L = self.sky
	local e = max(dir.Y, 0)
	local t = e ^ 0.55
	return L.horR + (L.topR - L.horR) * t, L.horG + (L.topG - L.horG) * t, L.horB + (L.topB - L.horB) * t
end

-- Duyệt cây giao diện 2D tại điểm (screenX, screenY) thông qua GetGuiObjectsAtPosition
function Liquid:_sampleUIStack(screenX, screenY)
	local lp = Players.LocalPlayer
	local pgui = lp and lp:FindFirstChildOfClass("PlayerGui")
	if not pgui then
		return 0, 0, 0, 0
	end

	-- Hỗ trợ kính chồng kính (Glass over Glass): kiểm tra nếu có tấm kính thấp hơn nằm dưới điểm này
	for otherPane in pairs(ACTIVE_PANES) do
		if otherPane ~= self and otherPane.enabled and not otherPane.destroyed and otherPane.gr and otherPane.body then
			local b = otherPane.body
			if b.Visible and not self.body:IsDescendantOf(b) and not b:IsDescendantOf(self.body) then
				local ap, as = b.AbsolutePosition, b.AbsoluteSize
				if screenX >= ap.X and screenX <= ap.X + as.X and screenY >= ap.Y and screenY <= ap.Y + as.Y then
					if b.ZIndex <= self.body.ZIndex then
						local u = clampN((screenX - ap.X) / max(as.X, 1) * (otherPane.gw - 1), 0, otherPane.gw - 1)
						local v = clampN((screenY - ap.Y) / max(as.Y, 1) * (otherPane.gh - 1), 0, otherPane.gh - 1)
						local idx = floor(v + 0.5) * otherPane.gw + floor(u + 0.5) + 1
						local r = otherPane.gr[idx]
						if r then
							return r, otherPane.gg[idx], otherPane.gb[idx], 0.92
						end
					end
				end
			end
		end
	end

	local ok, list = pcall(function()
		return pgui:GetGuiObjectsAtPosition(screenX, screenY)
	end)
	if not ok or type(list) ~= "table" or #list == 0 then
		return 0, 0, 0, 0
	end

	local accR, accG, accB, accA = 0, 0, 0, 0
	local myRoot = (self.isl and self.isl._gui) or self.body

	for _, obj in ipairs(list) do
		if obj ~= self.body and obj ~= self.pane and not obj:IsDescendantOf(myRoot) then
			-- 1) Kiểm tra TextLabel / TextButton có chữ tại vị trí lấy mẫu
			if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Text ~= "" and obj.TextTransparency < 0.98 then
				local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
				local tb = obj.TextBounds
				local tx0, ty0 = ap.X, ap.Y
				if obj.TextXAlignment == Enum.TextXAlignment.Center then
					tx0 = ap.X + (as.X - tb.X) * 0.5
				elseif obj.TextXAlignment == Enum.TextXAlignment.Right then
					tx0 = ap.X + as.X - tb.X
				end
				if obj.TextYAlignment == Enum.TextYAlignment.Center then
					ty0 = ap.Y + (as.Y - tb.Y) * 0.5
				elseif obj.TextYAlignment == Enum.TextYAlignment.Bottom then
					ty0 = ap.Y + as.Y - tb.Y
				end
				if screenX >= tx0 and screenX <= tx0 + tb.X and screenY >= ty0 and screenY <= ty0 + tb.Y then
					local ta = (1 - obj.TextTransparency) * 0.65
					local tc = obj.TextColor3
					local w = (1 - accA) * ta
					accR = accR + tc.R * w
					accG = accG + tc.G * w
					accB = accB + tc.B * w
					accA = accA + w
				end
			end

			-- 2) Kiểm tra ImageLabel / ImageButton
			if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= "" and obj.ImageTransparency < 0.98 then
				local ia = 1 - obj.ImageTransparency
				local ic = obj.ImageColor3
				local w = (1 - accA) * ia
				accR = accR + ic.R * w
				accG = accG + ic.G * w
				accB = accB + ic.B * w
				accA = accA + w
			end

			-- 3) Kiểm tra màu nền BackgroundColor3 của GuiObject
			if obj.BackgroundTransparency < 0.98 then
				local ba = 1 - obj.BackgroundTransparency
				local bc = obj.BackgroundColor3
				local w = (1 - accA) * ba
				accR = accR + bc.R * w
				accG = accG + bc.G * w
				accB = accB + bc.B * w
				accA = accA + w
			end

			if accA >= 0.98 then
				break
			end
		end
	end

	if accA > 1e-4 then
		return accR / accA, accG / accA, accB / accA, clampN(accA, 0, 1)
	end
	return 0, 0, 0, 0
end

-- Đánh giá màu 3D raycast (Part, Terrain/Water, ánh sáng mặt trời và sương mù Lighting)
function Liquid:_sampleWorld3D(ray)
	local res = workspace:Raycast(ray.Origin, ray.Direction * RAY_LEN, self.rayParams)
	local L = self.sky
	if not res or not res.Instance then
		return self:_skyColor(ray.Direction)
	end
	local inst = res.Instance
	local r, g, b
	if inst:IsA("Terrain") then
		if res.Material == Enum.Material.Water then
			local wc = inst.WaterColor
			r, g, b = wc.R, wc.G, wc.B
		else
			local mc = inst:GetMaterialColor(res.Material)
			r, g, b = mc.R, mc.G, mc.B
		end
	else
		local tr = inst.Transparency
		if tr >= 0.92 then
			return self:_skyColor(ray.Direction)
		end
		local c = inst.Color
		r, g, b = c.R, c.G, c.B
		if tr > 0.05 then
			local sr, sg, sb = self:_skyColor(ray.Direction)
			r, g, b = lerp(r, sr, tr), lerp(g, sg, tr), lerp(b, sb, tr)
		end
	end

	local nd = max(res.Normal:Dot(L.sun), 0)
	local sh = L.amb + (1 - L.amb) * nd
	r, g, b = r * sh, g * sh, b * sh

	-- Sương mù theo khoảng cách (Lighting Fog + Atmosphere)
	local dist = res.Distance
	local fogFactor = clampN((dist - L.fogStart) / max(L.fogEnd - L.fogStart, 1), 0, 0.65)
	local hz = max(fogFactor, min((dist / 1500) ^ 1.5 * 0.5, 0.5))
	return lerp(r, L.fogR, hz), lerp(g, L.fogG, hz), lerp(b, L.fogB, hz)
end

-- Quét màn trập cuốn (Rolling Refresh) trong ngân sách SamplingBudget (5 ms)
function Liquid:_stepSampler(deadline)
	local P = self.P
	-- Nếu Transparency == 0 (đặc 100%), bỏ qua lấy mẫu màn hình theo đúng đặc tả GlassmorphicUI
	if P.Transparency == 0 or P.Backdrop == false then
		return
	end
	local sh = self.shape
	if sh.w < 8 or sh.h < 8 then
		return
	end
	local W, H = max(floor(sh.w + 0.5), 8), max(floor(sh.h + 0.5), 8)
	self:_ensureGrid(W, H)

	local cam = workspace.CurrentCamera
	local ap, sz = self.body.AbsolutePosition, self.body.AbsoluteSize
	if not cam or sz.X < 4 or sz.Y < 4 then
		return
	end

	local gw, gh = self.gw, self.gh
	local totalCells = gw * gh
	if self.sampleCursor == 0 or not self.sky then
		self.sky = self:_skySnapshot()
		self.rayParams = self.rayParams or RaycastParams.new()
	end

	local blendK = self.gridFresh and 1 or 0.55
	local centersX, centersY = self.centersX, self.centersY
	local gr, gg, gb = self.gr, self.gg, self.gb
	local cursor = self.sampleCursor
	local scanned = 0

	while scanned < totalCells and os.clock() < deadline do
		local cx = cursor % gw
		local cy = floor(cursor / gw)
		local normX = centersX[cx + 1] / W
		local normY = centersY[cy + 1] / H
		local sx = ap.X + normX * sz.X
		local sy = ap.Y + normY * sz.Y

		-- 1) Lấy mẫu cây giao diện 2D trước
		local uiR, uiG, uiB, uiA = self:_sampleUIStack(sx, sy)
		local finalR, finalG, finalB
		if uiA >= 0.98 then
			finalR, finalG, finalB = uiR, uiG, uiB
		else
			-- 2) Nếu UI trong suốt, bắn tia 3D vào workspace
			local ray = cam:ViewportPointToRay(sx, sy)
			local wR, wG, wB = self:_sampleWorld3D(ray)
			if uiA > 0 then
				finalR = uiR * uiA + wR * (1 - uiA)
				finalG = uiG * uiA + wG * (1 - uiA)
				finalB = uiB * uiA + wB * (1 - uiA)
			else
				finalR, finalG, finalB = wR, wG, wB
			end
		end

		local idx = cursor + 1
		local oR, oG, oB = gr[idx], gg[idx], gb[idx]
		local nR = oR + (finalR - oR) * blendK
		local nG = oG + (finalG - oG) * blendK
		local nB = oB + (finalB - oB) * blendK

		if abs(nR - oR) + abs(nG - oG) + abs(nB - oB) > 0.008 then
			self.passChangedCells = self.passChangedCells + 1
		end
		gr[idx], gg[idx], gb[idx] = nR, nG, nB

		self.samplesReceived = self.samplesReceived + 1
		cursor = cursor + 1
		scanned = scanned + 1
		if cursor >= totalCells then
			-- Hoàn tất 1 vòng quét toàn bộ lưới (Pass Complete)
			cursor = 0
			if self.gridFresh or self.passChangedCells > 0 then
				self.reconstructDirty = true
			end
			self.gridFresh = false
			self.passChangedCells = 0
			break
		end
	end

	self.sampleCursor = cursor
end

----------------------------------------------------------------------
-- ĐÓNG BĂNG HÌNH HỌC, TÁI DỰNG VÀ GHI EDITABLEIMAGE
----------------------------------------------------------------------
function Liquid:_flushBuffer(buf, LW, LH)
	if not self.paneImg or self.paneW ~= LW or self.paneH ~= LH then
		local img = self:_newImage(LW, LH)
		if not img then
			-- Khi EditableImage hết bộ nhớ, tự động giảm một nửa độ phân giải theo đúng tài liệu GlassmorphicUI
			if self.scaleCap > 0.25 then
				self.scaleCap = self.scaleCap * 0.5
				self.geomDirty = true
				self.reconstructDirty = true
				return
			end
			self:_fail("Không thể cấp phát bộ nhớ EditableImage cho GlassPane")
			return
		end
		if not self:_write(img, LW, LH, buf) or not self:_show(self.pane, img) then
			pcall(function()
				img:Destroy()
			end)
			self:_fail("Không thể ghi hoặc gán EditableImage cho GlassPane")
			return
		end
		local old = self.paneImg
		self.paneImg, self.paneW, self.paneH = img, LW, LH
		if old then
			pcall(function()
				old:Destroy()
			end)
		end
	elseif not self:_write(self.paneImg, LW, LH, buf) then
		self:_fail("Lỗi khi cập nhật buffer vào GlassPane")
		return
	end
	self.firstRenderDone = true
	self.framesSinceReconstruct = 0
end

function Liquid:_buildReconstructJob(spec, geom)
	self:_ensureGrid(spec.W, spec.H)
	local baseColor = (self.isl and self.isl._style and self.isl._style.base) or self.body.BackgroundColor3
	local P = self.P
	local tr = clampN(P.Transparency or 0.85, 0, 1)
	-- Khi Transparency = 0, tấm kính đặc hoàn toàn màu nền; khi > 0, pha nhẹ màu nền theo TintMix
	local tintMix = (tr == 0) and 1 or clampN(P.TintMix or ((1 - tr) * 0.35), 0, 1)
	local paneAlpha = (tr == 0) and 1 or clampN(P.Opacity or 0.94, 0.1, 1)

	-- Chụp nhanh (Snapshot) lưới nguồn bất biến cho toàn bộ lượt tái dựng
	local n = self.gw * self.gh
	local snapR, snapG, snapB = newArray(n, 0), newArray(n, 0), newArray(n, 0)
	for i = 1, n do
		snapR[i], snapG[i], snapB[i] = self.gr[i], self.gg[i], self.gb[i]
	end

	return {
		geom = geom,
		gw = self.gw, gh = self.gh,
		gr = snapR, gg = snapG, gb = snapB,
		lutX = self.lutX, lutY = self.lutY,
		ChromaticAberration = spec.ChromaticAberration,
		BlurRadius = spec.BlurRadius,
		tintR = baseColor.R, tintG = baseColor.G, tintB = baseColor.B,
		tintMix = tintMix,
		paneAlpha = paneAlpha,
	}
end

-- Thực thi đồng bộ toàn bộ đường ống trong 1 frame duy nhất (dùng cho GlassmorphicUI.forceUpdate)
function Liquid:ForceUpdateSync()
	if self.failed or self.destroyed then
		return
	end
	local sh = self.shape
	if sh.w < 4 or sh.h < 4 then
		local as = self.body.AbsoluteSize
		self:NoteShape(max(as.X, 16), max(as.Y, 16), 0)
	end
	local spec = self:_resolveSpec()
	local gKey = getGeometryKey(spec)
	local entry = GEOM_CACHE[gKey]
	local geom
	if entry then
		entry.lastUsed = os.clock()
		geom = entry.geom
	else
		geom = bakeGeometry(spec, nil)
		GEOM_CACHE[gKey] = { geom = geom, lastUsed = os.clock() }
		GEOM_CACHE_COUNT = GEOM_CACHE_COUNT + 1
		evictGeometryCache()
	end
	self.currentGeom = geom
	self.geomDirty = false

	self.gridFresh = true
	self.sampleCursor = 0
	pcall(self._stepSampler, self, os.clock() + 0.025)

	local jobData = self:_buildReconstructJob(spec, geom)
	local buf, LW, LH = reconstructFrostAndLight(jobData, nil)
	self:_flushBuffer(buf, LW, LH)
	self.reconstructDirty = false
	self.geomJob = nil
	self.reconstructJob = nil
	self.pendingWrite = nil
	self.executionPath = "sync"
end

-- Vòng lặp mỗi khung hình với ngân sách tách biệt: 5 ms Sampling + 8 ms Rendering (Tổng <= 13 ms)
function Liquid:Step()
	if self.failed or self.destroyed or not self.enabled then
		return
	end
	local isl = self.isl
	if isl and (isl._destroyed or isl._hidden or not isl._glass or not isl._gui.Enabled) then
		return
	end
	if self.paused and self.firstRenderDone then
		self.executionPath = "idle"
		self.framesSinceReconstruct = self.framesSinceReconstruct + 1
		return
	end

	local sh = self.shape
	if sh.w < 8 or sh.h < 8 then
		local as = self.body.AbsoluteSize
		if as.X >= 8 and as.Y >= 8 then
			self:NoteShape(as.X, as.Y, sh.r)
		else
			return
		end
	end

	local now = os.clock()
	local sampDeadline = now + (self.P.SamplingBudget or 5) / 1000
	local renderDeadline = sampDeadline + (self.P.RenderingBudget or 8) / 1000
	self.framesSinceReconstruct = self.framesSinceReconstruct + 1

	-- 1) Ghi buffer đã dựng xong từ frame trước (EditableImage giới hạn tối đa 1 lần ghi mỗi frame)
	if self.pendingWrite then
		local pw = self.pendingWrite
		self.pendingWrite = nil
		self:_flushBuffer(pw.buf, pw.w, pw.h)
	end

	-- 2) Ngân sách Lấy mẫu màn hình (Sampling Budget <= 5 ms)
	pcall(self._stepSampler, self, sampDeadline)

	-- 3) Ngân sách Kết xuất (Rendering Budget <= 8 ms): Đóng băng hình học -> Tái dựng + Frost + Rim
	local spec = self:_resolveSpec()
	if self.geomDirty or not self.currentGeom then
		local gKey = getGeometryKey(spec)
		local cached = GEOM_CACHE[gKey]
		if cached then
			cached.lastUsed = now
			self.currentGeom = cached.geom
			self.geomDirty = false
			self.geomJob = nil
		else
			if not self.geomJob or self.geomJob.key ~= gKey then
				self.geomJob = self:_newJob(function(step)
					return bakeGeometry(spec, step)
				end)
				self.geomJob.key = gKey
			end
			local done, baked = self:_resume(self.geomJob, renderDeadline)
			if done then
				self.geomJob = nil
				if baked then
					GEOM_CACHE[gKey] = { geom = baked, lastUsed = now }
					GEOM_CACHE_COUNT = GEOM_CACHE_COUNT + 1
					evictGeometryCache()
					self.currentGeom = baked
					self.geomDirty = false
				end
			end
		end
	end

	-- Chỉ bắt đầu lượt tái dựng mới khi hình học đã sẵn sàng và (lần đầu tiên hoặc đảo đã ổn định nhịp ngắn)
	local settleWait = self.firstRenderDone and 0.055 or 0
	if
		self.currentGeom
		and not self.geomJob
		and not self.reconstructJob
		and not self.pendingWrite
		and self.reconstructDirty
		and (now - self.lastChange >= settleWait)
		and os.clock() < renderDeadline
	then
		local jobData = self:_buildReconstructJob(spec, self.currentGeom)
		self.reconstructJob = self:_newJob(function(step)
			return reconstructFrostAndLight(jobData, step)
		end)
		self.reconstructDirty = false
	end

	if self.reconstructJob and os.clock() < renderDeadline then
		self.executionPath = "sync"
		local done, buf, LW, LH = self:_resume(self.reconstructJob, renderDeadline)
		if done then
			self.reconstructJob = nil
			if buf then
				self.pendingWrite = { buf = buf, w = LW, h = LH }
			end
		end
	elseif not self.geomJob and not self.reconstructJob then
		self.executionPath = "idle"
	end
end

function Liquid:SafeStep()
	local ok, err = pcall(self.Step, self)
	if ok then
		self.errors = 0
	else
		self.errors = (self.errors or 0) + 1
		if self.errors >= 3 then
			self:_fail(err)
		end
	end
end

function Liquid:SetVisible(on)
	self.enabled = on and true or false
	self.pane.Visible = self.enabled
	if self.enabled then
		self.reconstructDirty = true
	end
end

function Liquid:Refresh()
	self.gridFresh = true
	self.sampleCursor = 0
	self.reconstructDirty = true
end

function Liquid:SetParams(opts)
	for k, v in pairs(opts or {}) do
		self.P[k] = v
	end
	self.geomDirty = true
	self.geomJob = nil
	self.reconstructJob = nil
	self:Refresh()
end

function Liquid:GetDebugStats()
	local spec = self:_resolveSpec()
	return {
		GridResolution = Vector2.new(self.gw or 0, self.gh or 0),
		OutputResolution = Vector2.new(spec.LW, spec.LH),
		BackdropSamplesReceived = self.samplesReceived,
		FramesSinceLastReconstruction = self.framesSinceReconstruct,
		ExecutionPath = self.executionPath,
	}
end

function Liquid:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	ACTIVE_PANES[self] = nil
	for _, c in ipairs(self.attrConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self.attrConns = {}
	if self.paneImg then
		pcall(function()
			self.paneImg:Destroy()
		end)
		self.paneImg = nil
	end
	pcall(function()
		self.pane:Destroy()
	end)
end

----------------------------------------------------------------------
-- MÔ-ĐUN CHUẨN GLASSMORPHICUI API (TƯƠNG THÍCH 100% REPO BOATBEAKER)
----------------------------------------------------------------------
local GlassmorphicUI = {}
local WINDOW_REGISTRY = setmetatable({}, { __mode = "k" })
local STANDALONE_CONNS = {}

local function ensureStandaloneLoop()
	if STANDALONE_CONNS.heartbeat then
		return
	end
	STANDALONE_CONNS.heartbeat = RunService.Heartbeat:Connect(function()
		for win, entry in pairs(WINDOW_REGISTRY) do
			if not win.Parent then
				entry.lg:Destroy()
				WINDOW_REGISTRY[win] = nil
			else
				local as = win.AbsoluteSize
				entry.lg:NoteShape(as.X, as.Y, 0)
				entry.lg:SafeStep()
			end
		end
	end)
end

function GlassmorphicUI.addGlassBackground(guiObject)
	assert(typeof(guiObject) == "Instance" and guiObject:IsA("GuiObject"), "Tham số phải là một GuiObject")
	if WINDOW_REGISTRY[guiObject] then
		return guiObject
	end
	pcall(function()
		CollectionService:AddTag(guiObject, "GlassmorphicUI")
	end)
	guiObject.BackgroundTransparency = 1
	local ok, lg = pcall(Liquid.new, nil, guiObject, nil)
	if ok and lg then
		local as = guiObject.AbsoluteSize
		lg:NoteShape(max(as.X, 16), max(as.Y, 16), 0)
		WINDOW_REGISTRY[guiObject] = { lg = lg }
		ensureStandaloneLoop()
	end
	return guiObject
end

function GlassmorphicUI.new()
	local frame = Instance.new("Frame")
	frame.Name = "GlassWindow"
	frame.Size = UDim2.fromOffset(300, 200)
	frame.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	return GlassmorphicUI.addGlassBackground(frame)
end

function GlassmorphicUI.applyGlassToImageLabel(imageLabel)
	GlassmorphicUI.addGlassBackground(imageLabel)
end

function GlassmorphicUI.forceUpdate(window)
	local entry = WINDOW_REGISTRY[window]
	if entry and entry.lg then
		entry.lg:ForceUpdateSync()
	end
	return window
end

function GlassmorphicUI.pauseUpdates(window)
	local entry = WINDOW_REGISTRY[window]
	if entry and entry.lg then
		entry.lg.paused = true
	end
	return window
end

function GlassmorphicUI.resumeUpdates(window)
	local entry = WINDOW_REGISTRY[window]
	if entry and entry.lg then
		entry.lg.paused = false
		entry.lg:Refresh()
	end
	return window
end

function GlassmorphicUI.setDefaultBlurRadius(blurRadius)
	if typeof(blurRadius) == "UDim" or type(blurRadius) == "number" then
		DEFAULT_BLUR_UDIM = blurRadius
	end
end

function GlassmorphicUI.getDebugStats(window)
	local entry = WINDOW_REGISTRY[window]
	if entry and entry.lg then
		return entry.lg:GetDebugStats()
	end
	return nil
end

-- Tự động lắng nghe CollectionService tag "GlassmorphicUI"
pcall(function()
	for _, inst in ipairs(CollectionService:GetTagged("GlassmorphicUI")) do
		if inst:IsA("GuiObject") then
			GlassmorphicUI.addGlassBackground(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal("GlassmorphicUI"):Connect(function(inst)
		if inst:IsA("GuiObject") then
			GlassmorphicUI.addGlassBackground(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("GlassmorphicUI"):Connect(function(inst)
		local entry = WINDOW_REGISTRY[inst]
		if entry then
			entry.lg:Destroy()
			WINDOW_REGISTRY[inst] = nil
		end
	end)
end)

Island.GlassmorphicUI = GlassmorphicUI

----------------------------------------------------------------------
-- KHỞI TẠO & VẬN HÀNH DYNAMIC ISLAND
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
		Liquid = config.Liquid ~= false and (config.Liquid or true) or false,
		Top = config.Top or 11,
		Scale = config.Scale,
		Intro = config.Intro ~= false,
		OnTap = config.OnTap,
		Glass = config.Glass ~= false,
		Transparency = config.Transparency or style.transparency,
	}
	self._glass = self._cfg.Glass
	self._conns = {}
	self._queue = {}
	self._layers = {}
	self._glassItems = {}
	self._lg = nil
	self._lgOn = false
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

	self:_build()
	self:_connect()
	self:_render(false)
	self:_blurInit()
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

	local shell = mk("Frame", {
		Name = "Shell",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, holder)
	self._shell = shell
	self._pressScale = mk("UIScale", { Scale = 1 }, shell)

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
	self:_lgCreate()
	self:_syncBodyFill()

	local function glassItem(obj)
		obj.Visible = glass
		table.insert(self._glassItems, obj)
		return obj
	end

	self._tint = glassItem(mk("Frame", {
		Name = "Tint",
		BackgroundColor3 = Island.Colors.Blue,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, body))
	addGradient(self._tint, 0, { { 0, 0.78 }, { 0.5, 0.95 }, { 1, 1 } })

	local glow = glassItem(mk("CanvasGroup", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(170, 170),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 1,
	}, body))
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

	self._glint = glassItem(mk("Frame", {
		Name = "Glint",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, body))
	self._glintGrad = addGradient(self._glint, 20, { { 0, 1 }, { 0.4, 1 }, { 0.5, 0.82 }, { 0.6, 1 }, { 1, 1 } })
	self._glintGrad.Offset = Vector2.new(-1, 0)
	self._glint.Visible = false

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
		local g = addGradient(s, 40, { { 0, L.lo }, { 0.2, near }, { 0.5, L.mid }, { 0.8, near }, { 1, L.lo } })
		table.insert(self._edges, { frame = f, corner = c, stroke = s, grad = g, t = L.t })
	end

	local act = newLayer(body, "Activity")
	self._layers.Activity = act
	act.right = newLabel(act.content, Island.Fonts.Bold, 14, WHITE, 0)
	act.right.AnchorPoint = Vector2.new(1, 0.5)
	act.right.TextXAlignment = Enum.TextXAlignment.Right
	act.right.Position = UDim2.new(1, -14, 0.5, 0)

	local nt = newLayer(body, "Notify")
	self._layers.Notify = nt
	nt.header = buildHeader(nt.content, 20)

	self._layers.Expanded = newLayer(body, "Expanded")
	self._icon = newIcon(body)

	local w0, h0 = M.IdleW, M.IdleH
	if self._cfg.Intro then
		w0, h0 = 26, 16
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

function Island:_apply()
	local sp = self._sp
	local w = math.max(sp.w.p, 1)
	local h = math.max(sp.h.p, 1)
	local r = math.min(h / 2, M.MaxCorner)
	self._r = r

	self._shell.Size = UDim2.fromOffset(w, h)
	self._shell.Position = UDim2.fromOffset(0, sp.oy.p)
	-- Khi Liquid bật, GlassPane tự cắt viền bằng mặt nạ siêu elip (SuperEllipseFactor = 3);
	-- đặt CornerRadius của CanvasGroup về 0 để không cắt mất góc squircle của GlassPane.
	self._bodyCorner.CornerRadius = UDim.new(0, self._lgOn and 0 or r)

	local k = math.clamp(h / 16, 0, 1)
	for _, e in ipairs(self._edges) do
		local t = math.min(e.t * k, h / 2 - 0.5, w / 2 - 0.5)
		local on = self._glass and not self._lgOn and t > 0.2
		e.frame.Visible = on
		if on then
			e.frame.Size = UDim2.new(1, -2 * t, 1, -2 * t)
			e.corner.CornerRadius = UDim.new(0, math.max(r - t, 0))
			e.stroke.Thickness = t
		end
	end
	for _, d in ipairs(self._depth) do
		local fits = self._glass and not self._lgOn and (h - 2 * d.inset) > 2 and (w - 2 * d.inset) > 2
		d.frame.Visible = fits
		if fits then
			d.corner.CornerRadius = UDim.new(0, math.max(r - d.inset, 0))
		end
	end

	if self._lgOn then
		self._lg:NoteShape(w, h, r)
	end

	local ic = self._icon
	local s = math.max(sp.is.p, 1)
	ic.group.Position = UDim2.fromOffset(sp.ix.p, sp.iy.p)
	ic.group.Size = UDim2.fromOffset(s, s)
	ic.corner.CornerRadius = UDim.new(math.clamp(sp.ir.p, 0, 0.5), 0)
	ic.glyph.TextSize = math.max(4, math.floor(s * 0.52))
end

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

	table.insert(
		self._conns,
		RunService.Heartbeat:Connect(function()
			local lg = self._lg
			if lg then
				lg:SafeStep()
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

function Island:_syncActivity()
	local a = self._activity
	if not a then
		return
	end
	local layer = self._layers.Activity
	local right = a.Right or ""
	layer.right.TextColor3 = a.RightColor or a.Color or WHITE
	local rw = right ~= "" and math.ceil(textWidth(right, 14, Island.Fonts.Bold)) + 18 or 0
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

		local head = newPart(c)
		layer.header = buildHeader(head.group, 20)
		layer.right = newLabel(head.group, Island.Fonts.Bold, 17, WHITE, 0)
		layer.right.AnchorPoint = Vector2.new(1, 0.5)
		layer.right.TextXAlignment = Enum.TextXAlignment.Right

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

function Island:_glassTransition(state)
	if not self._glass then
		return
	end
	local ang = RIM_ANGLE[state] or -50
	for _, e in ipairs(self._edges) do
		tween(e.grad, 0.9, { Rotation = ang }, Enum.EasingStyle.Quint)
	end
	if self._lg then
		self._lg:SetGlareAngle(ang)
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

	if self._glass then
		local accent = spec and spec.Color
		if self._lgOn then
			self._tint.BackgroundTransparency = 1
		elseif accent then
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

----------------------------------------------------------------------
-- Mờ nền thật (RealBlur DepthOfField)
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
		dof.NearIntensity = b.NearIntensity
		dof.InFocusRadius = b.InFocusRadius
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
			part.Material = Enum.Material.SmoothPlastic
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
	local focus = b.FocusDistance or d * 2
	if self._dofFocus ~= focus then
		self._dofFocus = focus
		self._dof.FocusDistance = focus
	end

	local t = os.clock()
	local pulse = 1.012 + 0.008 * (0.5 + 0.5 * math.sin(t * 1.35))
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

function Island:SetBlur(on)
	self:_blurCleanup()
	self._cfg.RealBlur = on and (on == true and true or on) or false
	if self._cfg.RealBlur then
		self:_blurInit()
	end
end

----------------------------------------------------------------------
-- API CÔNG KHAI DYNAMIC ISLAND
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

function Island:SetGlass(on)
	self._glass = on and true or false
	self._cfg.Glass = self._glass
	self._body.BackgroundColor3 = self._glass and self._style.base or BLACK
	self._body.BackgroundTransparency = self._glass and self._cfg.Transparency or 0
	for _, obj in ipairs(self._glassItems) do
		obj.Visible = self._glass
	end
	if self._glass then
		self:_lgCreate()
		if self._lg then
			self._lg:SetVisible(true)
		end
	elseif self._lg then
		self._lg:SetVisible(false)
	end
	self._lgOn = self._glass and self._lg ~= nil
	self:_syncBodyFill()
	self:_apply()
	self:_render(false)
end

function Island:_syncBodyFill()
	local body = self._body
	if not body then
		return
	end
	if not self._glass then
		body.BackgroundColor3 = BLACK
		body.BackgroundTransparency = 0
		return
	end
	body.BackgroundColor3 = self._style.base
	body.BackgroundTransparency = self._lgOn and 1 or self._cfg.Transparency
end

function Island:_lgCreate()
	if self._lg or not self._cfg.Liquid or not self._glass then
		return
	end
	local opts = type(self._cfg.Liquid) == "table" and self._cfg.Liquid or nil
	local ok, lg = pcall(Liquid.new, self, self._body, opts)
	if ok and lg then
		self._lg = lg
		self._lgOn = true
	else
		self._lgOn = false
		warn("[DynamicIsland] Không bật được Liquid glass (" .. tostring(lg) .. "), dùng kính cổ điển.")
	end
	self:_syncBodyFill()
end

function Island:_lgFailed()
	self._lgOn = false
	self:_syncBodyFill()
	local lg = self._lg
	self._lg = nil
	if lg then
		task.defer(function()
			lg:Destroy()
		end)
	end
	if not self._destroyed and self._sp then
		self:_apply()
	end
end

function Island:SetLiquid(opts)
	if opts == false then
		self._cfg.Liquid = false
		self._lgOn = false
		local lg = self._lg
		self._lg = nil
		if lg then
			lg:Destroy()
		end
	else
		self._cfg.Liquid = type(opts) == "table" and opts or true
		if self._lg then
			self._lg:SetParams(type(opts) == "table" and opts or nil)
		else
			self:_lgCreate()
		end
	end
	self:_syncBodyFill()
	self:_apply()
end

function Island:RefreshGlass()
	if self._lg then
		self._lg:ForceUpdateSync()
	end
end

function Island:GetDebugStats()
	if self._lg then
		return self._lg:GetDebugStats()
	end
	return nil
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
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self._conns = {}
	self:_blurCleanup()
	if self._lg then
		self._lg:Destroy()
		self._lg = nil
	end
	if self._gui then
		self._gui:Destroy()
	end
end

----------------------------------------------------------------------
-- Demo chạy thử nhanh: getgenv().DynamicIslandDemo = true
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
			Text = "Liquid Glass 100% chuẩn GlassmorphicUI đã sẵn sàng",
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
