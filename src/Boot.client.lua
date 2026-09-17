-- Standalone ReplicatedFirst UI. NO require(), NO DataStore, NO wait for a server remote.
-- The screen remains visible on failure. Handoff only after a rendered game-state snapshot.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("FrontierBoot")
if existing then existing:Destroy() end
local screen = Instance.new("ScreenGui")
screen.Name = "FrontierBoot"; screen.ResetOnSpawn = false; screen.IgnoreGuiInset = true
screen.DisplayOrder = 100; screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local bg = Instance.new("Frame"); bg.Name = "Backdrop"; bg.Size = UDim2.fromScale(1,1)
bg.BackgroundColor3 = Color3.fromRGB(103,190,181); bg.BorderSizePixel = 0; bg.Active = true; bg.Parent = screen
screen.Parent = playerGui -- Paint BEFORE anything dependent on server initialization.
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
local root = Instance.new("Frame"); root.Name = "BootContent"; root.Size = UDim2.fromOffset(1100,660)
root.AnchorPoint = Vector2.new(0.5,0.5); root.Position = UDim2.fromScale(0.5,0.5); root.BackgroundTransparency = 1; root.Parent = bg
local scale = Instance.new("UIScale"); scale.Parent = root
local mint = Color3.fromRGB(135,233,192)
local white = Color3.fromRGB(23,29,49)
local muted = Color3.fromRGB(83,93,89)
local amber = Color3.fromRGB(242,191,112)
local function box(parent,name,x,y,w,h,col,rounding)
    local f = Instance.new("Frame"); f.Name = name; f.Position = UDim2.fromOffset(x,y); f.Size = UDim2.fromOffset(w,h)
    f.BackgroundColor3 = col; f.BorderSizePixel = 0; f.Parent = parent
    if rounding then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,rounding); c.Parent = f end
    return f
end
local function text(parent,name,content,x,y,w,h,size,col)
    local t = Instance.new("TextLabel"); t.Name = name; t.BackgroundTransparency = 1; t.Position = UDim2.fromOffset(x,y); t.Size = UDim2.fromOffset(w,h)
    t.Text = content; t.TextSize = size; t.TextColor3 = col or white; t.Font = Enum.Font.Gotham
    t.TextWrapped = true; t.TextXAlignment = Enum.TextXAlignment.Left; t.TextYAlignment = Enum.TextYAlignment.Center; t.Parent = parent
    return t
end
local function border(object,col)
    local stroke = Instance.new("UIStroke"); stroke.Color = col; stroke.Transparency = 0.65; stroke.Parent = object
end
box(root,"Accent",36,37,29,3,mint)
text(root,"Kicker","DUSTBOUND / AUTOMATED OUTPOST",79,26,610,24,13,mint)
text(root,"Version","BUILD 0.7.0  /  LOCAL FIRST",777,26,300,24,11,muted)
text(root,"Title","荒星前哨",36,95,510,77,48,white).Font = Enum.Font.GothamBold
text(root,"Tagline","前哨自动防御，机器人波间采矿。\n把每一份资源用在刀刃上。",39,182,480,77,23,muted)
local labels = {{"01","机器人采矿","不需要驾驶或瞄准"},{"02","资源投入","基地 / 采矿 / 武器"},{"03","补给选择","维修 / 采矿 / 弹药"}}
for i,d in ipairs(labels) do
    local y = 302+(i-1)*63
    local card = box(root,"Guide"..i,39,y,435,52,Color3.fromRGB(247,241,219),9)
    text(card,"Number",d[1],13,4,39,43,13,mint)
    text(card,"Name",d[2],60,4,138,43,15,white)
    text(card,"Keys",d[3],200,4,226,43,12,muted)
end
-- Built-in 2D sector illustration, independent of Workspace and external assets.
local map = box(root,"SectorIllustration",543,94,515,379,Color3.fromRGB(247,241,219),15); border(map,mint)
for i = 1,10 do box(map,"GridX"..i,i*46,24,1,328,Color3.fromRGB(226,213,180)) end
for i = 1,7 do box(map,"GridY"..i,22,i*46,471,1,Color3.fromRGB(226,213,180)) end
text(map,"MapHeader","SECTOR 01    /    RESOURCE SURVEY",22,12,454,26,10,muted)
for i,d in ipairs({{85,106},{381,92},{406,255}}) do
    local zone = box(map,"Ore"..i,d[1]-20,d[2]-20,62,62,Color3.fromRGB(34,79,71),31)
    border(zone,mint)
    local ore = box(zone,"Crystal",24,22,16,21,mint,3); ore.Rotation = 28
end
local path = box(map,"Route",147,246,222,2,Color3.fromRGB(108,155,131)); path.Rotation = -29
local base = box(map,"Crawler",199,137,109,136,Color3.fromRGB(43,62,66),16)
box(base,"LeftTrack",-10,7,21,124,Color3.fromRGB(9,22,27),6)
box(base,"RightTrack",98,7,21,124,Color3.fromRGB(9,22,27),6)
for i = 1,7 do
    box(base,"LeftTread"..i,-8,i*15,17,5,Color3.fromRGB(73,97,96),1)
    box(base,"RightTread"..i,100,i*15,17,5,Color3.fromRGB(73,97,96),1)
