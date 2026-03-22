-- ======================================================
--   PatStore - AUTO MARSHMALLOW v8
--   Masak + Jual via FireServer langsung (no E/Prompt)
-- ======================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM          = game:GetService("VirtualInputManager")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- KONFIGURASI
-- ============================================================
local CFG = {
	WATER_WAIT = 20,
	COOK_WAIT  = 46,
	ITEM_WATER  = "Water",
	ITEM_SUGAR  = "Sugar Block Bag",
	ITEM_GEL    = "Gelatin",
	ITEM_EMPTY  = "Empty Bag",
	ITEM_MS_SMALL  = "Small Marshmallow Bag",
	ITEM_MS_MEDIUM = "Medium Marshmallow Bag",
	ITEM_MS_LARGE  = "Large Marshmallow Bag",
	SELL_RADIUS  = 10,
	BUY_RADIUS   = 10,
	SELL_TIMEOUT = 8,
}

-- ============================================================
-- REMOTE EVENTS
-- ============================================================
local remotes         = RS:WaitForChild("RemoteEvents")
local storePurchaseRE = remotes:FindFirstChild("StorePurchase")
local shootRE         = remotes:FindFirstChild("Shoot")
local rpcRE           = remotes:FindFirstChild("RPC")

-- ============================================================
-- STATE
-- ============================================================
local isRunning = false
local isBusy    = false
local totalSold = 0
local totalBuy  = 0
local stats     = { small=0, medium=0, large=0 }
local function totalMS() return stats.small+stats.medium+stats.large end

-- ============================================================
-- UTILITIES
-- ============================================================
local function countItem(name)
	local n=0
	for _,t in ipairs(player.Backpack:GetChildren()) do
		if t.Name==name then n+=1 end
	end
	local char=player.Character
	if char then
		for _,t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t.Name==name then n+=1 end
		end
	end
	return n
end

local function countAllMS()
	return countItem(CFG.ITEM_MS_SMALL)+countItem(CFG.ITEM_MS_MEDIUM)+countItem(CFG.ITEM_MS_LARGE)
end

local function getEquippableMS()
	if countItem(CFG.ITEM_MS_SMALL)>0  then return CFG.ITEM_MS_SMALL  end
	if countItem(CFG.ITEM_MS_MEDIUM)>0 then return CFG.ITEM_MS_MEDIUM end
	if countItem(CFG.ITEM_MS_LARGE)>0  then return CFG.ITEM_MS_LARGE  end
	return nil
end

local function hasAllIngredients()
	return countItem(CFG.ITEM_WATER)>=1
		and countItem(CFG.ITEM_SUGAR)>=1
		and countItem(CFG.ITEM_GEL)>=1
end

local function equipTool(name)
	local char=player.Character if not char then return false end
	local hum=char:FindFirstChildOfClass("Humanoid")
	local t=player.Backpack:FindFirstChild(name)
	if hum and t then hum:EquipTool(t) task.wait(0.3) return true end
	return false
end

local function unequipAll()
	local char=player.Character if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
end

-- ── INTERAKSI TANPA E/PROMPT ─────────────────────────
-- Pakai ProximityPrompt fireproximityprompt sebagai fallback
-- tapi prioritas: FireServer langsung ke remote game
local function firePromptNearby(radius)
	for _,obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local part=obj.Parent
			if part and part:IsA("BasePart") then
				if (hrp.Position-part.Position).Magnitude<=(radius or 8) then
					pcall(function() fireproximityprompt(obj) end)
				end
			end
		end
	end
end

-- ============================================================
-- AUTO JUAL — FireServer StorePurchase / Shoot / RPC
-- ============================================================
-- Dari debug: game pakai ProximityPrompt untuk jual
-- Kita fire langsung tanpa perlu equip atau E
local function doAutoSell(setStatus)
	local msTotal=countAllMS()
	if msTotal==0 then
		setStatus("ℹ️ Tidak ada MS di inventory",Color3.fromRGB(160,160,180))
		return
	end
	setStatus("💰 Memulai jual "..msTotal.." MS...",Color3.fromRGB(50,210,110))
	task.wait(0.3)
	local sold=0
	local maxFail=5
	local failStreak=0
	while countAllMS()>0 do
		local msName=getEquippableMS()
		if not msName then break end
		local equipped=equipTool(msName)
		if not equipped then
			failStreak+=1
			setStatus("❌ Gagal equip MS! ("..failStreak.."/"..maxFail..")",Color3.fromRGB(210,40,40))
			task.wait(1)
			if failStreak>=maxFail then break end
			continue
		end
		local beforeS=countItem(CFG.ITEM_MS_SMALL)
		local beforeM=countItem(CFG.ITEM_MS_MEDIUM)
		local beforeL=countItem(CFG.ITEM_MS_LARGE)
		-- Double fire: pressE + semua prompt dalam radius
		pressE()
		task.wait(0.1)
		firePromptNearby(CFG.SELL_RADIUS)
		task.wait(0.1)
		pressE()
		local elapsed=0
		local terjual=false
		while elapsed<CFG.SELL_TIMEOUT do
			local diff=(beforeS-countItem(CFG.ITEM_MS_SMALL))
				+(beforeM-countItem(CFG.ITEM_MS_MEDIUM))
				+(beforeL-countItem(CFG.ITEM_MS_LARGE))
			if diff>0 then
				sold+=diff totalSold+=diff terjual=true failStreak=0
				break
			end
			task.wait(0.25) elapsed+=0.25
		end
		if terjual then
			setStatus("💰 Terjual "..sold.." | Sisa: "..countAllMS().." MS",Color3.fromRGB(50,210,110))
			task.wait(0.2)
		else
			failStreak+=1
			setStatus("⚠️ Tidak terjual ("..failStreak.."/"..maxFail..") — Pastikan dekat NPC!",Color3.fromRGB(255,155,35))
			task.wait(1)
			if failStreak>=maxFail then
				setStatus("❌ Gagal jual. Dekati NPC jual!",Color3.fromRGB(210,40,40))
				break
			end
		end
	end
	unequipAll()
	if sold>0 then
		setStatus("✅ Selesai! Terjual "..sold.." MS (total: "..totalSold..")",Color3.fromRGB(50,210,110))
	else
		setStatus("⚠️ Tidak ada MS terjual. Pastikan di dekat NPC!",Color3.fromRGB(255,155,35))
	end
	task.wait(1)
end

-- ============================================================
-- AUTO BELI — StorePurchase FireServer
-- ============================================================
local buyQty={1,1,1}
local buyBusy=false
local BUY_ITEMS={
	{name="Gelatin",        display="🟡 Gelatin"},
	{name="Sugar Block Bag",display="🧂 Sugar Block Bag"},
	{name="Water",          display="💧 Water"},
}

local function doAutoBuy(setStatus)
	if not storePurchaseRE then
		setStatus("❌ Remote StorePurchase tidak ada!",Color3.fromRGB(210,40,40))
		task.wait(1.5) return
	end
	local totalBought=0
	for idx,item in ipairs(BUY_ITEMS) do
		local qty=buyQty[idx] or 1
		setStatus("🛒 Beli "..item.display.." ×"..qty.."...",Color3.fromRGB(100,180,255))
		for q=1,qty do
			pcall(function() storePurchaseRE:FireServer(item.name,1) end)
			task.wait(0.3)
			totalBought+=1
		end
		totalBuy+=qty
		setStatus("✅ "..item.display.." ×"..qty.." selesai!",Color3.fromRGB(80,220,130))
		task.wait(0.15)
	end
	setStatus("✅ Beli selesai! "..totalBought.."x item.",Color3.fromRGB(80,220,130))
	task.wait(1)
end

-- ============================================================
-- AUTO MASAK — RPC-driven (listen instruksi server)
-- Dari debug: server kirim RPC dengan instruksi masak:
--   "Wait 20 seconds for your water to boil." -> tunggu & fire prompt
--   "Pour gelatin into the pot."              -> equip Gelatin + fire prompt
--   "Bag the solution into the empty bag."    -> equip EmptyBag + fire prompt
-- ============================================================
local lblStatus

