--[[
	DynamicIsland.lua  v5  -  Dynamic Island (iPhone 14 Pro) + LIQUID GLASS dựng lại đúng theo bài
	"Reproducing Liquid Glass in Roblox" của boatbomber (boatbomber.com/blog/liquid-glass)
	-------------------------------------------------------------------------------
	MỚI Ở v5 - làm lại cách dựng kính cho đúng quy trình của bài (tên tham số lấy theo README GlassmorphicUI)
	• Hình dạng: rounded rect có góc SUPERELLIPSE (SuperEllipseFactor), mask byte chống răng cưa.
	• Độ sâu + pháp tuyến: lấy từ HỌ ĐƯỜNG ĐỒNG MỨC "melted" (bán kính góc và số mũ đổi mượt vào trong), giải bằng chia đôi + secant,
	  rồi pháp tuyến = -gradient của trường độ sâu trơn. Hết nếp gấp chéo ở góc của SDF thô (bản v4 bị lỗi này).
	• Khúc xạ: Snell trên bezel lồi (RefractionFactor = tỉ số chiết suất, Thickness = bề dày), vector dịch tính sẵn cho từng pixel,
	  tách kênh màu (đỏ xa hơn / xanh dương gần hơn ChromaticAberration).
	• Backdrop: lưới thô và MÉO (dày ở dải viền, thưa ở giữa), lấy mẫu bằng raycast xuyên qua part gần như vô hình,
	  làm tươi dần trong ngân sách ms; dựng lại bằng Catmull-Rom bicubic.
	• Frost: gaussian sigma = BlurRadius / 3 trên ảnh đã khúc xạ, RỒI MỚI chồng viền Fresnel + glare (GlareAngle, GlareConvergence,
	  GlareOppositeSide...) tính từ chính độ sâu và pháp tuyến đó.
	• Bản đồ tra cứu theo pixel chỉ tính lại khi HÌNH DẠNG đổi (và đảo đã đứng yên); nền đổi thì chỉ dựng lại ảnh.
	• Một ảnh EditableImage duy nhất cho cả tấm kính (không còn ảnh viền 9-slice riêng), tối đa 1 lần ghi mỗi frame.
	• Không có EditableImage (hoặc lỗi) -> tự quay về kính cổ điển của v3.

	KHÁC BÀI GỐC (nói thật)
	• Bài dùng Actor để dựng ảnh song song; executor thường không có nên ở đây chạy đường "sync" (chia nhỏ theo ngân sách ms/frame).
	• SuperEllipseFactor mặc định 2 thay vì 3: thân đảo vẫn bị cắt bằng UICorner (cung tròn) nên góc superellipse sẽ lệch với đường cắt.
	• Backdrop là CẢNH 3D dựng lại bằng raycast (màu Part + mô hình trời), không phải ảnh thật của màn hình: Roblox không cho đọc framebuffer.
	• Chưa có "glass over glass" của bài.

	MỚI Ở v3: hết tràn viền (mọi lớp nằm TRONG thân CanvasGroup), vùng mờ nền thật (Part DepthOfField) thu vào Inset px.
	MỚI Ở v2: spring kiểu SwiftUI, icon dùng chung (matched geometry), nội dung vào theo tầng, số/chữ "roll", kéo dây cao su.

	CÁCH DÙNG (API giữ nguyên như v1-v4)
	    local Island = loadstring(game:HttpGet("LINK_RAW_CUA_BAN"))()
	    local island = Island.new({
	        Top = 11, Scale = nil,          -- Scale nil = tự co theo màn hình
	        Style = "Frosted",              -- "Frosted" = kính xám mờ đục | "Dark" = kính đen kiểu iOS
	        RealBlur = true,                -- mờ nền thật (Part Glass + DepthOfField); false = tắt; hoặc bảng thông số:
	                                        --   { NearIntensity = 1, Inset = 6, Slices = 8, Distance = nil, FocusDistance = nil, InFocusRadius = 100 }
	        Liquid = true,                  -- engine kính v5; false = kính cổ điển v3; hoặc bảng ghi đè (xem LIQUID_DEFAULTS), ví dụ:
	                                        --   { Thickness = UDim.new(0.15, 0), RefractionFactor = 2.1, ChromaticAberration = 0.2,
	                                        --     SuperEllipseFactor = 2, BlurRadius = UDim.new(0.06, 0), FresnelIntensity = 25,
	                                        --     GlareIntensity = 70, GlareAngle = -50, Transparency = nil, Backdrop = true, Budget = 3 }
	        Glass = true,                   -- false = đen đặc 100% như iPhone thật (tự tắt luôn RealBlur và Liquid)
	        Transparency = nil,             -- độ trong của thân kính (nil = theo Style)
	    })

	    island:Notify({ Title = "Auto Farm", Text = "Đã bật Level Farm",
	        Color = Island.Colors.Green, Duration = 3, Callback = function() end })

	    island:SetActivity({ Title = "Auto Farm", Text = "Level Farm • Bandit",
	        Color = Island.Colors.Green, Right = "Lv 120", Progress = 0.35,
	        Buttons = {
	            { Text = "Dừng", Style = "destructive", Callback = function() end },
	            { Text = "Ẩn",   Style = "default",     Callback = function() island:Collapse() end },
	        } })
	    island:UpdateActivity({ Right = "Lv 121", Progress = 0.6 })
	    island:Expand() / :Collapse() / :Toggle() / :ClearActivity()
	    island:Hide() / :Show() / :SetGlass(true|false) / :SetBlur(true|false|{...}) / :SetTop(px) / :SetScale(s) / :Destroy()
	    island:SetLiquid(false | true | { ... })   -- đổi engine/tham số kính khi đang chạy
	    island:RefreshGlass()                       -- ép quét lại backdrop (vd. vừa teleport)

	Bấm vào đảo (khi có Activity) = mở rộng / thu lại.  Vuốt lên = đóng.
	Icon: Icon = "rbxassetid://123" (hoặc số id) hoặc Glyph = "⚡"; không có thì lấy chữ cái đầu của Title.
	Chạy thử nhanh: getgenv().DynamicIslandDemo = true trước khi load file này.

	GIỚI HẠN (nói thật)
	• CHƯA kiểm chứng trong Roblox thật. Phần toán (SDF superellipse, họ đường đồng mức, Snell, lưới méo, Catmull-Rom, frost, Fresnel/glare)
	  đã chạy thử bằng Luau trên máy tính và xem lại ảnh kết quả; phần gọi API Roblox (EditableImage, raycast) chạy thử trên môi trường giả.
	  Nếu EditableImage bị chặn trên executor của bạn, đảo tự dùng kính cổ điển.
	• Cần client có AssetService:CreateEditableImage, EditableImage:WritePixelsBuffer và ImageLabel.ImageContent.
	• Backdrop bằng raycast chỉ thấy vật thể 3D (màu Part, không texture/ánh sáng thật/skybox): màu kính là gần đúng.
	  Không thấy được ScreenGui khác. Chỉnh Sky = {...} nếu màu trời lệch.
	• Thân vẫn bị cắt bằng UICorner (bo tròn thường, không phải squircle liên tục của Apple).
	• RealBlur (DepthOfField) vẫn giữ nguyên như v3 và vẫn có giới hạn cũ: chỉ mờ cảnh 3D, cần đồ hoạ >= 8,
	  DOF có thể lem nhẹ ra ngoài viền (tăng Inset hoặc đặt RealBlur = false).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")

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
-- Hai phong cách kính. Frosted = kính xám mờ đục như Night Hub (nên đi cùng RealBlur), Dark = kính đen như iOS
local STYLES = {
	Frosted = { base = Color3.fromRGB(66, 64, 68), transparency = 0.4, depthAlpha = 0.035, sheenTop = 0.84, tint = 0.4 },
	Dark = { base = Color3.fromRGB(30, 32, 38), transparency = 0.12, depthAlpha = 0.07, sheenTop = 0.9, tint = 0.7 },
}
-- Mờ nền thật: Part kính vô hình + DepthOfField (xem _blurInit). Mọi số chỉnh được qua RealBlur = { ... }
local BLUR_DEFAULTS = {
	Transparency = 0.985, -- lớp nền không phản chiếu; chỉ dùng để tạo vùng DOF
	Distance = nil, -- khoảng cách Part tới camera; nil = tự tính theo NearPlaneZ
	FocusDistance = nil, -- nil = Distance * 2
	InFocusRadius = 100,
	NearIntensity = 1, -- độ mờ (0..1)
	Slices = 8, -- số lát mỗi bên để xấp xỉ góc bo
	Inset = 6, -- thu vùng mờ vào trong px để phần mờ lem ra không vượt khỏi viền kính
}
-- Quầng sáng theo ngón tay: GLOW_N vòng tròn rất nhạt chồng nhau, vòng lớn nhất = GLOW_D (khớp khung Glow 170px)
local GLOW_N, GLOW_D, GLOW_A = 16, 170, 0.0157
-- Viền kính: mỗi lớp là một UIStroke bám mép và dày vào TRONG thân. t = bề dày (px), lo = độ trong ở chỗ sáng nhất, mid = ở chỗ tối nhất.
-- Chồng 4 lớp -> mép sáng sắc rồi mờ dần vào trong (giống độ dày của kính). Không còn bóng đổ/viền nào nằm ngoài thân.
local EDGE_LAYERS = {
	{ t = 1.1, lo = 0.28, mid = 0.90 },
	{ t = 2.6, lo = 0.80, mid = 0.97 },
	{ t = 5, lo = 0.90, mid = 0.99 },
	{ t = 8.5, lo = 0.95, mid = 1 },
}
local DEPTH_N, DEPTH_STEP = 8, 2 -- chiều sâu kính: 8 lớp thu dần vào trong (độ đậm lấy theo STYLES)

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
-- LIQUID GLASS v5 - dựng lại theo đúng quy trình của bài "Reproducing Liquid Glass in Roblox" (boatbomber)
--   1) Hình dạng: rounded rect với góc SUPERELLIPSE -> mask byte + SDF, tính MỘT lần cho mỗi hình dạng
--   2) Độ sâu + pháp tuyến lấy từ họ đường đồng mức "melted" (bán kính góc và số mũ đổi mượt vào trong)
--      -> một trường trơn duy nhất, không còn nếp gấp chéo ở góc như SDF thô
--   3) Khúc xạ Snell trên mặt bezel lồi (RefractionFactor) -> vector dịch lấy mẫu từng pixel, tách kênh màu
--   4) Lưới backdrop thô và MÉO (dày ở dải viền), lấy mẫu bằng raycast, dựng lại bằng Catmull-Rom bicubic
--   5) Frost gaussian (sigma = BlurRadius / 3) trên ảnh đã khúc xạ, RỒI MỚI chồng Fresnel + glare
----------------------------------------------------------------------
--[[CORE_BEGIN]]
local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max
local sin, tan, asin, atan, rad = math.sin, math.tan, math.asin, math.atan, math.rad
local cos = math.cos

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

