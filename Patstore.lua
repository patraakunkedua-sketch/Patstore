-- ======================================================
--   282STORE - AUTO MARSHMALLOW v6
--   StarterPlayer > StarterPlayerScripts (LocalScript)
-- ======================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM          = game:GetService("VirtualInputManager")
local UIS          = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")



-- ============================================================
-- KONFIGURASI — sesuaikan jika nama berbeda di game kamu
-- ============================================================
local CFG = {
	WATER_WAIT    = 20,
	COOK_WAIT     = 46,

	-- Nama item bahan
	ITEM_WATER = "Water",
	ITEM_SUGAR = "Sugar Block Bag",
	ITEM_GEL   = "Gelatin",
	ITEM_EMPTY = "Empty Bag",

	-- Nama marshmallow sesuai ukuran di game (dari screenshot inventory)
	ITEM_MS_SMALL  = "Small Marshmallow Bag",
	ITEM_MS_MEDIUM = "Medium Marshmallow Bag",
	ITEM_MS_LARGE  = "Large Marshmallow Bag",

	-- Radius karakter harus berada di dekat NPC
	SELL_RADIUS  = 10,
	BUY_RADIUS   = 10,

	-- Timeout tunggu item berkurang setelah jual
	SELL_TIMEOUT = 8,

	-- Timeout tunggu dialog/GUI muncul setelah E ke NPC
	BUY_DIALOG_WAIT = 4,   -- detik tunggu GUI muncul
	BUY_ITEM_WAIT   = 2,   -- detik tunggu setelah klik item

	-- Keyword tombol konfirmasi dialog (huruf kecil, partial match)
	BUY_CONFIRM_KW = "yea",

	-- Item di menu toko (keyword huruf kecil, cocokkan dengan teks tombol di game)
	BUY_ITEMS = {
		{ keyword = "gelatin",  name = "Gelatin"        },
		{ keyword = "sugar",    name = "Sugar Block Bag" },  -- "Sugar Block" di menu
		{ keyword = "water",    name = "Water"           },  -- "Water" di menu
	},
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning = false
local isBusy    = false
local totalSold = 0
local totalBuy  = 0
local stats     = { small = 0, medium = 0, large = 0 }

local function totalMS() return stats.small + stats.medium + stats.large end

-- ============================================================
-- CORE UTILITIES
-- ============================================================
local function pressE()
	-- Coba VIM dulu, fallback ke fireproximityprompt
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.15)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

local function fireAllNearbyPrompts(radius)
	-- Fire SEMUA ProximityPrompt dalam radius tanpa filter keyword
	-- (karena kita tidak tahu nama prompt NPC di game)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local part = obj.Parent
			if part and part:IsA("BasePart") then
				local dist = (hrp.Position - part.Position).Magnitude
				if dist <= (radius or 10) then
					pcall(function() fireproximityprompt(obj) end)
				end
			end
		end
	end
end

local function countItem(name)
	local n = 0
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t.Name == name then n += 1 end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t.Name == name then n += 1 end
		end
	end
	return n
end

local function equipTool(name)
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t   = player.Backpack:FindFirstChild(name)
	if hum and t then
		hum:EquipTool(t)
		task.wait(0.4)
		return true
	end
	return false
end

local function unequipAll()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
end

local function hasAllIngredients()
	return countItem(CFG.ITEM_WATER) >= 1
		and countItem(CFG.ITEM_SUGAR) >= 1
		and countItem(CFG.ITEM_GEL)   >= 1
end

-- Cari button berdasarkan Name object (bukan teks)
local function findButtonByName(guiName, btnName, timeout)
	local elapsed = 0
	timeout = timeout or 5
	while elapsed < timeout do
		for _, sg in ipairs(playerGui:GetChildren()) do
			if sg:IsA("ScreenGui") and (guiName == "" or sg.Name == guiName) then
				for _, obj in ipairs(sg:GetDescendants()) do
					if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
						and obj.Visible
						and obj.Name == btnName then
						return obj
					end
				end
			end
		end
		task.wait(0.2)
		elapsed += 0.2
	end
	return nil
end

