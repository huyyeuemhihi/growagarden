--[[
	DynamicIsland.lua  v5.1  -  Dynamic Island (iPhone 14 Pro) + LIQUID GLASS dựng lại theo bài
	"Reproducing Liquid Glass in Roblox" của boatbomber (boatbomber.com/blog/liquid-glass)
	-------------------------------------------------------------------------------
	MỚI Ở v5.1 - kính trong suốt thật, không màu nền
	• Liquid bật = thân đảo KHÔNG còn tô màu (BackgroundTransparency = 1), tắt tint màu activity, tắt lớp depth/viền cổ điển.
	• Lens = frost thuần của backdrop (100% màu cảnh, không trộn màu nền), độ mờ đục chỉnh bằng Opacity (mặc định 0.8)
	  nên che được cả nút CoreGui phía sau thay vì để lộ nét. BlurRadius mặc định 20. Veil = nâng sáng trắng rất nhẹ.
	• GIỚI HẠN không vượt được: Roblox không cho đọc màn hình, nên "nền" trong kính là cảnh 3D dựng lại bằng raycast (không có
	  ScreenGui/CoreGui, bóng đổ, texture). Opacity cao = che nền thật nhưng màu kính lệch theo xấp xỉ đó.

	MỚI Ở v5 - lõi kính chân thật hơn (chỉ đổi phần tính ảnh, API giữ nguyên)
	• Khúc xạ theo định luật Snell trên mặt vát lồi dạng squircle (z = (1-(1-s/T)^4)^(1/4)), thay cho đường cong
	  bậc hai tự chế của v4: độ lệch cực đại ở sát mép rồi tắt trơn về 0 ở s = T (không nếp gấp).
	• Tán sắc thật: mỗi kênh R/G/B dùng một chiết suất riêng (xanh dương cao hơn đỏ), không còn chỉ nhân hệ số.
	• Lưới backdrop từ raycast được tái dựng bằng BICUBIC (Catmull-Rom) thay cho song tuyến -> hết vết ô vuông/kim cương.
	• Lưới lấy mẫu KHÔNG đều: dày hơn ở sát mép (nơi khúc xạ mạnh), thưa ở giữa (chỉ còn frost). Chỉnh bằng SamplerWarp.
	• Frost gaussian đúng nghĩa: 3 lượt box blur với bán kính tính theo "boxes for gauss" (v4 chỉ 2 lượt = tam giác).
	• Thứ tự đúng như bài blog: khúc xạ -> frost -> tint; Fresnel + glare nằm ở ảnh RIM riêng, cộng SAU frost nên không bị blur.
	• Thêm Saturation (nền đậm màu hơn nhẹ) và BevelShade (mặt vát sáng/tối theo nguồn sáng trên-trái).
	• Lens gần full-res ở đảo nhỏ (v4 hạ xuống ~2px/pixel nên mép bị nhoè).
	• Lưu ý đổi ngữ nghĩa: RefractionFactor giờ là chiết suất n (1 = tắt, ~1.5 = kính thật), mặc định 1.6.

	MỚI Ở v4 - làm lại cách dựng kính
	• Bỏ kiểu chồng frame/UIStroke giả. Kính giờ do hai ảnh EditableImage dựng bằng toán trên SDF bo góc:
	    1) LENS: dịch điểm lấy mẫu backdrop theo độ sâu tới mép -> khúc xạ, tách kênh màu (chromatic aberration),
	       rồi blur frosted (gaussian ~ 2 lần box blur), trộn với màu kính.
	    2) RIM: viền Fresnel + glare (glint) tính từ khoảng cách tới mép và pháp tuyến, bake MỘT lần cho một góc,
	       lật gương ra 4 góc, hiển thị bằng 9-slice -> luôn khớp đúng đường bo khi đảo co giãn (hết vệt sáng lệch).
	• Backdrop: Roblox không cho đọc framebuffer, nên "dựng lại cảnh" bằng raycast lưới thưa (tối đa 28x14 điểm),
	  chỗ trượt = màu trời theo mô hình ngày/đêm. Đây là xấp xỉ, không phải ảnh thật của màn hình.
	• Hiệu năng: bán kính viền có cache (lượng tử 2px), lens chỉ dựng lại khi đảo đứng yên hoặc nền đổi,
	  mọi việc chia nhỏ trong ngân sách Budget (ms/frame), tối đa 1 lần ghi EditableImage mỗi frame.
	• Không có EditableImage (hoặc lỗi) -> tự quay về kính cổ điển của v3.

	MỚI Ở v3: hết tràn viền (mọi lớp nằm TRONG thân CanvasGroup), vùng mờ nền thật (Part DepthOfField) thu vào Inset px.
	MỚI Ở v2: spring kiểu SwiftUI, icon dùng chung (matched geometry), nội dung vào theo tầng, số/chữ "roll", kéo dây cao su.

	CÁCH DÙNG (API giữ nguyên như v1-v3, thêm tuỳ chọn Liquid)
	    local Island = loadstring(game:HttpGet("LINK_RAW_CUA_BAN"))()
	    local GlassmorphicUI = require(game:GetService("ReplicatedStorage").Packages.GlassmorphicUI)
	    local island = Island.new({
	        GlassmorphicUI = GlassmorphicUI, -- dùng engine gốc từ repo boatbeaker
	        Top = 11, Scale = nil,          -- Scale nil = tự co theo màn hình
	        Style = "Frosted",              -- "Frosted" = kính xám mờ đục | "Dark" = kính đen kiểu iOS
	        RealBlur = true,                -- mờ nền thật (Part Glass + DepthOfField); false = tắt; hoặc bảng thông số:
	                                        --   { NearIntensity = 1, Inset = 6, Slices = 8, Distance = nil, FocusDistance = nil, InFocusRadius = 100 }
	        Liquid = true,                  -- engine kính mới; false = kính cổ điển v3; hoặc bảng tuỳ chỉnh (xem LIQUID_DEFAULTS):
	                                        --   { Thickness = 16, RefractionFactor = 1.6, ChromaticAberration = 0.2, BlurRadius = 12,
	                                        --     Saturation = 1.15, BevelShade = 0.1, SamplerWarp = 0.5,
	                                        --     FresnelIntensity = 22, GlareIntensity = 45 (0 = tắt glint), Backdrop = true,
	                                        --     BackdropHz = 5, Sky = { Top = Color3, Horizon = Color3 }, Budget = 3 }
	        Glass = true,                   -- false = đen đặc 100% như iPhone thật (tự tắt luôn RealBlur và Liquid)
	        Transparency = nil,             -- độ trong của thân kính cổ điển (nil = theo Style); bị bỏ qua khi Liquid bật
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
	• CHƯA kiểm chứng trong Roblox thật. Lõi toán v5 (SDF, bảng Snell, warp lưới, bicubic, blur, bake viền) đã chạy bằng
	  Lua 5.4 với shim `buffer` và xuất ảnh để xem bằng mắt; phần gọi API Roblox (EditableImage, 9-slice, raycast) chỉ được
	  kiểm tra cú pháp, chưa chạy. Nếu EditableImage bị chặn trên executor của bạn, đảo tự dùng kính cổ điển.
	• Bài blog là trang JS nên mình chỉ đọc được đoạn trích (thứ tự khúc xạ -> frost -> fresnel/glare, SDF + superellipse,
	  bicubic, lấy mẫu dày ở mép). Công thức cụ thể (Snell trên squircle, warp sin) là cách mình dựng theo mô tả đó,
	  không phải mã gốc của tác giả. Tham số tinh chỉnh: RefractionFactor, Thickness, BevelHeight, BlurRadius.
	• Cần client có AssetService:CreateEditableImage, EditableImage:WritePixelsBuffer và ImageLabel.ImageContent.
	• Backdrop bằng raycast chỉ thấy vật thể 3D (màu Part, không texture/ánh sáng thật/skybox): đó là lý do màu kính
	  là gần đúng. Không thấy được ScreenGui khác. Chỉnh Sky = {...} nếu màu trời lệch.
	• Thân vẫn bị cắt bằng UICorner (bo tròn thường, không phải squircle liên tục của Apple) nên chưa dùng góc superellipse như blog.
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
	Frosted = { base = Color3.fromRGB(66, 64, 68), transparency = 0.4, depthAlpha = 0.035, sheenTop = 0.84 },
	Dark = { base = Color3.fromRGB(30, 32, 38), transparency = 0.12, depthAlpha = 0.07, sheenTop = 0.9 },
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
-- LIQUID GLASS - lõi tính toán thuần (không gọi API Roblox): bake viền + dựng lại pixel lens
----------------------------------------------------------------------
--[[CORE_BEGIN]]
local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max

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

-- Bake viền kính (Fresnel + glare) cho MỘT góc rồi lật gương ra 4 góc -> ảnh (2*Cq+2)^2 dùng cho 9-slice.
-- rq = bán kính góc (px), q = siêu mẫu. Mọi thứ suy ra từ khoảng cách tới mép (SDF) và pháp tuyến.
local function bakeRim(rq, q, P, step)
	local Cq = rq * q
	local n = Cq + 1
	local Fs = min(P.FresnelSize, rq)
	local Gs = min(P.GlareSize, rq)
	local Fi = P.FresnelIntensity / 100
	local Gi = P.GlareIntensity / 100
	local Fe = 1 + 4 * (P.FresnelHardness / 100)
	local Ge = 1 + 4 * (P.GlareHardness / 100)
	local Gc = 0.5 + 3 * (P.GlareConvergence / 100)
	local quad = newArray(n * n, 0)
	local reach = max(Fs, Gs)
	local inner2 = rq > reach and (rq - reach) * (rq - reach) or -1 -- d^2 nhỏ hơn mức này = vùng giữa kính, bỏ qua
	for j = 0, Cq do
		for i = 0, Cq do
			if not (i == Cq and j == Cq) then
				local s, nx, ny
				local skip = false
				if i == Cq then
					s, nx, ny = (j + 0.5) / q, 0, 1 -- dải giữa (kéo giãn): chỉ phụ thuộc khoảng cách tới mép trên
					skip = s >= reach
				elseif j == Cq then
					s, nx, ny = (i + 0.5) / q, 1, 0
					skip = s >= reach
				else
					local qx, qy = rq - (i + 0.5) / q, rq - (j + 0.5) / q
					local d2 = qx * qx + qy * qy
					if d2 < inner2 then
						skip = true
					else
						local d = sqrt(d2)
						s, nx, ny = rq - d, qx / d, qy / d
					end
				end
				local m = skip and 0 or (s * q + 0.5) -- khử răng cưa mép
				if m > 0 then
					if m > 1 then
						m = 1
					end
					local sp = s > 0 and s or 0
					local a = 0
					if Fs > 0 and sp < Fs then
						a = a + Fi * (1 - sp / Fs) ^ Fe
					end
					if Gs > 0 and sp < Gs then
						-- glint mạnh ở góc chéo, yếu dọc cạnh thẳng
						local ang = 0.1 + 0.9 * (2 * nx * ny) ^ Gc
						a = a + Gi * ang * (1 - sp / Gs) ^ Ge
					end
					if a > 1 then
						a = 1
					end
					quad[j * n + i + 1] = a * m
				end
			end
		end
		if step then
			step()
		end
	end

	local S = 2 * Cq + 2
	local buf = buffer.create(S * S * 4)
	for Y = 0, S - 1 do
		local jy = Y < Cq and Y or (Y < Cq + 2 and Cq or S - 1 - Y)
		local rowBase = jy * n + 1
		for X = 0, S - 1 do
			local ix = X < Cq and X or (X < Cq + 2 and Cq or S - 1 - X)
			local a8 = floor(quad[rowBase + ix] * 255 + 0.5)
			buffer.writeu32(buf, (Y * S + X) * 4, 16777215 + a8 * 16777216)
		end
		if step then
			step()
		end
	end
	return buf, S, Cq
end

-- Lưới backdrop KHÔNG đều: ô dày hơn ở sát mép (nơi khúc xạ mạnh), thưa ở giữa (nơi chỉ còn frost).
-- x/len = u - beta*sin(2*pi*u)/(2*pi); beta = 0 là lưới đều, beta < 1 để hàm đơn điệu.
local PI2 = 2 * math.pi
local function warp01(u, beta)
	return u - beta * math.sin(PI2 * u) / PI2
end

-- Bảng nghịch đảo: vị trí px (0..len) -> chỉ số ô thập phân trên lưới n ô (đã warp). lut[p + 1] ứng với x = p.
local function buildInv(len, n, beta)
	local pos = {}
	for i = 0, n - 1 do
		pos[i] = len * warp01((i + 0.5) / n, beta)
	end
	local size = ceil(len) + 2
	local lut = {}
	local k = 0
	for p = 0, size do
		while k < n - 2 and p >= pos[k + 1] do
			k = k + 1
		end
		local g
		if p <= pos[0] then
			g = 0
		elseif p >= pos[n - 1] then
			g = n - 1
		else
			g = k + (p - pos[k]) / (pos[k + 1] - pos[k])
		end
		lut[p + 1] = g
	end
	return lut
end

local function lutGet(lut, x)
	if x < 0 then
		x = 0
	end
	local p = floor(x)
	local f = x - p
	local a = lut[p + 1]
	local b = lut[p + 2] or a
	return a + (b - a) * f
end

-- Catmull-Rom: trọng số 4 điểm lân cận (tái dựng bicubic cho lưới nguồn thưa)
local function crw(t)
	local t2 = t * t
	local t3 = t2 * t
	return (-t3 + 2 * t2 - t) * 0.5, (3 * t3 - 5 * t2 + 2) * 0.5, (-3 * t3 + 4 * t2 + t) * 0.5, (t3 - t2) * 0.5
end

-- Nội suy bicubic một kênh trên lưới gw x gh (mảng phẳng 1-based), kẹp mép
local function bic1(arr, gw, gh, gx, gy)
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
	local a0, a1, a2, a3 = crw(gx - x0)
	local b0, b1, b2, b3 = crw(gy - y0)
	local xm, xp, xq = x0 - 1, x0 + 1, x0 + 2
	if xm < 0 then
		xm = 0
	end
	if xp > gw - 1 then
		xp = gw - 1
	end
	if xq > gw - 1 then
		xq = gw - 1
	end
	local ym, yp, yq = y0 - 1, y0 + 1, y0 + 2
	if ym < 0 then
		ym = 0
	end
	if yp > gh - 1 then
		yp = gh - 1
	end
	if yq > gh - 1 then
		yq = gh - 1
	end
	local o = ym * gw + 1
	local r0 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = y0 * gw + 1
	local r1 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = yp * gw + 1
	local r2 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	o = yq * gw + 1
	local r3 = arr[o + xm] * a0 + arr[o + x0] * a1 + arr[o + xp] * a2 + arr[o + xq] * a3
	return r0 * b0 + r1 * b1 + r2 * b2 + r3 * b3
end

-- Bảng độ lệch khúc xạ theo độ sâu s (0..T) bằng định luật Snell trên mặt vát lồi (squircle):
--   cao độ z(s) = bevel * (1 - (1 - s/T)^4)^(1/4)  (0 ở mép, bevel ở mặt phẳng giữa)
--   tia thẳng đứng vào kính, góc tới = atan(dz/ds), gãy theo n = ior, rồi đi tiếp qua bề dày (z + base) tới nền.
-- Trả về mảng D[1..N+1] (px) ứng với s = k*T/N. Trơn về 0 tại s = T (không có nếp gấp).
local function refractTable(T, ior, bevel, base, N)
	local D = {}
	if ior <= 1.0001 then
		for k = 0, N do
			D[k + 1] = 0
		end
		return D
	end
	for k = 0, N do
		local x = k / N
		if x < 0.25 / N then
			x = 0.25 / N -- độ dốc vô hạn ở đúng mép: lấy mẫu nhích vào một chút
		end
		local om = 1 - x
		local p4 = om * om * om * om
		local h = (1 - p4) ^ 0.25
		local dh = om * om * om * (1 - p4) ^ -0.75
		local slope = bevel / T * dh
		local th1 = math.atan(slope)
		local s2 = math.sin(th1) / ior
		if s2 > 1 then
			s2 = 1
		end
		local th2 = math.asin(s2)
		D[k + 1] = (bevel * h + base) * math.tan(th1 - th2)
	end
	return D
end

local function tabGet(D, N, u) -- u = s / T trong 0..1
	local f = u * N
	local k = floor(f)
	if k >= N then
		return D[N + 1]
	end
	local t = f - k
	return D[k + 1] + (D[k + 2] - D[k + 1]) * t
end

-- 3 lần box blur xấp xỉ gaussian(sigma): trả về bán kính từng lượt (thuật toán "boxes for gauss")
local function gaussBoxRadii(sigma)
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
	for i = 1, n do
		local size = (i <= m) and wl or wu
		out[i] = (size - 1) // 2
	end
	return out
end

-- Box blur một trục có kẹp mép
local function blurAxis(src, dst, lines, len, rad, stepA, stepB, step)
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
			local ai = pos + rad + 1
			if ai > last then
				ai = last
			end
			local si = pos - rad
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

-- Dựng pixel cho ảnh "lens", đúng thứ tự bài blog:
--   SDF bo góc -> độ sâu + pháp tuyến -> khúc xạ Snell (+ tán sắc: mỗi kênh một chiết suất)
--   -> tái dựng bicubic từ lưới nguồn không đều -> frost gaussian -> tint.
-- (Fresnel + glare nằm ở ảnh RIM riêng, cộng SAU frost nên không bị blur.)
-- Trả về buffer RGBA8 cỡ LW*LH.
local function renderLens(P, step)
	local W, H, r = P.W, P.H, P.R
	local LW, LH = max(2, ceil(W / P.ds)), max(2, ceil(H / P.ds))
	local dsx, dsy = W / LW, H / LH
	local T = min(P.T, 0.9 * r, min(W, H) / 2 - 1)
	if T < 1 then
		T = 0
	end
	local gw, gh = P.gw, P.gh
	local gr, gg, gb = P.gr, P.gg, P.gb
	local beta = P.warp or 0
	local lutX, lutY = buildInv(W, gw, beta), buildInv(H, gh, beta)
	local N = LW * LH
	local R, G, B, Sd, Sh = newArray(N, 0), newArray(N, 0), newArray(N, 0), newArray(N, 0), newArray(N, 1)
	local hx, hy = W / 2, H / 2
	local ex, ey = hx - r, hy - r
	local maxX, maxY = W - 0.5, H - 0.5

	-- chiết suất mỗi kênh: đỏ thấp nhất, xanh dương cao nhất (tán sắc thật)
	local ior = clampN(P.ior, 1, 4)
	local disp = clampN(P.ca, 0, 1) * 0.12 * ior
	local TN = 48
	local bevel = (P.bevel or 1) * T
	local base = (P.glassBase or 0.45) * T
	local DR, DG, DB
	if T > 0 then
		DR = refractTable(T, max(1, ior - disp), bevel, base, TN)
		DG = refractTable(T, ior, bevel, base, TN)
		DB = refractTable(T, ior + disp, bevel, base, TN)
	end
	local shadeK = P.shade or 0
	local lx, ly = -0.55, -0.835 -- hướng về nguồn sáng (trên-trái)

	for y = 0, LH - 1 do
		local py = (y + 0.5) * dsy
		local dy = py - hy
		local qy = abs(dy) - ey
		local ay = qy > 0 and qy or 0
		for x = 0, LW - 1 do
			local px = (x + 0.5) * dsx
			local dx = px - hx
			local qx = abs(dx) - ex
			local ax = qx > 0 and qx or 0
			local dc = sqrt(ax * ax + ay * ay)
			local inner = qx > qy and qx or qy
			if inner > 0 then
				inner = 0
			end
			local s = r - dc - inner -- khoảng cách vào trong tính từ mép (px)
			if s < 0 then
				s = 0
			end
			local idx = y * LW + x + 1
			Sd[idx] = s
			if T > 0 and s < T and DG then
				local nx, ny -- pháp tuyến hướng RA NGOÀI
				if dc > 1e-6 then
					nx, ny = ax / dc, ay / dc
					if dx < 0 then
						nx = -nx
					end
					if dy < 0 then
						ny = -ny
					end
				elseif qx > qy then
					nx, ny = (dx < 0) and -1 or 1, 0
				else
					nx, ny = 0, (dy < 0) and -1 or 1
				end
				local u = s / T
				local dR, dG, dB = tabGet(DR, TN, u), tabGet(DG, TN, u), tabGet(DB, TN, u)
				local sx, sy = px - nx * dR, py - ny * dR
				sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
				sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
				R[idx] = bic1(gr, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
				sx, sy = px - nx * dG, py - ny * dG
				sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
				sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
				G[idx] = bic1(gg, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
				sx, sy = px - nx * dB, py - ny * dB
				sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
				sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
				B[idx] = bic1(gb, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
				if shadeK ~= 0 then
					local om = 1 - u
					Sh[idx] = 1 + shadeK * (nx * lx + ny * ly) * om * sqrt(om)
				end
			else
				local gx, gy = lutGet(lutX, px), lutGet(lutY, py)
				R[idx], G[idx], B[idx] = bic1(gr, gw, gh, gx, gy), bic1(gg, gw, gh, gx, gy), bic1(gb, gw, gh, gx, gy)
			end
		end
		if step then
			step()
		end
	end

	-- frost gaussian (3 lượt box mỗi trục)
	local radii = P.blurRadii
	if radii then
		local tmp = newArray(N, 0)
		for _, ch in ipairs({ R, G, B }) do
			for _, rad in ipairs(radii) do
				if rad >= 1 then
					blurAxis(ch, tmp, LH, LW, rad, 1, LW, step)
					blurAxis(tmp, ch, LW, LH, rad, LW, 1, step)
				end
			end
		end
	end

	local buf = buffer.create(N * 4)
	local bR, bG, bB = P.baseR, P.baseG, P.baseB
	local mixIn, mixRim, aIn, aRim = P.mixIn, P.mixRim, P.aIn, P.aRim
	local sat = P.sat or 1
	local veil = P.veil or 0
	local band = (T > 0 and T or 1) * 1.3
	for y = 0, LH - 1 do
		for x = 0, LW - 1 do
			local idx = y * LW + x + 1
			local rimK = 1 - smooth01(Sd[idx] / band)
			local mix = mixIn + (mixRim - mixIn) * rimK
			local a = aIn + (aRim - aIn) * rimK
			local cr, cg, cb = R[idx], G[idx], B[idx]
			if sat ~= 1 then
				local l = 0.299 * cr + 0.587 * cg + 0.114 * cb
				cr, cg, cb = l + (cr - l) * sat, l + (cg - l) * sat, l + (cb - l) * sat
			end
			if veil > 0 then
				cr, cg, cb = cr + (1 - cr) * veil, cg + (1 - cg) * veil, cb + (1 - cb) * veil
			end
			local k = Sh[idx]
			cr = clampN((bR + (cr - bR) * mix) * k, 0, 1)
			cg = clampN((bG + (cg - bG) * mix) * k, 0, 1)
			cb = clampN((bB + (cb - bB) * mix) * k, 0, 1)
			local r8, g8, b8 = floor(cr * 255 + 0.5), floor(cg * 255 + 0.5), floor(cb * 255 + 0.5)
			local a8 = floor(clampN(a, 0, 1) * 255 + 0.5)
			buffer.writeu32(buf, (idx - 1) * 4, r8 + g8 * 256 + b8 * 65536 + a8 * 16777216)
		end
		if step then
			step()
		end
	end
	return buf, LW, LH
end
--[[CORE_END]]

----------------------------------------------------------------------
-- LIQUID GLASS v4 - phần ghép vào Roblox (lịch dựng ảnh, EditableImage, lấy mẫu backdrop bằng raycast)
-- Tham số đặt tên theo README của GlassmorphicUI để dễ đối chiếu với bài blog.
----------------------------------------------------------------------
local LIQUID_DEFAULTS = {
	Thickness = 16, -- px: bề rộng vùng mặt vát (bezel) nơi ánh sáng bị bẻ
	RefractionFactor = 1.6, -- chiết suất n của kính (1 = tắt khúc xạ, 1.5 ~ kính thật, 4 = rất mạnh); dùng định luật Snell
	ChromaticAberration = 0.2, -- 0..1: tán sắc, chiết suất đỏ thấp hơn / xanh dương cao hơn -> viền ám màu
	BlurRadius = 20, -- px: bán kính frost (sigma = 1/3 bán kính, 3 lượt box blur ~ gaussian)
	Opacity = 0.8, -- 0..1: độ mờ đục của frost (cao = che hẳn nền thật như nút CoreGui phía sau, thấp = trong hơn)
	Veil = 0.06, -- 0..0.3: nâng sáng trắng rất nhẹ như kính thật (KHÔNG phải màu nền; 0 = tắt)
	BevelHeight = 1, -- độ cao mặt vát so với Thickness (lớn hơn = mép bẻ ánh sáng gắt hơn)
	GlassBase = 0.45, -- bề dày kính ở mép so với Thickness (tia còn đi thêm quãng này trong kính)
	Saturation = 1.15, -- 1 = giữ nguyên; kính thật làm nền đậm màu hơn một chút
	BevelShade = 0.1, -- 0..0.3: sáng/tối nhẹ theo hướng mặt vát so với nguồn sáng trên-trái
	SamplerWarp = 0.5, -- 0..0.9: lưới lấy mẫu backdrop dày hơn ở sát mép (0 = lưới đều)
	FresnelSize = 7, -- px: độ rộng quầng sáng mép
	FresnelHardness = 40, -- 0..100
	FresnelIntensity = 22, -- 0..100 (0 = tắt)
	GlareSize = 10, -- px: độ rộng vệt glint
	GlareHardness = 40, -- 0..100
	GlareIntensity = 45, -- 0..100 (0 = tắt hẳn phản chiếu/glint)
	GlareConvergence = 90, -- 0..100: glint bám chặt góc chéo
	Backdrop = true, -- lấy mẫu cảnh 3D bằng raycast (false = chỉ lấy một lần)
	BackdropHz = 5, -- số lần quét lại backdrop mỗi giây
	Sky = nil, -- { Top = Color3, Horizon = Color3 } nếu muốn ép màu trời
	RimQuality = 2, -- siêu mẫu cho ảnh viền (1..3)
	Budget = 3, -- ms tối đa mỗi frame cho việc dựng ảnh + raycast
}

local Liquid = {}
Liquid.__index = Liquid

local SETTLE = 0.12 -- đảo đứng yên bao lâu thì mới dựng lại lens
local LENS_GAP = 0.08 -- giãn cách tối thiểu giữa hai lần dựng lens
local RIM_CACHE_MAX = 10
local RAY_LEN = 2000
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
	self.q = clampN(floor(P.RimQuality or 2), 1, 3)
	self.rimCache, self.rimCount = {}, 0
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

	-- Lớp 1: lens (khúc xạ + frost). Nằm dưới tint/glow.
	self.lens = mk("ImageLabel", {
		Name = "Lens",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, body)
	-- Lớp 2: viền Fresnel + glare, 9-slice nên bám đúng đường bo ở mọi kích thước.
	self.rim = mk("ImageLabel", {
		Name = "Rim",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		ScaleType = Enum.ScaleType.Slice,
		SliceScale = 1 / self.q,
	}, body)
	-- Ánh sáng xoay theo trạng thái: gradient điều biến độ đậm glint giữa hai cặp góc đối diện
	self.rimGrad = addGradient(self.rim, RIM_ANGLE.idle, { { 0, 0 }, { 0.2, 0.35 }, { 0.5, 0.7 }, { 0.8, 0.35 }, { 1, 0 } })

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
		self.rim:Destroy()
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
-- Hình dạng đảo: gọi mỗi khi đảo đổi kích thước/bán kính (đơn vị của đảo, trước UIScale)
----------------------------------------------------------------------
function Liquid:NoteShape(w, h, r)
	local sh = self.shape
	sh.w, sh.h, sh.r = w, h, r
	local key = floor(w + 0.5) * 1000000 + floor(h + 0.5) * 1000 + floor(r * 2)
	if key ~= self.shapeKey then
		self.shapeKey = key
		self.lastChange = os.clock()
		self.lensDirty = true
		self.lensJob = nil -- huỷ lần dựng dở; dựng lại khi đảo đứng yên
		self.samp = nil
	end

	local k = clampN(h / 16, 0, 1) -- viền mờ dần khi đảo thu về 0
	local tr = 1 - k
	if self.rimTr ~= tr then
		self.rimTr = tr
		self.rim.ImageTransparency = tr
	end

	local m = min(w, h)
	if m >= 8 then
		local rq = floor(r / 2) * 2 -- lượng tử 2px: tile viền bake theo bán kính, có cache
		rq = max(4, min(rq, floor(m / 2)))
		self:_wantRim(rq)
	end
end

function Liquid:_wantRim(rq)
	self.rimWanted = rq
	local e = self.rimCache[rq]
	if e then
		self:_useRim(rq, e)
	elseif self.rimRq == nil then
		self:_bakeNow(rq) -- lần đầu: dựng đồng bộ để có viền ngay frame đầu
	elseif self.rimRq > rq then
		-- Đảo đang co lại mà tile đúng bán kính chưa bake xong: tạm dùng tile gần nhất KHÔNG lớn hơn,
		-- vì tile lớn hơn nửa chiều nhỏ của thân sẽ làm 9-slice bị chồng.
		local best
		for k in pairs(self.rimCache) do
			if k <= rq and (not best or k > best) then
				best = k
			end
		end
		if best then
			self:_useRim(best, self.rimCache[best])
		end
	end
end

function Liquid:_useRim(rq, e)
	e.last = os.clock()
	if self.rimRq == rq then
		return
	end
	self.rimRq = rq
	local rim = self.rim
	rim.SliceCenter = Rect.new(e.cq, e.cq, e.cq + 2, e.cq + 2)
	rim.SliceScale = 1 / self.q
	if not self:_show(rim, e.img) then
		self:_fail("không gán được ảnh viền")
	end
end

function Liquid:_bakeNow(rq)
	local buf, S, Cq = bakeRim(rq, self.q, self.P, nil)
	self:_storeRim(rq, buf, S, Cq)
end

function Liquid:_storeRim(rq, buf, S, Cq)
	local img = self:_newImage(S, S)
	if not img or not self:_write(img, S, S, buf) then
		self:_fail("không tạo/ghi được ảnh viền")
		return
	end
	local old = self.rimCache[rq]
	if old then
		pcall(function()
			old.img:Destroy()
		end)
		self.rimCount = self.rimCount - 1
	end
	self.rimCache[rq] = { img = img, cq = Cq, last = os.clock() }
	self.rimCount = self.rimCount + 1
	self:_evict()
	if self.rimWanted == rq then
		self:_useRim(rq, self.rimCache[rq])
	end
end

function Liquid:_evict()
	while self.rimCount > RIM_CACHE_MAX do
		local oldK, oldT
		for k, e in pairs(self.rimCache) do
			if k ~= self.rimRq and k ~= self.rimWanted and (not oldT or e.last < oldT) then
				oldK, oldT = k, e.last
			end
		end
		if not oldK then
			break
		end
		local e = self.rimCache[oldK]
		pcall(function()
			e.img:Destroy()
		end)
		self.rimCache[oldK] = nil
		self.rimCount = self.rimCount - 1
	end
end

function Liquid:_clearRims()
	for _, e in pairs(self.rimCache) do
		pcall(function()
			e.img:Destroy()
		end)
	end
	self.rimCache, self.rimCount = {}, 0
	self.rimRq = nil
end

----------------------------------------------------------------------
-- Lấy mẫu backdrop: Roblox không có API đọc màn hình -> "dựng lại cảnh" bằng raycast lưới thưa
----------------------------------------------------------------------
function Liquid:_ensureGrid(gw, gh)
	if self.gr and self.gw == gw and self.gh == gh then
		return
	end
	local base = self.isl._style.base
	local n = gw * gh
	local nr, ng, nb = newArray(n, base.R), newArray(n, base.G), newArray(n, base.B)
	local ogw, ogh, gr, gg, gb = self.gw, self.gh, self.gr, self.gg, self.gb
	if gr then
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
	self.gw, self.gh, self.gr, self.gg, self.gb = gw, gh, nr, ng, nb
	self.gridFresh = gr == nil
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

function Liquid:_sample(now, dl)
	local st = self.samp
	if not st then
		if now < self.nextSample or now - self.lastChange < SETTLE then
			return
		end
		local sh = self.shape
		if sh.w < 12 or sh.h < 12 then
			return
		end
		local gw, gh = clampN(floor(sh.w / 12 + 0.5), 8, 28), clampN(floor(sh.h / 12 + 0.5), 4, 14)
		self:_ensureGrid(gw, gh)
		self.sky = self:_skySnapshot()
		self.rayParams = self.rayParams or RaycastParams.new()
		st = { i = 0, n = gw * gh, gw = gw, gh = gh, gr = self.gr, gg = self.gg, gb = self.gb, delta = 0, fresh = self.gridFresh }
		self.samp = st
	end
	local cam = workspace.CurrentCamera
	local ap, sz = self.body.AbsolutePosition, self.body.AbsoluteSize
	if not cam or sz.X < 4 or sz.Y < 4 then
		self.samp = nil
		return
	end
	local gw, gh = st.gw, st.gh
	local k = st.fresh and 1 or 0.55 -- làm mượt theo thời gian để khỏi nhấp nháy
	local wb = clampN(self.P.SamplerWarp or 0.5, 0, 0.9) -- phải trùng với renderLens
	while st.i < st.n and os.clock() < dl do
		local i = st.i
		local cx, cy = i % gw, floor(i / gw)
		local ray = cam:ViewportPointToRay(ap.X + warp01((cx + 0.5) / gw, wb) * sz.X, ap.Y + warp01((cy + 0.5) / gh, wb) * sz.Y)
		local res = workspace:Raycast(ray.Origin, ray.Direction * RAY_LEN, self.rayParams)
		local r, g, b = self:_colorOf(res, ray.Direction)
		if r then
			local idx = i + 1
			local o1, o2, o3 = st.gr[idx], st.gg[idx], st.gb[idx]
			local n1, n2, n3 = o1 + (r - o1) * k, o2 + (g - o2) * k, o3 + (b - o3) * k
			st.delta = st.delta + abs(n1 - o1) + abs(n2 - o2) + abs(n3 - o3)
			st.gr[idx], st.gg[idx], st.gb[idx] = n1, n2, n3
		end
		st.i = i + 1
	end
	if st.i >= st.n then
		self.samp = nil
		self.sampledOnce = true
		self.gridFresh = false
		self.nextSample = now + 1 / max(self.P.BackdropHz or 5, 0.2)
		if st.fresh or st.delta / (st.n * 3) > 0.004 then
			self.lensDirty = true -- nền đổi đủ nhiều mới dựng lại lens (đứng yên = không tốn gì thêm)
		end
	end
end

----------------------------------------------------------------------
-- Lens: gom tham số rồi chạy renderLens (SDF -> khúc xạ/tán sắc -> frost) trong coroutine
----------------------------------------------------------------------
function Liquid:_startLens(now)
	local sh = self.shape
	local W, H, r = sh.w, sh.h, sh.r
	if W < 12 or H < 12 then
		return
	end
	local isl, P = self.isl, self.P
	self:_ensureGrid(clampN(floor(W / 12 + 0.5), 8, 28), clampN(floor(H / 12 + 0.5), 4, 14))
	local ds = max(1, sqrt(W * H / 9000)) -- lens gần full-res ở đảo nhỏ; đảo to hạ độ phân giải (frost che đi)
	local base = isl._style.base
	local wb = clampN(P.SamplerWarp or 0.5, 0, 0.9)
	-- sigma = BlurRadius/3 (như bài blog). Tái dựng bicubic nên chỉ cần sàn nhỏ theo ô lưới, không còn phải che vết bilinear
	local cell = max(W / self.gw, H / self.gh)
	local sigma = max(P.BlurRadius / 3, cell * 0.35) / ds
	local L = {
		W = W, H = H, R = r, T = P.Thickness,
		ior = clampN(P.RefractionFactor, 1, 4),
		ca = clampN(P.ChromaticAberration, 0, 1),
		bevel = P.BevelHeight, glassBase = P.GlassBase,
		ds = ds, blurRadii = gaussBoxRadii(sigma), warp = wb,
		sat = P.Saturation, shade = P.BevelShade,
		gw = self.gw, gh = self.gh, gr = self.gr, gg = self.gg, gb = self.gb,
		baseR = base.R, baseG = base.G, baseB = base.B,
		mixIn = 1, mixRim = 1, -- 100% màu backdrop, không trộn màu nền kính
		aIn = clampN(P.Opacity, 0, 1), aRim = clampN(P.Opacity + 0.08, 0, 1),
		veil = clampN(P.Veil, 0, 0.3),
	}
	self.lensJob = self:_newJob(function(step)
		return renderLens(L, step)
	end)
	self.lensDirty = false
	self.lensStart = now
end

function Liquid:_flush(w)
	if w.kind == "rim" then
		self:_storeRim(w.rq, w.buf, w.w, w.cq)
		return
	end
	if not self.lensImg or self.lensW ~= w.w or self.lensH ~= w.h then
		local img = self:_newImage(w.w, w.h)
		if not img or not self:_write(img, w.w, w.h, w.buf) or not self:_show(self.lens, img) then
			self:_fail("không tạo/ghi/gán được ảnh lens")
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
		self:_fail("ghi ảnh lens lỗi")
	end
end

----------------------------------------------------------------------
-- Mỗi Heartbeat: viền -> ghi tối đa 1 ảnh -> lấy mẫu -> lens, tất cả trong ngân sách ms
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

	-- 1) viền: dựng tile cho bán kính đang cần nếu chưa có trong cache
	local job = self.rimJob
	if not job then
		local want = self.rimWanted
		if want and not self.rimCache[want] then
			job = self:_newJob(function(step)
				return bakeRim(want, self.q, self.P, step)
			end)
			job.rq = want
			self.rimJob = job
		end
	end
	if job then
		local done, buf, S, Cq = self:_resume(job, deadline)
		if done then
			self.rimJob = nil
			if buf then
				self.writes[#self.writes + 1] = { kind = "rim", rq = job.rq, buf = buf, w = S, cq = Cq }
			end
		end
	end

	-- 2) EditableImage chỉ cho cập nhật 1 lần/frame -> mỗi frame ghi tối đa một ảnh
	local w = table.remove(self.writes, 1)
	if w then
		self:_flush(w)
	end

	-- 3) backdrop
	if os.clock() < deadline and (self.P.Backdrop ~= false or not self.sampledOnce) then
		local ok, err = pcall(self._sample, self, now, min(deadline, os.clock() + 0.001))
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

	-- 4) lens
	if
		self.lensDirty
		and not self.lensJob
		and not self.rimJob
		and #self.writes == 0
		and now - self.lastChange >= SETTLE
		and now - self.lensStart >= LENS_GAP
	then
		self:_startLens(now)
	end
	local lj = self.lensJob
	if lj and os.clock() < deadline then
		local done, buf, LW, LH = self:_resume(lj, deadline)
		if done and self.lensJob == lj then
			self.lensJob = nil
			if buf then
				self.writes[#self.writes + 1] = { kind = "lens", buf = buf, w = LW, h = LH }
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
	self.rim.Visible = self.enabled
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
	self.q = clampN(floor(self.P.RimQuality or 2), 1, 3)
	self.rimJob = nil
	self.writes = {}
	self:_clearRims()
	self:Refresh()
	if self.rimWanted then
		self:_bakeNow(self.rimWanted)
	end
end

function Liquid:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:_clearRims()
	if self.lensImg then
		pcall(function()
			self.lensImg:Destroy()
		end)
		self.lensImg = nil
	end
	pcall(function()
		self.lens:Destroy()
	end)
	pcall(function()
		self.rim:Destroy()
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
		-- Truyền ModuleScript/module gốc boatbeaker/GlassmorphicUI để dùng pipeline upstream.
		GlassmorphicUI = config.GlassmorphicUI,
		-- Chỉ bật nếu chủ động muốn renderer raycast cũ khi không có upstream.
		LegacyGlassFallback = config.LegacyGlassFallback == true,
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
	self:_lgCreate() -- ưu tiên GlassmorphicUI upstream; thiếu module thì dùng kính cổ điển
	self:_syncBodyFill()

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
	if self._lg then
		tween(self._lg.rimGrad, 0.9, { Rotation = ang }, Enum.EasingStyle.Quint)
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
		if self._lgOn then
			self._tint.BackgroundTransparency = 1 -- Liquid: không hắt màu lên kính
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
	self:_syncBodyFill()
	self:_apply()
	self:_render(false)
end

----------------------------------------------------------------------
-- Liquid glass: tạo / tắt / chỉnh khi đang chạy
----------------------------------------------------------------------
-- Thân đảo chỉ tô màu cho kính cổ điển. Khi Liquid bật: trong suốt hoàn toàn, mọi thứ do lens (frost của backdrop) + rim lo.
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

-- Adapter dùng trực tiếp API của boatbeaker/GlassmorphicUI.
-- Quan trọng: các thuộc tính UDim của upstream là tỷ lệ theo kích thước cửa sổ,
-- không phải pixel offset như renderer cũ.
local UpstreamGlass = {}
UpstreamGlass.__index = UpstreamGlass

local function asUDim(v, fallback)
	if typeof(v) == "UDim" then
		return v
	end
	if type(v) == "number" then
		-- Số truyền vào từ API DynamicIsland cũ được hiểu là pixel.
		return UDim.new(0, v)
	end
	return fallback
end

local function getUpstreamModule(candidate)
	if type(candidate) == "table" and type(candidate.addGlassBackground) == "function" then
		return candidate
	end

	-- Tự tìm nếu thư viện đã được cài dưới ReplicatedStorage.Packages.
	local ok, module = pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local packages = rs:FindFirstChild("Packages")
		local scriptModule = packages and packages:FindFirstChild("GlassmorphicUI")
		if scriptModule and scriptModule:IsA("ModuleScript") then
			return require(scriptModule)
		end
		return nil
	end)
	if ok and type(module) == "table" and type(module.addGlassBackground) == "function" then
		return module
	end
	return nil
end

function UpstreamGlass.new(module, body, opts)
	module = getUpstreamModule(module)
	assert(type(module) == "table", "Không tìm thấy GlassmorphicUI gốc. Cài ModuleScript tại ReplicatedStorage.Packages.GlassmorphicUI hoặc truyền config.GlassmorphicUI.")
	assert(type(module.addGlassBackground) == "function", "Thiếu GlassmorphicUI.addGlassBackground")

	local self = setmetatable({
		module = module,
		body = body,
		alive = true,
		cornerRadius = UDim.new(0.5, 0), -- Dynamic Island: góc bo bằng nửa chiều cao
	}, UpstreamGlass)

	-- API upstream tạo GlassPane và tự quản lý pipeline EditableImage/backdrop.
	module.addGlassBackground(body)
	self.pane = body:FindFirstChild("GlassPane")
	assert(self.pane, "GlassmorphicUI không tạo GlassPane trong body")

	-- Đảm bảo pane phủ toàn thân và nằm dưới các lớp nội dung của Dynamic Island.
	self.pane.Name = "GlassPane"
	self.pane.AnchorPoint = Vector2.zero
	self.pane.Position = UDim2.fromScale(0, 0)
	self.pane.Size = UDim2.fromScale(1, 1)
	self.pane.BackgroundTransparency = 1
	self:SetParams(opts, true)
	self:NoteShape()
	-- Đợi Dynamic Island được đặt kích thước ban đầu trước khi rebuild ảnh.
	task.defer(function()
		if self.alive and self.body and self.body.Parent and type(self.module.forceUpdate) == "function" then
			pcall(self.module.forceUpdate, self.body)
		end
	end)
	return self
end

function UpstreamGlass:SetParams(opts, deferInitialUpdate)
	if not self.alive then return end
	opts = type(opts) == "table" and opts or {}
	local body = self.body
	local function pick(name, default)
		local value = opts[name]
		if value == nil then return default end
		return value
	end
	local function attr(name, value)
		if value ~= nil then body:SetAttribute(name, value) end
	end

	-- Dùng đúng kiểu và mặc định của README upstream v1.0.0.
	attr("Thickness", asUDim(pick("Thickness", UDim.new(0.15, 0)), UDim.new(0.15, 0)))
	attr("RefractionFactor", pick("RefractionFactor", 2.1))
	attr("ChromaticAberration", pick("ChromaticAberration", 0.2))
	attr("CornerRadius", asUDim(pick("CornerRadius", self.cornerRadius), self.cornerRadius))
	attr("SuperEllipseFactor", pick("SuperEllipseFactor", 3))
	attr("FresnelSize", asUDim(pick("FresnelSize", UDim.new(0.1, 0)), UDim.new(0.1, 0)))
	attr("FresnelHardness", pick("FresnelHardness", 40))
	attr("FresnelIntensity", pick("FresnelIntensity", 25))
	attr("GlareSize", asUDim(pick("GlareSize", UDim.new(0.2, 0)), UDim.new(0.2, 0)))
	attr("GlareHardness", pick("GlareHardness", 40))
	attr("GlareIntensity", pick("GlareIntensity", 70))
	attr("GlareConvergence", pick("GlareConvergence", 90))
	attr("GlareOppositeSide", pick("GlareOppositeSide", 50))
	attr("GlareAngle", pick("GlareAngle", -50))
	attr("BlurRadius", asUDim(pick("BlurRadius", UDim.new(0.06, 0)), UDim.new(0.06, 0)))
	attr("MaxOutputResolution", pick("MaxOutputResolution", 1024))

	-- Upstream Transparency là alpha tint: 0 = đục, 1 = trong.
	-- Không ghi đè mặc định upstream nếu người dùng không yêu cầu.
	local transparency = opts.Transparency
	if transparency == nil and opts.Opacity ~= nil then
		transparency = 1 - math.clamp(opts.Opacity, 0, 1)
	end
	if transparency ~= nil then
		attr("Transparency", math.clamp(transparency, 0, 1))
	end
	if opts.Tint then
		body.BackgroundColor3 = opts.Tint
	end

	if not deferInitialUpdate and type(self.module.forceUpdate) == "function" then
		pcall(self.module.forceUpdate, body)
	end
end

-- _apply() gọi hàm này mỗi frame khi spring chạy. Dùng UDim scale 0.5 để
-- góc kính tự bám kích thước đảo, tránh ghi attribute liên tục và gây rebuild.
function UpstreamGlass:NoteShape()
	if not self.alive or not self.body then return end
	if not self.body:GetAttribute("CornerRadius") then
		self.body:SetAttribute("CornerRadius", self.cornerRadius)
	end
	if self.pane and self.pane.Parent then
		self.pane.Position = UDim2.fromScale(0, 0)
		self.pane.Size = UDim2.fromScale(1, 1)
	end
end

function UpstreamGlass:SetVisible(visible)
	if self.pane and self.pane.Parent then
		self.pane.Visible = visible
	end
end

function UpstreamGlass:Refresh()
	if self.alive and type(self.module.forceUpdate) == "function" then
		self.module.forceUpdate(self.body)
	end
end

function UpstreamGlass:Destroy()
	if not self.alive then return end
	self.alive = false
	if self.pane and self.pane.Parent then
		self.pane:Destroy()
	end
end

function Island:_lgCreate()
	if self._lg or not self._cfg.Liquid or not self._glass then
		return
	end
	local opts = type(self._cfg.Liquid) == "table" and self._cfg.Liquid or nil
	local upstream = getUpstreamModule(self._cfg.GlassmorphicUI)
	local ok, lg
	if upstream then
		ok, lg = pcall(UpstreamGlass.new, upstream, self._body, opts)
	elseif self._cfg.LegacyGlassFallback then
		-- Renderer raycast tự viết chỉ chạy khi được bật rõ ràng.
		ok, lg = pcall(Liquid.new, self, self._body, opts)
	else
		ok, lg = false, "Thiếu GlassmorphicUI gốc; renderer raycast dự phòng đang tắt"
	end
	if ok and lg then
		self._lg = lg
		self._lgOn = true
	else
		self._lgOn = false
		warn("[DynamicIsland] Không bật được GlassmorphicUI: " .. tostring(lg) .. ". Đang dùng kính cổ điển.")
	end
	self:_syncBodyFill()
end

-- Engine tự báo lỗi (EditableImage hết bộ nhớ, bị chặn...): bỏ engine, bật lại kính cổ điển
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

-- false = kính cổ điển; true/bảng = bật engine GlassmorphicUI (bảng = ghi đè thuộc tính upstream)
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