local function clampN(x, a, b)
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

local function smooth01(t)
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

-- UDim (hoặc bảng {Scale, Offset}) hoặc số px -> px, kẹp trong [lo, hi]
local function resolveLen(v, axis, lo, hi)
	local x
	local tv = typeof(v)
	if tv == "number" then
		x = v
	elseif tv == "UDim" or tv == "table" then
		x = (v.Scale or 0) * axis + (v.Offset or 0)
	else
		x = 0
	end
	return clampN(x, lo, hi)
end

-- Khoảng cách có dấu tới rounded rect có góc superellipse (chuẩn n, n = 2 là cung tròn). Âm = bên trong.
local function sdSuper(px, py, hx, hy, r, n)
	local qx, qy = abs(px) - (hx - r), abs(py) - (hy - r)
	local ax, ay = qx > 0 and qx or 0, qy > 0 and qy or 0
	local len
	if n == 2 then
		len = sqrt(ax * ax + ay * ay)
	elseif ax == 0 or ay == 0 then
		len = ax + ay
	else
		len = (ax ^ n + ay ^ n) ^ (1 / n)
	end
	local inner = qx > qy and qx or qy
	if inner > 0 then
		inner = 0
	end
	return len + inner - r
end

-- Họ đường đồng mức "melted": ở độ sâu d, đường đồng mức là rounded rect thu vào d px,
-- bán kính góc tăng dần tới stadium và số mũ superellipse giảm dần về 2 khi đi vào trong.
local function contour(d, S)
	local hx, hy = S.hx - d, S.hy - d
	local rmax = hx < hy and hx or hy
	local u = smooth01(d / S.melt)
	local r0 = S.r < rmax and S.r or rmax
	return hx, hy, r0 + (rmax - r0) * u, S.n + (2 - S.n) * u
end