local function setStatus(msg,color)
	if lblStatus then
		lblStatus.Text=msg
		lblStatus.TextColor3=color or Color3.fromRGB(155,165,200)
	end
end

local function countdown(secs,fmt,color)
	for i=secs,1,-1 do
		if not isRunning then return false end
		setStatus(string.format(fmt,i),color)
		task.wait(1)
	end
	return true
end

-- Interaksi masak: equip tool + semua metode interaksi
local function cookInteract(toolName, radius)
	if toolName then
		equipTool(toolName)
		task.wait(0.4)
	end
	-- Method 1: fireproximityprompt (executor function)
	firePromptNearby(radius or 8)
	task.wait(0.1)
	-- Method 2: VIM press E (fallback)
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.15)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
	task.wait(0.1)
	-- Method 3: fire lagi untuk pastikan
	firePromptNearby(radius or 8)
end

-- ============================================================
-- RPC LISTENER — decode instruksi masak dari server
-- Flow yang terdeteksi dari debug:
--   {1=20, 2="TextLabel"}                          → timer countdown 20 det
--   "Wait 20 seconds for your water to boil."      → tunggu mendidih
--   "Dump the sugar block from the bag into the pot." → equip Sugar + interact
--   "Pour gelatin into the pot."                   → equip Gelatin + interact
--   {1=45, 2="TextLabel"}                          → timer countdown 45 det
--   "Let the solution cook for 45 seconds."        → tunggu masak
--   "Bag the solution into the empty bag."         → equip EmptyBag + interact
-- ============================================================
local rpcQueue = {}  -- antrian instruksi dari server

local rpcRE2 = remotes:FindFirstChild("RPC")
if rpcRE2 then
	rpcRE2.OnClientEvent:Connect(function(bufArg, tblArg)
		if type(tblArg) ~= "table" then return end
		local v1 = tblArg[1]
		local v2 = tblArg[2]
		local msg = tostring(v1 or ""):lower()

		if v2 == "TextLabel" and tonumber(v1) then
			-- Timer countdown dari server
			table.insert(rpcQueue, {type="timer", secs=tonumber(v1)})

		elseif msg:find("boil") or (msg:find("wait") and msg:find("water")) then
			-- "Wait 20 seconds for your water to boil."
			table.insert(rpcQueue, {type="wait_boil"})

		elseif msg:find("sugar") or msg:find("dump") then
			-- "Dump the sugar block from the bag into the pot."
			table.insert(rpcQueue, {type="add_sugar"})

		elseif msg:find("gelatin") or msg:find("pour") then
			-- "Pour gelatin into the pot."
			table.insert(rpcQueue, {type="add_gelatin"})

		elseif msg:find("cook for") or msg:find("solution cook") or msg:find("let the") then
			-- "Let the solution cook for 45 seconds."
			table.insert(rpcQueue, {type="wait_cook"})

		elseif msg:find("bag") or msg:find("empty bag") then
			-- "Bag the solution into the empty bag."
			table.insert(rpcQueue, {type="bag_result"})
		end
	end)
end

-- Tunggu instruksi tertentu dari antrian (dengan timeout)
local function waitRPC(instrType, timeout)
	local elapsed = 0
	while elapsed < timeout do
		for i, inst in ipairs(rpcQueue) do
			if inst.type == instrType then
				table.remove(rpcQueue, i)
				return inst
			end
		end
		task.wait(0.15)
		elapsed += 0.15
	end
	return nil
end

-- Ambil timer terakhir dari antrian
local function popTimer()
	for i = #rpcQueue, 1, -1 do
		if rpcQueue[i].type == "timer" then
			local t = rpcQueue[i]
			table.remove(rpcQueue, i)
			return t.secs
		end
	end
	return nil
end

local function doOneCook()
	isBusy = true
	rpcQueue = {}  -- reset antrian
	local snapS=countItem(CFG.ITEM_MS_SMALL)
	local snapM=countItem(CFG.ITEM_MS_MEDIUM)
	local snapL=countItem(CFG.ITEM_MS_LARGE)

	-- ── STEP 1: Masukkan Water ──────────────────────────
	setStatus("💧 Masukkan Water...",Color3.fromRGB(100,180,255))
	cookInteract(CFG.ITEM_WATER, 8)
	task.wait(0.5)

	-- Tunggu server kirim timer boil (server kirim timer LALU instruksi teks)
	-- Beri waktu 5 detik untuk terima kedua pesan dari server
	setStatus("💧 Menunggu server...",Color3.fromRGB(80,150,255))
	task.wait(1)  -- beri waktu server kirim RPC

	-- Ambil timer dari queue (dikirim duluan sebelum teks boil)
	local boilSecs = popTimer() or CFG.WATER_WAIT

	-- Countdown boil
	setStatus("💧 Mendidih... "..boilSecs.."s",Color3.fromRGB(80,150,255))
	if not countdown(boilSecs,"💧 Mendidih... ⏱ %ds",Color3.fromRGB(80,150,255)) then
		isBusy=false return false
	end

	-- ── STEP 2: Sugar (server kirim "Dump the sugar" setelah boil) ──
	setStatus("🧂 Tunggu instruksi Sugar...",Color3.fromRGB(255,220,100))
	local sugarInst = waitRPC("add_sugar", 8)  -- tunggu max 8 detik
	if not isRunning then isBusy=false return false end
	setStatus("🧂 Masukkan Sugar...",Color3.fromRGB(255,220,100))
	cookInteract(CFG.ITEM_SUGAR, 8)
	task.wait(0.8)

	-- ── STEP 3: Gelatin (server kirim "Pour gelatin") ──────
	setStatus("🟡 Tunggu instruksi gelatin...",Color3.fromRGB(255,200,50))
	local gelInst = waitRPC("add_gelatin", 6)
	setStatus("🟡 Masukkan Gelatin...",Color3.fromRGB(255,200,50))
	cookInteract(CFG.ITEM_GEL, 8)
	task.wait(0.5)

	-- ── STEP 4: Tunggu masak (server kirim timer setelah gelatin) ──
	setStatus("🔥 Tunggu server...",Color3.fromRGB(80,140,255))
	task.wait(1)  -- beri waktu server kirim RPC timer

	local cookSecs = popTimer() or CFG.COOK_WAIT
	setStatus("🔥 Memasak... "..cookSecs.."s",Color3.fromRGB(80,140,255))
	if not countdown(cookSecs,"🔥 Memasak... ⏱ %ds",Color3.fromRGB(80,140,255)) then
		isBusy=false return false
	end

	-- ── STEP 5: Bag result (server kirim "Bag the solution") ──
	setStatus("🎒 Tunggu instruksi bag...",Color3.fromRGB(100,160,255))
	local bagInst = waitRPC("bag_result", 10)

	-- Tunggu Empty Bag muncul di inventory
	local bag,t3=nil,0
	repeat
		bag=player.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
		task.wait(0.5) t3+=0.5
	until bag or t3>12
	if not bag then
		setStatus("❌ Empty Bag tidak ada!",Color3.fromRGB(210,40,40))
		task.wait(1.5) isBusy=false return false
	end

	setStatus("🎒 Ambil Marshmallow...",Color3.fromRGB(100,180,255))
	cookInteract(CFG.ITEM_EMPTY, 8)

	-- ── STEP 6: Tunggu MS masuk ─────────────────────────
	setStatus("⏳ Tunggu MS masuk...",Color3.fromRGB(100,160,255))
	local waitMS=0
	local newS,newM,newL=0,0,0
	repeat
		task.wait(0.4) waitMS+=0.4
		newS=countItem(CFG.ITEM_MS_SMALL)-snapS
		newM=countItem(CFG.ITEM_MS_MEDIUM)-snapM
		newL=countItem(CFG.ITEM_MS_LARGE)-snapL
	until (newS>0 or newM>0 or newL>0) or waitMS>10

	if newS>0 then stats.small+=newS
	elseif newM>0 then stats.medium+=newM
	elseif newL>0 then stats.large+=newL
	else stats.small+=1 end

	setStatus("✅ MS ke-"..totalMS().." selesai!",Color3.fromRGB(80,210,255))
	task.wait(0.5)
	isBusy=false
	return true
end

