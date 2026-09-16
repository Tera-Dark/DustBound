local U={}
U.colors={ink=Color3.fromRGB(23,29,49),cream=Color3.fromRGB(247,241,219),paper=Color3.fromRGB(232,218,184),orange=Color3.fromRGB(235,137,61),mint=Color3.fromRGB(135,226,185),muted=Color3.fromRGB(105,109,104),red=Color3.fromRGB(181,63,59),gold=Color3.fromRGB(251,206,85),purple=Color3.fromRGB(103,72,110)}
function U.frame(parent,name,x,y,w,h,color,trans)
 local f=Instance.new("Frame");f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.BackgroundColor3=color or U.colors.cream;f.BackgroundTransparency=trans or 0;f.BorderSizePixel=0;f.Parent=parent;return f
end
function U.corner(f,n) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,n or 10);c.Parent=f end
function U.outline(f,n,color) local a=Instance.new("UIStroke");a.Color=color or U.colors.ink;a.Thickness=n or 2;a.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;a.Parent=f end
function U.panel(parent,name,x,y,w,h,color) local f=U.frame(parent,name,x,y,w,h,color);U.corner(f,12);U.outline(f,2);return f end
function U.text(parent,name,value,x,y,w,h,size,color,bold,align)
 local t=Instance.new("TextLabel");t.Name=name;t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.BackgroundTransparency=1;t.Text=value;t.TextSize=size or 22;t.TextColor3=color or U.colors.ink;t.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;t.TextWrapped=true;t.TextXAlignment=align or Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Parent=parent;return t
end
function U.button(parent,name,value,x,y,w,h,fn,accent)
 local b=Instance.new("TextButton");b.Name=name;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,h);b.BackgroundColor3=accent and U.colors.orange or U.colors.cream;b.Text=value;b.TextColor3=U.colors.ink;b.TextSize=22;b.Font=Enum.Font.GothamBold;b.TextWrapped=true;b.BorderSizePixel=0;b.AutoButtonColor=true;b.Active=true;b.Parent=parent;U.corner(b,9);U.outline(b,2)
 b.Activated:Connect(function() if b.Active then fn() end end);return b
end
function U.scroll(parent,name,x,y,w,h,content,direction)
 local f=Instance.new("ScrollingFrame");f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.CanvasSize=direction=="x" and UDim2.fromOffset(content,0) or UDim2.fromOffset(0,content);f.ScrollBarThickness=7;f.ScrollBarImageColor3=U.colors.ink;f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ClipsDescendants=true;f.ScrollingDirection=direction=="x" and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y;f.CanvasPosition=Vector2.zero;f.Parent=parent;return f
end
function U.clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end end
function U.enabled(b,value) b.Active=value==true;b.AutoButtonColor=value==true;b.BackgroundColor3=value and U.colors.orange or U.colors.paper end
return U
