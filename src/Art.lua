-- Sprite rendering: one shared embedded EditableImage; optional uploaded atlas; safe GUI-raster fallback.
local Art={mode="loading",detail=""}
local shared=script.Parent
local data=require(shared:WaitForChild("ArtData",10))
local C=require(shared:WaitForChild("Config",10))
local imageObject=nil
-- Decode at most 32 rows into a temporary buffer. Do not materialize a 119k-entry
-- full-atlas string table + concatenated 4 MiB string + buffer on the same frame.
-- write/checkpoint are injectable so exact pixels and bounded batches are testable.
function Art.decode(source,write,checkpoint)
    local palette={}
    for i=1,#source.palette,8 do
        palette[(i-1)/8]=string.char(tonumber(source.palette:sub(i,i+1),16),tonumber(source.palette:sub(i+2,i+3),16),tonumber(source.palette:sub(i+4,i+5),16),tonumber(source.palette:sub(i+6,i+7),16))
    end
    local pos,remaining,pixel,total=1,0,nil,0
    local clock=os.clock();local operations=0
    for y=0,source.size-1,32 do
        local rows=math.min(32,source.size-y);local count=source.size*rows;local filled=0;local chunks={}
        while filled<count do
            if remaining==0 then
                assert(pos+5<=#source.rle,"Embedded atlas truncated")
                remaining=tonumber(source.rle:sub(pos,pos+3),16)
                pixel=palette[tonumber(source.rle:sub(pos+4,pos+5),16)]
                assert(remaining and remaining>0 and pixel,"Embedded atlas invalid run")
                pos=pos+6
            end
            local take=math.min(remaining,count-filled)
            chunks[#chunks+1]=string.rep(pixel,take)
            filled=filled+take;remaining=remaining-take;operations=operations+1
            if checkpoint and operations%512==0 and os.clock()-clock>=.003 then
                checkpoint((total+filled)/(source.size*source.size));clock=os.clock()
            end
        end
        local bytes=table.concat(chunks)
        write(y,rows,bytes);total=total+filled
        if checkpoint then checkpoint(total/(source.size*source.size));clock=os.clock() end
    end
    assert(remaining==0 and pos==#source.rle+1,"Embedded atlas length invalid")
    return total
end
function Art.init(onProgress,yieldFrame)
    if Art.mode~="loading" then return end
    Art.mode="initializing";local started=os.clock()
    if type(C.AtlasImageId)=="number" and C.AtlasImageId>0 then
        Art.mode="asset";Art.detail="已配置上传图集";Art.loadSeconds=os.clock()-started
        if onProgress then onProgress(1) end
        return
    end
    local ok,err=pcall(function()
        imageObject=game:GetService("AssetService"):CreateEditableImage({Size=Vector2.new(data.size,data.size)})
        assert(imageObject,"EditableImage memory budget unavailable")
        Art.decode(data,function(y,rows,bytes)
            imageObject:WritePixelsBuffer(Vector2.new(0,y),Vector2.new(data.size,rows),buffer.fromstring(bytes))
        end,function(fraction)
            if onProgress then onProgress(fraction) end
            if yieldFrame then yieldFrame() end
        end)
        Art.content=Content.fromObject(imageObject)
    end)
    Art.loadSeconds=os.clock()-started
    if ok then Art.mode="embedded";Art.detail="内嵌高清图集 / 分帧解码"
    else
        if imageObject then pcall(function() imageObject:Destroy() end);imageObject=nil end
        Art.mode="fallback";Art.detail="兼容绘制 / 图像 API 不可用（GUI 实例较多）"
        warn("[DUSTBOUND ART] "..tostring(err).."; compatible GUI artwork is active")
    end
    if onProgress then onProgress(1) end
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
        for index,r in ipairs(f.rects) do
            local p=Instance.new("Frame");p.BorderSizePixel=0
            p.Position=UDim2.fromScale(r[1]/f.w,r[2]/f.h);p.Size=UDim2.fromScale(r[3]/f.w,r[4]/f.h)
            local color=f.colors[r[5]+1];p.BackgroundColor3=Color3.fromRGB(color[1],color[2],color[3]);p.Parent=container
            if Art.yieldFrame and index%96==0 then Art.yieldFrame() end
        end
    end
    return container
end
function Art.close()
    if imageObject then imageObject:Destroy();imageObject=nil end
end
return Art