-- Cari SEMUA button dengan Name tertentu sekaligus
local function findAllButtonsByName(guiName, btnName)
	local list = {}
	for _, sg in ipairs(playerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and (guiName == "" or sg.Name == guiName) then
			for _, obj in ipairs(sg:GetDescendants()) do
				if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
					and obj.Visible
					and obj.Name == btnName then
					table.insert(list, obj)
				end
			end
		end
	end
	return list
end

-- Klik TextButton — pakai semua metode yang tersedia di executor
local function clickButton(btn)
	if not btn then return false end

	-- Metode 1: VIM SendMouseButtonEvent (paling umum di executor)
	pcall(function()
		local pos = btn.AbsolutePosition
		local sz  = btn.AbsoluteSize
		local cx  = math.floor(pos.X + sz.X / 2)
		local cy  = math.floor(pos.Y + sz.Y / 2)
		VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
		task.wait(0.1)
		VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
	end)
	task.wait(0.05)

	-- Metode 2: firebutton (executor function khusus TextButton)
	pcall(function()
		-- luau executor function
		local ok = firebutton ~= nil
		if ok then firebutton(btn) end
	end)

	-- Metode 3: Simulasi MouseButton1Click signal langsung
	pcall(function()
		btn.MouseButton1Click:Fire()
	end)

	-- Metode 4: Activate button
	pcall(function()
		btn:Activate()
	end)

	return true
end

-- ============================================================
-- AUTO JUAL
-- Logika:
--   Karakter HARUS sudah berdiri dekat NPC jual (dalam radius)
--   1. Equip 1 Marshmallow
--   2. Fire semua ProximityPrompt di sekitar + pressE
--   3. Tunggu MS berkurang (konfirmasi terjual)
--   4. Ulangi sampai inventory MS = 0
-- ============================================================
-- Ambil nama item MS pertama yang ada di inventory (small → medium → large)
local function getEquippableMS()
	if countItem(CFG.ITEM_MS_SMALL)  > 0 then return CFG.ITEM_MS_SMALL  end
	if countItem(CFG.ITEM_MS_MEDIUM) > 0 then return CFG.ITEM_MS_MEDIUM end
	if countItem(CFG.ITEM_MS_LARGE)  > 0 then return CFG.ITEM_MS_LARGE  end
	return nil
end

local function countAllMS()
	return countItem(CFG.ITEM_MS_SMALL)
		+ countItem(CFG.ITEM_MS_MEDIUM)
		+ countItem(CFG.ITEM_MS_LARGE)
end

local function doAutoSell(setStatus)
	local msTotal = countAllMS()

	if msTotal == 0 then
		setStatus("ℹ️ Tidak ada MS di inventory", Color3.fromRGB(160,160,180))
		return
	end

	setStatus("💰 Memulai jual "..msTotal.." MS...", Color3.fromRGB(50,210,110))
	task.wait(0.3)

	local sold       = 0
	local maxFail    = 5
	local failStreak = 0

	while countAllMS() > 0 do
		local msName = getEquippableMS()
		if not msName then break end

		-- Equip 1 marshmallow (tipe apapun yang ada)
		local equipped = equipTool(msName)
		if not equipped then
			failStreak += 1
			setStatus("❌ Gagal equip MS! ("..failStreak.."/"..maxFail..")", Color3.fromRGB(210,40,40))
			task.wait(1)
			if failStreak >= maxFail then break end
			continue
		end

		local beforeS = countItem(CFG.ITEM_MS_SMALL)
		local beforeM = countItem(CFG.ITEM_MS_MEDIUM)
		local beforeL = countItem(CFG.ITEM_MS_LARGE)

		-- Double fire: pressE + semua prompt dalam radius
		pressE()
		task.wait(0.1)
		fireAllNearbyPrompts(CFG.SELL_RADIUS)
		task.wait(0.1)
		pressE()

		-- Tunggu salah satu jenis MS berkurang
		local elapsed = 0
		local terjual = false
		while elapsed < CFG.SELL_TIMEOUT do
			local diffS = beforeS - countItem(CFG.ITEM_MS_SMALL)
			local diffM = beforeM - countItem(CFG.ITEM_MS_MEDIUM)
			local diffL = beforeL - countItem(CFG.ITEM_MS_LARGE)
			local diff  = diffS + diffM + diffL
			if diff > 0 then
				sold      += diff
				totalSold += diff
				terjual    = true
				failStreak = 0
				break
			end
			task.wait(0.25)
			elapsed += 0.25
		end

		if terjual then
			setStatus("💰 Terjual "..sold.." | Sisa: "..countAllMS().." MS",
				Color3.fromRGB(50,210,110))
			task.wait(0.2)
		else
			failStreak += 1
			setStatus("⚠️ Tidak terjual ("..failStreak.."/"..maxFail..") — Pastikan dekat NPC!",
				Color3.fromRGB(255,155,35))
			task.wait(1)
			if failStreak >= maxFail then
				setStatus("❌ Gagal jual. Dekati NPC jual!", Color3.fromRGB(210,40,40))
				break
			end
		end
	end

	unequipAll()

	if sold > 0 then
		setStatus("✅ Selesai! Terjual "..sold.." MS (total: "..totalSold..")",
			Color3.fromRGB(50,210,110))
	else
		setStatus("⚠️ Tidak ada MS terjual. Pastikan di dekat NPC!", Color3.fromRGB(255,155,35))
	end
	task.wait(1)
end

-- ============================================================
-- AUTO BELI BAHAN
-- Logika:
--   Karakter HARUS sudah berdiri dekat NPC toko (dalam radius)
--   1. Tekan E / fire prompt → tunggu GUI dialog muncul
--   2. Klik "Ya kamu orangnya?"
--   3. Tunggu GUI toko muncul
--   4. Klik tiap item (Gelatin, Gula, Air)
--   5. Klik KELUAR / tutup
-- ============================================================
-- AUTO BELI — DIRECT FireServer ke StorePurchase
-- Tidak perlu buka GUI, dialog, atau proximity prompt
-- Cukup dekati NPC lalu tekan Start
-- ============================================================
local buyQty  = { 1, 1, 1 }  -- qty per item [1]=Gelatin [2]=Sugar [3]=Water
local buyBusy = false

-- Item list yang akan dibeli (urutan sama dengan GUI qty)
local BUY_ITEMS = {
	{ name = "Gelatin",        display = "🟡 Gelatin"        },
	{ name = "Sugar Block Bag", display = "🧂 Sugar Block Bag" },
	{ name = "Water",          display = "💧 Water"           },
}

local storePurchaseRemote = nil
pcall(function()
	storePurchaseRemote = game.ReplicatedStorage.RemoteEvents.StorePurchase
end)

local function doAutoBuy(setStatus)
	if not storePurchaseRemote then
		setStatus("❌ Remote StorePurchase tidak ditemukan!", Color3.fromRGB(210,40,40))
		task.wait(1.5)
		return
	end

	local totalBought = 0

	for idx, item in ipairs(BUY_ITEMS) do
		local qty = buyQty[idx] or 1
		setStatus("🛒 Beli "..item.display.." ×"..qty.."...", Color3.fromRGB(100,180,255))

		for q = 1, qty do
			pcall(function()
				storePurchaseRemote:FireServer(item.name, 1)
			end)
			task.wait(0.35) -- jeda antar pembelian
			totalBought += 1
		end

		totalBuy += qty
		setStatus("✅ "..item.display.." ×"..qty.." selesai!", Color3.fromRGB(80,220,130))
		task.wait(0.2)
	end

	setStatus("✅ Beli selesai! "..totalBought.."x item dibeli.", Color3.fromRGB(80,220,130))
	task.wait(1)
end

-- ============================================================
-- AUTO MASAK
-- ============================================================
local lblStatus  -- forward declare

local function setStatus(msg, color)
	if lblStatus then
		lblStatus.Text       = msg
		lblStatus.TextColor3 = color or Color3.fromRGB(155,165,200)
	end
end

local function countdown(secs, fmt, color)
	for i = secs, 1, -1 do
		if not isRunning then return false end
		setStatus(string.format(fmt, i), color)
		task.wait(1)
	end
	return true
end

local function doOneCook()
	isBusy = true

	-- Snapshot inventory MS sebelum masak
	local snapS = countItem(CFG.ITEM_MS_SMALL)
	local snapM = countItem(CFG.ITEM_MS_MEDIUM)
	local snapL = countItem(CFG.ITEM_MS_LARGE)

	setStatus("💧 Water...", Color3.fromRGB(100,180,255))
	equipTool(CFG.ITEM_WATER)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(0.7)

	if not countdown(CFG.WATER_WAIT, "💧 Mendidih... ⏱ %ds", Color3.fromRGB(80,150,255)) then
		isBusy = false return false
	end

	setStatus("🧂 Sugar Bag...", Color3.fromRGB(255,220,100))
	equipTool(CFG.ITEM_SUGAR)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(2)

	setStatus("🟡 Gelatin...", Color3.fromRGB(255,200,50))
	equipTool(CFG.ITEM_GEL)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(1)

	if not countdown(CFG.COOK_WAIT, "🔥 Memasak... ⏱ %ds", Color3.fromRGB(80,140,255)) then
		isBusy = false return false
	end

	-- Tunggu Empty Bag
	setStatus("🎒 Tunggu Tas Kosong...", Color3.fromRGB(100,160,255))
	local bag, t2 = nil, 0
	repeat
		bag = player.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
		task.wait(0.5)
		t2 += 0.5
	until bag or t2 > 12

	if not bag then
		setStatus("❌ Tas kosong tidak ditemukan!", Color3.fromRGB(210,40,40))
		task.wait(1.5)
		isBusy = false
		return false
	end

	setStatus("🎒 Ambil Marshmallow...", Color3.fromRGB(100,180,255))
	equipTool(CFG.ITEM_EMPTY)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)

	-- Tunggu sampai ada MS baru masuk inventory (max 8 detik)
	setStatus("🎒 Tunggu MS masuk inventory...", Color3.fromRGB(100,160,255))
	local waitMS = 0
	local newS, newM, newL = 0, 0, 0
	repeat
		task.wait(0.4)
		waitMS += 0.4
		newS = countItem(CFG.ITEM_MS_SMALL)  - snapS
		newM = countItem(CFG.ITEM_MS_MEDIUM) - snapM
		newL = countItem(CFG.ITEM_MS_LARGE)  - snapL
	until (newS > 0 or newM > 0 or newL > 0) or waitMS > 8

	-- Catat jenis MS yang masuk
	if newS > 0 then
		stats.small += newS
		setStatus("✅ Small MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	elseif newM > 0 then
		stats.medium += newM
		setStatus("✅ Medium MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	elseif newL > 0 then
		stats.large += newL
		setStatus("✅ Large MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	else
		-- Tidak terdeteksi, hitung manual dari total yang ada sekarang
		local totalNow = countAllMS()
		local totalBefore = snapS + snapM + snapL
		if totalNow > totalBefore then
			stats.small += (totalNow - totalBefore)
		else
			stats.small += 1 -- fallback
		end
		setStatus("✅ MS ke-"..(totalMS()).." selesai! (tipe tidak terdeteksi)", Color3.fromRGB(80,210,255))
	end
	task.wait(0.5)

	isBusy = false
	return true
end

local function autoLoop()
	while isRunning do
		if not hasAllIngredients() then
			setStatus("❌ Bahan habis! Gunakan Auto Beli.", Color3.fromRGB(210,40,40))
			isRunning = false
			break
		end
		doOneCook()
		if isRunning then task.wait(0.3) end
	end
end

-- ============================================================
-- GUI — PatStore v1.0
-- ============================================================

if playerGui:FindFirstChild("PatStoreGUI") then
	playerGui.PatStoreGUI:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name="PatStoreGUI" sg.ResetOnSpawn=false sg.IgnoreGuiInset=true sg.DisplayOrder=10 sg.Parent=playerGui

-- ── WARNA ──
local C = {
	bg=Color3.fromRGB(13,13,18), panel=Color3.fromRGB(18,18,24), card=Color3.fromRGB(26,26,34),
	tabBg=Color3.fromRGB(14,14,20), line=Color3.fromRGB(36,36,48),
	blue=Color3.fromRGB(82,130,255), blueL=Color3.fromRGB(110,165,255), blueD=Color3.fromRGB(48,88,200),
	green=Color3.fromRGB(52,210,110), greenD=Color3.fromRGB(30,140,70),
	red=Color3.fromRGB(215,50,50), orange=Color3.fromRGB(255,160,40),
	purple=Color3.fromRGB(148,80,255), cyan=Color3.fromRGB(50,210,230),
	txt=Color3.fromRGB(230,232,240), txtM=Color3.fromRGB(148,154,175), txtD=Color3.fromRGB(72,76,96),
}

-- ── HELPERS ──
local function F(p,bg,zi)
	local f=Instance.new("Frame") f.BackgroundColor3=bg or C.card f.BorderSizePixel=0 f.ZIndex=zi or 2
	if p then f.Parent=p end return f
end
local function T(p,txt,col,font,xa,zi,ts)
	local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Text=txt or ""
	l.TextColor3=col or C.txt l.Font=font or Enum.Font.Gotham
	l.TextXAlignment=xa or Enum.TextXAlignment.Left l.ZIndex=zi or 3
	if ts then l.TextScaled=false l.TextSize=ts else l.TextScaled=true end
	if p then l.Parent=p end return l
end
local function B(p,txt,col,font,zi,ts)
	local b=Instance.new("TextButton") b.BackgroundTransparency=1 b.Text=txt or ""
	b.TextColor3=col or C.txt b.Font=font or Enum.Font.Gotham b.ZIndex=zi or 3
	if ts then b.TextScaled=false b.TextSize=ts else b.TextScaled=true end
	if p then b.Parent=p end return b
end
local function corner(p,r) Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 8) end
local function stroke(p,col,th)
	local s=Instance.new("UIStroke",p) s.Color=col or C.line s.Thickness=th or 1 return s
end
local function glow(p,col,th)
	local s=Instance.new("UIStroke",p) s.Color=col or C.blue s.Thickness=th or 2 s.Transparency=0.5 return s
end
local function line(p,y)
	local d=F(p,C.line,2) d.Size=UDim2.new(1,-32,0,1) d.Position=UDim2.new(0,16,0,y)
end
local function secHdr(p,y,txt)
	local bar=F(p,C.blue,3) bar.Size=UDim2.new(0,3,0,13) bar.Position=UDim2.new(0,16,0,y+3) corner(bar,2)
	local l=T(p,txt,C.txtM,Enum.Font.GothamBold,Enum.TextXAlignment.Left,3,11)
	l.Size=UDim2.new(1,-36,0,18) l.Position=UDim2.new(0,24,0,y) return l
end
local function statRow(p,y,icon,lbl,valCol)
	local row=F(p,C.card,2) row.Size=UDim2.new(1,-32,0,38) row.Position=UDim2.new(0,16,0,y) corner(row,8)
	local ic=T(row,icon,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Center,3,14)
	ic.Size=UDim2.new(0,30,1,0) ic.Position=UDim2.new(0,4,0,0)
	local nm=T(row,lbl,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,3,12)
	nm.Size=UDim2.new(0.55,-34,1,0) nm.Position=UDim2.new(0,36,0,0)
	local vl=T(row,"0",valCol or C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Right,3,14)
	vl.Size=UDim2.new(0.45,-10,1,0) vl.Position=UDim2.new(0.55,0,0,0)
	return vl
end
local function actionBtn(p,y,txt,bg,txtC)
	local w=F(p,bg or C.blue,3) w.Size=UDim2.new(1,-32,0,40) w.Position=UDim2.new(0,16,0,y) corner(w,8)
	local sh=F(w,Color3.fromRGB(255,255,255),4) sh.Size=UDim2.new(1,0,0.5,0) sh.BackgroundTransparency=0.92 corner(sh,8)
	local b=B(w,txt,txtC or C.txt,Enum.Font.GothamBold,4) b.Size=UDim2.new(1,0,1,0) b.TextSize=12 b.TextScaled=false
	return w,b
end
local function toggleRow(p,y,lbl,defaultOn)
	local row=F(p,C.card,2) row.Size=UDim2.new(1,-32,0,38) row.Position=UDim2.new(0,16,0,y) corner(row,8)
	local nm=T(row,lbl,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,3,12)
	nm.Size=UDim2.new(0.75,0,1,0) nm.Position=UDim2.new(0,12,0,0)
	local on=defaultOn or false
	local knobW=F(row,on and C.blue or C.line,4)
	knobW.Size=UDim2.new(0,36,0,20) knobW.Position=UDim2.new(1,-46,0.5,-10) corner(knobW,10)
	local knob=F(knobW,C.txt,5)
	knob.Size=UDim2.new(0,14,0,14) knob.Position=UDim2.new(on and 1 or 0,on and -18 or 4,0.5,-7) corner(knob,7)
	local togBtn=B(row,"",C.txt,Enum.Font.Gotham,5) togBtn.Size=UDim2.new(1,0,1,0)
	local function update(v)
		on=v
		TweenService:Create(knobW,TweenInfo.new(0.15),{BackgroundColor3=on and C.blue or C.line}):Play()
		TweenService:Create(knob,TweenInfo.new(0.15),{Position=on and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,4,0.5,-7)}):Play()
	end
	togBtn.MouseButton1Click:Connect(function() update(not on) end)
	return togBtn, function() return on end, update
end
local function sliderRow(p,y,lbl,minV,maxV,defV,unit)
	local row=F(p,C.card,2) row.Size=UDim2.new(1,-32,0,52) row.Position=UDim2.new(0,16,0,y) corner(row,8)
	local nm=T(row,lbl,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,3,11)
	nm.Size=UDim2.new(0.6,0,0,22) nm.Position=UDim2.new(0,10,0,2)
	local valL=T(row,tostring(defV)..(unit or ""),C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Right,3,12)
	valL.Size=UDim2.new(0.4,-10,0,22) valL.Position=UDim2.new(0.6,0,0,2)
	local track=F(row,C.line,3) track.Size=UDim2.new(1,-20,0,4) track.Position=UDim2.new(0,10,0,32) corner(track,2)
	local fill=F(track,C.blue,4) fill.Size=UDim2.new((defV-minV)/(maxV-minV),0,1,0) fill.Position=UDim2.new(0,0,0,0) corner(fill,2)
	local curVal=defV
	local function setVal(v)
		v=math.clamp(math.floor(v),minV,maxV) curVal=v
		fill.Size=UDim2.new((v-minV)/(maxV-minV),0,1,0)
		valL.Text=tostring(v)..(unit or "")
	end
	local dragging=false
	track.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true
			local rel=(i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X
			setVal(minV+rel*(maxV-minV))
		end
	end)
	track.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
	UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			local rel=(i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X
			setVal(minV+rel*(maxV-minV))
		end
	end)
	return function() return curVal end
end
local function hoverBtn(w,b,nc,hc)
	b.MouseEnter:Connect(function() TweenService:Create(w,TweenInfo.new(0.1),{BackgroundColor3=hc}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(w,TweenInfo.new(0.1),{BackgroundColor3=nc}):Play() end)
end

-- ── PANEL ──
local PW,PH=340,560
local panel=F(sg,C.panel,1) panel.Name="Panel"
panel.Size=UDim2.new(0,PW,0,PH) panel.Position=UDim2.new(0,14,0.5,-PH/2)
corner(panel,12) stroke(panel,C.line,1.5)

-- Gradient top accent
local panelGrad=F(panel,C.blue,1) panelGrad.Size=UDim2.new(1,0,0,2) panelGrad.Position=UDim2.new(0,0,0,0)
local ug=Instance.new("UIGradient",panelGrad)
ug.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,C.blue),ColorSequenceKeypoint.new(0.5,C.purple),ColorSequenceKeypoint.new(1,C.cyan)}

