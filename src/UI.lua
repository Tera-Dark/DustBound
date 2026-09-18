local U={}
U.colors={ink=Color3.fromRGB(238,237,215),cream=Color3.fromRGB(22,39,45),paper=Color3.fromRGB(34,54,60),orange=Color3.fromRGB(236,160,84),mint=Color3.fromRGB(140,212,184),muted=Color3.fromRGB(154,175,173),red=Color3.fromRGB(241,117,94),gold=Color3.fromRGB(244,199,122),purple=Color3.fromRGB(134,132,162),line=Color3.fromRGB(67,87,88),shadow=Color3.fromRGB(16,29,36)}
function U.frame(parent,name,x,y,w,h,color,trans)
 local f=Instance.new("Frame");f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.BackgroundColor3=color or U.colors.cream;f.BackgroundTransparency=trans or 0;f.BorderSizePixel=0;f.Parent=parent;return f
end
function U.corner(f,n) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,n or 10);c.Parent=f end
function U.outline(f,n,color) local a=Instance.new("UIStroke");a.Color=color or U.colors.line;a.Thickness=n or 2;a.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;a.Parent=f end
function U.panel(parent,name,x,y,w,h,color) local f=U.frame(parent,name,x,y,w,h,color);U.corner(f,8);U.outline(f,1);return f end
function U.text(parent,name,value,x,y,w,h,size,color,bold,align)
 local t=Instance.new("TextLabel");t.Name=name;t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.BackgroundTransparency=1;t.Text=value;t.TextSize=size or 22;t.TextColor3=color or U.colors.ink;t.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;t.TextWrapped=true;t.TextXAlignment=align or Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Parent=parent;return t
end
function U.button(parent,name,value,x,y,w,h,fn,accent)
 local b=Instance.new("TextButton");b.Name=name;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,h);b.BackgroundColor3=accent and U.colors.orange or U.colors.cream;b.Text=value;b.TextColor3=accent and U.colors.shadow or U.colors.ink;b.TextSize=20;b.Font=Enum.Font.GothamBold;b.TextWrapped=true;b.BorderSizePixel=0;b.AutoButtonColor=true;b.Active=true;b.Parent=parent;b:SetAttribute("Primary",accent==true);U.corner(b,8);U.outline(b,1)
 b.Activated:Connect(function() if b.Active then fn() end end);return b
end
function U.scroll(parent,name,x,y,w,h,content,direction)
 local f=Instance.new("ScrollingFrame");f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.CanvasSize=direction=="x" and UDim2.fromOffset(content,0) or UDim2.fromOffset(0,content);f.ScrollBarThickness=7;f.ScrollBarImageColor3=U.colors.ink;f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ClipsDescendants=true;f.ScrollingDirection=direction=="x" and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y;f.CanvasPosition=Vector2.zero;f.Parent=parent;return f
end
function U.clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end end
function U.enabled(b,value)
 local active=value==true
 if b.Active~=active then b.Active=active end
 if b.AutoButtonColor~=active then b.AutoButtonColor=active end
 local color=not active and U.colors.paper or b:GetAttribute("Primary") and U.colors.orange or U.colors.cream
 b.TextColor3=active and (b:GetAttribute("Primary") and U.colors.shadow or U.colors.ink) or U.colors.muted
 if b.BackgroundColor3~=color then b.BackgroundColor3=color end
end
return U