-- Độ sâu (px) của một điểm nằm bên trong: nghiệm d của "điểm nằm đúng trên đường đồng mức d" (chia đôi, các đường lồng nhau),
-- kết thúc bằng một bước nội suy secant để độ sâu gần như chính xác (tránh nhiễu lượng tử hóa khi lấy đạo hàm ra pháp tuyến).
local function depthInside(px, py, S, phi0)
	local hx, hy, rc, nc = contour(S.dmax, S)
	local fhi = sdSuper(px, py, hx, hy, rc, nc)
	if fhi <= 0 then
		return S.dmax
	end
	local lo, hi, flo = 0, S.dmax, phi0
	for _ = 1, 8 do
		local mid = (lo + hi) * 0.5
		hx, hy, rc, nc = contour(mid, S)
		local fm = sdSuper(px, py, hx, hy, rc, nc)
		if fm <= 0 then
			lo, flo = mid, fm
		else
			hi, fhi = mid, fm
		end
	end
	local span = fhi - flo
	if span > 1e-9 then
		return lo + (hi - lo) * (-flo) / span
	end
	return (lo + hi) * 0.5
end

-- Bezel lồi h(x) = (1 - (1 - x)^4)^(1/4), x = độ sâu / Thickness. Tia nhìn thẳng xuống gặp mặt nghiêng góc ti = atan(h'),
-- khúc xạ theo Snell sin(tt) = sin(ti) / rho, rồi đi hết bề dày h -> dịch ngang T * h * tan(ti - tt) (hướng vào trong).
local function bezelShift(x, rho, T)
	if x <= 0 or x >= 1 or rho <= 1 then
		return 0
	end
	if x < 0.004 then
		x = 0.004
	end
	local om = 1 - x
	local om2 = om * om
	local base = 1 - om2 * om2
	local h = base ^ 0.25
	local slope = om2 * om * base ^ -0.75
	local ti = atan(slope)
	local tt = asin(sin(ti) / rho)
	return T * h * tan(ti - tt)
end

-- Cường độ theo độ sâu: Hardness cao = giữ sáng đều rồi cắt gấp gần mép trong
local function edgeProfile(t, hardness)
	local w = (1 - hardness / 100) * 0.9 + 0.05
	local v = (1 - t) / w
	if v <= 0 then
		return 0
	end
	if v >= 1 then
		return 1
	end
	return v * v * (3 - 2 * v)
end

-- Quy đổi tham số (UDim/số) sang px theo kích thước hiện tại của đảo
local function resolveShape(W, H, r, P)
	local mn = min(W, H)
	local hmin = mn / 2
	local S = { W = W, H = H, hx = W / 2, hy = H / 2, hmin = hmin }
	S.n = clampN(P.SuperEllipseFactor or 2, 2, 7)
	if P.CornerRadius ~= nil then
		S.r = resolveLen(P.CornerRadius, mn, 0, hmin)
	else
		S.r = clampN(r, 0, hmin)
	end
	S.T = resolveLen(P.Thickness, mn, 1, hmin)
	S.FS = resolveLen(P.FresnelSize, mn, 0, hmin)
	S.GS = resolveLen(P.GlareSize, mn, 0, hmin)
	S.blur = resolveLen(P.BlurRadius, mn, 1, mn)
	S.rho = clampN(P.RefractionFactor, 1, 4)
	S.ca = clampN(P.ChromaticAberration, 0, 1)
	S.Fi = clampN(P.FresnelIntensity, 0, 100) / 100
	S.Fh = clampN(P.FresnelHardness, 0, 100)
	S.Gi = clampN(P.GlareIntensity, 0, 120) / 100
	S.Gh = clampN(P.GlareHardness, 0, 100)
	S.gq = 1 + 11 * clampN(P.GlareConvergence, 0, 100) / 100
	S.Go = clampN(P.GlareOppositeSide, 0, 100) / 100
	local th = rad(clampN(P.GlareAngle, -180, 180))
	S.ax, S.ay = cos(th), -sin(th) -- trục glare (y hướng xuống màn hình)
	S.reach = max(S.T, S.FS, S.GS)
	S.dmax = max(1, min(S.reach * 1.25 + 1, hmin - 0.5))
	S.melt = S.dmax
	return S
end

-- Số điểm lưới backdrop theo kích thước đảo (trần 32x16 = 512 raycast mỗi lượt quét)
local function gridDims(W, H)
	return clampN(floor(W / 11 + 0.5), 8, 32), clampN(floor(H / 11 + 0.5), 4, 16)
end

-- Lưới MÉO một trục: mật độ điểm cao ở dải viền (nơi khúc xạ phóng đại mạnh nhất), thưa ở giữa.
-- Trả về pos[1..n] (px trong cửa sổ) và lut[px + 1] = chỉ số lưới thập phân tương ứng (để tra ngược khi lấy mẫu).
local function warpAxis(L, T, n)
	local band = max(T * 1.6, 1)
	local MS = 256
	local cum = newArray(MS + 1, 0)
	local acc = 0
	for k = 1, MS do
		local x = (k - 0.5) / MS * L
		local s = x < L - x and x or L - x
		local t = s / band
		if t > 1 then
			t = 1
		end
		acc = acc + 1 + 2.5 * (1 - smooth01(t))
		cum[k + 1] = acc
	end
	local pos = newArray(n, 0)
	pos[n] = L
	local k = 1
	for i = 2, n - 1 do
		local target = (i - 1) / (n - 1) * acc
		while k < MS and cum[k + 1] < target do
			k = k + 1
		end
		local c0, c1 = cum[k], cum[k + 1]
		local f = c1 > c0 and (target - c0) / (c1 - c0) or 0
		pos[i] = (k - 1 + f) / MS * L
	end
	local nl = ceil(L) + 2
	local lut = newArray(nl, 0)
	local i = 1
	for px = 0, nl - 1 do
		while i < n - 1 and pos[i + 1] < px do
			i = i + 1
		end
		local p0, p1 = pos[i], pos[i + 1]
		local f = p1 > p0 and (px - p0) / (p1 - p0) or 0
		if f < 0 then
			f = 0
		elseif f > 1 then
			f = 1
		end
		lut[px + 1] = (i - 1) + f
	end
	return pos, lut
end

-- Bản đồ tra cứu theo pixel (chỉ tính lại khi HÌNH DẠNG đổi): mask, độ sâu, vector dịch lấy mẫu, độ sáng Fresnel+glare
local function buildMaps(S, ds, step)
	local W, H = S.W, S.H
	local OW, OH = max(2, ceil(W / ds)), max(2, ceil(H / ds))
	local dsx, dsy = W / OW, H / OH
	local dsa = (dsx + dsy) * 0.5
	local N = OW * OH
	local hx, hy = S.hx, S.hy
	local mask, D = newArray(N, 0), newArray(N, 0)

	for y = 0, OH - 1 do
		local py = (y + 0.5) * dsy - hy
		for x = 0, OW - 1 do
			local px = (x + 0.5) * dsx - hx
			local phi = sdSuper(px, py, hx, hy, S.r, S.n)
			local idx = y * OW + x + 1
			local a = 0.5 - phi / dsa
			mask[idx] = a < 0 and 0 or (a > 1 and 1 or a)
			if phi >= 0 then
				D[idx] = -phi -- ngoài mép: độ sâu âm, liên tục qua mép nên đạo hàm trơn
			else
				D[idx] = depthInside(px, py, S, phi)
			end
		end
		if step then
			step()
		end
	end

	-- bảng dịch theo x = độ sâu / T (cùng một đường cong cho mọi pixel)
	local TB = 256
	local shiftTbl = newArray(TB, 0)
	for i = 1, TB do
		shiftTbl[i] = bezelShift((i - 0.5) / TB, S.rho, S.T)
	end

	local dx, dy, shade = newArray(N, 0), newArray(N, 0), newArray(N, 0)
	local T, reach = S.T, S.reach
	local ax, ay = S.ax, S.ay
	for y = 0, OH - 1 do
		local ym = y > 0 and y - 1 or 0
		local yp = y < OH - 1 and y + 1 or OH - 1
		for x = 0, OW - 1 do
			local idx = y * OW + x + 1
			local d = D[idx]
			if mask[idx] > 0 and d < reach then
				if d < 0 then
					d = 0
				end
				-- pháp tuyến = -gradient của trường độ sâu trơn (hướng RA NGOÀI)
				local xm = x > 0 and x - 1 or 0
				local xp = x < OW - 1 and x + 1 or OW - 1
				local gx = (D[y * OW + xp + 1] - D[y * OW + xm + 1]) / ((xp - xm) * dsx)
				local gy = (D[yp * OW + x + 1] - D[ym * OW + x + 1]) / ((yp - ym) * dsy)
				local gl = sqrt(gx * gx + gy * gy)
				if gl > 1e-6 then
					local nx, ny = -gx / gl, -gy / gl
					if d < T and S.rho > 1 then
						local k = floor(d / T * TB) + 1
						if k > TB then
							k = TB
						end
						local mag = shiftTbl[k]
						dx[idx], dy[idx] = -nx * mag, -ny * mag -- lấy mẫu sâu hơn vào trong
					end
					local sh = 0
					if S.FS > 0 and S.Fi > 0 and d < S.FS then
						sh = sh + S.Fi * edgeProfile(d / S.FS, S.Fh)
					end
					if S.GS > 0 and S.Gi > 0 and d < S.GS then
						local c = nx * ax + ny * ay
						local g = 0
						if c > 0 then
							g = c ^ S.gq
						elseif c < 0 then
							g = (-c) ^ S.gq * S.Go
						end
						sh = sh + S.Gi * g * edgeProfile(d / S.GS, S.Gh)
					end
					shade[idx] = sh > 1 and 1 or sh
				end
			end
		end
		if step then
			step()
		end
	end
	return { OW = OW, OH = OH, dsx = dsx, dsy = dsy, mask = mask, D = D, dx = dx, dy = dy, shade = shade }
end

-- Catmull-Rom (căng 0.5) trên chỉ số lưới, kẹp mép
local WX = { 0, 0, 0, 0 }
local WY = { 0, 0, 0, 0 }
local function crSet(w, t)
	local t2 = t * t
	local t3 = t2 * t
	w[1] = -0.5 * t3 + t2 - 0.5 * t
	w[2] = 1.5 * t3 - 2.5 * t2 + 1
	w[3] = -1.5 * t3 + 2 * t2 + 0.5 * t
	w[4] = 0.5 * t3 - 0.5 * t2
end

local function fetch3(gr, gg, gb, gw, gh, gx, gy)
	if gx < 0 then
		gx = 0
	elseif gx > gw - 1 then
		gx = gw - 1
	end
	if gy < 0 then
		gy = 0
	elseif gy > gh - 1 then
		gy = gh - 1
	end
	local x0, y0 = floor(gx), floor(gy)
	crSet(WX, gx - x0)
	crSet(WY, gy - y0)
	local last = gw - 1
	local xa, xb, xc, xd = x0 - 1, x0, x0 + 1, x0 + 2
	if xa < 0 then
		xa = 0
	end
	if xc > last then
		xc = last
	end
	if xd > last then
		xd = last
	end
	local w1, w2, w3, w4 = WX[1], WX[2], WX[3], WX[4]
	local r, g, b = 0, 0, 0
	for j = 1, 4 do
		local yy = y0 - 2 + j
		if yy < 0 then
			yy = 0
		elseif yy > gh - 1 then
			yy = gh - 1
		end
		local base = yy * gw + 1
		local wy = WY[j]
		local i1, i2, i3, i4 = base + xa, base + xb, base + xc, base + xd
		r = r + wy * (w1 * gr[i1] + w2 * gr[i2] + w3 * gr[i3] + w4 * gr[i4])
		g = g + wy * (w1 * gg[i1] + w2 * gg[i2] + w3 * gg[i3] + w4 * gg[i4])
		b = b + wy * (w1 * gb[i1] + w2 * gb[i2] + w3 * gb[i3] + w4 * gb[i4])
	end
	return clampN(r, 0, 1), clampN(g, 0, 1), clampN(b, 0, 1)
end

local function fetch1(ga, gw, gh, gx, gy)
	if gx < 0 then
		gx = 0
	elseif gx > gw - 1 then
		gx = gw - 1
	end
	if gy < 0 then
		gy = 0
	elseif gy > gh - 1 then
		gy = gh - 1
	end
	local x0, y0 = floor(gx), floor(gy)
	crSet(WX, gx - x0)
	crSet(WY, gy - y0)
	local last = gw - 1
	local xa, xb, xc, xd = x0 - 1, x0, x0 + 1, x0 + 2
	if xa < 0 then
		xa = 0
	end
	if xc > last then
		xc = last
	end
	if xd > last then
		xd = last
	end
	local w1, w2, w3, w4 = WX[1], WX[2], WX[3], WX[4]
	local v = 0
	for j = 1, 4 do
		local yy = y0 - 2 + j
		if yy < 0 then
			yy = 0
		elseif yy > gh - 1 then
			yy = gh - 1
		end
		local base = yy * gw + 1
		v = v + WY[j] * (w1 * ga[base + xa] + w2 * ga[base + xb] + w3 * ga[base + xc] + w4 * ga[base + xd])
	end
	return clampN(v, 0, 1)
end

-- Box blur một trục có kẹp mép
local function blurAxis(src, dst, lines, len, radius, stepA, stepB, step)
	local inv = 1 / (2 * radius + 1)
	local last = len - 1
	for line = 0, lines - 1 do
		local base = line * stepB + 1
		local sum = 0
		for k = -radius, radius do
			local idx = k < 0 and 0 or (k > last and last or k)
			sum = sum + src[base + idx * stepA]
		end
		for pos = 0, last do
			dst[base + pos * stepA] = sum * inv
			local ai = pos + radius + 1
			if ai > last then
				ai = last
			end
			local si = pos - radius
			if si < 0 then
				si = 0
			end
			sum = sum + src[base + ai * stepA] - src[base + si * stepA]
		end
		if step then
			step()
		end
	end
end

-- Gaussian xấp xỉ bằng 3 lần box blur (bán kính từng lần tính theo sigma)
local function boxRadii(sigma)
	local n = 3
	local wIdeal = sqrt(12 * sigma * sigma / n + 1)
	local wl = floor(wIdeal)
	if wl % 2 == 0 then
		wl = wl - 1
	end
	if wl < 1 then
		wl = 1
	end
	local wu = wl + 2
	local m = floor((12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4) + 0.5)
	local out = {}
	for i = 0, n - 1 do
		out[#out + 1] = ((i < m) and wl or wu) // 2
	end
	return out
end

-- Dựng lại ảnh kính: lấy mẫu lưới (khúc xạ + tách kênh) -> frost -> tint -> chồng Fresnel/glare -> RGBA8
local function reconstruct(S, M, G, step)
	local OW, OH = M.OW, M.OH
	local N = OW * OH
	local dsx, dsy = M.dsx, M.dsy
	local gw, gh, gr, gg, gb = G.gw, G.gh, G.gr, G.gg, G.gb
	local lutX, lutY = G.lutX, G.lutY
	local W, H = S.W, S.H
	local mR, mB = 1 + S.ca, 1 - S.ca
	local hasCA = S.ca > 0
	local R, Gc, B = newArray(N, 0), newArray(N, 0), newArray(N, 0)
	local mdx, mdy = M.dx, M.dy

	local function gxOf(sx)
		if sx < 0 then
			sx = 0
		elseif sx > W then
			sx = W
		end
		local k = floor(sx)
		local a = lutX[k + 1]
		return a + ((lutX[k + 2] or a) - a) * (sx - k)
	end
	local function gyOf(sy)
		if sy < 0 then
			sy = 0
		elseif sy > H then
			sy = H
		end
		local k = floor(sy)
		local a = lutY[k + 1]
		return a + ((lutY[k + 2] or a) - a) * (sy - k)
	end

	for y = 0, OH - 1 do
		local py = (y + 0.5) * dsy
		for x = 0, OW - 1 do
			local idx = y * OW + x + 1
			local px = (x + 0.5) * dsx
			local ddx, ddy = mdx[idx], mdy[idx]
			if ddx == 0 and ddy == 0 then
				R[idx], Gc[idx], B[idx] = fetch3(gr, gg, gb, gw, gh, gxOf(px), gyOf(py))
			elseif not hasCA then
				R[idx], Gc[idx], B[idx] = fetch3(gr, gg, gb, gw, gh, gxOf(px + ddx), gyOf(py + ddy))
			else
				R[idx] = fetch1(gr, gw, gh, gxOf(px + ddx * mR), gyOf(py + ddy * mR))
				Gc[idx] = fetch1(gg, gw, gh, gxOf(px + ddx), gyOf(py + ddy))
				B[idx] = fetch1(gb, gw, gh, gxOf(px + ddx * mB), gyOf(py + ddy * mB))
			end
		end
		if step then
			step()
		end
	end

	-- Frost: gaussian sigma = BlurRadius / 3 (đổi sang đơn vị pixel của ảnh ra)
	local sigma = S.blur / 3 / ((dsx + dsy) * 0.5)
	if sigma >= 0.45 then
		local tmp = newArray(N, 0)
		for _, ch in ipairs({ R, Gc, B }) do
			for _, rr in ipairs(boxRadii(sigma)) do
				if rr >= 1 then
					blurAxis(ch, tmp, OH, OW, rr, 1, OW, step)
					blurAxis(tmp, ch, OW, OH, rr, OW, 1, step)
				end
			end
		end
	end

	-- Tint + chồng Fresnel/glare (SAU frost) + alpha theo mask
	local buf = buffer.create(N * 4)
	local mask, D, shade = M.mask, M.D, M.shade
	local tR, tG, tB, tk = S.tR, S.tG, S.tB, S.tintAmt
	local aIn, aRim = S.aIn, S.aRim
	local band = S.T * 1.3
	for y = 0, OH - 1 do
		for x = 0, OW - 1 do
			local idx = y * OW + x + 1
			local m = mask[idx]
			local out = 0
			if m > 0 then
				local cr = R[idx] + (tR - R[idx]) * tk
				local cg = Gc[idx] + (tG - Gc[idx]) * tk
				local cb = B[idx] + (tB - B[idx]) * tk
				local d = D[idx]
				local rimK = 1 - smooth01((d > 0 and d or 0) / band)
				local aB = aIn + (aRim - aIn) * rimK
				local sh = shade[idx]
				local aT = sh + aB * (1 - sh)
				if aT > 1e-4 then
					local wB, wS = aB * (1 - sh) / aT, sh / aT
					cr, cg, cb = cr * wB + wS, cg * wB + wS, cb * wB + wS
					local a8 = floor(clampN(m * aT, 0, 1) * 255 + 0.5)
					local r8 = floor(clampN(cr, 0, 1) * 255 + 0.5)
					local g8 = floor(clampN(cg, 0, 1) * 255 + 0.5)
					local b8 = floor(clampN(cb, 0, 1) * 255 + 0.5)
					out = r8 + g8 * 256 + b8 * 65536 + a8 * 16777216
				end
			end
			buffer.writeu32(buf, (idx - 1) * 4, out)
		end
		if step then
			step()
		end
	end
	return buf, OW, OH
end
--[[CORE_END]]

----------------------------------------------------------------------
-- LIQUID GLASS v5 - phần ghép vào Roblox (lịch dựng ảnh, EditableImage, lấy mẫu backdrop bằng raycast)
-- Tên tham số đặt đúng theo README của GlassmorphicUI. Thickness / BlurRadius / FresnelSize / GlareSize / CornerRadius
-- nhận UDim (Scale tính theo CẠNH NGẮN của đảo, như README) hoặc số px.
----------------------------------------------------------------------
local LIQUID_DEFAULTS = {
	Thickness = UDim.new(0.15, 0), -- bề dày dải khúc xạ: vừa là độ sâu ống kính vừa là độ mạnh bẻ tia
	RefractionFactor = 2.1, -- 1 = tắt khúc xạ, tối đa 4
	ChromaticAberration = 0.2, -- đỏ lấy mẫu xa hơn 20%, xanh dương gần hơn 20% so với xanh lá
	CornerRadius = nil, -- nil = theo độ bo của thân đảo (UICorner)
	SuperEllipseFactor = 2, -- bài blog mặc định 3; ở đây là 2 vì thân đảo bị cắt bằng UICorner (cung tròn). Đặt 3+ nếu muốn góc vuông hơn
	FresnelSize = UDim.new(0.1, 0),
	FresnelHardness = 40,
	FresnelIntensity = 25,
	GlareSize = UDim.new(0.2, 0),
	GlareHardness = 40,
	GlareIntensity = 70, -- 0 = tắt glint
	GlareConvergence = 90,
	GlareOppositeSide = 50,
	GlareAngle = -50, -- độ, trục glare
	BlurRadius = UDim.new(0.06, 0), -- frost: sigma gaussian = BlurRadius / 3
	Transparency = nil, -- độ trong của lớp tint (nil = theo Style); 0 = đặc hoàn toàn
	MaxOutputResolution = 1024,
	OutputScale = 1, -- px cửa sổ trên mỗi pixel ảnh ra (tăng lên nếu máy yếu)
	TargetPixels = 45000, -- số pixel ảnh ra mong muốn; đảo lớn hơn sẽ tự giảm độ phân giải
	Backdrop = true, -- quét lại cảnh 3D theo chu kỳ (false = chỉ quét một lần)
	BackdropHz = 5,
	Sky = nil, -- { Top = Color3, Horizon = Color3 } nếu muốn ép màu trời
	Budget = 3, -- ms tối đa mỗi frame cho việc dựng ảnh + raycast
}

local Liquid = {}
Liquid.__index = Liquid

local SETTLE = 0.12 -- đảo đứng yên bao lâu thì mới dựng lại kính
local LENS_GAP = 0.08 -- giãn cách tối thiểu giữa hai lần dựng ảnh
local RAY_LEN = 2000
local MAX_HOPS = 4 -- số lần xuyên qua part gần như vô hình khi raycast
local DAY_TOP, DAY_HOR = { 0.36, 0.56, 0.88 }, { 0.74, 0.84, 0.94 }
local NIGHT_TOP, NIGHT_HOR = { 0.02, 0.03, 0.08 }, { 0.07, 0.09, 0.15 }
local SUNSET = { 0.95, 0.5, 0.3 }

local function lerp(a, b, t)
	return a + (b - a) * t
end

function Liquid.new(isl, body, opts)
	local P = {}
	for k, v in pairs(LIQUID_DEFAULTS) do
		P[k] = v
	end
	if type(opts) == "table" then
		for k, v in pairs(opts) do
			P[k] = v
		end
	end
	local self = setmetatable({}, Liquid)
	self.isl, self.body, self.P = isl, body, P
	self.writes = {}
	self.shape = { w = 0, h = 0, r = 0 }
	self.shapeKey = -1
	self.lastChange = os.clock()
	self.lensStart = 0
	self.lensDirty = true
	self.nextSample = 0
	self.enabled = true
	self.failed = false
	self.destroyed = false

	-- Một ảnh duy nhất cho cả tấm kính (khúc xạ + frost + tint + Fresnel/glare), alpha = mask byte
	self.lens = mk("ImageLabel", {
		Name = "Glass",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, body)

	-- Thử trước: tạo được EditableImage và gán được vào ImageLabel không?
	local probe = self:_newImage(2, 2)
	local okShow = probe ~= nil and self:_show(self.lens, probe)
	if probe then
		pcall(function()
			probe:Destroy()
		end)
	end
	pcall(function()
		self.lens.ImageContent = Content.none
	end)
	if not okShow then
		self.lens:Destroy()
		error("EditableImage/Content.fromObject không khả dụng")
	end
	return self
end

----------------------------------------------------------------------
-- EditableImage
----------------------------------------------------------------------
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
	warn("[DynamicIsland] Liquid glass tắt, quay về kính cổ điển: " .. tostring(reason))
	self.isl:_lgFailed()
end

----------------------------------------------------------------------
-- Việc chạy nền chia nhỏ theo ngân sách ms (coroutine)
----------------------------------------------------------------------
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

-- Trả về: done, kết quả...
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

----------------------------------------------------------------------
-- Hình dạng đảo: gọi mỗi khi đảo đổi kích thước/bán kính (đơn vị của đảo, trước UIScale).
-- Bản đồ tra cứu CHỈ tính lại khi hình dạng đổi và đảo đã đứng yên (như bài blog).
----------------------------------------------------------------------
function Liquid:NoteShape(w, h, r)
	local sh = self.shape
	sh.w, sh.h, sh.r = w, h, r
	local key = floor(w + 0.5) * 1000000 + floor(h + 0.5) * 1000 + floor(r * 2)
	if key ~= self.shapeKey then
		self.shapeKey = key
		self.lastChange = os.clock()
		self.lensDirty = true
		self.S, self.maps = nil, nil
		self.mapsJob, self.lensJob = nil, nil -- huỷ việc dở; dựng lại khi đảo đứng yên
		self.samp = nil
	end
end

-- Quy đổi tham số sang px theo hình dạng hiện tại + dựng lưới backdrop méo cho hình dạng đó
function Liquid:_prepare()
	local sh = self.shape
	if sh.w < 12 or sh.h < 12 then
		return false
	end
	local isl, P = self.isl, self.P
	local S = resolveShape(sh.w, sh.h, sh.r, P)
	if S.hmin < 3 then
		return false
	end
	S.ds = max(
		1,
		P.OutputScale or 1,
		sqrt(sh.w * sh.h / (P.TargetPixels or 45000)),
		max(sh.w, sh.h) / (P.MaxOutputResolution or 1024)
	)
	local base = isl._style.base
	S.tR, S.tG, S.tB = base.R, base.G, base.B
	if P.Transparency ~= nil then
		S.tintAmt = clampN(1 - P.Transparency, 0, 1)
	else
		S.tintAmt = isl._style.tint or 0.4
	end
	self.S = S
	self.maps, self.mapsJob, self.lensJob = nil, nil, nil
	self:_ensureGrid(S)
	return true
end

----------------------------------------------------------------------
-- Lưới backdrop thô và MÉO (dày ở dải viền)
----------------------------------------------------------------------
function Liquid:_ensureGrid(S)
	local gw, gh = gridDims(S.W, S.H)
	local posX, lutX = warpAxis(S.W, S.T, gw)
	local posY, lutY = warpAxis(S.H, S.T, gh)
	local base = self.isl._style.base
	local n = gw * gh
	local nr, ng, nb = newArray(n, base.R), newArray(n, base.G), newArray(n, base.B)
	local old = self.grid
	if old then
		-- giữ lại màu cũ (tương ứng theo chỉ số chuẩn hoá) để đổi hình dạng không bị nhấp nháy
		for j = 0, gh - 1 do
			for i = 0, gw - 1 do
				local oi = clampN(floor(i / (gw - 1) * (old.gw - 1) + 0.5), 0, old.gw - 1)
				local oj = clampN(floor(j / (gh - 1) * (old.gh - 1) + 0.5), 0, old.gh - 1)
				local ok = oj * old.gw + oi + 1
				local d = j * gw + i + 1
				nr[d], ng[d], nb[d] = old.gr[ok], old.gg[ok], old.gb[ok]
			end
		end
	end
	self.grid = {
		gw = gw, gh = gh, gr = nr, gg = ng, gb = nb,
		posX = posX, posY = posY, lutX = lutX, lutY = lutY,
		fresh = old == nil,
	}
	self.samp = nil
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
	local warm = clampN(1 - abs(sunY - 0.02) / 0.25, 0, 1) * 0.55 -- hoàng hôn/bình minh ám cam ở chân trời
	horR, horG, horB = lerp(horR, SUNSET[1], warm), lerp(horG, SUNSET[2], warm), lerp(horB, SUNSET[3], warm)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		local c = atmo.Color
		horR, horG, horB = lerp(horR, c.R, 0.35), lerp(horG, c.G, 0.35), lerp(horB, c.B, 0.35)
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
		amb = 0.22 + 0.4 * day,
		topR = topR, topG = topG, topB = topB,
		horR = horR, horG = horG, horB = horB,
	}
end

function Liquid:_skyColor(dir)
	local L = self.sky
	local e = dir.Y
	if e < 0 then
		e = 0
	end
	local t = e ^ 0.55
	return L.horR + (L.topR - L.horR) * t, L.horG + (L.topG - L.horG) * t, L.horB + (L.topB - L.horB) * t
end

-- Màu một điểm trên màn hình: trúng vật -> màu vật nhân sáng đơn giản (Lambert + sương xa), trượt -> màu trời
function Liquid:_colorOf(res, dir)
	if not res then
		return self:_skyColor(dir)
	end
	local inst = res.Instance
	if not inst then
		return nil
	end
	local L = self.sky
	local r, g, b
	if inst:IsA("Terrain") then
		local c = inst:GetMaterialColor(res.Material)
		r, g, b = c.R, c.G, c.B
	else
		local tr = inst.Transparency
		if tr >= 0.9 then
			return nil -- vật vô hình (hitbox...): giữ giá trị cũ
		end
		local c = inst.Color
		r, g, b = c.R, c.G, c.B
		if tr > 0.05 then
			local sr, sg, sb = self:_skyColor(dir)
			r, g, b = r + (sr - r) * tr, g + (sg - g) * tr, b + (sb - b) * tr
		end
	end
	local nd = res.Normal:Dot(L.sun)
	if nd < 0 then
		nd = 0
	end
	local sh = L.amb + (1 - L.amb) * nd
	r, g, b = r * sh, g * sh, b * sh
	local hz = (res.Distance / 1500) ^ 1.5 * 0.5
	if hz > 0.5 then
		hz = 0.5
	end
	return r + (L.horR - r) * hz, g + (L.horG - g) * hz, b + (L.horB - b) * hz
end

-- Raycast xuyên qua các part gần như vô hình (hitbox, kính...) tối đa MAX_HOPS lần, như bài blog
function Liquid:_cast(origin, dir)
	local params = self.rayParams
	local res = workspace:Raycast(origin, dir, params)
	local hops = 0
	while res and hops < MAX_HOPS do
		local inst = res.Instance
		if inst and not inst:IsA("Terrain") and inst.Transparency >= 0.95 then
			hops = hops + 1
			local list = params.FilterDescendantsInstances
			list[#list + 1] = inst
			params.FilterDescendantsInstances = list
			res = workspace:Raycast(origin, dir, params)
		else
			break
		end
	end
	if hops > 0 then
		params.FilterDescendantsInstances = {}
	end
	return res
end

function Liquid:_sample(now, dl)
	local g, S = self.grid, self.S
	if not g or not S then
		return
	end
	local st = self.samp
	if not st then
		if now < self.nextSample then
			return
		end
		self.sky = self:_skySnapshot()
		self.rayParams = self.rayParams or RaycastParams.new()
		st = { i = 0, n = g.gw * g.gh, delta = 0, fresh = g.fresh }
		self.samp = st
	end
	local cam = workspace.CurrentCamera
	local ap, sz = self.body.AbsolutePosition, self.body.AbsoluteSize
	if not cam or sz.X < 4 or sz.Y < 4 then
		self.samp = nil
		return
	end
	local gw, W, H = g.gw, S.W, S.H
	local k = st.fresh and 1 or 0.55 -- làm mượt theo thời gian để khỏi nhấp nháy
	while st.i < st.n and os.clock() < dl do
		local i = st.i
		local cx, cy = i % gw, floor(i / gw)
		-- điểm lưới (đã méo) trong cửa sổ -> toạ độ màn hình
		local ray = cam:ViewportPointToRay(ap.X + g.posX[cx + 1] / W * sz.X, ap.Y + g.posY[cy + 1] / H * sz.Y)
		local res = self:_cast(ray.Origin, ray.Direction * RAY_LEN)
		local r, gg, b = self:_colorOf(res, ray.Direction)
		if r then
			local idx = i + 1
			local o1, o2, o3 = g.gr[idx], g.gg[idx], g.gb[idx]
			local n1, n2, n3 = o1 + (r - o1) * k, o2 + (gg - o2) * k, o3 + (b - o3) * k
			st.delta = st.delta + abs(n1 - o1) + abs(n2 - o2) + abs(n3 - o3)
			g.gr[idx], g.gg[idx], g.gb[idx] = n1, n2, n3
		end
		st.i = i + 1
	end
	if st.i >= st.n then
		self.samp = nil
		self.sampledOnce = true
		g.fresh = false
		self.nextSample = now + 1 / max(self.P.BackdropHz or 5, 0.2)
		if st.fresh or st.delta / (st.n * 3) > 0.004 then
			self.lensDirty = true -- nền đổi đủ nhiều mới dựng lại ảnh (đứng yên = không tốn gì thêm)
		end
	end
end

----------------------------------------------------------------------
-- Dựng lại ảnh kính từ bản đồ hình dạng + lưới backdrop hiện tại (trong coroutine)
----------------------------------------------------------------------
function Liquid:_startLens(now)
	local S, M, g = self.S, self.maps, self.grid
	if not (S and M and g) then
		return
	end
	local hasDof = self.isl._dof ~= nil -- có mờ nền thật thì phần giữa trong suốt, chỉ dải viền khúc xạ hiện lên
	S.aIn = hasDof and 0 or 1
	S.aRim = hasDof and 0.55 or 1
	local G = {
		gw = g.gw, gh = g.gh,
		gr = table.clone(g.gr), gg = table.clone(g.gg), gb = table.clone(g.gb),
		lutX = g.lutX, lutY = g.lutY,
	}
	self.lensJob = self:_newJob(function(step)
		return reconstruct(S, M, G, step)
	end)
	self.lensDirty = false
	self.lensStart = now
end

function Liquid:_flush(w)
	if not self.lensImg or self.lensW ~= w.w or self.lensH ~= w.h then
		local img = self:_newImage(w.w, w.h)
		if not img or not self:_write(img, w.w, w.h, w.buf) or not self:_show(self.lens, img) then
			self:_fail("không tạo/ghi/gán được ảnh kính")
			return
		end
		local old = self.lensImg
		self.lensImg, self.lensW, self.lensH = img, w.w, w.h
		if old then
			pcall(function()
				old:Destroy()
			end)
		end
	elseif not self:_write(self.lensImg, w.w, w.h, w.buf) then
		self:_fail("ghi ảnh kính lỗi")
	end
end

----------------------------------------------------------------------
-- Mỗi Heartbeat: bản đồ hình dạng -> ghi tối đa 1 ảnh -> lấy mẫu -> dựng lại ảnh, tất cả trong ngân sách ms
----------------------------------------------------------------------
function Liquid:Step()
	if self.failed or self.destroyed or not self.enabled then
		return
	end
	local isl = self.isl
	if isl._destroyed or isl._hidden or not isl._glass or not isl._gui.Enabled then
		return
	end
	local now = os.clock()
	local deadline = now + (self.P.Budget or 3) / 1000
	local settled = now - self.lastChange >= SETTLE

	-- 1) hình dạng đã đứng yên: quy đổi tham số + dựng lưới méo, rồi bản đồ tra cứu theo pixel
	if settled and not self.S then
		self:_prepare()
	end
	if self.S and not self.maps and not self.mapsJob then
		local S = self.S
		self.mapsJob = self:_newJob(function(step)
			return buildMaps(S, S.ds, step)
		end)
	end
	local mj = self.mapsJob
	if mj and os.clock() < deadline then
		local done, maps = self:_resume(mj, deadline)
		if done and self.mapsJob == mj then
			self.mapsJob = nil
			if maps then
				self.maps = maps
				self.lensDirty = true
			end
		end
	end

	-- 2) EditableImage chỉ cho cập nhật 1 lần/frame -> mỗi frame ghi tối đa một ảnh
	local w = table.remove(self.writes, 1)
	if w then
		self:_flush(w)
	end

	-- 3) backdrop
	if self.S and os.clock() < deadline and (self.P.Backdrop ~= false or not self.sampledOnce) then
		local ok, err = pcall(self._sample, self, now, min(deadline, os.clock() + 0.0015))
		if not ok then
			self.sampErrors = (self.sampErrors or 0) + 1
			self.samp = nil
			if self.sampErrors >= 3 then
				self.P.Backdrop = false
				self.sampledOnce = true
				warn("[DynamicIsland] Tắt lấy mẫu backdrop vì lỗi: " .. tostring(err))
			end
		end
	end

	-- 4) dựng lại ảnh kính
	if
		self.lensDirty
		and self.maps
		and not self.lensJob
		and not self.mapsJob
		and #self.writes == 0
		and settled
		and now - self.lensStart >= LENS_GAP
	then
		self:_startLens(now)
	end
	local lj = self.lensJob
	if lj and os.clock() < deadline then
		local done, buf, OW, OH = self:_resume(lj, deadline)
		if done and self.lensJob == lj then
			self.lensJob = nil
			if buf then
				self.writes[#self.writes + 1] = { buf = buf, w = OW, h = OH }
			end
		end
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

----------------------------------------------------------------------
-- Điều khiển
----------------------------------------------------------------------
function Liquid:SetVisible(on)
	self.enabled = on and true or false
	self.lens.Visible = self.enabled
	if self.enabled then
		self.lensDirty = true
	end
end

function Liquid:Refresh()
	self.sampledOnce = false
	self.nextSample = 0
	self.lensDirty = true
end

function Liquid:SetParams(opts)
	for k, v in pairs(opts or {}) do
		self.P[k] = v
	end
	self.S, self.maps = nil, nil
	self.mapsJob, self.lensJob = nil, nil
	self.writes = {}
	self.lastChange = os.clock()
	self:Refresh()
end

function Liquid:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.lensImg then
		pcall(function()
			self.lensImg:Destroy()
		end)
		self.lensImg = nil
	end
	pcall(function()
		self.lens:Destroy()
	end)
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
		Liquid = config.Liquid ~= false and (config.Liquid or true) or false,
		Top = config.Top or 11,
		Scale = config.Scale, -- nil = tự co theo màn hình
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
	self:_lgCreate() -- lens (ZIndex 1) + rim (ZIndex 3); lỗi thì tự dùng kính cổ điển

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
	local focus = b.FocusDistance or d * 2
	if self._dofFocus ~= focus then
		self._dofFocus = focus
		self._dof.FocusDistance = focus
	end

	-- Lens breathing: một callback RenderStep duy nhất cập nhật hình học mỗi frame.
	-- Không dùng hàng trăm loop song song: chúng không tăng độ chân thực, chỉ tốn FPS.
	-- Inset + reserve giữ mép vùng lens nằm bên trong thân đảo.
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
	if self._glass then
		self:_lgCreate()
		if self._lg then
			self._lg:SetVisible(true)
		end
	elseif self._lg then
		self._lg:SetVisible(false)
	end
	self._lgOn = self._glass and self._lg ~= nil
	self:_apply()
	self:_render(false)
end

----------------------------------------------------------------------
-- Liquid glass: tạo / tắt / chỉnh khi đang chạy
----------------------------------------------------------------------
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
end

-- Engine tự báo lỗi (EditableImage hết bộ nhớ, bị chặn...): bỏ engine, bật lại kính cổ điển
function Island:_lgFailed()
	self._lgOn = false
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

-- false = kính cổ điển; true/bảng = bật engine mới (bảng = ghi đè LIQUID_DEFAULTS)
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
	self:_apply()
end

-- Ép quét lại backdrop + dựng lại lens (vd. vừa teleport / đổi cảnh)
function Island:RefreshGlass()
	if self._lg then
		self._lg:Refresh()
	end
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
			Text = "Liquid glass đã sẵn sàng",
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