-- ── TITLE BAR ──
local titleBar=F(panel,C.bg,3) titleBar.Size=UDim2.new(1,0,0,46) titleBar.Position=UDim2.new(0,0,0,2) corner(titleBar,10)
local dot=F(titleBar,C.blue,4) dot.Size=UDim2.new(0,10,0,10) dot.Position=UDim2.new(0,14,0.5,-5) corner(dot,5)
local dotGlow=F(titleBar,C.blue,3) dotGlow.Size=UDim2.new(0,18,0,18) dotGlow.Position=UDim2.new(0,10,0.5,-9) corner(dotGlow,9) dotGlow.BackgroundTransparency=0.75
local titleL=T(titleBar,"PatStore",C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,16)
titleL.Size=UDim2.new(0.4,0,1,0) titleL.Position=UDim2.new(0,32,0,0)
local verL=T(titleBar,"v1.0",C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,11)
verL.Size=UDim2.new(0,28,1,0) verL.Position=UDim2.new(0,96,0,0)

-- FPS + Ping
local fpsBox=F(titleBar,C.card,4) fpsBox.Size=UDim2.new(0,90,0,24) fpsBox.Position=UDim2.new(1,-128,0.5,-12) corner(fpsBox,6)
local fpsL=T(fpsBox,"-- fps  -- ms",C.cyan,Enum.Font.Gotham,Enum.TextXAlignment.Center,5,9)
fpsL.Size=UDim2.new(1,-4,1,0) fpsL.Position=UDim2.new(0,2,0,0) fpsL.RichText=true

