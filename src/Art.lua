-- Sprite rendering: one shared embedded EditableImage; optional uploaded atlas; safe GUI-raster fallback.
local Art={mode="loading",detail=""}
local shared=script.Parent
local data=require(shared:WaitForChild("ArtData",10))
local C=require(shared:WaitForChild("Config",10))
local imageObject=nil
function Art.init()
    if Art.mode~="loading" then return end
    if type(C.AtlasImageId)=="number" and C.AtlasImageId>0 then
        Art.mode="asset";Art.detail="已配置上传图集";return
    end
    local ok,err=pcall(function()
        imageObject=game:GetService("AssetService"):CreateEditableImage({Size=Vector2.new(data.size,data.size)})
        assert(imageObject,"EditableImage memory budget unavailable")
        local palette={}
        for i=1,#data.palette,8 do
            palette[(i-1)/8]=string.char(tonumber(data.palette:sub(i,i+1),16),tonumber(data.palette:sub(i+2,i+3),16),tonumber(data.palette:sub(i+4,i+5),16),tonumber(data.palette:sub(i+6,i+7),16))
        end
        local chunks={};local length=0
        for i=1,#data.rle,6 do
            local n=tonumber(data.rle:sub(i,i+3),16);local id=tonumber(data.rle:sub(i+4,i+5),16)
            chunks[#chunks+1]=string.rep(palette[id],n);length=length+n
        end
        assert(length==data.size*data.size,"Embedded atlas length invalid")
        imageObject:WritePixelsBuffer(Vector2.zero,Vector2.new(data.size,data.size),buffer.fromstring(table.concat(chunks)))
        Art.content=Content.fromObject(imageObject)
    end)
    if ok then Art.mode="embedded";Art.detail="内嵌高清图集"
    else
        if imageObject then pcall(function() imageObject:Destroy() end);imageObject=nil end
        Art.mode="fallback";Art.detail="兼容绘制 / 图像 API 不可用"
        warn("[DUSTBOUND ART] "..tostring(err).."; compatible GUI artwork is active")
    end
end
function Art.sprite(parent,key,x,y,w,h)
    local container=Instance.new("Frame");container.Name="Sprite_"..key;container.Position=UDim2.fromOffset(x,y);container.Size=UDim2.fromOffset(w,h)
    container.BackgroundTransparency=1;container.BorderSizePixel=0;container.Parent=parent
    if Art.mode=="embedded" or Art.mode=="asset" then
        local r=data.sprites[key];assert(r,"Unknown sprite "..key)
        local view=Instance.new("ImageLabel");view.Name="Artwork";view.BackgroundTransparency=1;view.Size=UDim2.fromScale(1,1)
        view.ImageRectOffset=Vector2.new(r.x,r.y);view.ImageRectSize=Vector2.new(r.w,r.h)
        view.ScaleType=Enum.ScaleType.Stretch
        if Art.mode=="embedded" then view.ImageContent=Art.content else view.Image="rbxassetid://"..C.AtlasImageId end
        view.Parent=container
    else
        local f=data.fallback[key];assert(f,"Unknown fallback sprite "..key)
        for _,r in ipairs(f.rects) do
            local p=Instance.new("Frame");p.BorderSizePixel=0
            p.Position=UDim2.fromScale(r[1]/f.w,r[2]/f.h);p.Size=UDim2.fromScale(r[3]/f.w,r[4]/f.h)
            local color=f.colors[r[5]+1];p.BackgroundColor3=Color3.fromRGB(color[1],color[2],color[3]);p.Parent=container
        end
    end
    return container
end
function Art.close()
    if imageObject then imageObject:Destroy();imageObject=nil end
end
return Art