local function autoLoop()
	while isRunning do
		if not hasAllIngredients() then
			setStatus("❌ Bahan habis! Gunakan Auto Beli.",Color3.fromRGB(210,40,40))
			isRunning=false break
		end
		doOneCook()
		if isRunning then task.wait(0.3) end
	end
end

-- ============================================================
-- ESP STATE
-- ============================================================

-- ============================================================
-- GUI — PatStore v1.0
-- ============================================================
-- ============================================================
-- ESP STATE
-- ============================================================
-- ============================================================
-- GUI — PatStore v1.0  (lebar, menu di kiri, no combat)
-- ============================================================
-- ============================================================
-- TELEPORT (motor-based)
-- ============================================================
local isTeleporting = false

local function stepTeleport(targetPos, locName)
	if isTeleporting then return end
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then return end
	isTeleporting = true

	task.spawn(function()
		local seatPart = hum.SeatPart
		if seatPart then
			-- Naik motor: pindahkan model motor ke tujuan
			local vehicle = seatPart:FindFirstAncestorOfClass("Model")
			if vehicle then
				local anchor = vehicle.PrimaryPart
					or vehicle:FindFirstChildOfClass("VehicleSeat")
					or seatPart
				local newCF = CFrame.new(targetPos + Vector3.new(0,5,0))
				if vehicle.PrimaryPart then
					vehicle:SetPrimaryPartCFrame(newCF)
				else
					anchor.CFrame = newCF
				end
				for _,p in ipairs(vehicle:GetDescendants()) do
					if p:IsA("BasePart") then
						pcall(function()
							p.AssemblyLinearVelocity  = Vector3.zero
							p.AssemblyAngularVelocity = Vector3.zero
						end)
					end
				end
			end
		else
			-- Tidak naik motor: tidak teleport, kasih info
			print("[PatStore] Naiki kendaraan dulu!")
		end
		task.wait(0.1)
		isTeleporting = false
	end)
end

if playerGui:FindFirstChild("PatStoreGUI") then
	playerGui.PatStoreGUI:Destroy()
end

local sg=Instance.new("ScreenGui")
sg.Name="PatStoreGUI" sg.ResetOnSpawn=false sg.IgnoreGuiInset=true sg.DisplayOrder=10
pcall(function() sg.Parent=game.CoreGui end)
if sg.Parent~=game.CoreGui then sg.Parent=playerGui end

-- ── ESP DRAWING SYSTEM ───────────────────────────────
local espEnabled = false
local ESP_CFG = {
	username=true, skeleton=true, healthBar=true,
	box=true, fillBox=false, distance=true, headDot=true, tracer=true,
}
local ESP_COL = {
	name    = Color3.fromRGB(255,255,255),
	box     = Color3.fromRGB(255,60,60),
	fill    = Color3.fromRGB(255,60,60),
	skel    = Color3.fromRGB(255,200,50),
	health  = Color3.fromRGB(50,210,80),
	healthBg= Color3.fromRGB(20,20,20),
	dist    = Color3.fromRGB(180,220,255),
	dot     = Color3.fromRGB(255,60,60),
	tracer  = Color3.fromRGB(255,60,60),
}
local SKEL_PAIRS={
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local espCache = {}

-- ESP ScreenGui (terpisah dari main GUI supaya selalu on top)
local espSg = Instance.new("ScreenGui")
espSg.Name="PatESP" espSg.ResetOnSpawn=false espSg.IgnoreGuiInset=true espSg.DisplayOrder=999
pcall(function() espSg.Parent=game.CoreGui end)
if espSg.Parent~=game.CoreGui then espSg.Parent=playerGui end

local function mkESPLabel(text,col,size)
	local l=Instance.new("TextLabel",espSg)
	l.BackgroundTransparency=1 l.BorderSizePixel=0
	l.TextColor3=col l.TextStrokeTransparency=0.4
	l.TextStrokeColor3=Color3.new(0,0,0)
	l.Font=Enum.Font.GothamBold l.TextScaled=false
	l.TextSize=size or 11 l.ZIndex=10
	l.Text=text l.Size=UDim2.new(0,120,0,14)
	l.AnchorPoint=Vector2.new(0.5,0.5)
	l.Visible=false
	return l
end
local function mkESPFrame(col,alpha,thick)
	local f=Instance.new("Frame",espSg)
	f.BackgroundColor3=col f.BackgroundTransparency=alpha or 1
	f.BorderSizePixel=0 f.ZIndex=8 f.Visible=false
	if thick then
		local s=Instance.new("UIStroke",f)
		s.Color=col s.Thickness=thick
	end
	return f
end
local function mkESPLine(col)
	local f=Instance.new("Frame",espSg)
	f.BackgroundColor3=col f.BorderSizePixel=0
	f.ZIndex=7 f.Visible=false
	f.AnchorPoint=Vector2.new(0,0.5)
	return f
end
local function setLine(f,x1,y1,x2,y2)
	local dx,dy=x2-x1,y2-y1
	local len=math.sqrt(dx*dx+dy*dy)
	if len<1 then f.Visible=false return end
	f.Size=UDim2.new(0,len,0,1.5)
	f.Position=UDim2.new(0,x1,0,y1)
	f.Rotation=math.deg(math.atan2(dy,dx))
	f.Visible=true
end

local function getESP(plr)
	if espCache[plr] then return espCache[plr] end
	local d={
		nameTag  = mkESPLabel("",ESP_COL.name,11),
		distTag  = mkESPLabel("",ESP_COL.dist,9),
		box      = mkESPFrame(ESP_COL.box,1,1.5),
		fillBox  = mkESPFrame(ESP_COL.fill,0.75,0),
		headDot  = mkESPFrame(ESP_COL.dot,0,0),
		healthBg = mkESPFrame(ESP_COL.healthBg,0,0),
		healthFg = mkESPFrame(ESP_COL.health,0,0),
		tracer   = mkESPLine(ESP_COL.tracer),
		skelLines= {},
	}
	Instance.new("UICorner",d.headDot).CornerRadius=UDim.new(0.5,0)
	for _=1,#SKEL_PAIRS do table.insert(d.skelLines,mkESPLine(ESP_COL.skel)) end
	espCache[plr]=d
	return d
end
local function hideESP(d)
	if not d then return end
	d.nameTag.Visible=false d.distTag.Visible=false
	d.box.Visible=false d.fillBox.Visible=false
	d.headDot.Visible=false
	d.healthBg.Visible=false d.healthFg.Visible=false
	d.tracer.Visible=false
	for _,l in ipairs(d.skelLines) do l.Visible=false end
end
local function destroyESP(plr)
	local d=espCache[plr]
	if not d then return end
	d.nameTag:Destroy() d.distTag:Destroy()
	d.box:Destroy() d.fillBox:Destroy()
	d.headDot:Destroy() d.healthBg:Destroy() d.healthFg:Destroy()
	d.tracer:Destroy()
	for _,l in ipairs(d.skelLines) do l:Destroy() end
	espCache[plr]=nil
end

RunService.RenderStepped:Connect(function()
	if not espEnabled then
		for _,d in pairs(espCache) do hideESP(d) end
		return
	end
	local cam=workspace.CurrentCamera
	local vp=cam.ViewportSize
	local lc=player.Character
	local lhrp=lc and lc:FindFirstChild("HumanoidRootPart")

	for _,plr in ipairs(Players:GetPlayers()) do
		if plr==player then continue end
		local ch=plr.Character
		local hrpT=ch and ch:FindFirstChild("HumanoidRootPart")
		local hum=ch and ch:FindFirstChild("Humanoid")
		if not ch or not hrpT or not hum or hum.Health<=0 then
			hideESP(espCache[plr]) continue
		end
		local d=getESP(plr)
		local sp,onScreen=cam:WorldToViewportPoint(hrpT.Position)
		if not onScreen then hideESP(d) continue end

		local dist=lhrp and math.floor((hrpT.Position-lhrp.Position).Magnitude) or 0
		local head=ch:FindFirstChild("Head")
		local hp=head and cam:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0)) or sp
		local foot=ch:FindFirstChild("HumanoidRootPart")
		local fp=foot and cam:WorldToViewportPoint(foot.Position-Vector3.new(0,2.5,0)) or Vector3.new(sp.X,sp.Y+50,sp.Z)
		local charH=math.abs(hp.Y-fp.Y) if charH<10 then charH=60 end
		local charW=charH*0.45
		local cx,cy=sp.X,sp.Y

		-- Name
		d.nameTag.Visible=ESP_CFG.username
		if ESP_CFG.username then
			d.nameTag.Text=plr.Name
			d.nameTag.Position=UDim2.new(0,cx,0,hp.Y-16)
		end
		-- Distance
		d.distTag.Visible=ESP_CFG.distance
		if ESP_CFG.distance then
			d.distTag.Text=dist.."m"
			d.distTag.Position=UDim2.new(0,cx,0,fp.Y+8)
		end
		-- Box
		local bx,by=cx-charW/2,hp.Y
		d.box.Visible=ESP_CFG.box
		if ESP_CFG.box then
			d.box.Position=UDim2.new(0,bx,0,by)
			d.box.Size=UDim2.new(0,charW,0,charH)
			d.box.BackgroundTransparency=1
		end
		d.fillBox.Visible=ESP_CFG.fillBox
		if ESP_CFG.fillBox then
			d.fillBox.Position=UDim2.new(0,bx,0,by)
			d.fillBox.Size=UDim2.new(0,charW,0,charH)
		end
		-- Head dot
		d.headDot.Visible=ESP_CFG.headDot
		if ESP_CFG.headDot then
			local ds=7
			d.headDot.Size=UDim2.new(0,ds,0,ds)
			d.headDot.Position=UDim2.new(0,hp.X-ds/2,0,hp.Y-ds/2)
			d.headDot.BackgroundTransparency=0
		end
		-- Health bar
		local hpRatio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
		d.healthBg.Visible=ESP_CFG.healthBar
		d.healthFg.Visible=ESP_CFG.healthBar
		if ESP_CFG.healthBar then
			local hbx=bx-5
			d.healthBg.Position=UDim2.new(0,hbx,0,by)
			d.healthBg.Size=UDim2.new(0,3,0,charH)
			d.healthBg.BackgroundTransparency=0
			d.healthFg.Position=UDim2.new(0,hbx,0,by+charH*(1-hpRatio))
			d.healthFg.Size=UDim2.new(0,3,0,charH*hpRatio)
			d.healthFg.BackgroundTransparency=0
			d.healthFg.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-hpRatio)),math.floor(200*hpRatio),30)
		end
		-- Tracer
		d.tracer.Visible=ESP_CFG.tracer
		if ESP_CFG.tracer then
			setLine(d.tracer,vp.X/2,vp.Y,cx,cy)
		end
		-- Skeleton
		if ESP_CFG.skeleton then
			for idx,pair in ipairs(SKEL_PAIRS) do
				local p1=ch:FindFirstChild(pair[1])
				local p2=ch:FindFirstChild(pair[2])
				local sl=d.skelLines[idx]
				if p1 and p2 and sl then
					local s1,o1=cam:WorldToViewportPoint(p1.Position)
					local s2,o2=cam:WorldToViewportPoint(p2.Position)
					if o1 and o2 then setLine(sl,s1.X,s1.Y,s2.X,s2.Y)
					else sl.Visible=false end
				elseif sl then sl.Visible=false end
			end
		else for _,l in ipairs(d.skelLines) do l.Visible=false end end
	end
	for plr in pairs(espCache) do
		if not plr.Parent then destroyESP(plr) end
	end