local closeW=F(titleBar,C.card,4) closeW.Size=UDim2.new(0,26,0,26) closeW.Position=UDim2.new(1,-36,0.5,-13) corner(closeW,6)
local closeB=B(closeW,"x",C.txtM,Enum.Font.GothamBold,5) closeB.Size=UDim2.new(1,0,1,0) closeB.TextSize=17 closeB.TextScaled=false
closeB.MouseButton1Click:Connect(function() panel.Visible=not panel.Visible end)
closeB.MouseEnter:Connect(function() TweenService:Create(closeW,TweenInfo.new(0.1),{BackgroundColor3=C.red}):Play() closeB.TextColor3=C.txt end)
closeB.MouseLeave:Connect(function() TweenService:Create(closeW,TweenInfo.new(0.1),{BackgroundColor3=C.card}):Play() closeB.TextColor3=C.txtM end)

-- ── MENU BAR (Farm / Combat / Teleport) ──
local menuBar=F(panel,C.bg,3) menuBar.Size=UDim2.new(1,0,0,36) menuBar.Position=UDim2.new(0,0,0,48)
local menuLine=F(panel,C.line,3) menuLine.Size=UDim2.new(1,0,0,1) menuLine.Position=UDim2.new(0,0,0,84)

local MENUS={"🌾 FARM","⚔ COMBAT","🗺 TELEPORT"}
local menuBtns,menuPages={},{}
local mw=PW/#MENUS

for i,name in ipairs(MENUS) do
	local mb=B(menuBar,name,C.txtD,Enum.Font.GothamBold,4,11)
	mb.BackgroundTransparency=0 mb.BackgroundColor3=C.bg
	mb.Size=UDim2.new(0,mw,1,0) mb.Position=UDim2.new(0,(i-1)*mw,0,0)
	menuBtns[i]=mb
	local mul=F(mb,C.blue,5) mul.Name="UL" mul.Size=UDim2.new(0.6,0,0,2) mul.Position=UDim2.new(0.2,0,1,-2) mul.Visible=(i==1)
	local mdot=F(mb,C.blue,5) mdot.Name="DOT" mdot.Size=UDim2.new(0,4,0,4) mdot.Position=UDim2.new(0.5,-2,0,4) corner(mdot,2) mdot.Visible=(i==1)
	local mp=F(panel,C.panel,2) mp.Size=UDim2.new(1,0,1,-84) mp.Position=UDim2.new(0,0,0,84)
	mp.Visible=(i==1) mp.ClipsDescendants=true menuPages[i]=mp
end