end
box(base,"Deck",14,10,80,111,Color3.fromRGB(84,119,111),10)
box(base,"Cabin",24,18,60,33,Color3.fromRGB(30,56,65),7)
box(base,"Windshield",31,24,46,14,mint,4)
box(base,"Turret",28,68,48,39,Color3.fromRGB(162,184,161),15)
box(base,"Barrel",46,51,11,39,amber,3)
box(base,"Drill",38,119,32,23,amber,5)
box(map,"Extraction",104,292,24,24,amber,12)
text(map,"ExtractionLabel","撤离信标",140,289,165,29,12,amber)
text(map,"MapFooter","AUTO FIRE   /   BUILD YOUR WAY OUT",22,343,472,24,10,muted)
local status = text(root,"Status","正在启动二维前哨系统…",39,508,960,34,20,white)
local detail = text(root,"Detail","本地试玩不需要发布，也不需要开启 API。",40,550,991,37,13,muted)
local progressBack = box(root,"ProgressTrack",40,600,1018,4,Color3.fromRGB(35,56,62),2)
local progress = box(progressBack,"Progress",0,0,80,4,mint,2)
local diagButton = Instance.new("TextButton"); diagButton.Name = "DiagnosticsButton"; diagButton.Text = "查看启动诊断"
diagButton.Size = UDim2.fromOffset(140,31); diagButton.Position = UDim2.fromOffset(913,619)
diagButton.BackgroundTransparency = 1; diagButton.TextColor3 = mint; diagButton.TextSize = 12; diagButton.Font = Enum.Font.Gotham; diagButton.Parent = root
text(root,"Footer","F5 = Play / 游玩    ·    Shift + F5 = 停止    ·    本地会话模式",40,619,819,29,11,muted)
local diagnostics = box(root,"Diagnostics",39,86,1019,397,Color3.fromRGB(247,241,219),13); diagnostics.Visible = false; diagnostics.ZIndex = 10
text(diagnostics,"DiagnosticsHeading","启动诊断 / 可选中文本复制",20,14,960,30,18,mint)
local output = Instance.new("TextBox"); output.Name = "Output"; output.Position = UDim2.fromOffset(20,59); output.Size = UDim2.fromOffset(979,316)
output.BackgroundTransparency = 1; output.TextColor3 = white; output.TextSize = 14; output.Font = Enum.Font.Code
output.TextWrapped = true; output.MultiLine = true; output.ClearTextOnFocus = false; output.TextEditable = false
output.TextXAlignment = Enum.TextXAlignment.Left; output.TextYAlignment = Enum.TextYAlignment.Top; output.Parent = diagnostics
local forceVisible = false
diagButton.Activated:Connect(function() diagnostics.Visible = not diagnostics.Visible; forceVisible = diagnostics.Visible end)
local started = os.clock(); local interval = 0; local polling=nil;local watchedNetwork=nil
local function value(parent,name,fallback)
    local child = parent and parent:FindFirstChild(name)
    return child and child.Value or fallback
end
local function refresh()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.min(camera.ViewportSize.X/1100,camera.ViewportSize.Y/660) end
    local age = os.clock()-started
    local network = RS:FindFirstChild("FrontierNetwork")
    if network and network~=watchedNetwork then
        watchedNetwork=network
        for _,name in ipairs({"BootStatus","BootError"}) do
            local field=network:FindFirstChild(name)
            if field then field:GetPropertyChangedSignal("Value"):Connect(refresh) end
        end
    end
    local server = value(network,"BootStatus","NO_NETWORK")
    local serverError = value(network,"BootError","")
    local client = playerGui:GetAttribute("FrontierClientPhase") or "WAITING_FOR_CLIENT"
    local clientError = playerGui:GetAttribute("FrontierClientError") or ""
    local ready = playerGui:GetAttribute("FrontierGameReady") == true
    local failed = server == "ERROR" or client == "ERROR" or clientError ~= ""
    screen.Enabled = not ready or failed or forceVisible
    if ready and not failed and not forceVisible and polling then polling:Disconnect();polling=nil end
    output.Text = "Frontier 0.7.0\nClient: "..client.."\nServer: "..server.."\nElapsed: "..math.floor(age).."s\n\n"..
        (clientError ~= "" and ("CLIENT ERROR\n"..clientError.."\n\n") or "")..
        (serverError ~= "" and ("SERVER ERROR\n"..serverError.."\n\n") or "")..
        "如果停在这里，请截图本面板并附 Studio 输出窗口的第一条红色报错。\n本地试玩无需发布，无需开启 API。"
    if failed then
        status.Text = "启动遇到错误，诊断已保留。"; status.TextColor3 = amber
        detail.Text = (clientError ~= "" and clientError or serverError):sub(1,150)
        diagnostics.Visible = true
    elseif age > 15 and not ready then
        status.Text = "启动超时：尚未收到可玩的战局。"; status.TextColor3 = amber
        detail.Text = "点击右下角“查看启动诊断”。请确认使用的是 0.7.0 完整工程和 Play / F5。"
    elseif ready then
        status.Text = "二维前哨系统已就绪"; progress.Size = UDim2.fromScale(1,1)
    else
        status.Text = server == "READY" and "服务端就绪，正在连接游戏界面…" or "正在启动二维前哨系统…"
        detail.Text = playerGui:GetAttribute("FrontierLoadDetail") or ("本地试玩无需发布 / "..client)
        progress.Size = UDim2.new(math.max(0,math.min(.98,playerGui:GetAttribute("FrontierLoadProgress") or 0)),0,1,0)
    end
end
-- Report runtime LocalScript errors as visible UI, where permitted by the engine.
pcall(function()
    game:GetService("ScriptContext").Error:Connect(function(message,stack,source)
        if source and source.Name == "FrontierClient" then
            playerGui:SetAttribute("FrontierClientError", tostring(message).."\n"..tostring(stack))
            playerGui:SetAttribute("FrontierClientPhase", "ERROR")
            refresh()
        end
    end)
end)
polling=RunService.Heartbeat:Connect(function(dt)
    interval = interval+dt
    if interval >= 0.2 then interval = 0; refresh() end
end)
for _,name in ipairs({"FrontierGameReady","FrontierClientError","FrontierClientPhase"}) do
    playerGui:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