end)
Players.PlayerRemoving:Connect(destroyESP)


local C={
	bg    =Color3.fromRGB(11,11,16),
	panel =Color3.fromRGB(16,16,22),
	card  =Color3.fromRGB(22,22,30),
	tabBg =Color3.fromRGB(13,13,19),
	line  =Color3.fromRGB(32,32,44),
	blue  =Color3.fromRGB(82,130,255),
	blueD =Color3.fromRGB(48,88,200),
	green =Color3.fromRGB(52,210,110),
	greenD=Color3.fromRGB(30,140,70),
	red   =Color3.fromRGB(215,50,50),
	orange=Color3.fromRGB(255,160,40),
	purple=Color3.fromRGB(148,80,255),
	cyan  =Color3.fromRGB(50,210,230),
	txt   =Color3.fromRGB(230,232,240),
	txtM  =Color3.fromRGB(148,154,175),
	txtD  =Color3.fromRGB(60,64,84),
}

local function F(p,bg,zi)
	local f=Instance.new("Frame") f.BackgroundColor3=bg or C.card
	f.BorderSizePixel=0 f.ZIndex=zi or 2 if p then f.Parent=p end return f
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
	local d=F(p,C.line,2) d.Size=UDim2.new(1,-24,0,1) d.Position=UDim2.new(0,12,0,y)
end
local function secHdr(p,y,txt)
	local bar=F(p,C.blue,3) bar.Size=UDim2.new(0,3,0,12) bar.Position=UDim2.new(0,12,0,y+3) corner(bar,2)
	local l=T(p,txt,C.txtM,Enum.Font.GothamBold,Enum.TextXAlignment.Left,3,10)
	l.Size=UDim2.new(1,-30,0,18) l.Position=UDim2.new(0,20,0,y) return l
end
local function statRow(p,y,icon,lbl,valCol)
	local row=F(p,C.card,2) row.Size=UDim2.new(1,-24,0,34) row.Position=UDim2.new(0,12,0,y) corner(row,8)
	local ic=T(row,icon,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Center,3,13)
	ic.Size=UDim2.new(0,28,1,0) ic.Position=UDim2.new(0,4,0,0)
	local nm=T(row,lbl,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,3,11)
	nm.Size=UDim2.new(0.55,-32,1,0) nm.Position=UDim2.new(0,34,0,0)
	local vl=T(row,"0",valCol or C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Right,3,13)
	vl.Size=UDim2.new(0.45,-10,1,0) vl.Position=UDim2.new(0.55,0,0,0)
	return vl
end
local function actionBtn(p,y,txt,bg,txtC)
	local w=F(p,bg or C.blue,3) w.Size=UDim2.new(1,-24,0,36) w.Position=UDim2.new(0,12,0,y) corner(w,8)
	local sh=F(w,Color3.fromRGB(255,255,255),4) sh.Size=UDim2.new(1,0,0.5,0) sh.BackgroundTransparency=0.92 corner(sh,8)
	local b=B(w,txt,txtC or C.txt,Enum.Font.GothamBold,4) b.Size=UDim2.new(1,0,1,0) b.TextSize=11 b.TextScaled=false
	return w,b