local function switchMenu(idx)
	for i=1,#MENUS do
		menuPages[i].Visible=(i==idx)
		menuBtns[i].TextColor3=(i==idx) and C.txt or C.txtD
		local ul=menuBtns[i]:FindFirstChild("UL") if ul then ul.Visible=(i==idx) end
		local d=menuBtns[i]:FindFirstChild("DOT") if d then d.Visible=(i==idx) end
		TweenService:Create(menuBtns[i],TweenInfo.new(0.12),{BackgroundColor3=(i==idx) and Color3.fromRGB(24,24,34) or C.bg}):Play()
	end
end
for i,mb in ipairs(menuBtns) do mb.MouseButton1Click:Connect(function() switchMenu(i) end) end

-- ============================================================
-- FARM PAGE — Sub tabs: MASAK | JUAL | BELI | STATS
-- ============================================================
local farmPage=menuPages[1]

local tabBar=F(farmPage,C.tabBg,3) tabBar.Size=UDim2.new(1,0,0,32) tabBar.Position=UDim2.new(0,0,0,0)
local tabLine2=F(farmPage,C.line,3) tabLine2.Size=UDim2.new(1,0,0,1) tabLine2.Position=UDim2.new(0,0,0,32)

local TABS={"MASAK","JUAL","BELI","STATS"}
local tabBtns,pages={},{}
local tw=PW/#TABS

for i,name in ipairs(TABS) do
	local tb=B(tabBar,name,C.txtD,Enum.Font.GothamBold,4,10)
	tb.BackgroundTransparency=0 tb.BackgroundColor3=C.tabBg
	tb.Size=UDim2.new(0,tw,1,0) tb.Position=UDim2.new(0,(i-1)*tw,0,0)
	tabBtns[i]=tb
	local ul=F(tb,C.blue,5) ul.Name="UL" ul.Size=UDim2.new(0.6,0,0,2) ul.Position=UDim2.new(0.2,0,1,-2) ul.Visible=(i==1)
	local pg=F(farmPage,C.panel,2) pg.Size=UDim2.new(1,0,1,-33) pg.Position=UDim2.new(0,0,0,33)
	pg.Visible=(i==1) pg.ClipsDescendants=true pages[i]=pg
end
local function switchTab(idx)
	for i=1,#TABS do
		pages[i].Visible=(i==idx)
		tabBtns[i].TextColor3=(i==idx) and C.txt or C.txtD
		local ul=tabBtns[i]:FindFirstChild("UL") if ul then ul.Visible=(i==idx) end
		TweenService:Create(tabBtns[i],TweenInfo.new(0.12),{BackgroundColor3=(i==idx) and Color3.fromRGB(22,22,30) or C.tabBg}):Play()
	end
end
for i,tb in ipairs(tabBtns) do tb.MouseButton1Click:Connect(function() switchTab(i) end) end

-- PAGE 1: MASAK
local pg1=pages[1]
local statusCard=F(pg1,C.bg,3) statusCard.Size=UDim2.new(1,-32,0,30) statusCard.Position=UDim2.new(0,16,0,10) corner(statusCard,8) stroke(statusCard,C.line,1)
lblStatus=T(statusCard,"Siap digunakan",C.cyan,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,11)
lblStatus.Size=UDim2.new(1,-8,1,0) lblStatus.Position=UDim2.new(0,4,0,0)
line(pg1,50)
secHdr(pg1,58,"BAHAN TERSEDIA")
local vW =statRow(pg1, 80,"💧","Water",       Color3.fromRGB(100,200,255))
local vSu=statRow(pg1,124,"🧂","Sugar Bag",   Color3.fromRGB(255,220,100))
local vGe=statRow(pg1,168,"🟡","Gelatin",     Color3.fromRGB(255,190,60))
line(pg1,212)
secHdr(pg1,220,"HASIL MASAK")
local msCard=F(pg1,C.bg,3) msCard.Size=UDim2.new(1,-32,0,52) msCard.Position=UDim2.new(0,16,0,240) corner(msCard,10) glow(msCard,C.blue,1.5)
local msBig=T(msCard,"0",C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Center,4,30)
msBig.Size=UDim2.new(0.45,0,1,0) msBig.Position=UDim2.new(0,0,0,0)
local msDiv=F(msCard,C.line,4) msDiv.Size=UDim2.new(0,1,0.7,0) msDiv.Position=UDim2.new(0.45,0,0.15,0)
local msSubL=T(msCard,"Marshmallow dibuat",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11)
msSubL.Size=UDim2.new(0.55,-16,1,0) msSubL.Position=UDim2.new(0.45,12,0,0) msSubL.TextWrapped=true
line(pg1,304)
local startW,startB=actionBtn(pg1,314,"Start Auto Masak",C.blueD,C.txt)
local stopW,stopB  =actionBtn(pg1,314,"Stop Auto Masak", C.red,  C.txt)
stopW.Visible=false
local function setRunUI(r) startW.Visible=not r stopW.Visible=r end
startB.MouseButton1Click:Connect(function()
	if isBusy then return end
	if not hasAllIngredients() then setStatus("Bahan tidak lengkap!",C.red) return end
	isRunning=true setRunUI(true) setStatus("Berjalan...",C.green) task.spawn(autoLoop)
end)
stopB.MouseButton1Click:Connect(function() isRunning=false setRunUI(false) setStatus("Dihentikan",C.orange) end)
hoverBtn(startW,startB,C.blueD,Color3.fromRGB(62,110,230))
hoverBtn(stopW,stopB,C.red,Color3.fromRGB(240,65,65))

-- PAGE 2: JUAL
local pg2=pages[2]
secHdr(pg2,10,"AUTO JUAL MARSHMALLOW")
local jualInfo=F(pg2,C.bg,3) jualInfo.Size=UDim2.new(1,-32,0,38) jualInfo.Position=UDim2.new(0,16,0,30) corner(jualInfo,8) stroke(jualInfo,C.line,1)
local jIT=T(jualInfo,"Dekati NPC Jual lalu tekan tombol.",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11)
jIT.Size=UDim2.new(1,-10,1,0) jIT.Position=UDim2.new(0,8,0,0) jIT.TextWrapped=true
line(pg2,78) secHdr(pg2,86,"STATISTIK")
local vSold =statRow(pg2,106,"💰","Total Terjual",  Color3.fromRGB(52,210,110))
local vMSInv=statRow(pg2,150,"🍬","MS di Inventory",Color3.fromRGB(100,180,255))
line(pg2,194)
local jualStatBox=F(pg2,C.bg,3) jualStatBox.Size=UDim2.new(1,-32,0,28) jualStatBox.Position=UDim2.new(0,16,0,202) corner(jualStatBox,6) stroke(jualStatBox,C.line,1)
local jualStatL=T(jualStatBox,"",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,11)
jualStatL.Size=UDim2.new(1,-8,1,0) jualStatL.Position=UDim2.new(0,4,0,0)
line(pg2,238)
local jualBtnW,jualBtnB=actionBtn(pg2,248,"Jual Semua Marshmallow",C.greenD,C.txt)
local jualBusy=false
local function setJualStatus(msg,col) jualStatL.Text=msg jualStatL.TextColor3=col or C.txtM setStatus(msg,col) end
jualBtnB.MouseButton1Click:Connect(function()
	if jualBusy then return end jualBusy=true
	jualBtnW.BackgroundColor3=Color3.fromRGB(18,88,42) jualBtnB.Text="Menjual..."
	task.spawn(function() doAutoSell(setJualStatus) jualBtnW.BackgroundColor3=C.greenD jualBtnB.Text="Jual Semua Marshmallow" jualBusy=false end)
end)
hoverBtn(jualBtnW,jualBtnB,C.greenD,Color3.fromRGB(40,170,85))

