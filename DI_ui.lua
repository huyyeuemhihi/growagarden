--[[
	DynamicIsland.lua  v6  -  Dynamic Island (iPhone 14 Pro) + LIQUID GLASS dựng lại theo GlassmorphicUI
	(github.com/boatbeaker/GlassmorphicUI của boatbomber; bài giải thích: boatbomber.com/blog/liquid-glass)
	-------------------------------------------------------------------------------
	MỚI Ở v6 - làm lại engine kính để bám đúng mô hình của GlassmorphicUI (README + bài blog), thay cho bản tự suy luận ở v4-v5.1
	• THUỘC TÍNH GIỐNG README: cùng tên, cùng giá trị mặc định, cùng khoảng giá trị, UDim phân giải theo TRỤC NHỎ của cửa sổ:
	    Thickness (0.15,0) • RefractionFactor 2.1 • ChromaticAberration 0.2 • SuperEllipseFactor 3
	    FresnelSize (0.1,0) / Hardness 40 / Intensity 25 • GlareSize (0.2,0) / Hardness 40 / Intensity 70 / Convergence 90 /
	    OppositeSide 50 / Angle -50 • BlurRadius (0.06,0) • Transparency (độ trong của tint) • BackgroundColor3 (màu tint) •
	    MaxOutputResolution 1024.   Sai kiểu giá trị = bỏ qua, dùng mặc định (như README). Truyền số thay cho UDim = px.
	• HÌNH DẠNG SIÊU ELIP: góc là đường cong |x|^n + |y|^n = r^n (n = SuperEllipseFactor; 2 = tròn, cao hơn = vuông hơn).
	  Thân đảo được UICorner cắt theo bán kính tròn tương đương của góc đó nên viền kính và đường cắt khớp nhau.
	• TÁN SẮC đúng định nghĩa README: kênh đỏ lấy mẫu xa hơn (1+ca), xanh dương gần hơn (1-ca) so với xanh lá (v5 dùng chiết suất riêng).
	• GLARE CÓ HƯỚNG: GlareAngle là trục glare, glint thứ hai ở phía đối diện (GlareOppositeSide), GlareConvergence = glint bám trục
	  chặt đến đâu. Ảnh viền (Fresnel + glare) bake 4 góc RIÊNG (không lật gương như v5) vì glare có hướng.
	• TRANSPARENCY = độ trong của lớp tint: màu = tint*(1-T) + backdrop*T. T = 0 -> tint đặc và KHÔNG lấy mẫu backdrop.
	• ĐƯỜNG ỐNG 3 BƯỚC như bài blog: (1) bake hình học (bản đồ độ lệch + độ phủ, cache theo khoá hình học) ->
	  (2) lấy mẫu backdrop vào lưới thô KHÔNG đều, làm dần theo ngân sách ms -> (3) dựng lại: khúc xạ, bicubic, tint, frost
	  gaussian (sigma = BlurRadius/3, độ phủ vẫn sắc nét), rồi viền Fresnel/glare cộng SAU frost.
	• BACKDROP ước lượng từ: các lớp GUI sau đảo (PlayerGui:GetGuiObjectsAtPosition) -> raycast cảnh 3D -> màu trời. Tắt phần GUI: GuiLayers = false.
	• MaxOutputResolution; hết bộ nhớ EditableImage thì hạ độ phân giải một nửa (xuống tối thiểu 32) và cảnh báo, như README.
	• API tương ứng thư viện gốc: island:PauseGlass() / :ResumeGlass() / :RefreshGlass() (forceUpdate) / :GlassStats() (getDebugStats).
	• GIỐNG 100% THẬT SỰ: Liquid = { Library = <ModuleScript GlassmorphicUI> } -> đảo dùng CHÍNH module gốc (xem GIỚI HẠN).
	• Đã bỏ các tham số không có trong README: Opacity, Veil, BevelHeight, GlassBase, Saturation, BevelShade (truyền vào cũng bị bỏ qua).
	• Mặc định riêng cho ĐẢO (thân chỉ cao 37px): Thickness (0.3,0), Transparency 0.7, tint (10,10,14). Muốn đúng README:
	    Liquid = { Thickness = UDim.new(0.15, 0), Transparency = 0.5, BackgroundColor3 = Color3.fromRGB(163, 162, 165) }
	• Muốn đầu đảo tròn như viên thuốc thay vì siêu elip: Liquid = { SuperEllipseFactor = 2 }.

	Lịch sử: v5.1 kính trong không màu nền • v5 Snell + tán sắc + bicubic • v4 làm lại bằng EditableImage + SDF (bỏ frame/UIStroke giả)
	• v3 hết tràn viền, vùng mờ nền thật (Part DepthOfField) thu vào Inset px • v2 spring kiểu SwiftUI, icon dùng chung, số/chữ "roll", dây cao su.

	CÁCH DÙNG (API giữ nguyên như v1-v5, tuỳ chọn Liquid dùng tên thuộc tính của README)
	    local Island = loadstring(game:HttpGet("LINK_RAW_CUA_BAN"))()
	    local island = Island.new({
	        Top = 11, Scale = nil,          -- Scale nil = tự co theo màn hình
	        Style = "Frosted",              -- "Frosted" = kính xám mờ đục | "Dark" = kính đen kiểu iOS
	        RealBlur = true,                -- mờ nền thật (Part Glass + DepthOfField); false = tắt; hoặc bảng thông số:
	                                        --   { NearIntensity = 1, Inset = 6, Slices = 8, Distance = nil, FocusDistance = nil, InFocusRadius = 100 }
	        Liquid = true,                  -- engine kính mới; false = kính cổ điển v3; hoặc bảng tuỳ chỉnh:
	                                        --   { Thickness = UDim.new(0.3, 0), RefractionFactor = 2.1, ChromaticAberration = 0.2,
	                                        --     SuperEllipseFactor = 3, BlurRadius = UDim.new(0.06, 0), Transparency = 0.7,
	                                        --     BackgroundColor3 = Color3.fromRGB(10, 10, 14),  -- (hoặc Tint = ...)
	                                        --     FresnelIntensity = 25, GlareIntensity = 70 (0 = tắt glint), GlareAngle = -50, ...
	                                        --     GuiLayers = true, Backdrop = true, BackdropHz = 5, Sky = { Top = Color3, Horizon = Color3 },
	                                        --     MaxOutputResolution = 1024, MaxPixels = 24000, Budget = 3,
	                                        --     Library = nil }   -- ModuleScript GlassmorphicUI nếu muốn dùng module gốc
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
	    island:SetLiquid(false | true | { ... })   -- đổi engine/tham số kính khi đang chạy (tên thuộc tính như README)
	    island:RefreshGlass()                       -- dựng lại toàn bộ kính (vd. vừa teleport) - tương ứng forceUpdate
	    island:PauseGlass() / island:ResumeGlass()  -- tạm dừng cập nhật kính (nền tĩnh) / chạy lại
	    island:GlassStats()                         -- thống kê đường ống (lưới, độ phân giải ảnh, số mẫu backdrop, ...)

	Bấm vào đảo (khi có Activity) = mở rộng / thu lại.  Vuốt lên = đóng.
	Icon: Icon = "rbxassetid://123" (hoặc số id) hoặc Glyph = "⚡"; không có thì lấy chữ cái đầu của Title.
	Chạy thử nhanh: getgenv().DynamicIslandDemo = true trước khi load file này.

	GIỚI HẠN (nói thật)
	• MÌNH KHÔNG ĐỌC ĐƯỢC MÃ NGUỒN GỐC: GitHub chặn truy cập tự động vào thư mục src, còn bài blog là trang JS chỉ lộ phần mô tả.
	  Mình chỉ có README (bảng thuộc tính, mặc định, khoảng giá trị, ý nghĩa từng tham số) và phần "How it works" của blog.
	  Vì vậy engine này khớp MÔ HÌNH, TÊN/MẶC ĐỊNH/Ý NGHĨA tham số và thứ tự đường ống của thư viện gốc, nhưng các công thức bên
	  trong là mình dựng theo mô tả đó, KHÔNG phải mã gốc, nên chưa thể gọi là giống từng pixel. Những chỗ đang là suy đoán:
	    - CornerRadius ở thư viện gốc phân giải thế nào (ở đảo không dùng: bán kính do spring của đảo quyết định);
	    - hồ sơ cắt của Fresnel/Glare theo Hardness, độ hội tụ glint theo Convergence, hướng GlareAngle (đang hiểu là toạ độ
	      màn hình, y hướng xuống: -50 = hướng lên-phải) và độ dày kính bên trong khúc xạ;
	    - cách thư viện gốc đọc màu lớp GUI/ảnh/skybox phía sau (ở đây chỉ đọc màu nền của các GuiObject + raycast + màu trời).
	  Cách DUY NHẤT để giống y hệt: Liquid = { Library = game.ReplicatedStorage.GlassmorphicUI } (tải .rbxm ở trang Releases của repo,
	  đặt vào game rồi trỏ tới ModuleScript). Phần này CHƯA kiểm chứng với module thật; lỗi thì tự quay về engine trong file.
	• CHƯA kiểm chứng trong Roblox thật. Lõi toán (SDF siêu elip, bảng Snell, warp lưới, bicubic, blur, bake viền 4 góc) đã chạy bằng
	  Lua 5.4 với shim `buffer` và xuất ảnh để xem bằng mắt. Toàn bộ file (kể cả phần ghép EditableImage, 9-slice, raycast, lấy mẫu
	  GUI, spring của đảo) đã chạy thử với bộ giả lập API Roblox tự viết để kiểm tra logic, lịch dựng ảnh và các đường lui; nên hành vi
	  thật của Roblox (EditableImage + 9-slice + GetGuiObjectsAtPosition) vẫn chưa được kiểm chứng. Nếu EditableImage bị chặn trên
	  executor của bạn, đảo tự dùng kính cổ điển.
	• GetGuiObjectsAtPosition: mình đang trừ GuiInset ở trục Y và giả định danh sách trả về từ trên xuống dưới; nếu màu lớp GUI
	  phía sau bị lệch vị trí thì đặt GuiLayers = false.
	• Backdrop chỉ là ƯỚC LƯỢNG: Roblox không cho đọc màn hình. Không thấy texture/ảnh của GUI, ánh sáng thật, skybox, CoreGui.
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
-- LIQUID GLASS v6 - lõi tính toán thuần (không gọi API Roblox): bake hình học, dựng lại ảnh lens, bake viền 4 góc
----------------------------------------------------------------------
--[[CORE_BEGIN]]
local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max
local sin, cos, tan, asin, atan = math.sin, math.cos, math.tan, math.asin, math.atan
-- Chỉ các hàm dưới đây lộ ra ngoài khối do...end (giữ số biến local ở cấp file thấp, tránh chạm giới hạn 200 local)
local newArray, clampN, smooth01, warp01, resolveUDim, gaussBoxRadii, bakeGeometry, renderLens, bakeRim
do

	function newArray(n, v)
		if table.create then
			return table.create(n, v)
		end
		local t = {}
		for i = 1, n do
			t[i] = v
		end
		return t
	end

	function clampN(x, a, b)
		if x < a then
			return a
		end
		if x > b then
			return b
		end
		return x
	end

	function smooth01(t)
		if t <= 0 then
			return 0
		end
		if t >= 1 then
			return 1
		end
		return t * t * (3 - 2 * t)
	end

	-- Cắt UDim ra px theo trục nhỏ nhất của cửa sổ (đúng như README: "UDim, resolved ... min axis")
	function resolveUDim(u, minAxis, lo, hi)
		local v = u.Scale * minAxis + u.Offset
		if v < lo then
			v = lo
		elseif v > hi then
			v = hi
		end
		return v
	end

	-- Khoảng cách có dấu tới mép cửa sổ SIÊU ELIP (dương = bên trong) + pháp tuyến hướng RA NGOÀI.
	--   (dx, dy): toạ độ so với tâm; ex, ey: nửa kích thước của "lõi" (nửa W - r, nửa H - r)
	--   r: bán kính góc (px); nn: SuperEllipseFactor (2 = góc tròn, càng cao càng vuông)
	-- Góc là đường cong |qx|^n + |qy|^n = r^n; khoảng cách xấp xỉ bậc nhất (r - G)/|grad G| với G là chuẩn-n.
	local function sdfAt(dx, dy, ex, ey, r, nn)
		local sx = dx < 0 and -1 or 1
		local sy = dy < 0 and -1 or 1
		local qx, qy = abs(dx) - ex, abs(dy) - ey
		if qx > 0 and qy > 0 then
			local gx, gy = qx ^ (nn - 1), qy ^ (nn - 1)
			local gl = sqrt(gx * gx + gy * gy)
			if gl < 1e-12 then
				return r, 0.70710678 * sx, 0.70710678 * sy
			end
			local G = (gx * qx + gy * qy) ^ (1 / nn)
			local gp = G ^ (nn - 1)
			return (r - G) * gp / gl, sx * gx / gl, sy * gy / gl
		elseif qx > qy then
			return r - qx, sx, 0
		end
		return r - qy, 0, sy
	end

	-- Hồ sơ cắt của dải sáng mép: u = độ sâu/độ rộng (0 = sát mép, 1 = hết tầm với).
	-- hardness 0 = tắt dần mượt suốt cả tầm; hardness 1 = giữ phẳng rồi cắt rất gắt ở cuối.
	local function edgeProfile(u, h01)
		if u >= 1 then
			return 0
		end
		local e0 = h01 * 0.92
		if u <= e0 then
			return 1
		end
		return 1 - smooth01((u - e0) / (1 - e0))
	end

	-- Lưới backdrop KHÔNG đều: ô dày hơn ở sát mép (nơi khúc xạ mạnh), thưa ở giữa (nơi chỉ còn frost).
	-- x/len = u - beta*sin(2*pi*u)/(2*pi); beta = 0 là lưới đều, beta < 1 để hàm đơn điệu.
	local PI2 = 2 * math.pi
	function warp01(u, beta)
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

	-- Nội suy bicubic CẢ BA kênh cùng một vị trí (dùng chung trọng số), kẹp mép
	local function bic3(ar, ag, ab, gw, gh, gx, gy)
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
		local o0, o1, o2, o3 = ym * gw + 1, y0 * gw + 1, yp * gw + 1, yq * gw + 1
		local r = (ar[o0 + xm] * a0 + ar[o0 + x0] * a1 + ar[o0 + xp] * a2 + ar[o0 + xq] * a3) * b0
			+ (ar[o1 + xm] * a0 + ar[o1 + x0] * a1 + ar[o1 + xp] * a2 + ar[o1 + xq] * a3) * b1
			+ (ar[o2 + xm] * a0 + ar[o2 + x0] * a1 + ar[o2 + xp] * a2 + ar[o2 + xq] * a3) * b2
			+ (ar[o3 + xm] * a0 + ar[o3 + x0] * a1 + ar[o3 + xp] * a2 + ar[o3 + xq] * a3) * b3
		local g = (ag[o0 + xm] * a0 + ag[o0 + x0] * a1 + ag[o0 + xp] * a2 + ag[o0 + xq] * a3) * b0
			+ (ag[o1 + xm] * a0 + ag[o1 + x0] * a1 + ag[o1 + xp] * a2 + ag[o1 + xq] * a3) * b1
			+ (ag[o2 + xm] * a0 + ag[o2 + x0] * a1 + ag[o2 + xp] * a2 + ag[o2 + xq] * a3) * b2
			+ (ag[o3 + xm] * a0 + ag[o3 + x0] * a1 + ag[o3 + xp] * a2 + ag[o3 + xq] * a3) * b3
		local b = (ab[o0 + xm] * a0 + ab[o0 + x0] * a1 + ab[o0 + xp] * a2 + ab[o0 + xq] * a3) * b0
			+ (ab[o1 + xm] * a0 + ab[o1 + x0] * a1 + ab[o1 + xp] * a2 + ab[o1 + xq] * a3) * b1
			+ (ab[o2 + xm] * a0 + ab[o2 + x0] * a1 + ab[o2 + xp] * a2 + ab[o2 + xq] * a3) * b2
			+ (ab[o3 + xm] * a0 + ab[o3 + x0] * a1 + ab[o3 + xp] * a2 + ab[o3 + xq] * a3) * b3
		return r, g, b
	end

	-- Nội suy bicubic MỘT kênh (dùng khi mỗi kênh lấy mẫu ở vị trí riêng: tán sắc)
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
	-- Trả về mảng D[1..N+1] (px) ứng với s = k*T/N. Trơn về 0 tại s = T. Độ lệch tỉ lệ thuận với T
	-- (đúng mô tả README: Thickness vừa là tầm với vào trong vừa là độ gắt của khúc xạ).
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
			local th1 = atan(slope)
			local s2 = sin(th1) / ior
			if s2 > 1 then
				s2 = 1
			end
			local th2 = asin(s2)
			D[k + 1] = (bevel * h + base) * tan(th1 - th2)
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
	function gaussBoxRadii(sigma)
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

	----------------------------------------------------------------------
	-- BƯỚC 1 (theo bài blog): "Bake the geometry" - bản đồ độ lệch khúc xạ + độ phủ, không phụ thuộc nội dung màn hình.
	-- G = { W, H, R, n, T, ior, bevel, base, LW, LH }.  Cache được theo khoá hình học (W,H,R,n,T,ior,LW,LH).
	-- Trả về { DX, DY, M }: DX/DY = véc-tơ lấy mẫu của kênh XANH LÁ (px cửa sổ), M = độ phủ khử răng cưa 0..1.
	----------------------------------------------------------------------
	function bakeGeometry(G, step)
		local W, H, r, nn, T = G.W, G.H, G.R, G.n, G.T
		local LW, LH = G.LW, G.LH
		local dsx, dsy = W / LW, H / LH
		local ds = max(dsx, dsy)
		local N = LW * LH
		local DX, DY, M = newArray(N, 0), newArray(N, 0), newArray(N, 1)
		local hx, hy = W / 2, H / 2
		local ex, ey = hx - r, hy - r
		local TN = 48
		local D = nil
		if T > 0 and G.ior > 1.0001 then
			D = refractTable(T, G.ior, G.bevel * T, G.base * T, TN)
		end
		for y = 0, LH - 1 do
			local py = (y + 0.5) * dsy
			for x = 0, LW - 1 do
				local px = (x + 0.5) * dsx
				local s, nx, ny = sdfAt(px - hx, py - hy, ex, ey, r, nn)
				local idx = y * LW + x + 1
				local cov = s / ds + 0.5
				M[idx] = cov >= 1 and 1 or (cov <= 0 and 0 or cov)
				if D and s < T then
					if s < 0 then
						s = 0
					end
					local d = tabGet(D, TN, s / T)
					DX[idx], DY[idx] = -nx * d, -ny * d
				end
			end
			if step then
				step()
			end
		end
		return { DX = DX, DY = DY, M = M }
	end

	----------------------------------------------------------------------
	-- BƯỚC 3 (theo bài blog): "Reconstruct the output" - phóng lưới nguồn lên pixel đầy đủ, mỗi lần lấy mẫu bị dịch/warp
	-- (khúc xạ), bicubic, TÁN SẮC (đỏ lấy xa hơn 1+ca, xanh dương gần hơn 1-ca so với xanh lá), tint, rồi frost gaussian.
	-- Độ phủ (mask) giữ nguyên sắc nét, KHÔNG bị blur. Fresnel + glare nằm ở ảnh viền riêng, cộng sau frost.
	-- P = { W, H, LW, LH, gw, gh, gr, gg, gb, warp, ca, blurRadii, tr, tg, tb, tw }   tw = 1 - Transparency (trọng số tint)
	----------------------------------------------------------------------
	function renderLens(P, geo, step)
		local W, H = P.W, P.H
		local LW, LH = P.LW, P.LH
		local N = LW * LH
		local dsx, dsy = W / LW, H / LH
		local DX, DY, M = geo.DX, geo.DY, geo.M
		local tr, tg, tb, tw = P.tr, P.tg, P.tb, P.tw
		local buf = buffer.create(N * 4)

		-- Transparency = 0 -> chỉ còn màu tint đặc, không cần backdrop (README: "skips backdrop sampling entirely")
		if tw >= 0.999 or not P.gr then
			local c8 = floor(tr * 255 + 0.5) + floor(tg * 255 + 0.5) * 256 + floor(tb * 255 + 0.5) * 65536
			for y = 0, LH - 1 do
				for x = 0, LW - 1 do
					local i = y * LW + x + 1
					buffer.writeu32(buf, (i - 1) * 4, c8 + floor(M[i] * 255 + 0.5) * 16777216)
				end
				if step then
					step()
				end
			end
			return buf, LW, LH
		end

		local gw, gh = P.gw, P.gh
		local gr, gg, gb = P.gr, P.gg, P.gb
		local beta = P.warp or 0
		local lutX, lutY = buildInv(W, gw, beta), buildInv(H, gh, beta)
		local R, G, B = newArray(N, 0), newArray(N, 0), newArray(N, 0)
		local maxX, maxY = W - 0.5, H - 0.5
		local ca = P.ca
		local kR, kB = 1 + ca, 1 - ca

		for y = 0, LH - 1 do
			local py = (y + 0.5) * dsy
			for x = 0, LW - 1 do
				local px = (x + 0.5) * dsx
				local idx = y * LW + x + 1
				local dx, dy = DX[idx], DY[idx]
				if dx == 0 and dy == 0 then
					local gx, gy = lutGet(lutX, px), lutGet(lutY, py)
					R[idx], G[idx], B[idx] = bic3(gr, gg, gb, gw, gh, gx, gy)
				else
					local sx, sy = px + dx * kR, py + dy * kR
					sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
					sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
					R[idx] = bic1(gr, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
					sx, sy = px + dx, py + dy
					sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
					sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
					G[idx] = bic1(gg, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
					sx, sy = px + dx * kB, py + dy * kB
					sx = sx < 0.5 and 0.5 or (sx > maxX and maxX or sx)
					sy = sy < 0.5 and 0.5 or (sy > maxY and maxY or sy)
					B[idx] = bic1(gb, gw, gh, lutGet(lutX, sx), lutGet(lutY, sy))
				end
			end
			if step then
				step()
			end
		end

		-- frost gaussian (3 lượt box mỗi trục), sigma = BlurRadius / 3
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

		-- tint: màu = backdrop*(Transparency) + tint*(1-Transparency); alpha = độ phủ hình dạng
		for y = 0, LH - 1 do
			for x = 0, LW - 1 do
				local i = y * LW + x + 1
				local cr, cg, cb = R[i], G[i], B[i]
				cr = clampN(cr + (tr - cr) * tw, 0, 1)
				cg = clampN(cg + (tg - cg) * tw, 0, 1)
				cb = clampN(cb + (tb - cb) * tw, 0, 1)
				buffer.writeu32(
					buf,
					(i - 1) * 4,
					floor(cr * 255 + 0.5) + floor(cg * 255 + 0.5) * 256 + floor(cb * 255 + 0.5) * 65536 + floor(M[i] * 255 + 0.5) * 16777216
				)
			end
			if step then
				step()
			end
		end
		return buf, LW, LH
	end

	----------------------------------------------------------------------
	-- Ảnh VIỀN (rim lighting): Fresnel + glare, bake MỘT lần cho một bán kính góc rồi hiển thị bằng 9-slice.
	-- Bốn góc được tính RIÊNG (không lật gương) vì glare có hướng (GlareAngle) nên mỗi góc khác nhau.
	-- P = { n, FS, FH, FI, GS, GH, GI, GK, GO, GA }: kích thước đã đổi ra px cửa sổ, FH/GH/FI/GI/GO đã chia 100,
	-- GK = số mũ glint (hội tụ), GA = góc glare (radian, hệ toạ độ màn hình: y hướng xuống).
	-- Trả về buffer RGBA8 (trắng, alpha = độ sáng) kích thước S*S, S = 2*Cq + 2.
	----------------------------------------------------------------------
	function bakeRim(P, rq, q, step)
		local Rt = rq * q
		local Cq = ceil(Rt)
		local S = 2 * Cq + 2
		local nn = P.n
		local hx = S / 2
		local ex = hx - Rt
		local Fs, Gs = P.FS * q, P.GS * q
		local Fi, Gi = P.FI, P.GI
		local Fh, Gh = P.FH, P.GH
		local k, opp = P.GK, P.GO
		local ax, ay = cos(P.GA), sin(P.GA)
		local buf = buffer.create(S * S * 4)
		for Y = 0, S - 1 do
			for X = 0, S - 1 do
				local s, nx, ny = sdfAt(X + 0.5 - hx, Y + 0.5 - hx, ex, ex, Rt, nn)
				local a8 = 0
				local m = s + 0.5
				if m > 0 then
					if m > 1 then
						m = 1
					end
					local sp = s > 0 and s or 0
					local a = 0
					if Fi > 0 and sp < Fs then
						a = a + Fi * edgeProfile(sp / Fs, Fh)
					end
					if Gi > 0 and sp < Gs then
						local c = nx * ax + ny * ay
						local g = 0
						if c > 0 then
							g = c ^ k
						elseif opp > 0 and c < 0 then
							g = opp * (-c) ^ k
						end
						if g > 0.002 then
							a = a + Gi * g * edgeProfile(sp / Gs, Gh)
						end
					end
					if a > 1 then
						a = 1
					end
					a8 = floor(a * m * 255 + 0.5)
				end
				buffer.writeu32(buf, (Y * S + X) * 4, 16777215 + a8 * 16777216)
			end
			if step then
				step()
			end
		end
		return buf, S, Cq
	end

end
--[[CORE_END]]

----------------------------------------------------------------------
-- LIQUID GLASS v6 - phần ghép vào Roblox.
-- Mô hình thuộc tính, giá trị mặc định và khoảng giá trị lấy NGUYÊN theo bảng "Controls" trong README của GlassmorphicUI.
-- Đường ống 3 bước theo bài blog: (1) bake hình học (cache theo khoá hình học) -> (2) lấy mẫu backdrop vào lưới thô
-- KHÔNG đều, làm dần theo ngân sách ms/frame -> (3) dựng lại ảnh: khúc xạ + tán sắc + bicubic + tint + frost gaussian,
-- rồi viền Fresnel/glare cộng SAU frost.
----------------------------------------------------------------------
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")

local GLASS_DEFAULTS = {
	Thickness = UDim.new(0.15, 0), -- độ sâu dải khúc xạ = tầm với vào trong = độ gắt của khúc xạ (1px .. trục nhỏ)
	RefractionFactor = 2.1, -- 1..4 (1 = tắt khúc xạ)
	ChromaticAberration = 0.2, -- 0..1: đỏ lấy xa hơn 20%, xanh dương gần hơn 20% so với xanh lá
	CornerRadius = UDim.new(0.8, 0), -- (bị bỏ qua ở ĐẢO: bán kính góc do spring của đảo quyết định)
	SuperEllipseFactor = 3, -- 2..7: 2 = góc tròn, càng cao càng vuông
	FresnelSize = UDim.new(0.1, 0), -- tầm với của viền sáng (0 = tắt)
	FresnelHardness = 40, -- 0..100
	FresnelIntensity = 25, -- 0..100
	GlareSize = UDim.new(0.2, 0), -- tầm với của glint (0 = tắt)
	GlareHardness = 40, -- 0..100
	GlareIntensity = 70, -- 0..120
	GlareConvergence = 90, -- 0..100: glint bám chặt trục glare đến đâu
	GlareOppositeSide = 50, -- 0..100: độ mạnh glint thứ hai ở phía đối diện
	GlareAngle = -50, -- ±180 độ, hệ toạ độ màn hình (y hướng xuống): âm = hướng lên
	BlurRadius = UDim.new(0.06, 0), -- bán kính frost (1px .. trục nhỏ); sigma gaussian = 1/3 bán kính
	Transparency = 0.5, -- 0..1: độ trong của tint. 0 = tint đặc, KHÔNG lấy mẫu backdrop
	BackgroundColor3 = Color3.fromRGB(163, 162, 165), -- màu tint
	MaxOutputResolution = 1024, -- 16..1024: trục lớn tối đa của ảnh kính
}

local NUM_RANGE = {
	RefractionFactor = { 1, 4 },
	ChromaticAberration = { 0, 1 },
	SuperEllipseFactor = { 2, 7 },
	FresnelHardness = { 0, 100 },
	FresnelIntensity = { 0, 100 },
	GlareHardness = { 0, 100 },
	GlareIntensity = { 0, 120 },
	GlareConvergence = { 0, 100 },
	GlareOppositeSide = { 0, 100 },
	GlareAngle = { -180, 180 },
	Transparency = { 0, 1 },
	MaxOutputResolution = { 16, 1024 },
}
local UDIM_ATTRS = { Thickness = true, CornerRadius = true, FresnelSize = true, GlareSize = true, BlurRadius = true }

-- Riêng cho ĐẢO (README không có mục này): thân đảo chỉ cao 37px nên dải khúc xạ dày hơn mặc định một chút,
-- và có lớp tint tối nhẹ để chữ trắng dễ đọc. Muốn giống README tuyệt đối: Liquid = { Thickness = UDim.new(0.15, 0), Transparency = 0.5 }
local ISLAND_GLASS = {
	Thickness = UDim.new(0.3, 0),
	Transparency = 0.7,
	BackgroundColor3 = Color3.fromRGB(10, 10, 14),
}

-- Tuỳ chọn engine ngoài README (lấy mẫu backdrop + hiệu năng)
local ENGINE_DEFAULTS = {
	GuiLayers = true, -- đọc cả các lớp GUI nằm sau đảo (PlayerGui:GetGuiObjectsAtPosition) như bài blog mô tả
	Backdrop = true, -- false = chỉ lấy mẫu một lần
	BackdropHz = 5, -- số lần quét lại backdrop mỗi giây
	SamplerWarp = 0.5, -- 0..0.9: lưới nguồn dày hơn ở sát mép (0 = lưới đều)
	RimQuality = 2, -- siêu mẫu cho ảnh viền (1..3)
	MaxPixels = 24000, -- trần số pixel của ảnh lens (đảo to sẽ hạ độ phân giải; frost che đi)
	Budget = 3, -- ms tối đa mỗi frame cho việc dựng ảnh + lấy mẫu
	-- Sky = { Top = Color3, Horizon = Color3 }  ép màu trời nếu ước lượng bị lệch
	-- Library = <ModuleScript | bảng đã require | hàm trả về module> của chính GlassmorphicUI -> dùng đúng thư viện gốc
}

local function mergeAttrs(dst, src)
	if type(src) ~= "table" then
		return
	end
	for k, v in pairs(src) do
		if k == "Tint" then
			k = "BackgroundColor3"
		end
		if UDIM_ATTRS[k] then
			if typeof(v) == "UDim" then
				dst[k] = v
			elseif type(v) == "number" then
				dst[k] = UDim.new(0, v)
			end
		elseif NUM_RANGE[k] then
			if type(v) == "number" then -- sai kiểu = bỏ qua, giữ mặc định (đúng như README)
				dst[k] = clampN(v, NUM_RANGE[k][1], NUM_RANGE[k][2])
			end
		elseif k == "BackgroundColor3" then
			if typeof(v) == "Color3" then
				dst[k] = v
			end
		else
			dst[k] = v
		end
	end
end

local function buildAttrs(opts)
	local A = {}
	for k, v in pairs(GLASS_DEFAULTS) do
		A[k] = v
	end
	for k, v in pairs(ISLAND_GLASS) do
		A[k] = v
	end
	for k, v in pairs(ENGINE_DEFAULTS) do
		A[k] = v
	end
	mergeAttrs(A, opts)
	return A
end

-- Bán kính tròn tương đương để UICorner cắt thân đảo khớp góc siêu elip (cùng tiếp điểm với hai cạnh và cùng điểm chéo)
local function clipFactor(nn)
	return (1 - 2 ^ (-1 / nn)) * 1.41421356 / 0.41421356
end

local Liquid = {}
Liquid.__index = Liquid

local SETTLE = 0.12 -- đảo đứng yên bao lâu thì mới dựng lại lens
local LENS_GAP = 0.08 -- giãn cách tối thiểu giữa hai lần dựng lens
local RIM_CACHE_MAX = 14
local RAY_LEN = 2000
local DAY_TOP, DAY_HOR = { 0.36, 0.56, 0.88 }, { 0.74, 0.84, 0.94 }
local NIGHT_TOP, NIGHT_HOR = { 0.02, 0.03, 0.08 }, { 0.07, 0.09, 0.15 }
local SUNSET = { 0.95, 0.5, 0.3 }

local function lerp(a, b, t)
	return a + (b - a) * t
end

function Liquid.new(isl, body, A)
	local self = setmetatable({}, Liquid)
	self.isl, self.body, self.A = isl, body, A
	self.q = clampN(floor(A.RimQuality or 2), 1, 3)
	self.rimCache, self.rimCount = {}, 0
	self.writes = {}
	self.shape = { w = 0, h = 0, r = 0 }
	self.shapeKey = -1
	self.lastChange = os.clock()
	self.lensStart = 0
	self.lensDirty = true
	self.nextSample = 0
	self.enabled = true
	self.paused = false
	self.failed = false
	self.destroyed = false
	self.resCap = clampN(floor(A.MaxOutputResolution), 16, 1024)
	self.framesSince = 0
	self.samplesTotal = 0

	-- GlassPane: ảnh kính (khúc xạ + frost + tint). Nằm dưới mọi thứ khác trong thân, như README ("below other children").
	self.lens = mk("ImageLabel", {
		Name = "GlassPane",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, body)
	-- Viền Fresnel + glare, 9-slice nên bám đúng đường bo ở mọi kích thước.
	self.rim = mk("ImageLabel", {
		Name = "GlassRim",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		ScaleType = Enum.ScaleType.Slice,
		SliceScale = 1 / self.q,
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
	local ok, a, b, c, d, e = coroutine.resume(job.co)
	if not ok then
		self:_fail(a)
		return true
	end
	if coroutine.status(job.co) == "dead" then
		return true, a, b, c, d, e
	end
	return false
end

----------------------------------------------------------------------
-- Hình dạng đảo: gọi mỗi khi đảo đổi kích thước/bán kính (đơn vị của đảo, trước UIScale)
----------------------------------------------------------------------
function Liquid:ClipRadius(r)
	return r * clipFactor(clampN(self.A.SuperEllipseFactor, 2, 7))
end

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
		self.sampledOnce = false -- lưới backdrop gắn với hình dạng cũ: lấy mẫu lại rồi mới dựng lens
	end

	local k = clampN(h / 16, 0, 1) -- viền mờ dần khi đảo thu về 0
	local tr = 1 - k
	if self.rimTr ~= tr then
		self.rimTr = tr
		self.rim.ImageTransparency = tr
	end

	local m = min(w, h)
	if m >= 8 then
		local A = self.A
		local half = m / 2
		local rq = floor(min(r, half) / 2) * 2 -- lượng tử 2px: tile viền bake theo bán kính, có cache
		rq = max(4, min(rq, floor(half)))
		self:_wantRim(rq, resolveUDim(A.FresnelSize, m, 0, half), resolveUDim(A.GlareSize, m, 0, half))
	end
end

function Liquid:_rimParams(w)
	local A = self.A
	local c = A.GlareConvergence / 100
	return {
		n = clampN(A.SuperEllipseFactor, 2, 7),
		FS = w.FS,
		FH = A.FresnelHardness / 100,
		FI = A.FresnelIntensity / 100,
		GS = w.GS,
		GH = A.GlareHardness / 100,
		GI = A.GlareIntensity / 100,
		GK = 1 + 59 * c * c, -- hội tụ cao -> số mũ lớn -> glint chỉ bám sát trục glare
		GO = A.GlareOppositeSide / 100,
		GA = math.rad(A.GlareAngle),
	}
end

function Liquid:_wantRim(rq, FS, GS)
	local key = rq * 1000000 + floor(FS * 2) * 1000 + floor(GS * 2)
	local w = self.rimWanted
	if not w or w.key ~= key then
		w = { key = key, rq = rq, FS = FS, GS = GS }
		self.rimWanted = w
	end
	local e = self.rimCache[key]
	if e then
		self:_useRim(e)
	elseif self.rimShown == nil then
		self:_bakeNow(w) -- lần đầu: dựng đồng bộ để có viền ngay frame đầu
	elseif self.rimShown.rq > rq then
		-- Đảo đang co lại mà tile đúng bán kính chưa bake xong: tạm dùng tile gần nhất KHÔNG lớn hơn,
		-- vì tile lớn hơn nửa chiều nhỏ của thân sẽ làm 9-slice bị chồng.
		local best
		for _, c in pairs(self.rimCache) do
			if c.rq <= rq and (not best or c.rq > best.rq) then
				best = c
			end
		end
		if best then
			self:_useRim(best)
		end
	end
end

function Liquid:_useRim(e)
	e.last = os.clock()
	if self.rimShown == e then
		return
	end
	self.rimShown = e
	local rim = self.rim
	rim.SliceCenter = Rect.new(e.cq, e.cq, e.cq + 2, e.cq + 2)
	rim.SliceScale = 1 / self.q
	if not self:_show(rim, e.img) then
		self:_fail("không gán được ảnh viền")
	end
end

function Liquid:_bakeNow(w)
	local buf, S, Cq = bakeRim(self:_rimParams(w), w.rq, self.q, nil)
	self:_storeRim(w, buf, S, Cq)
end

function Liquid:_storeRim(w, buf, S, Cq)
	local img = self:_newImage(S, S)
	if not img or not self:_write(img, S, S, buf) then
		self:_fail("không tạo/ghi được ảnh viền")
		return
	end
	local old = self.rimCache[w.key]
	if old then
		pcall(function()
			old.img:Destroy()
		end)
		self.rimCount = self.rimCount - 1
		if self.rimShown == old then
			self.rimShown = nil
		end
	end
	local e = { img = img, cq = Cq, rq = w.rq, key = w.key, last = os.clock() }
	self.rimCache[w.key] = e
	self.rimCount = self.rimCount + 1
	self:_evict()
	local want = self.rimWanted
	if want and want.key == w.key then
		self:_useRim(e)
	end
end

function Liquid:_evict()
	while self.rimCount > RIM_CACHE_MAX do
		local oldK, oldT
		local want = self.rimWanted
		for k, e in pairs(self.rimCache) do
			if e ~= self.rimShown and not (want and want.key == k) and (not oldT or e.last < oldT) then
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
	self.rimShown = nil
end

----------------------------------------------------------------------
-- Lấy mẫu backdrop (bước 2 của bài blog). Roblox không có API đọc màn hình nên "ước lượng" từ:
--   (a) các lớp GUI nằm sau đảo (PlayerGui:GetGuiObjectsAtPosition) -> (b) raycast cảnh 3D -> (c) màu trời theo ngày/đêm
----------------------------------------------------------------------
function Liquid:_gridSize(W, H)
	return clampN(floor(W / 12 + 0.5), 8, 28), clampN(floor(H / 12 + 0.5), 4, 14)
end

function Liquid:_ensureGrid(gw, gh)
	if self.gr and self.gw == gw and self.gh == gh then
		return
	end
	local base = self.A.BackgroundColor3
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
	local sky = self.A.Sky
	if type(sky) == "table" then
		local t, h = sky.Top, sky.Horizon
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

-- Màu một điểm trên màn hình (cảnh 3D): trúng vật -> màu vật nhân sáng đơn giản (Lambert + sương xa), trượt -> màu trời
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

-- Các lớp GUI nằm sau điểm (x, y): chồng màu nền (BackgroundColor3 theo BackgroundTransparency) từ DƯỚI lên TRÊN lên màu cảnh.
-- Ảnh (ImageLabel...) không đọc được pixel nên chỉ tính phần nền của chúng.
function Liquid:_guiLayers(st, x, y, r, g, b)
	local ok, list = pcall(st.pg.GetGuiObjectsAtPosition, st.pg, x, y - st.inset)
	if not ok then
		self.guiErrors = (self.guiErrors or 0) + 1
		if self.guiErrors >= 3 then
			self.guiOff = true
			warn("[DynamicIsland] Tắt đọc lớp GUI phía sau vì lỗi: " .. tostring(list))
		end
		return r, g, b
	end
	local n = #list
	if n > 8 then
		n = 8
	end
	local mine = self.isl._gui
	for i = n, 1, -1 do -- danh sách trả về từ trên xuống dưới
		local o = list[i]
		if o ~= mine and not o:IsDescendantOf(mine) then
			local bt = o.BackgroundTransparency
			if bt < 0.98 then
				local c = o.BackgroundColor3
				local a = 1 - bt
				r, g, b = r + (c.R - r) * a, g + (c.G - g) * a, b + (c.B - b) * a
			end
		end
	end
	return r, g, b
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
		local gw, gh = self:_gridSize(sh.w, sh.h)
		self:_ensureGrid(gw, gh)
		self.sky = self:_skySnapshot()
		self.rayParams = self.rayParams or RaycastParams.new()
		local pg, inset = nil, 0
		if self.A.GuiLayers ~= false and not self.guiOff then
			local lp = Players.LocalPlayer
			pg = lp and lp:FindFirstChildOfClass("PlayerGui")
			local okI, v = pcall(function()
				return GuiService:GetGuiInset()
			end)
			if okI and v then
				inset = v.Y
			end
		end
		st = { i = 0, n = gw * gh, gw = gw, gh = gh, gr = self.gr, gg = self.gg, gb = self.gb, delta = 0, fresh = self.gridFresh, pg = pg, inset = inset }
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
	local wb = clampN(self.A.SamplerWarp or 0.5, 0, 0.9) -- phải trùng với renderLens
	while st.i < st.n and os.clock() < dl do
		local i = st.i
		local cx, cy = i % gw, floor(i / gw)
		local sx = ap.X + warp01((cx + 0.5) / gw, wb) * sz.X
		local sy = ap.Y + warp01((cy + 0.5) / gh, wb) * sz.Y
		local ray = cam:ViewportPointToRay(sx, sy)
		local res = workspace:Raycast(ray.Origin, ray.Direction * RAY_LEN, self.rayParams)
		local idx = i + 1
		local r, g, b = self:_colorOf(res, ray.Direction)
		if not r then
			r, g, b = st.gr[idx], st.gg[idx], st.gb[idx]
		end
		if st.pg and not self.guiOff then
			r, g, b = self:_guiLayers(st, sx, sy, r, g, b)
		end
		local o1, o2, o3 = st.gr[idx], st.gg[idx], st.gb[idx]
		local n1, n2, n3 = o1 + (r - o1) * k, o2 + (g - o2) * k, o3 + (b - o3) * k
		st.delta = st.delta + abs(n1 - o1) + abs(n2 - o2) + abs(n3 - o3)
		st.gr[idx], st.gg[idx], st.gb[idx] = n1, n2, n3
		st.i = i + 1
		self.samplesTotal = self.samplesTotal + 1
	end
	if st.i >= st.n then
		self.samp = nil
		self.sampledOnce = true
		self.gridFresh = false
		self.nextSample = now + 1 / max(self.A.BackdropHz or 5, 0.2)
		if st.fresh or st.delta / (st.n * 3) > 0.004 then
			self.lensDirty = true -- nền đổi đủ nhiều mới dựng lại lens (đứng yên = không tốn gì thêm)
		end
	end
end

----------------------------------------------------------------------
-- Lens: bake hình học (có cache) rồi dựng lại ảnh (bước 1 + 3), chạy trong coroutine theo ngân sách ms
----------------------------------------------------------------------
function Liquid:_startLens(now)
	local sh = self.shape
	local W, H = sh.w, sh.h
	if W < 12 or H < 12 then
		return
	end
	local A = self.A
	local m = min(W, H)
	local half = m / 2
	local R = clampN(sh.r, 0, half)
	local nn = clampN(A.SuperEllipseFactor, 2, 7)
	local T = resolveUDim(A.Thickness, m, 1, half)
	local ior = clampN(A.RefractionFactor, 1, 4)
	local ca = clampN(A.ChromaticAberration, 0, 1)
	local blur = resolveUDim(A.BlurRadius, m, 1, m)
	local T01 = clampN(A.Transparency, 0, 1)
	local cap = min(self.resCap, clampN(floor(A.MaxOutputResolution), 16, 1024))
	local ds = max(1, sqrt(W * H / (A.MaxPixels or 24000)), max(W, H) / cap)
	local LW, LH = max(2, ceil(W / ds)), max(2, ceil(H / ds))
	local tint = A.BackgroundColor3
	local P = {
		W = W, H = H, LW = LW, LH = LH, ca = ca,
		tr = tint.R, tg = tint.G, tb = tint.B, tw = 1 - T01,
		warp = clampN(A.SamplerWarp or 0.5, 0, 0.9),
	}
	if T01 > 0.001 then -- Transparency = 0: tint đặc, bỏ qua backdrop hoàn toàn
		local gw, gh = self:_gridSize(W, H)
		self:_ensureGrid(gw, gh)
		P.gw, P.gh = self.gw, self.gh
		-- ảnh chụp lưới tại thời điểm bắt đầu: đầu vào bất biến cho cả lượt dựng (sampler vẫn cập nhật lưới gốc)
		P.gr, P.gg, P.gb = table.clone(self.gr), table.clone(self.gg), table.clone(self.gb)
		P.blurRadii = gaussBoxRadii(blur / 3 / (W / LW)) -- sigma = BlurRadius / 3 (tính theo pixel lens)
	end
	local gkey = string.format(
		"%d|%d|%d|%d|%d|%d|%d|%d",
		floor(W * 2 + 0.5), floor(H * 2 + 0.5), floor(R * 4 + 0.5), floor(nn * 100 + 0.5),
		floor(T * 4 + 0.5), floor(ior * 100 + 0.5), LW, LH
	)
	local reuse = nil
	if self.geoKey == gkey then
		reuse = self.geo
	end
	local G = { W = W, H = H, R = R, n = nn, T = T, ior = ior, bevel = 1, base = 0.45, LW = LW, LH = LH }
	self.lensJob = self:_newJob(function(step)
		local geo = reuse or bakeGeometry(G, step)
		local buf, w, h = renderLens(P, geo, step)
		return buf, w, h, geo, gkey
	end)
	self.lensDirty = false
	self.lensStart = now
end

function Liquid:_flush(w)
	if w.kind == "rim" then
		self:_storeRim(w.entry, w.buf, w.w, w.cq)
		return
	end
	if not self.lensImg or self.lensW ~= w.w or self.lensH ~= w.h then
		local img = self:_newImage(w.w, w.h)
		if not img then
			-- hết bộ nhớ EditableImage: hạ độ phân giải một nửa (README: "halves its resolution down to 32") rồi dựng lại
			local axis = max(w.w, w.h)
			if axis <= 32 then
				self:_fail("không tạo được ảnh lens (đã hạ tới 32px)")
			else
				self.resCap = max(32, axis // 2)
				self.lensDirty = true
				warn("[DynamicIsland] Hết bộ nhớ EditableImage, hạ độ phân giải kính xuống " .. tostring(self.resCap))
			end
			return
		end
		if not self:_write(img, w.w, w.h, w.buf) or not self:_show(self.lens, img) then
			self:_fail("không ghi/gán được ảnh lens")
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
	self.framesSince = self.framesSince + 1
	local A = self.A
	local deadline = now + (A.Budget or 3) / 1000

	-- 1) viền: dựng tile cho bán kính đang cần nếu chưa có trong cache
	local job = self.rimJob
	if not job then
		local want = self.rimWanted
		if want and not self.rimCache[want.key] then
			job = self:_newJob(function(step)
				return bakeRim(self:_rimParams(want), want.rq, self.q, step)
			end)
			job.want = want
			self.rimJob = job
		end
	end
	if job then
		local done, buf, S, Cq = self:_resume(job, deadline)
		if done then
			self.rimJob = nil
			if buf then
				self.writes[#self.writes + 1] = { kind = "rim", entry = job.want, buf = buf, w = S, cq = Cq }
			end
		end
	end

	-- 2) EditableImage chỉ cho cập nhật 1 lần/frame -> mỗi frame ghi tối đa một ảnh
	local w = table.remove(self.writes, 1)
	if w then
		self:_flush(w)
	end

	-- Pause: lần dựng đầu vẫn chạy để kính không trống (đúng README), sau đó đứng yên tới khi Resume/ForceUpdate
	local frozen = self.paused and self.lensImg ~= nil
	if frozen then
		return
	end

	-- 3) backdrop (Transparency = 0 thì không cần)
	if A.Transparency > 0.001 and os.clock() < deadline and (A.Backdrop ~= false or not self.sampledOnce) then
		local ok, err = pcall(self._sample, self, now, min(deadline, os.clock() + 0.001))
		if not ok then
			self.sampErrors = (self.sampErrors or 0) + 1
			self.samp = nil
			if self.sampErrors >= 3 then
				A.Backdrop = false
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
		-- chờ lượt lấy mẫu backdrop đầu tiên xong (không lấy được quá 1.5s thì vẫn dựng với lưới hiện có)
		and (A.Transparency <= 0.001 or self.sampledOnce or now - self.lastChange > 1.5)
	then
		self:_startLens(now)
	end
	local lj = self.lensJob
	if lj and os.clock() < deadline then
		local done, buf, LW, LH, geo, gkey = self:_resume(lj, deadline)
		if done and self.lensJob == lj then
			self.lensJob = nil
			if buf then
				self.geo, self.geoKey = geo, gkey
				self.framesSince = 0
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
-- Điều khiển (tương ứng pauseUpdates / resumeUpdates / forceUpdate / getDebugStats của thư viện gốc)
----------------------------------------------------------------------
function Liquid:SetVisible(on)
	self.enabled = on and true or false
	self.lens.Visible = self.enabled
	self.rim.Visible = self.enabled
	if self.enabled then
		self.lensDirty = true
	end
end

-- Dựng lại toàn bộ: hình học + lấy mẫu + ảnh (làm dần theo ngân sách, không chặn một frame như forceUpdate gốc)
function Liquid:Refresh()
	self.geo, self.geoKey = nil, nil
	self.sampledOnce = false
	self.nextSample = 0
	self.samp = nil
	self.lensDirty = true
	self.lensJob = nil
	self.lastChange = 0
end

function Liquid:Pause()
	self.paused = true
end

function Liquid:Resume()
	self.paused = false
	self.lensDirty = true
end

function Liquid:GetStats()
	local path = "idle"
	if self.lensJob or self.rimJob or self.samp then
		path = "sync"
	end
	return {
		GridResolution = Vector2.new(self.gw or 0, self.gh or 0),
		OutputResolution = Vector2.new(self.lensW or 0, self.lensH or 0),
		BackdropSamples = self.samplesTotal,
		FramesSinceReconstruction = self.framesSince,
		ExecutionPath = path,
	}
end

function Liquid:SetParams(opts)
	mergeAttrs(self.A, opts)
	self.q = clampN(floor(self.A.RimQuality or 2), 1, 3)
	self.resCap = clampN(floor(self.A.MaxOutputResolution), 16, 1024)
	self.rimJob = nil
	self.writes = {}
	self:_clearRims()
	self:Refresh()
	local sh = self.shape
	if sh.w > 0 then
		self:NoteShape(sh.w, sh.h, sh.r)
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
-- LibGlass: dùng CHÍNH module GlassmorphicUI (boatbeaker) làm kính - cách DUY NHẤT để giống 100% với bản gốc.
-- Bật bằng Liquid = { Library = <ModuleScript> } (hoặc bảng đã require / hàm trả về module). Mọi tên thuộc tính như README.
-- Lỗi gì thì tự quay về engine dựng lại trong file. CHƯA kiểm chứng với module thật (mình không đọc được mã nguồn của nó).
----------------------------------------------------------------------
local LibGlass = {}
LibGlass.__index = LibGlass

local LIB_ATTRS = {
	"Thickness", "RefractionFactor", "ChromaticAberration", "SuperEllipseFactor", "FresnelSize", "FresnelHardness",
	"FresnelIntensity", "GlareSize", "GlareHardness", "GlareIntensity", "GlareConvergence", "GlareOppositeSide",
	"GlareAngle", "BlurRadius", "Transparency", "MaxOutputResolution",
}

function LibGlass.new(isl, body, A)
	local lib = A.Library
	if typeof(lib) == "Instance" then
		lib = require(lib)
	elseif type(lib) == "function" then
		lib = lib()
	end
	if type(lib) ~= "table" or type(lib.addGlassBackground) ~= "function" then
		error("Library phải là module GlassmorphicUI (có addGlassBackground)")
	end
	local self = setmetatable({}, LibGlass)
	self.isl, self.body, self.lib, self.A = isl, body, lib, A
	self.lastChange = os.clock()
	self.shapeKey = -1
	self.paused = false
	self.destroyed = false
	self:_applyAttrs(A)
	body.BackgroundColor3 = A.BackgroundColor3
	lib.addGlassBackground(body)
	self.pane = body:FindFirstChild("GlassPane")
	return self
end

function LibGlass:_applyAttrs(A)
	for _, name in ipairs(LIB_ATTRS) do
		local v = A[name]
		if v ~= nil then
			pcall(self.body.SetAttribute, self.body, name, v)
		end
	end
end

function LibGlass:ClipRadius(r)
	return r * clipFactor(clampN(self.A.SuperEllipseFactor, 2, 7))
end

function LibGlass:NoteShape(w, h, r)
	local key = floor(w + 0.5) * 1000000 + floor(h + 0.5) * 1000 + floor(r * 2)
	if key == self.shapeKey then
		return
	end
	self.shapeKey = key
	self.lastChange = os.clock()
	-- đang co giãn: tạm dừng để thư viện khỏi dựng lại mỗi frame; đứng yên rồi mới Resume (xem SafeStep)
	if not self.paused then
		self.paused = true
		pcall(self.lib.pauseUpdates, self.body)
	end
	-- README: CornerRadius resolved 0..trục nhỏ; 1.0 = bo tròn hết (viên thuốc)
	local m = max(min(w, h), 1)
	pcall(self.body.SetAttribute, self.body, "CornerRadius", UDim.new(clampN(2 * r / m, 0, 1), 0))
end

function LibGlass:SafeStep()
	if self.paused and os.clock() - self.lastChange >= SETTLE then
		self.paused = false
		pcall(self.lib.resumeUpdates, self.body)
	end
end

function LibGlass:SetVisible(on)
	if self.pane then
		self.pane.Visible = on and true or false
	end
end

function LibGlass:Refresh()
	pcall(self.lib.forceUpdate, self.body)
end

function LibGlass:Pause()
	self.paused = true
	pcall(self.lib.pauseUpdates, self.body)
end

function LibGlass:Resume()
	self.paused = false
	pcall(self.lib.resumeUpdates, self.body)
end

function LibGlass:GetStats()
	local ok, s = pcall(self.lib.getDebugStats, self.body)
	return ok and s or nil
end

function LibGlass:SetParams(opts)
	mergeAttrs(self.A, opts)
	self:_applyAttrs(self.A)
	self.body.BackgroundColor3 = self.A.BackgroundColor3
end

function LibGlass:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	pcall(function()
		CollectionService:RemoveTag(self.body, "GlassmorphicUI")
	end)
	if self.pane then
		pcall(function()
			self.pane:Destroy()
		end)
	end
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
	-- Liquid: UICorner cắt thân theo bán kính tròn TƯƠNG ĐƯƠNG của góc siêu elip (khớp hình dạng kính)
	local rc = r
	if self._lgOn and self._lg then
		rc = self._lg:ClipRadius(r)
	end
	self._bodyCorner.CornerRadius = UDim.new(0, rc)

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
	-- v6: glare có hướng cố định theo GlareAngle (như README) nên viền Liquid không xoay theo trạng thái nữa
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

function Island:_lgCreate()
	if self._lg or not self._cfg.Liquid or not self._glass then
		return
	end
	local opts = type(self._cfg.Liquid) == "table" and self._cfg.Liquid or nil
	local A = buildAttrs(opts)
	local ok, lg
	if A.Library ~= nil then
		ok, lg = pcall(LibGlass.new, self, self._body, A)
		if not ok then
			warn("[DynamicIsland] Không dùng được module GlassmorphicUI (" .. tostring(lg) .. "), chuyển sang engine dựng lại trong file.")
			A.Library = nil
			ok, lg = pcall(Liquid.new, self, self._body, A)
		end
	else
		ok, lg = pcall(Liquid.new, self, self._body, A)
	end
	if ok and lg then
		self._lg = lg
		self._lgOn = true
	else
		self._lgOn = false
		warn("[DynamicIsland] Không bật được Liquid glass (" .. tostring(lg) .. "), dùng kính cổ điển.")
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

-- false = kính cổ điển; true/bảng = bật engine mới (bảng = ghi đè thuộc tính, tên như README GlassmorphicUI)
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

-- Tạm dừng / chạy lại / thống kê kính (tương ứng pauseUpdates / resumeUpdates / getDebugStats của thư viện gốc)
function Island:PauseGlass()
	if self._lg then
		self._lg:Pause()
	end
end

function Island:ResumeGlass()
	if self._lg then
		self._lg:Resume()
	end
end

function Island:GlassStats()
	return self._lg and self._lg:GetStats() or nil
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