end
local function hoverBtn(w,b,nc,hc)
	b.MouseEnter:Connect(function() TweenService:Create(w,TweenInfo.new(0.1),{BackgroundColor3=hc}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(w,TweenInfo.new(0.1),{BackgroundColor3=nc}):Play() end)
end
local function sliderRow(p,y,lbl,minV,maxV,defV,unit,w)
	w = w or (p.AbsoluteSize.X > 0 and p.AbsoluteSize.X - 24 or 300)
	local row=F(p,C.card,2) row.Size=UDim2.new(1,-24,0,48) row.Position=UDim2.new(0,12,0,y) corner(row,8)
	local nm=T(row,lbl,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,3,10)
	nm.Size=UDim2.new(0.6,0,0,20) nm.Position=UDim2.new(0,10,0,2)
	local valL=T(row,tostring(defV)..(unit or ""),C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Right,3,11)
	valL.Size=UDim2.new(0.4,-10,0,20) valL.Position=UDim2.new(0.6,0,0,2)
	local track=F(row,C.line,3) track.Size=UDim2.new(1,-20,0,4) track.Position=UDim2.new(0,10,0,30) corner(track,2)
	local fill=F(track,C.blue,4) fill.Size=UDim2.new((defV-minV)/(maxV-minV),0,1,0) corner(fill,2)
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
			setVal(minV+(i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X*(maxV-minV))
		end
	end)
	track.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
	UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			setVal(minV+(i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X*(maxV-minV))
		end
	end)
	return function() return curVal end
end

-- ── PANEL (lebar, tidak terlalu tinggi) ──────────────
-- Layout: menu tabs di KIRI (vertikal), konten di KANAN
local PW, PH = 560, 420
local SIDEBAR = 110  -- lebar sidebar kiri
local CONTENT = PW - SIDEBAR  -- lebar area konten

local panel=F(sg,C.panel,1) panel.Name="Panel"
panel.Size=UDim2.new(0,PW,0,PH)
panel.Position=UDim2.new(0.5,-PW/2,0.5,-PH/2)
corner(panel,12) stroke(panel,C.line,1.5)

-- Gradient top accent
local acc=F(panel,C.blue,2) acc.Size=UDim2.new(1,0,0,2)
local ag=Instance.new("UIGradient",acc)
ag.Color=ColorSequence.new{
	ColorSequenceKeypoint.new(0,C.blue),
	ColorSequenceKeypoint.new(0.5,C.purple),
	ColorSequenceKeypoint.new(1,C.cyan)
}

-- ── TITLE BAR ────────────────────────────────────────
local titleBar=F(panel,C.bg,3)
titleBar.Size=UDim2.new(1,0,0,40)
titleBar.Position=UDim2.new(0,0,0,2)
corner(titleBar,10)

local dot=F(titleBar,C.blue,4) dot.Size=UDim2.new(0,8,0,8) dot.Position=UDim2.new(0,12,0.5,-4) corner(dot,4)
local dotGlow=F(titleBar,C.blue,3) dotGlow.Size=UDim2.new(0,16,0,16) dotGlow.Position=UDim2.new(0,8,0.5,-8) corner(dotGlow,8) dotGlow.BackgroundTransparency=0.75
local titleL=T(titleBar,"PatStore",C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,14)
titleL.Size=UDim2.new(0.3,0,1,0) titleL.Position=UDim2.new(0,28,0,0)
local verL=T(titleBar,"v1.0",C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,10)
verL.Size=UDim2.new(0,26,1,0) verL.Position=UDim2.new(0,88,0,0)

-- FPS + Ping
local fpsBox=F(titleBar,C.card,4) fpsBox.Size=UDim2.new(0,100,0,22) fpsBox.Position=UDim2.new(1,-134,0.5,-11) corner(fpsBox,6)
local fpsNumL=T(fpsBox,"--fps",Color3.fromRGB(50,230,110),Enum.Font.Gotham,Enum.TextXAlignment.Left,5,9)
fpsNumL.Size=UDim2.new(0.5,0,1,0) fpsNumL.Position=UDim2.new(0,4,0,0)
local pingNumL=T(fpsBox,"--ms",Color3.fromRGB(50,230,110),Enum.Font.Gotham,Enum.TextXAlignment.Right,5,9)
pingNumL.Size=UDim2.new(0.5,-4,1,0) pingNumL.Position=UDim2.new(0.5,0,0,0)

local closeW=F(titleBar,C.card,4) closeW.Size=UDim2.new(0,24,0,24) closeW.Position=UDim2.new(1,-32,0.5,-12) corner(closeW,6)
local closeB=B(closeW,"x",C.txtM,Enum.Font.GothamBold,5) closeB.Size=UDim2.new(1,0,1,0) closeB.TextSize=15 closeB.TextScaled=false
closeB.MouseButton1Click:Connect(function() panel.Visible=not panel.Visible end)
closeB.MouseEnter:Connect(function() TweenService:Create(closeW,TweenInfo.new(0.1),{BackgroundColor3=C.red}):Play() closeB.TextColor3=C.txt end)
closeB.MouseLeave:Connect(function() TweenService:Create(closeW,TweenInfo.new(0.1),{BackgroundColor3=C.card}):Play() closeB.TextColor3=C.txtM end)

-- ── BODY (di bawah titlebar) ──────────────────────────
local body=F(panel,C.bg,2)
body.Size=UDim2.new(1,0,1,-44)
body.Position=UDim2.new(0,0,0,44)
corner(body,10)

-- ── SIDEBAR KIRI ─────────────────────────────────────
local sidebar=F(body,C.panel,3)
sidebar.Size=UDim2.new(0,SIDEBAR,1,0)
corner(sidebar,10)

-- Divider antara sidebar dan content
local sideDiv=F(body,C.line,3)
sideDiv.Size=UDim2.new(0,1,1,-16)
sideDiv.Position=UDim2.new(0,SIDEBAR,0,8)

-- ── CONTENT AREA ─────────────────────────────────────
local contentArea=F(body,Color3.fromRGB(0,0,0),2)
contentArea.BackgroundTransparency=1
contentArea.Size=UDim2.new(1,-SIDEBAR-1,1,0)
contentArea.Position=UDim2.new(0,SIDEBAR+1,0,0)

-- ── MENU TABS DI SIDEBAR (vertikal) ──────────────────
local MENUS={"🌾 FARM","👁 ESP","🗺 TELEPORT"}
local menuBtns,menuPages={},{}

for i,name in ipairs(MENUS) do
	-- Sidebar button
	local mb=F(sidebar,C.bg,4)
	mb.Size=UDim2.new(1,-12,0,48)
	mb.Position=UDim2.new(0,6,0,10+(i-1)*54)
	corner(mb,8)

	local icon=name:match("^(.-)%s") or name:sub(1,2)
	local label=name:match("%s(.+)$") or name

	local mbIcon=T(mb,icon,C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Center,5,16)
	mbIcon.Size=UDim2.new(1,0,0,26) mbIcon.Position=UDim2.new(0,0,0,4)

	local mbLabel=T(mb,label,C.txtD,Enum.Font.GothamBold,Enum.TextXAlignment.Center,5,8)
	mbLabel.Size=UDim2.new(1,0,0,14) mbLabel.Position=UDim2.new(0,0,0,30)

	-- Indicator bar kiri
	local ind=F(mb,C.blue,6) ind.Size=UDim2.new(0,3,0.6,0) ind.Position=UDim2.new(0,0,0.2,0) corner(ind,2) ind.Visible=(i==1)

	local clickBtn=B(mb,"",C.txt,Enum.Font.Gotham,6) clickBtn.Size=UDim2.new(1,0,1,0)

	menuBtns[i]={frame=mb, icon=mbIcon, label=mbLabel, ind=ind, btn=clickBtn}

	-- Content page
	local mp=F(contentArea,Color3.fromRGB(0,0,0),2)
	mp.BackgroundTransparency=1
	mp.Size=UDim2.new(1,0,1,0)
	mp.Visible=(i==1) mp.ClipsDescendants=true
	menuPages[i]=mp
end

local function switchMenu(idx)
	for i=1,#MENUS do
		local mb=menuBtns[i]
		local active=(i==idx)
		mb.ind.Visible=active
		mb.icon.TextColor3=active and C.blue or C.txtM
		mb.label.TextColor3=active and C.txt or C.txtD
		TweenService:Create(mb.frame,TweenInfo.new(0.12),{
			BackgroundColor3=active and Color3.fromRGB(20,20,30) or C.bg
		}):Play()
		menuPages[i].Visible=active
	end
end
for i,mb in ipairs(menuBtns) do
	mb.btn.MouseButton1Click:Connect(function() switchMenu(i) end)
end

-- ============================================================
-- FARM PAGE — Sub tabs: MASAK | JUAL | BELI | STATS
-- ============================================================
local farmPage=menuPages[1]

-- Sub-tab bar di atas content
local tabBar=F(farmPage,C.tabBg,3) tabBar.Size=UDim2.new(1,0,0,30)
local tabLine=F(farmPage,C.line,3) tabLine.Size=UDim2.new(1,0,0,1) tabLine.Position=UDim2.new(0,0,0,30)
local TABS={"MASAK","JUAL","BELI","STATS"}
local tabBtns,pages={},{}
local tw=CONTENT/#TABS
for i,name in ipairs(TABS) do
	local tb=B(tabBar,name,C.txtD,Enum.Font.GothamBold,4,10)
	tb.BackgroundTransparency=0 tb.BackgroundColor3=C.tabBg
	tb.Size=UDim2.new(0,tw,1,0) tb.Position=UDim2.new(0,(i-1)*tw,0,0)
	tabBtns[i]=tb
	local ul=F(tb,C.blue,5) ul.Name="UL" ul.Size=UDim2.new(0.6,0,0,2) ul.Position=UDim2.new(0.2,0,1,-2) ul.Visible=(i==1)
	local pg=F(farmPage,Color3.fromRGB(0,0,0),2)
	pg.BackgroundTransparency=1
	pg.Size=UDim2.new(1,0,1,-31) pg.Position=UDim2.new(0,0,0,31)
	pg.Visible=(i==1) pg.ClipsDescendants=true pages[i]=pg
end
local function switchTab(idx)
	for i=1,#TABS do
		pages[i].Visible=(i==idx)
		tabBtns[i].TextColor3=(i==idx) and C.txt or C.txtD
		local ul=tabBtns[i]:FindFirstChild("UL") if ul then ul.Visible=(i==idx) end
		TweenService:Create(tabBtns[i],TweenInfo.new(0.12),{BackgroundColor3=(i==idx) and Color3.fromRGB(20,20,28) or C.tabBg}):Play()
	end
end
for i,tb in ipairs(tabBtns) do tb.MouseButton1Click:Connect(function() switchTab(i) end) end

-- ── PAGE 1: MASAK ─────────────────────────────────────
local pg1=pages[1]
local statusCard=F(pg1,C.bg,3) statusCard.Size=UDim2.new(1,-24,0,26) statusCard.Position=UDim2.new(0,12,0,8) corner(statusCard,8) stroke(statusCard,C.line,1)
lblStatus=T(statusCard,"Siap digunakan",C.cyan,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,10)
lblStatus.Size=UDim2.new(1,-8,1,0) lblStatus.Position=UDim2.new(0,4,0,0)

local infoCard=F(pg1,Color3.fromRGB(11,22,11),3) infoCard.Size=UDim2.new(1,-24,0,18) infoCard.Position=UDim2.new(0,12,0,38) corner(infoCard,6) stroke(infoCard,C.green,1)
local infoL=T(infoCard,"⚡ Auto interact — tidak perlu tekan E",C.green,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,8)
infoL.Size=UDim2.new(1,-8,1,0) infoL.Position=UDim2.new(0,4,0,0)

line(pg1,62) secHdr(pg1,68,"BAHAN TERSEDIA")
local vW =statRow(pg1, 86,"💧","Water",       Color3.fromRGB(100,200,255))
local vSu=statRow(pg1,126,"🧂","Sugar Bag",   Color3.fromRGB(255,220,100))
local vGe=statRow(pg1,166,"🟡","Gelatin",     Color3.fromRGB(255,190,60))
line(pg1,206) secHdr(pg1,212,"HASIL MASAK")

local msCard=F(pg1,C.bg,3) msCard.Size=UDim2.new(1,-24,0,46) msCard.Position=UDim2.new(0,12,0,228) corner(msCard,10) glow(msCard,C.blue,1.5)
local msBig=T(msCard,"0",C.blue,Enum.Font.GothamBold,Enum.TextXAlignment.Center,4,28)
msBig.Size=UDim2.new(0.38,0,1,0)
local msDiv=F(msCard,C.line,4) msDiv.Size=UDim2.new(0,1,0.7,0) msDiv.Position=UDim2.new(0.38,0,0.15,0)
local msSubL=T(msCard,"Marshmallow dibuat",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
msSubL.Size=UDim2.new(0.62,-12,1,0) msSubL.Position=UDim2.new(0.38,10,0,0) msSubL.TextWrapped=true

line(pg1,282)
local startW,startB=actionBtn(pg1,290,"▶  Start Auto Masak",C.blueD,C.txt)
local stopW, stopB =actionBtn(pg1,290,"■  Stop Auto Masak", C.red,  C.txt)
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

-- ── PAGE 2: JUAL ──────────────────────────────────────
local pg2=pages[2]
secHdr(pg2,8,"AUTO JUAL MARSHMALLOW")
local jualInfo=F(pg2,C.bg,3) jualInfo.Size=UDim2.new(1,-24,0,34) jualInfo.Position=UDim2.new(0,12,0,26) corner(jualInfo,8) stroke(jualInfo,C.line,1)
local jIT=T(jualInfo,"Dekati NPC Jual lalu tekan tombol di bawah.",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
jIT.Size=UDim2.new(1,-10,1,0) jIT.Position=UDim2.new(0,8,0,0) jIT.TextWrapped=true
line(pg2,66) secHdr(pg2,72,"STATISTIK")
local vSold =statRow(pg2, 90,"💰","Total Terjual",  Color3.fromRGB(52,210,110))
local vMSInv=statRow(pg2,130,"🍬","MS di Inventory",Color3.fromRGB(100,180,255))
line(pg2,170)
local jualStatBox=F(pg2,C.bg,3) jualStatBox.Size=UDim2.new(1,-24,0,24) jualStatBox.Position=UDim2.new(0,12,0,178) corner(jualStatBox,6) stroke(jualStatBox,C.line,1)
local jualStatL=T(jualStatBox,"",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,10)
jualStatL.Size=UDim2.new(1,-8,1,0) jualStatL.Position=UDim2.new(0,4,0,0)
line(pg2,208)
local jualBtnW,jualBtnB=actionBtn(pg2,216,"💰  Jual Semua Marshmallow",C.greenD,C.txt)
local jualBusy=false
local function setJualStatus(msg,col) jualStatL.Text=msg jualStatL.TextColor3=col or C.txtM setStatus(msg,col) end
jualBtnB.MouseButton1Click:Connect(function()
	if jualBusy then return end jualBusy=true
	jualBtnW.BackgroundColor3=Color3.fromRGB(18,88,42) jualBtnB.Text="Menjual..."
	task.spawn(function()
		doAutoSell(setJualStatus)
		jualBtnW.BackgroundColor3=C.greenD jualBtnB.Text="💰  Jual Semua Marshmallow" jualBusy=false
	end)
end)
hoverBtn(jualBtnW,jualBtnB,C.greenD,Color3.fromRGB(40,170,85))

-- ── PAGE 3: BELI (slider qty) ─────────────────────────
local pg3=pages[3]

-- Pakai ScrollingFrame supaya konten tidak terpotong
local pg3Scroll=Instance.new("ScrollingFrame")
pg3Scroll.Size=UDim2.new(1,0,1,0)
pg3Scroll.CanvasSize=UDim2.new(0,0,0,400)
pg3Scroll.BackgroundTransparency=1
pg3Scroll.BorderSizePixel=0
pg3Scroll.ScrollBarThickness=3
pg3Scroll.ScrollBarImageColor3=C.line
pg3Scroll.Parent=pg3

local function F3(bg,zi) return F(pg3Scroll,bg,zi) end

secHdr(pg3Scroll,8,"AUTO BELI BAHAN")
local beliInfo=F(pg3Scroll,C.bg,3) beliInfo.Size=UDim2.new(1,-24,0,28) beliInfo.Position=UDim2.new(0,12,0,26) corner(beliInfo,8) stroke(beliInfo,C.line,1)
local bIT=T(beliInfo,"Slider = jumlah beli per item. Tekan Start untuk beli semua.",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
bIT.Size=UDim2.new(1,-10,1,0) bIT.Position=UDim2.new(0,8,0,0) bIT.TextWrapped=true

line(pg3Scroll,60) secHdr(pg3Scroll,66,"JUMLAH BELI")

local getQtyAll = sliderRow(pg3Scroll,82,"Jumlah semua bahan",1,50,5,"x")

local itemData={
	{icon="🟡",name="Gelatin",        price="$70"},
	{icon="🧂",name="Sugar Block Bag", price="$100"},
	{icon="💧",name="Water",          price="$20"},
}
for i,item in ipairs(itemData) do
	local ry=136+(i-1)*36
	local row=F(pg3Scroll,C.card,3) row.Size=UDim2.new(1,-24,0,30) row.Position=UDim2.new(0,12,0,ry) corner(row,8)
	local ic=T(row,item.icon,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,13) ic.Size=UDim2.new(0,24,1,0) ic.Position=UDim2.new(0,4,0,0)
	local nm=T(row,item.name,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10) nm.Size=UDim2.new(0.55,-28,1,0) nm.Position=UDim2.new(0,30,0,0)
	local pr=T(row,item.price,C.txtD,Enum.Font.Gotham,Enum.TextXAlignment.Right,4,10) pr.Size=UDim2.new(0.4,-10,1,0) pr.Position=UDim2.new(0.6,0,0,0)
end

line(pg3Scroll,244)
local vBuy2=statRow(pg3Scroll,252,"🛒","Total Dibeli",Color3.fromRGB(100,180,255))
line(pg3Scroll,292)
local beliStatBox=F(pg3Scroll,C.bg,3) beliStatBox.Size=UDim2.new(1,-24,0,24) beliStatBox.Position=UDim2.new(0,12,0,300) corner(beliStatBox,6) stroke(beliStatBox,C.line,1)
local beliStatL=T(beliStatBox,"Atur jumlah lalu tekan Start",C.txtM,Enum.Font.Gotham,Enum.TextXAlignment.Center,4,10)
beliStatL.Size=UDim2.new(1,-8,1,0) beliStatL.Position=UDim2.new(0,4,0,0)
line(pg3Scroll,330)
local beliBtnW,beliBtnB=actionBtn(pg3Scroll,338,"🛒  Start Auto Beli",C.blueD,C.txt)
local function setBeliStatus(msg,col) beliStatL.Text=msg beliStatL.TextColor3=col or C.txtM setStatus(msg,col) end
beliBtnB.MouseButton1Click:Connect(function()
	if buyBusy then return end buyBusy=true
	local qty=getQtyAll()
	for i=1,3 do buyQty[i]=qty end
	beliBtnW.BackgroundColor3=Color3.fromRGB(30,50,140) beliBtnB.Text="Membeli..."
	task.spawn(function()
		doAutoBuy(setBeliStatus)
		beliBtnW.BackgroundColor3=C.blueD beliBtnB.Text="🛒  Start Auto Beli" buyBusy=false
	end)
end)
hoverBtn(beliBtnW,beliBtnB,C.blueD,Color3.fromRGB(62,105,220))

-- ── PAGE 4: STATS ─────────────────────────────────────
local pg4=pages[4]
secHdr(pg4,8,"STATISTIK SESSION")
local sData={
	{icon="🍬",lbl="Total MS Dibuat",  col=Color3.fromRGB(100,190,255)},
	{icon="🔹",lbl="Small MS",         col=Color3.fromRGB(130,205,255)},
	{icon="🔷",lbl="Medium MS",        col=Color3.fromRGB(80,160,255)},
	{icon="🔵",lbl="Large MS",         col=Color3.fromRGB(55,115,220)},
	{icon="💰",lbl="Total MS Terjual", col=Color3.fromRGB(52,210,110)},
	{icon="🛒",lbl="Total Beli Bahan", col=Color3.fromRGB(100,180,255)},
	{icon="📡",lbl="Ping",             col=Color3.fromRGB(50,210,230)},
	{icon="🖥",lbl="FPS",              col=Color3.fromRGB(148,80,255)},
}
local sVals={}
for i,s in ipairs(sData) do
	local y=26+(i-1)*36
	local v=statRow(pg4,y,s.icon,s.lbl,s.col) sVals[i]=v
	if i<#sData then line(pg4,y+34) end
end

-- ============================================================
-- ESP PAGE
-- ============================================================
local espPage=menuPages[2]

local function espTogRow(parent, y, lbl, cfgKey, col)
	local row=F(espPage,C.card,3) row.Size=UDim2.new(1,-24,0,34) row.Position=UDim2.new(0,12,0,y) corner(row,8)
	-- Accent bar
	local bar=F(row,col or C.blue,4) bar.Size=UDim2.new(0,3,0.6,0) bar.Position=UDim2.new(0,0,0.2,0) corner(bar,2)
	local lbl2=T(row,lbl,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11)
	lbl2.Size=UDim2.new(0.72,0,1,0) lbl2.Position=UDim2.new(0,14,0,0)
	local on=ESP_CFG[cfgKey]
	local knobBg=F(row,on and C.blue or C.line,4) knobBg.Size=UDim2.new(0,34,0,18) knobBg.Position=UDim2.new(1,-44,0.5,-9) corner(knobBg,9)
	local knob=F(knobBg,C.txt,5) knob.Size=UDim2.new(0,14,0,14) knob.Position=on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7) corner(knob,7)
	local btn=B(row,"",C.txt,Enum.Font.Gotham,5) btn.Size=UDim2.new(1,0,1,0)
	btn.MouseButton1Click:Connect(function()
		ESP_CFG[cfgKey]=not ESP_CFG[cfgKey]
		local v=ESP_CFG[cfgKey]
		TweenService:Create(knobBg,TweenInfo.new(0.15),{BackgroundColor3=v and C.blue or C.line}):Play()
		TweenService:Create(knob,TweenInfo.new(0.15),{Position=v and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
	end)
end

secHdr(espPage,8,"ESP")
-- Master toggle
local espRow=F(espPage,C.card,3) espRow.Size=UDim2.new(1,-24,0,36) espRow.Position=UDim2.new(0,12,0,26) corner(espRow,8) stroke(espRow,C.blue,1.5)
local espLbl=T(espRow,"Enable ESP",C.txt,Enum.Font.GothamBold,Enum.TextXAlignment.Left,4,12)
espLbl.Size=UDim2.new(0.65,0,1,0) espLbl.Position=UDim2.new(0,12,0,0)
local espKnobBg=F(espRow,C.line,4) espKnobBg.Size=UDim2.new(0,34,0,18) espKnobBg.Position=UDim2.new(1,-44,0.5,-9) corner(espKnobBg,9)
local espKnob=F(espKnobBg,C.txt,5) espKnob.Size=UDim2.new(0,14,0,14) espKnob.Position=UDim2.new(0,2,0.5,-7) corner(espKnob,7)
local espMasterBtn=B(espRow,"",C.txt,Enum.Font.Gotham,5) espMasterBtn.Size=UDim2.new(1,0,1,0)
espMasterBtn.MouseButton1Click:Connect(function()
	espEnabled=not espEnabled
	TweenService:Create(espKnobBg,TweenInfo.new(0.15),{BackgroundColor3=espEnabled and C.blue or C.line}):Play()
	TweenService:Create(espKnob,TweenInfo.new(0.15),{Position=espEnabled and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
	if not espEnabled then for _,d in pairs(espCache) do hideESP(d) end end
end)

line(espPage,68) secHdr(espPage,74,"FITUR ESP")
espTogRow(espPage,  92,"👤  Username",   "username", Color3.fromRGB(255,255,255))
espTogRow(espPage, 132,"🦴  Skeleton",   "skeleton",  ESP_COL.skel)
espTogRow(espPage, 172,"❤️  Health Bar", "healthBar", C.green)
espTogRow(espPage, 212,"📦  Bounding Box","box",      ESP_COL.box)
espTogRow(espPage, 252,"🎨  Fill Box",   "fillBox",   Color3.fromRGB(255,100,100))
espTogRow(espPage, 292,"📏  Distance",   "distance",  ESP_COL.dist)
espTogRow(espPage, 332,"⚫  Head Dot",   "headDot",   ESP_COL.dot)
espTogRow(espPage, 372,"📍  Tracer",     "tracer",    ESP_COL.tracer)

-- ============================================================
-- TELEPORT PAGE
-- ============================================================
local teleportPage=menuPages[3]
secHdr(teleportPage,8,"TELEPORT LOKASI")

local warnCard=F(teleportPage,Color3.fromRGB(14,24,14),3) warnCard.Size=UDim2.new(1,-24,0,28) warnCard.Position=UDim2.new(0,12,0,26) corner(warnCard,8) stroke(warnCard,C.green,1)
local warnL=T(warnCard,"⚡ Naiki motor dulu — motor yang akan dipindahkan",C.green,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,9)
warnL.Size=UDim2.new(1,-10,1,0) warnL.Position=UDim2.new(0,8,0,0)

line(teleportPage,60) secHdr(teleportPage,66,"BLINK TP")
local blinkRow=F(teleportPage,C.card,3) blinkRow.Size=UDim2.new(1,-24,0,34) blinkRow.Position=UDim2.new(0,12,0,84) corner(blinkRow,8)
local blinkLbl=T(blinkRow,"Blink TP [T] = maju 6 studs",C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,10)
blinkLbl.Size=UDim2.new(0.72,0,1,0) blinkLbl.Position=UDim2.new(0,10,0,0)
local blinkEnabled=false
local blinkKnobBg=F(blinkRow,C.line,4) blinkKnobBg.Size=UDim2.new(0,34,0,18) blinkKnobBg.Position=UDim2.new(1,-44,0.5,-9) corner(blinkKnobBg,9)
local blinkKnob=F(blinkKnobBg,C.txt,5) blinkKnob.Size=UDim2.new(0,14,0,14) blinkKnob.Position=UDim2.new(0,2,0.5,-7) corner(blinkKnob,7)
local blinkBtn=B(blinkRow,"",C.txt,Enum.Font.Gotham,5) blinkBtn.Size=UDim2.new(1,0,1,0)
blinkBtn.MouseButton1Click:Connect(function()
	blinkEnabled=not blinkEnabled
	TweenService:Create(blinkKnobBg,TweenInfo.new(0.15),{BackgroundColor3=blinkEnabled and C.blue or C.line}):Play()
	TweenService:Create(blinkKnob,TweenInfo.new(0.15),{Position=blinkEnabled and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
end)

UIS.InputBegan:Connect(function(i,gp)
	if gp then return end
	if i.KeyCode==Enum.KeyCode.T and blinkEnabled then
		local char=player.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame=root.CFrame+root.CFrame.LookVector*6 end
	end
end)

-- Noclip toggle
local noclipOn=false
RunService.Stepped:Connect(function()
	if not noclipOn then return end
	local char=player.Character
	if not char then return end
	for _,p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide=false end
	end
end)

local noclipRow=F(teleportPage,C.card,3) noclipRow.Size=UDim2.new(1,-24,0,34) noclipRow.Position=UDim2.new(0,12,0,124) corner(noclipRow,8)
local noclipLbl=T(noclipRow,"🚶 Noclip",C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11)
noclipLbl.Size=UDim2.new(0.7,0,1,0) noclipLbl.Position=UDim2.new(0,10,0,0)
local noclipKnobBg=F(noclipRow,C.line,4) noclipKnobBg.Size=UDim2.new(0,34,0,18) noclipKnobBg.Position=UDim2.new(1,-44,0.5,-9) corner(noclipKnobBg,9)
local noclipKnob=F(noclipKnobBg,C.txt,5) noclipKnob.Size=UDim2.new(0,14,0,14) noclipKnob.Position=UDim2.new(0,2,0.5,-7) corner(noclipKnob,7)
local noclipBtn=B(noclipRow,"",C.txt,Enum.Font.Gotham,5) noclipBtn.Size=UDim2.new(1,0,1,0)
noclipBtn.MouseButton1Click:Connect(function()
	noclipOn=not noclipOn
	TweenService:Create(noclipKnobBg,TweenInfo.new(0.15),{BackgroundColor3=noclipOn and C.purple or C.line}):Play()
	TweenService:Create(noclipKnob,TweenInfo.new(0.15),{Position=noclipOn and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
	-- Restore collision saat dimatikan
	if not noclipOn then
		local char=player.Character
		if char then
			for _,p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end
			end
		end
	end
end)

line(teleportPage,164) secHdr(teleportPage,170,"LOKASI")

local LOCATIONS={
	{name="🏪 Dealer NPC",     pos=Vector3.new( 770.992,  3.71,  433.75)},
	{name="🍬 NPC Marshmallow", pos=Vector3.new( 511.035,  3.414, 599.698)},
	{name="🏠 Apart 1",        pos=Vector3.new(1137.992,  9.932, 449.753)},
	{name="🏠 Apart 2",        pos=Vector3.new(1139.174,  9.932, 420.556)},
	{name="🏠 Apart 3",        pos=Vector3.new( 984.856,  9.932, 247.280)},
	{name="🏠 Apart 4",        pos=Vector3.new( 988.311,  9.932, 221.664)},
	{name="🏠 Apart 5",        pos=Vector3.new( 923.954,  9.932,  42.202)},
	{name="🏠 Apart 6",        pos=Vector3.new( 895.721,  9.932,  41.928)},
	{name="🎰 Casino",         pos=Vector3.new(1166.33,   3.36,  -29.77)},
}

local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,0,1,-226) scroll.Position=UDim2.new(0,0,0,226)
scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=3
scroll.Parent=teleportPage

local lo=Instance.new("UIListLayout",scroll) lo.Padding=UDim.new(0,5) lo.SortOrder=Enum.SortOrder.LayoutOrder
local loPad=Instance.new("UIPadding",scroll) loPad.PaddingLeft=UDim.new(0,12) loPad.PaddingRight=UDim.new(0,12) loPad.PaddingTop=UDim.new(0,4)

for i,loc in ipairs(LOCATIONS) do
	local row=F(scroll,C.card,3) row.Size=UDim2.new(1,0,0,36) corner(row,8) stroke(row,C.line,1) row.LayoutOrder=i
	local nm=T(row,loc.name,C.txt,Enum.Font.Gotham,Enum.TextXAlignment.Left,4,11) nm.Size=UDim2.new(0.65,0,1,0) nm.Position=UDim2.new(0,10,0,0)
	local tpW=F(row,C.blueD,4) tpW.Size=UDim2.new(0,70,0,24) tpW.Position=UDim2.new(1,-80,0.5,-12) corner(tpW,6)
	local tpB=B(tpW,"Teleport",C.txt,Enum.Font.GothamBold,5) tpB.Size=UDim2.new(1,0,1,0) tpB.TextSize=10 tpB.TextScaled=false
	local tp,ln=loc.pos,loc.name
	tpB.MouseButton1Click:Connect(function() stepTeleport(tp,ln) end)
	hoverBtn(tpW,tpB,C.blueD,Color3.fromRGB(62,110,230))
end
lo:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize=UDim2.new(0,0,0,lo.AbsoluteContentSize.Y+8)
end)

-- ============================================================
-- DRAG (titlebar)
-- ============================================================
local dragging,dragStart,startPos
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 then
		dragging=true dragStart=i.Position startPos=panel.Position
		i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
		local d=i.Position-dragStart
		panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)

-- ============================================================
-- FPS + PING + ANTI-DISCONNECT
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

	vW.Text=tostring(countItem(CFG.ITEM_WATER))
	vSu.Text=tostring(countItem(CFG.ITEM_SUGAR))
	vGe.Text=tostring(countItem(CFG.ITEM_GEL))
	msBig.Text=tostring(totalMS())
	vSold.Text=tostring(totalSold) vMSInv.Text=tostring(countAllMS())
	vBuy2.Text=tostring(totalBuy)
	sVals[1].Text=tostring(totalMS()) sVals[2].Text=tostring(stats.small)
	sVals[3].Text=tostring(stats.medium) sVals[4].Text=tostring(stats.large)
	sVals[5].Text=tostring(totalSold) sVals[6].Text=tostring(totalBuy)

	pcall(function()
		local ps=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
		ping=tonumber(ps:match("%d+")) or ping
	end)
	sVals[7].Text=tostring(ping).." ms"
	sVals[8].Text=tostring(fps).." fps"

	local fc=fps>=55 and Color3.fromRGB(50,230,110) or fps>=30 and Color3.fromRGB(255,200,50) or Color3.fromRGB(220,60,60)
	local pc=ping<=80 and Color3.fromRGB(50,230,110) or ping<=150 and Color3.fromRGB(255,200,50) or Color3.fromRGB(220,60,60)
	fpsNumL.Text=tostring(fps).."fps" fpsNumL.TextColor3=fc
	pingNumL.Text=tostring(ping).."ms" pingNumL.TextColor3=pc

	if now-lastAntiAfk>25 then
		lastAntiAfk=now
		pcall(function()
			VIM:SendMouseButtonEvent(0,0,0,true,game,0) task.wait(0.05)
			VIM:SendMouseButtonEvent(0,0,0,false,game,0)
		end)
	end
end)


player.CharacterAdded:Connect(function(char)
	character=char hrp=char:WaitForChild("HumanoidRootPart")
end)

print("[PatStore v8] Loaded! fireproximityprompt — no E needed")