-- PAGE 3: BELI
local pg3=pages[3]
secHdr(pg3,10,"AUTO BELI BAHAN")
local beliInfo=F(pg3,C.bg,3) beliInfo.Size=UDim2.new(1,-32,0,38) beliInfo.Position=UDim2.new(0,16,0,30) corner(beliInfo,8) stroke(beliInfo,C.line,1)
local bIT=T(beliInfo,"Dekati NPC toko lalu tekan tombol. Langsung beli tanpa buka dialog!",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11)
bIT.Size=UDim2.new(1,-10,1,0) bIT.Position=UDim2.new(0,8,0,0) bIT.TextWrapped=true
line(pg3,78) secHdr(pg3,86,"JUMLAH BELI PER ITEM")
local itemData={{icon="🟡",name="Gelatin",price="$70"},{icon="🧂",name="Sugar Block Bag",price="$100"},{icon="💧",name="Water",price="$20"}}
local qtyLabels={}
for i,item in ipairs(itemData) do
	local ry=108+(i-1)*46
	local row=F(pg3,C.card,3) row.Size=UDim2.new(1,-32,0,40) row.Position=UDim2.new(0,16,0,ry) corner(row,8) stroke(row,C.line,1)
	local ic=T(row,item.icon,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,14) ic.Size=UDim2.new(0,26,1,0) ic.Position=UDim2.new(0,4,0,0)
	local nm=T(row,item.name,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11) nm.Size=UDim2.new(0.42,-30,1,0) nm.Position=UDim2.new(0,32,0,0)
	local pr=T(row,item.price,C.txtD,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10) pr.Size=UDim2.new(0.2,0,1,0) pr.Position=UDim2.new(0.44,0,0,0)
	local minW=F(row,Color3.fromRGB(40,40,54),4) minW.Size=UDim2.new(0,24,0,24) minW.Position=UDim2.new(1,-84,0.5,-12) corner(minW,6) stroke(minW,C.line,1)
	local minB=B(minW,"-",C.txt,Enum.Font.GothamBold,5) minB.Size=UDim2.new(1,0,1,0) minB.TextSize=16 minB.TextScaled=false
	local qL=T(row,tostring(buyQty[i]),C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Center,4,13) qL.Size=UDim2.new(0,26,1,0) qL.Position=UDim2.new(1,-58,0,0) qtyLabels[i]=qL
	local plsW=F(row,Color3.fromRGB(40,40,54),4) plsW.Size=UDim2.new(0,24,0,24) plsW.Position=UDim2.new(1,-30,0.5,-12) corner(plsW,6) stroke(plsW,C.line,1)
	local plsB=B(plsW,"+",C.txt,Enum.Font.GothamBold,5) plsB.Size=UDim2.new(1,0,1,0) plsB.TextSize=16 plsB.TextScaled=false
	local idx=i
	minB.MouseButton1Click:Connect(function() if buyQty[idx]>1 then buyQty[idx]-=1 qtyLabels[idx].Text=tostring(buyQty[idx]) end end)
	plsB.MouseButton1Click:Connect(function() if buyQty[idx]<99 then buyQty[idx]+=1 qtyLabels[idx].Text=tostring(buyQty[idx]) end end)
end
line(pg3,252) secHdr(pg3,260,"STATISTIK")
local vBuy=statRow(pg3,280,"🛒","Total Beli",Color3.fromRGB(100,180,255))
line(pg3,324)
local beliStatBox=F(pg3,C.bg,3) beliStatBox.Size=UDim2.new(1,-32,0,28) beliStatBox.Position=UDim2.new(0,16,0,332) corner(beliStatBox,6) stroke(beliStatBox,C.line,1)
local beliStatL=T(beliStatBox,"Dekati NPC toko lalu tekan Start",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,11)
beliStatL.Size=UDim2.new(1,-8,1,0) beliStatL.Position=UDim2.new(0,4,0,0)
line(pg3,370)
local beliBtnW,beliBtnB=actionBtn(pg3,380,"Start Auto Beli",C.blueD,C.txt)
local function setBeliStatus(msg,col) beliStatL.Text=msg beliStatL.TextColor3=col or C.txtM setStatus(msg,col) end
beliBtnB.MouseButton1Click:Connect(function()
	if buyBusy then return end buyBusy=true
	beliBtnW.BackgroundColor3=Color3.fromRGB(30,50,140) beliBtnB.Text="Membeli..."
	task.spawn(function() doAutoBuy(setBeliStatus) beliBtnW.BackgroundColor3=C.blueD beliBtnB.Text="Start Auto Beli" buyBusy=false end)
end)
hoverBtn(beliBtnW,beliBtnB,C.blueD,Color3.fromRGB(62,105,220))

-- PAGE 4: STATS
local pg4=pages[4]
secHdr(pg4,10,"STATISTIK SESSION")
local sData={
	{icon="🍬",lbl="Total MS Dibuat",  col=Color3.fromRGB(100,190,255)},
	{icon="🔹",lbl="Small MS",         col=Color3.fromRGB(130,205,255)},
	{icon="🔷",lbl="Medium MS",        col=Color3.fromRGB(80,160,255) },
	{icon="🔵",lbl="Large MS",         col=Color3.fromRGB(55,115,220) },
	{icon="💰",lbl="Total MS Terjual", col=Color3.fromRGB(52,210,110) },
	{icon="🛒",lbl="Total Beli Bahan", col=Color3.fromRGB(100,180,255)},
	{icon="📡",lbl="Ping",             col=Color3.fromRGB(50,210,230) },
	{icon="🖥",lbl="FPS",              col=Color3.fromRGB(148,80,255) },
}
local sVals={}
for i,s in ipairs(sData) do
	local y=32+(i-1)*40
	local v=statRow(pg4,y,s.icon,s.lbl,s.col) sVals[i]=v
	if i<#sData then line(pg4,y+38) end
end

-- ============================================================
-- COMBAT PAGE — Aimbot + FOV Circle
-- ============================================================
local combatPage=menuPages[2]

-- Aimbot state
local aimbotEnabled=false
local aimbotBone="Head" -- "Head" or "HumanoidRootPart"
local fovRadius=120
local maxDistance=300
local smoothness=0.18
local aimbotTarget=nil
local fovCircle=nil

-- FOV Circle (drawn on screen)
local function createFOVCircle()
	if fovCircle then fovCircle:Destroy() end
	local circ=Instance.new("Frame")
	circ.Name="FOVCircle" circ.BackgroundTransparency=1
	circ.Size=UDim2.new(0,fovRadius*2,0,fovRadius*2)
	circ.AnchorPoint=Vector2.new(0.5,0.5)
	circ.Position=UDim2.new(0.5,0,0.5,0)
	circ.BorderSizePixel=0 circ.ZIndex=999
	-- Use UIStroke on a circle frame for the ring
	local inner=Instance.new("Frame",circ)
	inner.Size=UDim2.new(1,0,1,0) inner.BackgroundTransparency=1
	inner.BorderSizePixel=0
	Instance.new("UICorner",inner).CornerRadius=UDim.new(0.5,0)
	local s=Instance.new("UIStroke",inner) s.Thickness=1.5 s.Color=Color3.fromRGB(255,255,255)
	fovCircle=circ circ.Parent=sg
	return circ,s
end

-- Get closest target in FOV
local function getAimbotTarget()
	local cam=workspace.CurrentCamera
	local mousePos=UIS:GetMouseLocation()
	local closest=nil local closestDist=math.huge
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr==player then continue end
		local ch=plr.Character if not ch then continue end
		local hrpT=ch:FindFirstChild("HumanoidRootPart") if not hrpT then continue end
		local hum=ch:FindFirstChild("Humanoid") if not hum or hum.Health<=0 then continue end
		local dist=(hrpT.Position-hrp.Position).Magnitude
		if dist>maxDistance then continue end
		local screenPos,onScreen=cam:WorldToViewportPoint(hrpT.Position)
		if not onScreen then continue end
		local screenVec=Vector2.new(screenPos.X,screenPos.Y)
		local fovDist=(screenVec-mousePos).Magnitude
		if fovDist<fovRadius and fovDist<closestDist then
			closestDist=fovDist closest=plr
		end
	end
	return closest
end

-- Aimbot loop
local rmb=false
UIS.InputBegan:Connect(function(i,gp)
	if gp then return end
	if i.UserInputType==Enum.UserInputType.MouseButton2 then rmb=true end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton2 then rmb=false end
end)

local _,fovStroke=createFOVCircle()
fovCircle.Visible=false

RunService.RenderStepped:Connect(function()
	if not aimbotEnabled then
		if fovCircle then fovCircle.Visible=false end
		aimbotTarget=nil return
	end
	-- Update FOV circle position to mouse
	local mpos=UIS:GetMouseLocation()
	if fovCircle then
		fovCircle.Visible=true
		fovCircle.Position=UDim2.new(0,mpos.X,0,mpos.Y)
		fovCircle.Size=UDim2.new(0,fovRadius*2,0,fovRadius*2)
	end
	-- Find target
	aimbotTarget=getAimbotTarget()
	-- Color: merah=lock, putih=mencari
	if fovStroke then
		fovStroke.Color=aimbotTarget and Color3.fromRGB(220,50,50) or Color3.fromRGB(255,255,255)
	end
	-- Lock on RMB
	if rmb and aimbotTarget then
		local ch=aimbotTarget.Character if not ch then return end
		local bone=ch:FindFirstChild(aimbotBone) or ch:FindFirstChild("HumanoidRootPart")
		if not bone then return end
		local cam=workspace.CurrentCamera
		local targetPos,onScreen=cam:WorldToViewportPoint(bone.Position)
		if onScreen then
			local smooth=math.clamp(smoothness,0.01,1)
			local camCF=cam.CFrame
			local targetCF=CFrame.lookAt(camCF.Position,bone.Position)
			cam.CFrame=camCF:Lerp(targetCF,smooth)
		end
	end
end)

-- Combat GUI
secHdr(combatPage,10,"AIMBOT")
local aimbotTogBtn,getAimOn,setAimOn=toggleRow(combatPage,30,"Enable Aimbot",false)
aimbotTogBtn.MouseButton1Click:Connect(function()
	task.wait(0.05) aimbotEnabled=getAimOn()
end)

-- Info hints
local hintCard=F(combatPage,C.bg,3) hintCard.Size=UDim2.new(1,-32,0,68) hintCard.Position=UDim2.new(0,16,0,78) corner(hintCard,8) stroke(hintCard,C.line,1)
local hints={
	" Tahan RMB untuk aktifkan lock",
	" FOV circle ngikut posisi kursor",
	" Merah = locked  |  Putih = mencari",
}
for i,h in ipairs(hints) do
	local hl=T(hintCard,h,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
	hl.Size=UDim2.new(1,-8,0,20) hl.Position=UDim2.new(0,8,0,(i-1)*22)
end

line(combatPage,154)
secHdr(combatPage,162,"TARGET BONE")
-- Bone selector
local boneCard=F(combatPage,C.card,3) boneCard.Size=UDim2.new(1,-32,0,38) boneCard.Position=UDim2.new(0,16,0,182) corner(boneCard,8)
local boneL=T(boneCard,"Head",C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,13)
boneL.Size=UDim2.new(0.6,0,1,0) boneL.Position=UDim2.new(0,12,0,0)
local boneTogW=F(boneCard,C.blueD,4) boneTogW.Size=UDim2.new(0,80,0,26) boneTogW.Position=UDim2.new(1,-92,0.5,-13) corner(boneTogW,6)
local boneTogB=B(boneTogW,"Switch",C.txt,Enum.Font.GothamBold,5) boneTogB.Size=UDim2.new(1,0,1,0) boneTogB.TextSize=11 boneTogB.TextScaled=false
boneTogB.MouseButton1Click:Connect(function()
	if aimbotBone=="Head" then aimbotBone="HumanoidRootPart" boneL.Text="HumanoidRootPart"
	else aimbotBone="Head" boneL.Text="Head" end
end)

line(combatPage,228)
secHdr(combatPage,236,"SETTINGS")
local getFOV=sliderRow(combatPage,256,"FOV Radius",50,400,120,"px")
local getDist=sliderRow(combatPage,316,"Max Distance",50,500,300,"st")
local getSmooth=sliderRow(combatPage,376,"Smooth",1,100,18,"%")

-- Update aimbot values from sliders
RunService.Heartbeat:Connect(function()
	fovRadius=getFOV() maxDistance=getDist() smoothness=getSmooth()/100
end)

-- ============================================================
-- TELEPORT PAGE
-- ============================================================
local teleportPage=menuPages[3]

secHdr(teleportPage,10,"TELEPORT LOKASI")
-- Warning note
local warnCard=F(teleportPage,Color3.fromRGB(60,30,10),3) warnCard.Size=UDim2.new(1,-32,0,46) warnCard.Position=UDim2.new(0,16,0,30) corner(warnCard,8) stroke(warnCard,C.orange,1)
local warnL=T(warnCard,"⚠️ Map ini anti-teleport! Gunakan KENDARAAN sebelum teleport agar tidak gagal.",C.orange,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,10)
warnL.Size=UDim2.new(1,-10,1,0) warnL.Position=UDim2.new(0,8,0,0) warnL.TextWrapped=true

-- Blink TP toggle
line(teleportPage,84)
secHdr(teleportPage,92,"BLINK TP")
local blinkTogBtn,getBlinkOn,setBlinkOn=toggleRow(teleportPage,112,"Aktifkan Blink TP [T]",false)
local blinkEnabled=false
blinkTogBtn.MouseButton1Click:Connect(function() task.wait(0.05) blinkEnabled=getBlinkOn() end)
local blinkInfo=F(teleportPage,C.bg,3) blinkInfo.Size=UDim2.new(1,-32,0,24) blinkInfo.Position=UDim2.new(0,16,0,156) corner(blinkInfo,6)
local blinkL=T(blinkInfo,"Tekan T = blink maju 6 studs",C.txtD,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
blinkL.Size=UDim2.new(1,-8,1,0) blinkL.Position=UDim2.new(0,8,0,0)

UIS.InputBegan:Connect(function(i,gp)
	if gp then return end
	if i.KeyCode==Enum.KeyCode.T and blinkEnabled then
		local hum=character and character:FindFirstChild("Humanoid")
		if hum and hrp then
			local cf=hrp.CFrame
			hrp.CFrame=cf+cf.LookVector*6
		end
	end
end)

line(teleportPage,186)
secHdr(teleportPage,194,"LOKASI")

local LOCATIONS={
	{name="🏪 Dealer NPC",    pos=Vector3.new(770.98,3.71,433.75)},
	{name="🍬 NPC Marshmallow",pos=Vector3.new(524.94,2.56,586.91)},
	{name="🏠 Apart 1",       pos=Vector3.new(1106.29,10.09,456.03)},
	{name="🏠 Apart 2",       pos=Vector3.new(1107.30,10.11,427.55)},
	{name="🏠 Apart 3",       pos=Vector3.new(1019.42,10.11,243.70)},
	{name="🏠 Apart 4",       pos=Vector3.new(1018.73,10.11,214.25)},
	{name="🏠 Apart 5",       pos=Vector3.new(930.72,10.11,74.17)},
	{name="🏠 Apart 6",       pos=Vector3.new(902.35,10.11,73.81)},
	{name="🎰 Casino",        pos=Vector3.new(1166.33,3.36,-29.77)},
}

local scroll2=Instance.new("ScrollingFrame")
scroll2.Size=UDim2.new(1,0,1,-210) scroll2.Position=UDim2.new(0,0,0,210)
scroll2.BackgroundTransparency=1 scroll2.BorderSizePixel=0 scroll2.ScrollBarThickness=3
scroll2.CanvasSize=UDim2.new(0,0,0,#LOCATIONS*50+8) scroll2.Parent=teleportPage

local lo=Instance.new("UIListLayout",scroll2) lo.Padding=UDim.new(0,6) lo.SortOrder=Enum.SortOrder.LayoutOrder
local loPad=Instance.new("UIPadding",scroll2) loPad.PaddingLeft=UDim.new(0,16) loPad.PaddingRight=UDim.new(0,16) loPad.PaddingTop=UDim.new(0,4)

for i,loc in ipairs(LOCATIONS) do
	local row=F(scroll2,C.card,3) row.Size=UDim2.new(1,0,0,42) corner(row,8) stroke(row,C.line,1) row.LayoutOrder=i
	local nm=T(row,loc.name,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,12)
	nm.Size=UDim2.new(0.65,0,1,0) nm.Position=UDim2.new(0,12,0,0)
	local tpW=F(row,C.blueD,4) tpW.Size=UDim2.new(0,70,0,28) tpW.Position=UDim2.new(1,-82,0.5,-14) corner(tpW,6)
	local tpB=B(tpW,"Teleport",C.txt,Enum.Font.GothamBold,5) tpB.Size=UDim2.new(1,0,1,0) tpB.TextSize=10 tpB.TextScaled=false
	local targetPos=loc.pos
	tpB.MouseButton1Click:Connect(function()
		if character and hrp then
			hrp.CFrame=CFrame.new(targetPos+Vector3.new(0,3,0))
		end
	end)
	hoverBtn(tpW,tpB,C.blueD,Color3.fromRGB(62,110,230))
end

lo:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll2.CanvasSize=UDim2.new(0,0,0,lo.AbsoluteContentSize.Y+8)
end)

-- ============================================================
-- DRAG
-- ============================================================
local dragging,dragInput,dragStart,startPos
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=true dragStart=i.Position startPos=panel.Position
		i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
	end
end)
titleBar.InputChanged:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end
end)
UIS.InputChanged:Connect(function(i)
	if i==dragInput and dragging then
		local d=i.Position-dragStart
		panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)

-- ============================================================
-- FPS + PING + ANTI-DISCONNECT LOOP
-- ============================================================
local frameCount,lastFPSTime,fps=0,tick(),60
RunService.RenderStepped:Connect(function()
	frameCount+=1
	if tick()-lastFPSTime>=1 then fps=frameCount frameCount=0 lastFPSTime=tick() end
end)

local ping=0
local lastUpdate,lastAntiAfk=tick(),tick()
RunService.Heartbeat:Connect(function()
	local now=tick()
	if now-lastUpdate<0.5 then return end
	lastUpdate=now

	-- Inventory
	vW.Text=tostring(countItem(CFG.ITEM_WATER))
	vSu.Text=tostring(countItem(CFG.ITEM_SUGAR))
	vGe.Text=tostring(countItem(CFG.ITEM_GEL))
	msBig.Text=tostring(totalMS())
	vSold.Text=tostring(totalSold) vMSInv.Text=tostring(countAllMS())
	vBuy.Text=tostring(totalBuy)
	sVals[1].Text=tostring(totalMS()) sVals[2].Text=tostring(stats.small)
	sVals[3].Text=tostring(stats.medium) sVals[4].Text=tostring(stats.large)
	sVals[5].Text=tostring(totalSold) sVals[6].Text=tostring(totalBuy)

	-- Ping
	pcall(function()
		local ps=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
		ping=tonumber(ps:match("%d+")) or ping
	end)
	sVals[7].Text=tostring(ping).." ms"
	sVals[8].Text=tostring(fps).." fps"

	local fc=fps>=55 and "50,230,110" or fps>=30 and "255,200,50" or "220,60,60"
	local pc=ping<=80 and "50,230,110" or ping<=150 and "255,200,50" or "220,60,60"
	fpsL.Text='<font color="rgb('..fc..'">'..fps..'fps</font>  <font color="rgb('..pc..'">'..ping..'ms</font>'

	-- Anti-disconnect
	if now-lastAntiAfk>25 then
		lastAntiAfk=now
		pcall(function()
			local v=game:GetService("VirtualInputManager")
			v:SendMouseButtonEvent(0,0,0,true,game,0) task.wait(0.05)
			v:SendMouseButtonEvent(0,0,0,false,game,0)
		end)
	end
end)


-- ============================================================
player.CharacterAdded:Connect(function(char)
	character = char
	hrp       = char:WaitForChild("HumanoidRootPart")
end)

print("[JawaHub v6.1] Loaded! Small/Medium/Large MS tracking fixed")
