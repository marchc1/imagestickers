--TODO: make this actually readable, got way too carried away with this UI
--it's a huge mess and was made in one night in a rush, but it looks kinda cool for what it is so /shrug
--also hate the weirdness with lerpcolor/lerpcoloralpha but it is what it is for now

local Transparent = Color(0, 0, 0, 0)
local Backdrop = Color(15, 20, 25, 180)
local Outline = Color(130, 150, 200, 155)
local Outline2 = Color(180, 200, 235, 200)
local Outline3 = Color(210, 230, 255, 200)

local Label_Normal = Color(190, 220, 235)
local Label_Disabled = Color(142, 155, 175)
local Label_Selected = Color(230, 230, 255)

local CloseButton_Normal = Color(210, 100, 90)
local CloseButton_Hovered = Color(255, 110, 110)
local CloseButton_Depressed = Color(121, 80, 60)

local surface_DrawRect = surface.DrawRect
local surface_DrawTexturedRectRotated = surface.DrawTexturedRectRotated
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawLine = surface.DrawLine

local inner_offset = 24

--custom drawline function with line thickness & start->end fraction
local function DrawLine(sx, sy, ex, ey, size, fraction)
    fraction = fraction == nil and 1 or math.Clamp(fraction, 0, 1)
    ex, ey = Lerp(fraction, sx, ex), Lerp(fraction, sy, ey)

    local cx = (sx + ex) / 2
	local cy = (sy + ey) / 2
	
	local w = math.sqrt( (ex-sx) ^ 2 + (ey-sy) ^ 2 )
	local angle = math.deg(math.atan2(sy-ey,ex-sx))
	draw.NoTexture()
	surface_DrawTexturedRectRotated(cx, cy, w, size, angle)
end

--hsvadjust color in one function
local cmt = FindMetaTable("Color")
local function hsvAdjust(color, h, s, v)
    --h is add, s and v are multiply
    local oh, os, ov = ColorToHSV(color)
    local c2 = HSVToColor(oh + h, os * s, ov * v)
    --metatable fix
    setmetatable(c2, cmt)
    c2.a = color.a
    return c2
end

-- to-do: transfer these functions to a new animation library?

--toggleable animation class. increases/decreases a value by speed based off its internal enabled variable 
local function ToggleableAnimation(def, speed)
    return {
        enabled = false,
        val = def or 0,
        lastThink = CurTime(),
        speed = speed or 5,
        easing = function(x) return x end,
        think = function(self, inp)
            if inp ~= nil then self.enabled = inp end

            local time = CurTime()
            local diff = time - self.lastThink

            self.val = math.Clamp(self.val + ( diff * self.speed * (self.enabled == true and 1 or -1) ), 0, 1)
            self.lastThink = time

            return self.easing(self.val)
        end
    }
end

local function TextAnimator(text, cps, offset)
    return{
        __desired_text = text,
        cps = cps or 100, -- characters per second
        __text = "",
        birth = CurTime() + (offset or 0),
        dead = false,
        text = function(self)
            if self.dead then return self.__text end
            
            -- check if text has reached desired text?
            if self.__text == self.__desired_text then 
                --print(self.__text, "==", self.__desired_text)
                self.dead = true 
                return self.__text 
            end
             
            local now = CurTime()
            local characters = math.Clamp((now - self.birth) * self.cps, 0, #self.__desired_text)
            self.__text = string.sub(self.__desired_text, 1, characters)
            return self.__text
        end
    }
end

--single number quadratic bezier function 
local LerpQ = function(T,P0,P1,P2) return Lerp(T,Lerp(T,P0,P1),Lerp(T,P1,P2)) end

--lerp color by input
local function LerpColor(col1, col2, input)
    if input <= 0 then return col1.r, col1.g, col1.b, col1.a end
    if input >= 1 then return col2.r, col2.g, col2.b, col2.a end

    return Lerp(input, col1.r, col2.r), Lerp(input, col1.g, col2.g), Lerp(input, col1.b, col2.b), Lerp(input, col1.a or 255, col2.a or 255)
end

--lerp colors alpha only
local function LerpColorAlpha(col, input)
    return col.r, col.g, col.b, col.a * math.Clamp(input, 0, 1)
end

local function Dialog3Dto2D(entity, rect3d, paint)
    local Frame = g_ContextMenu:Add("DFrame")
    
    Frame.ralphaAnimation = 0
	Frame.CreationCurtime = CurTime()
    Frame.CurTime = 0
	Frame.OldClose = Frame.Close
    Frame.PostPaint = paint
    Frame.Animator = ToggleableAnimation(0, 1)
    Frame.Animator.enabled = true

    function Frame:MarkForDeath()
        Frame.markedfordeath = true
        Frame.Animator.enabled = false
    end

    Frame.Paint = function(self, w, h)

        local ct = CurTime() - self.CreationCurtime
        Frame.CurTime = ct

        Frame.Animator:think()

        local alphaAnimation = math.Clamp(Frame.Animator.val, 0, 0.5) / 0.5
        local ralphaAnimation = (math.Clamp(Frame.Animator.val,0.5,1)-0.5)/0.5

        Frame.ralphaAnimation = ralphaAnimation
        
        local EasingFunc = self.markedfordeath == true and math.ease.OutCubic or math.ease.InCubic
        local Ease = EasingFunc(alphaAnimation) 
        
        if self.markedfordeath then
            local v1 = Frame.Animator.val - 0.72
            self.closingMult = math.ease.OutCubic(math.Clamp(v1, 0, 1) * 2)
            if self.closingMult == 0 then
                Ease = 0 --easy way to close window immediately instead of playing line animation. may return to the line animation at some point
            end
        end

        if Ease ~= 1 then
			local bezUp = LocalPlayer():GetPos():Distance(entity:GetPos())/4
		
			local TLU = entity:LocalToWorld((entity:WorldToLocal(rect3d.TL) + Vector(0,0,bezUp)))
			local TRU = entity:LocalToWorld((entity:WorldToLocal(rect3d.TR) + Vector(0,0,bezUp)))
			local BLU = entity:LocalToWorld((entity:WorldToLocal(rect3d.BL) + Vector(0,0,bezUp)))
			local BRU = entity:LocalToWorld((entity:WorldToLocal(rect3d.BR) + Vector(0,0,bezUp)))
			
            local TL = rect3d.TL:ToScreen() local TR = rect3d.TR:ToScreen()
            local BL = rect3d.BL:ToScreen() local BR = rect3d.BR:ToScreen()
			
			local TLup = TLU:ToScreen() local TRup = TRU:ToScreen()
            local BLup = BLU:ToScreen() local BRup = BRU:ToScreen()
            
            cam.Start2D()
                local px, py = self:GetPos()
                local sx, sy = self:GetSize()

                px = px + inner_offset
                py = py + inner_offset
                sx = sx - (inner_offset * 2)
                sy = sy - (inner_offset * 2)

                local TLx, TLy = LerpQ(Ease,TL.x,TLup.x,px),    LerpQ(Ease,TL.y,TLup.y,py)
                local TRx, TRy = LerpQ(Ease,TR.x,TRup.x,px+sx), LerpQ(Ease,TR.y,TRup.y,py)
                local BLx, BLy = LerpQ(Ease,BL.x,BLup.x,px),    LerpQ(Ease,BL.y,BLup.y,py+sy)
                local BRx, BRy = LerpQ(Ease,BR.x,BRup.x,px+sx), LerpQ(Ease,BR.y,BRup.y,py+sy)

                --kept commented in case I decide to re-add the background of the frame rendering
                --[[
                surface.SetDrawColor(Backdrop.r, Backdrop.g, Backdrop.b, 190 * (alphaAnimation-ralphaAnimation))

                draw.NoTexture()
                surface.DrawPoly({
                        {x = TLx, y = TLy},
                        {x = TRx, y = TRy},
                        {x = BLx, y = BLy}
                    }
                )
                surface.DrawPoly({
                        {x = TRx, y = TRy},
                        {x = BRx, y = BRy},
                        {x = BLx, y = BLy}
                    }
                )]]
                
                surface_SetDrawColor(Color(LerpColor(Outline2, Outline, math.ease.InCirc(alphaAnimation))))
                surface_DrawLine(TLx, TLy, TRx, TRy)
                surface_DrawLine(TRx, TRy, BRx, BRy)
                surface_DrawLine(BRx, BRy, BLx, BLy)
                surface_DrawLine(BLx, BLy, TLx, TLy)
                
            cam.End2D()
		end

		if self.PostPaint then
			self.PostPaint(self, w , h)
		end

        if Ease <= 0 and self.markedfordeath == true then
            self:Close()
        end
    end
   
    return Frame 
end

--draws outline with corners
local function drawOutlineSpecial(w, h, cval, innerOffset)
    local w2, h2 = w - (innerOffset), h - (innerOffset)
    local x, y, w, h = innerOffset, innerOffset, w - (innerOffset * 2), h - (innerOffset * 2)

    surface.SetDrawColor(Color(LerpColorAlpha(Backdrop, cval)))
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(Color(LerpColorAlpha(Outline, cval*20000)))
    surface.DrawOutlinedRect(x, y, w, h, 1)
    local cornersize = 24
    cornersize = cornersize * math.Remap(innerOffset, 0, inner_offset, 1, 0)

    surface.SetDrawColor(Color(LerpColorAlpha(Outline2, cval)))

    --TL, TR, BL, BR corners

    surface.DrawRect(0 + x, 0 + y, cornersize, 2)
    surface.DrawRect(0 + x, 0 + y, 2, cornersize)

    surface.DrawRect((w2 - cornersize), y, cornersize, 2)
    surface.DrawRect((w2 - 2), y, 2, cornersize)

    surface.DrawRect(x, h2 - 2, cornersize, 2)
    surface.DrawRect(x, h2 - cornersize, 2, cornersize)

    surface.DrawRect(w2 - cornersize, h2 - 2, cornersize, 2)
    surface.DrawRect(w2 - 2, h2 - cornersize, 2, cornersize)
end

--All because for some reason knob.Depressed is set to nil in Paint??
local currentKnob = nil
local mousebtn = {
    [107] = true,
    [108] = true,
    [109] = true,
    [110] = true,
    [111] = true
}

hook.Add("PlayerButtonUp", "march.imagestickers.releaseknobui", function(ply, btn)
    if IsValid(currentKnob) and mousebtn[btn] then
        if IsFirstTimePredicted() then

            currentKnob.aDepressed = false
            currentKnob = nil
        end
    end
end)


--most of this is copy-paste from the gmod repo
local function FixNumSlider(self)
    local oldthink = self.Scratch.Think

    self.Scratch.Think = function(self)
        if not self.animation then
            self.animation = ToggleableAnimation(0, 3)
        end

        oldthink(self)
        local drawScreen = self:GetShouldDrawScreen()

        if drawScreen and self.oldDrawScreen ~= drawScreen then
            self.animation.lastThink = CurTime()
            self.animation.val = 0
            self.animation.enabled = false
        end

        self.oldDrawScreen = drawScreen
    end

    --?
    self.Scratch.OnMouseReleased = function(self, mousecode)
        g_Active = nil
        self:SetActive(false)
        self:MouseCapture(false)
        self:SetCursor("sizewe")
        self:SetShouldDrawScreen(false)
    end

    self.Scratch.DrawScreen = function(self, x, y, w, h)
        local ox, oy, ow, oh = x, y, w, h

        local sx, sy = self:GetPos()
        sx, sy = self:LocalToScreen(sx, sy)
        local sw, sh = self:GetSize()

        if not self:GetShouldDrawScreen() then return end
        local wasEnabled = DisableClipping( true )

        self.animation.enabled = true
        self.animation:think()

        local min = self:GetMin()
        local max = self:GetMax()
        local range = self:GetMax() - self:GetMin()
        local value = self:GetFloatValue()

        local animationValue1 = math.ease.InOutQuart(self.animation.val)
        local animationValue2 = math.ease.OutQuart(self.animation.val)
        local animationValue3 = math.ease.OutCubic(self.animation.val)

        x, y, w, h = Lerp(animationValue3, sx, ox), Lerp(animationValue3, sy, oy), Lerp(animationValue3, sw, ow), Lerp(animationValue3, sh, oh)

        surface.SetDrawColor(Backdrop.r, Backdrop.g, Backdrop.b, Backdrop.a * animationValue1)
        local yoff = 84
        surface.DrawRect(x, y + yoff, w, h-yoff)

        surface.SetDrawColor(183, 216, 230, 100 * animationValue1)
        local targetX = x + w * 0.5 - ( ( value - min ) * self:GetZoom())
        local targetW = range * self:GetZoom()
        targetW = targetW - math.max( 0, x - targetX )
        targetW = math.min(targetW, w - math.max( 0, targetX - x ))
        surface.DrawRect(math.max( targetX, x ) + 3, y + h * 0.4, targetW - 6, h * 0.6)

        for i = 1, 4 do
            self:DrawNotches(10 ^ i, x, y, w, h, range, value, min, max, self.animation.val)
        end

        for i = 0, self:GetDecimals() do
            self:DrawNotches(1 / 10 ^ i, x, y, w, h, range, value, min, max, self.animation.val)
        end

        surface.SetDrawColor(Outline.r, Outline.g, Outline.b, Outline.a * animationValue2)
        local yoff = 84
        surface.DrawOutlinedRect(x, y + yoff, w, h-yoff, 2)

        surface.SetFont("DermaLarge")
        local str = self:GetTextValue()
        str = string.Comma(str)
        local tw, th = surface.GetTextSize(str)

        surface.SetDrawColor(20, 40, 70, 150 * animationValue1)
        surface.DrawRect(x + w * 0.5 - tw / 2 - 10, y + h - 43, tw + 20, 39)
        surface.SetDrawColor(Outline2.r, Outline2.g, Outline2.b, Outline2.a * animationValue1)
        surface.DrawOutlinedRect(x + w * 0.5 - tw / 2 - 10, y + h - 43, tw + 20, 39, 3)
        local xC, yC = x + (w / 2), y + (h / 2)
        DrawLine(xC, yC + 85, xC, yC - 42, 3)

        surface.SetTextColor(255, 255, 255, 255 * animationValue1)
        surface.SetTextPos(x + w * 0.5 - tw * 0.5, y + h - th - 6)
        surface.DrawText(str)

        surface.SetDrawColor(Outline2.r, Outline2.g, Outline2.b, Outline2.a * animationValue1)

        DisableClipping(wasEnabled)
    end

    self.Scratch.DrawNotches = function(self, level, x, y, w, h, range, value, min, max, animationValue1)
        animationValue1 = animationValue1 or 1

        local size = level * self:GetZoom()
        if size < 5 then return end
        if size > w * 2 then return end
    
        local alpha = 255
    
        if size < 150 then alpha = alpha * ((size - 2) / 140) end
        if size > (w * 2) - 100 then alpha = alpha * (1 - ((size - (w - 50)) / 50 )) end
    
        local halfw = w * 0.5
        local span = math.ceil(w / size)
        local realmid = x + w * 0.5 - (value * self:GetZoom())
        local mid = x + w * 0.5 - math.fmod(value * self:GetZoom(), size)
        local top = h * 0.4
        local nh = h - top
    
        local frame_min = math.floor(realmid + min * self:GetZoom())
        local frame_width = math.ceil(range * self:GetZoom())
        local targetW = math.min(w - math.max( 0, frame_min - x ), frame_width - math.max(0, x - frame_min ))
    
        surface.SetDrawColor( 0, 0, 0, alpha * animationValue1 )
        surface.DrawRect( math.max( x, frame_min ), y + top, targetW, 2 )
    
        surface.SetFont( "DermaDefault" )
    
        for n = -span, span, 1 do
    
            local nx = mid + n * size
    
            if ( nx > x + w || nx < x ) then continue end
    
            local dist = 1 - ( math.abs( halfw - nx + x ) / w )
    
            local val = ( nx - realmid ) / self:GetZoom()
    
            if ( val <= min + 0.001 ) then continue end
            if ( val >= max - 0.001 ) then continue end
    
            surface.SetDrawColor( 0, 0, 0, alpha * dist * animationValue1 )
            surface.SetTextColor( 255, 255, 255, alpha * dist * animationValue1 )
    
            surface.DrawRect( nx, y + top, 2, nh )
    
            local tw, th = surface.GetTextSize( val )
    
            surface.SetTextPos( nx - ( tw * 0.5 ), y + top - th )
            surface.DrawText( val )
    
        end
    
        surface.SetDrawColor( 0, 0, 0, alpha * animationValue1 )
        surface.SetTextColor( 255, 255, 255, alpha * animationValue1 )
    
        local nx = realmid + max * self:GetZoom()
        if ( nx < x + w ) then
            surface.DrawRect( nx, y + top, 2, nh )
    
            local val = max
            local tw, th = surface.GetTextSize( val )
    
            surface.SetTextPos( nx - ( tw * 0.5 ), y + top - th )
            surface.DrawText( val )
        end
    
        local nx = realmid + min * self:GetZoom()
        if ( nx > x ) then
            surface.DrawRect( nx, y + top, 2, nh )
    
            local val = min
            local tw, th = surface.GetTextSize( val )
    
            surface.SetTextPos( nx - ( tw * 0.5 ), y + top - th )
            surface.DrawText( val )
        end
    end

    local function paintSliderNotches(x, y, w, h, num)
        if not num then return end
        local space = w / num

        if space < 2 then
            space = 2
            num = w / space
        end

        for i = 0, math.ceil(num) do
            surface.DrawRect(x + i * space, y + 4, 1, 5)
        end
    end

    self.Slider.Paint = function(panel, w, h)
	    surface.SetDrawColor(hsvAdjust(self.TextArea:GetTextColor(), 0, 0.6, 0.5))
    	surface.DrawRect(8, h / 2 - 1, w - 15, 1)

	    paintSliderNotches(8, h / 2 - 1, w - 16, 1, panel:GetNotches())
    end

    --Why is Depressed not on the Knob??
    local oKP, oKR = self.Slider.Knob.OnMousePressed, self.Slider.Knob.OnMouseReleased
    self.Slider.Knob.OnMousePressed = function(self, mcode) oKP(self, mcode) self.aDepressed = true currentKnob = self end
    local externalADepress = false
    self.Slider.Knob.AnimateColor = ToggleableAnimation(0, 3.5)

    self.Slider.Knob.Paint = function(panel, w, h)
        panel.lastPaint = panel.lastPaint or CurTime()
        local ct = CurTime()
        local diff = ct - panel.lastPaint

        if panel.aDepressed == true then
            externalADepress = true
        end
        panel.AnimateColor.enabled = panel.aDepressed
        panel.AnimateColor:think()

        surface.SetDrawColor(LerpColor(Outline, Outline3, panel.AnimateColor.val))
        panel.fakeSpin = externalADepress and panel.fakeSpin + (diff * 2) or panel.fakeSpin or 0.5

        if panel.fakeSpin >= 0.5 and panel.aDepressed == false then
            panel.fakeSpin = 0.5
            externalADepress = false
        else
            panel.fakeSpin = panel.fakeSpin % 1
        end

        local fakeSpinVal = (math.sin(panel.fakeSpin * math.pi) + 1) / 2
        local leftLineEX  = 2
        local rightLineEX = w - 1
        local llX, rlX = Lerp(fakeSpinVal, leftLineEX, rightLineEX), Lerp(fakeSpinVal, rightLineEX, leftLineEX)

        surface.DrawLine(llX, h - 2, (w / 2), h / 2)
        surface.DrawLine((w / 2), h / 2, rlX, h - 2)

        panel.lastPaint = ct
    end
end

local function vscrollbarInject(animated_parent, object) 
    local window = animated_parent
    object.createdTime = CurTime()

    object.ScrollwheelBackgroundColor = Outline
    object.ScrollwheelForegroundColor = Outline2
    
    function object:OnMouseWheeled( dlta )
        if not self:IsVisible() then return false end
        self:AnimateTo(self:GetScroll() + (dlta * -48), 0.2, 0, 0.5)
    end

    function object:Think()

    end

	function object:Paint(w, h)	end

	function object.btnUp:Paint(w, h)
        local cval = math.Clamp((window.getLifetime() - 1) * (1), 0, 1) * window.closingMult

        local w2, h2 = w / 2, h / 2

        local arrowWidth, arrowHeight = 4, -2
        surface_SetDrawColor(LerpColorAlpha(object.ScrollwheelForegroundColor, cval))
        
        surface_DrawLine(w2 - arrowWidth, h2 - arrowHeight, w2, h2 + arrowHeight)
        surface_DrawLine(w2 + (arrowWidth-1), h2 - arrowHeight, w2, h2 + arrowHeight)
	end
	
	function object.btnDown:Paint(w, h)
        local cval = math.Clamp((window.getLifetime() - 1) * (1), 0, 1) * window.closingMult

        local w2, h2 = w / 2, h / 2
        
        local arrowWidth, arrowHeight = 4, 2
        surface_SetDrawColor(LerpColorAlpha(object.ScrollwheelForegroundColor, cval))

        surface_DrawLine(w2 - arrowWidth, h2 - arrowHeight, w2, h2 + arrowHeight)
        surface_DrawLine(w2 + (arrowWidth-1), h2 - arrowHeight, w2, h2 + arrowHeight)
	end
	
    local gripWidth = 4
	function object.btnGrip:Paint(w, h)
        local cval = math.Clamp((window.getLifetime() - 1) * (1), 0, 1) * window.closingMult

        if not self.anim then
            self.anim = 0
        end
        self.anim = math.Clamp(self.anim + (0.02 * (self:IsHovered() and 1 or -1)), 0, 1)

        local w2, h2 = w / 2, h / 2

        draw.RoundedBox(3, gripWidth, 0, w-(gripWidth*2), h, Color(LerpColorAlpha(object.ScrollwheelForegroundColor, cval)))
	end
end

local fadeinSpeed = 6

--Turns DEntityProperties into a fancier menu.
function ImageStickers.NicerProperties(window, entproperties, ent)
    window.createdTime = CurTime()
    vscrollbarInject(window, entproperties.Canvas:GetVBar())

    local renderOffset = 0.5
    local renderOffsetAdd = 0.05
    local function offsetRender()
        renderOffset = renderOffset + renderOffsetAdd
        return renderOffset
    end
    local curtime = CurTime
    local function getLifetime()
        return curtime() - window.createdTime
    end
    window.renderOffset = offsetRender()

    window.getLifetime = getLifetime
    window.offsetRender = offsetRender
    window.closingMult = 1

    window.Text = string.Replace(ImageStickers.Language.GetPhrase("imagesticker.ui.editingtitle"), "{ENTID}", "[" .. tostring(ent:EntIndex()) .. "]")

    window.PostPaint = function(self, w, h)
        local cval = math.Clamp((getLifetime() - self.renderOffset) * fadeinSpeed, 0, 1) * window.closingMult

        local sizein = math.Remap(math.ease.OutQuart(math.Clamp(cval, 0, 1)), 0, 1, inner_offset, 0)
        drawOutlineSpecial(w, h, cval, sizein)
        draw.SimpleText(self.Text, "DermaDefault", w / 2, 12 + sizein, Color(LerpColorAlpha(Label_Normal, cval)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    window.btnClose.DoClick = function(self) window:MarkForDeath() end

    for k, v in pairs(ent.__propcategories) do
        entproperties.Categories[k].zpos = v
    end

    for catName, cat in SortedPairsByMemberValue(entproperties.Categories, "zpos") do
        cat.renderOffset = offsetRender()

        cat:DockMargin(8, 8, 8, 8)
        local oldPerfLayout = cat.PerformLayout
        cat.Expand.animatePlus = ToggleableAnimation(0, 8)
        cat.Expand.easing = math.ease.InOutBack

        cat.Label.TextAnimator = TextAnimator(catName, nil, cat.renderOffset)

        cat.PerformLayout = function(self)
            oldPerfLayout(self)

            cat.Expand.Paint = function(self, w, h)
                self.animatePlus.enabled = not self:GetExpanded()

                surface.SetDrawColor(LerpColorAlpha(Outline, math.Clamp((getLifetime() - cat.renderOffset) * fadeinSpeed, 0, 1) * window.closingMult))
                surface.DrawOutlinedRect(5, 3, w-6, h-6, 1)

                draw.NoTexture()
	            surface.DrawTexturedRectRotated(10, 8, 6, 1, 0)
                surface.DrawTexturedRectRotated(10, 8, 6, 1, 90 * self.animatePlus:think())
            end

            cat.Paint = function(self, w, h)
                cat.Label:SetTextColor(Color(LerpColorAlpha(color_white, math.Clamp((getLifetime() - self.renderOffset) * fadeinSpeed, 0, 1) * window.closingMult)))
                cat.Label:SetText(self.Label.TextAnimator:text())
                surface.SetDrawColor(LerpColorAlpha(Backdrop, math.Clamp((getLifetime() - self.renderOffset) * fadeinSpeed, 0, 1) * window.closingMult))
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(LerpColorAlpha(Outline, math.Clamp((getLifetime() - self.renderOffset) * fadeinSpeed, 0, 1) * window.closingMult))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            cat.Container.Paint = function(self, w, h) end
        end

        for rowName, row in SortedPairsByMemberValue(cat.Rows, "order") do
            local rrenderOffset = offsetRender()
            
            local oldPerfLayout = row.PerformLayout
            
            if row.Label.SetText then
                row.Label.TextAnimator = TextAnimator(rowName, nil, rrenderOffset)
                function row.Label:Paint(w, h)
                    draw.SimpleText(self.Text, "DermaDefault", 0, h / 2, self:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end

            row.PerformLayout = function(self)
                oldPerfLayout(self)
    
                row.Label:SetTextColor(color_white)
                
                row.Paint = function(self, w, h)
                    if not IsValid(self.Inner) then return end

                    local editing = self.Inner:IsEditing()
                    local disabled = not self.Inner:IsEnabled() or not self:IsEnabled()

                    local c = nil
                    if disabled then
                        c = Label_Disabled
                    elseif editing then
                        c = Label_Selected
                    else
                        c = Label_Normal
                    end
 
                    self.Label:SetTextColor(Color(LerpColorAlpha(c, math.Clamp((getLifetime() - rrenderOffset) * fadeinSpeed, 0, 1) * window.closingMult)))
                    
                    if self.Label.SetText ~= nil then
                        self.Label:SetText("")
                        self.Label.Text = self.Label.TextAnimator:text()
                    end
                    
                    if self.ExtraPaintOperation then
                        self.ExtraPaintOperation(self.Label:GetTextColor())
                    end
                end
                
                local innerItem = nil
                local children = row.Inner:GetChildren()

                for _, v in ipairs(children) do
                    local panelType = v:GetName()
                    if panelType == "DTextEntry" then
                        v.TextAnimator = TextAnimator(ImageStickers.Language.GetPhrase("imagesticker.ui.pastelink"), nil, rrenderOffset)
                        
                        row.ExtraPaintOperation = function(color) 
                            local c2 = hsvAdjust(color, 0, 0.3, 0.5) 
                            v:SetPlaceholderColor(c2) 
                            v:SetTextColor(color)
                            v:SetPlaceholderText(v.TextAnimator:text())
                        end
                    elseif panelType == "DNumSlider" then
                        FixNumSlider(v)
                        row.ExtraPaintOperation = function(color) v.TextArea:SetTextColor(color) end
                    elseif panelType == "DButton" then
                        v.animationStateHovered = ToggleableAnimation(0, 7)
                        v.animationStateDepressed = ToggleableAnimation(0, 7)
                        v.animationStateHovered.easing = math.ease.InOutQuart
                        v.animationStateDepressed.easing = math.ease.InOutBack
                        
                        v.TextAnimator = TextAnimator(v.Text or "", nil, rrenderOffset)

                        v.Paint = function(self, w, h)
                            self.animationStateHovered.enabled = self.Hovered 
                            self.animationStateDepressed.enabled = self.Depressed 
                    
                            local hovered, depressed = self.Hovered, self.Depressed
                    
                            local color1 = Color(LerpColor(Label_Normal, Label_Selected, self.animationStateHovered:think()))
                            local color2 = Color(LerpColor(color1, Label_Disabled, self.animationStateDepressed:think()))
                            local color3 = Color(LerpColorAlpha(color2, math.Clamp((getLifetime() - rrenderOffset) * fadeinSpeed, 0, 1) * window.closingMult ))
                            surface.SetDrawColor(color3)
                            surface.DrawOutlinedRect(0, 0, w, h, 1)

                            draw.SimpleText(self.TextAnimator:text(), "DermaDefault", w / 2, h / 2, color3, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        end
                    elseif panelType == "DCheckBox" then
                        v.animationState = ToggleableAnimation(v:GetChecked() and 1 or 0)
                        v.easing = math.ease.InOutQuart

                        v.Paint = function(self, w, h)
                            local checked = self:GetChecked()

                            self.animationState.enabled = checked
                            self.animationState:think()
                            
                            --this sucks =(
                            surface.SetDrawColor(LerpColorAlpha( Color(LerpColor(Outline, Label_Selected, self.animationState.val)), math.Clamp((getLifetime() - rrenderOffset) * fadeinSpeed, 0, 1) * window.closingMult ))
                            surface.DrawOutlinedRect(0, 0, w, h, 1)
                            
                            if self.animationState.val >= 0 then
                                DrawLine(2, h / 2, w * 0.4, h - 2, 2, self.animationState.val * 2)
                                DrawLine(w * 0.4, h - 2, w - 2, 4, 2, (self.animationState.val - 0.5) * 2)
                            end
                        end
                    else
                        print("unsupported element customer for '" .. panelType .. "'")
                    end
                end
            end
        end
    end
end

local textNotice = vgui.RegisterTable( {
	Init = function( self )
		self:Dock(TOP)
		self.Label = self:Add( "DLabel" )
	end,

	PerformLayout = function( self )
		self.Label.textColor = color_white
		self.Label:DockMargin(4, 0, 0, 0)
	end,
	Paint = function(self, w, h) 
        self.Label:SetTextColor(Color(LerpColorAlpha(self.Label.textColor, math.Clamp((self.window.getLifetime() - self.renderOffset) * fadeinSpeed, 0, 1) * self.window.closingMult)))
    end
}, "Panel" )


local edit_imagestickers = {
	MenuLabel = ImageStickers.Language.GetPhrase("imagesticker.openprompt"),
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/image_edit.png",

	Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        if ent:GetClass() ~= "image_sticker" then return false end
        return true
	end,

	Action = function(self, ent)
		local window = Dialog3Dto2D(ent, ent:GetBorderRect3D())
        window.IsImageStickerDialog = true

		window:SetSize(700, 500)
		window:SetTitle("")
        window.lblTitle:SetTextColor(Label_Normal)
		window:Center()
		window:SetSizable(true)

        window.btnMaxim:Hide()
        window.btnMinim:Hide()
        window.btnClose.animationStateHovered = ToggleableAnimation(0, 7)
        window.btnClose.animationStateDepressed = ToggleableAnimation(0, 7)
        window.btnClose.animationStateHovered.easing = math.ease.InOutQuart
        window.btnClose.animationStateDepressed.easing = math.ease.InOutBack
        
        window.btnClose.Paint = function(self, w, h)
            self.animationStateHovered.enabled = self.Hovered 
            self.animationStateDepressed.enabled = self.Depressed 

            local hovered, depressed = self.Hovered, self.Depressed

            --frowning
            local color1 = Color(LerpColor(CloseButton_Normal, CloseButton_Hovered, self.animationStateHovered:think()))
            local color2 = Color(LerpColor(color1, CloseButton_Depressed, self.animationStateDepressed:think()))
            local color3 = Color(LerpColorAlpha(color2, math.Clamp((window.getLifetime() - 1) * fadeinSpeed, 0, 1) * window.closingMult ))

            surface.SetDrawColor(color3)
            surface.DrawOutlinedRect(0, 4, w, h-8, 1)

            local w2, h2 = w / 2, h / 2
            local xSize = (h / 2) - 8

            DrawLine(w2 - xSize, h2 - xSize, w2 + xSize, h2 + xSize, 2, 1)
            DrawLine(w2 + xSize, h2 - xSize, w2 - xSize, h2 + xSize, 2, 1)
        end

		local control = window:Add("DEntityProperties")

        --a trick to make the animating properties animate in order
        --there's probably a function that returns this, but I CBA to find it
        local zPosCat = 0

        local oldGetCategory = control.GetCategory
        function control:GetCategory(name, bCreate)
            local cat = self.Categories[name]
	        if IsValid(cat) then return cat end

            local cat = oldGetCategory(self, name, bCreate)
            cat.zpos = zPosCat
            zPosCat = zPosCat + 1

            local zPosRow = 0
            local oldGetRow = cat.GetRow
            function cat:GetRow(name, bCreate)
                if IsValid(self.Rows[name]) then return self.Rows[name] end
                local row = oldGetRow(self, name, bCreate)
                row.zpos = zPosRow
                zPosRow = zPosRow + 1
                return row
            end
            return cat
        end

        function control:RebuildControls()
            self:Clear()
            if not IsValid(self.m_Entity) then return end
            
            local editor = self.m_Entity.__propertiesandtriggers

            local i = 1000
            for name, edit in pairs(editor) do
                if edit.order == nil then
                    edit.order = i
                end

                i = i + 1
            end
            
            for name, edit in SortedPairsByMemberValue(editor, "order") do
                self:EditVariable(name, edit)
            end

            for k, v in SortedPairsByValue(self.m_Entity.__propcategories) do
                self.Categories[k]:MoveToFront()
                self.Categories[k]:DockPadding(4,4,4,4)
                for k2, v2 in SortedPairsByMemberValue(self.Categories[k].Rows, "order") do
                    v2:MoveToFront()
                end
                --entproperties.Categories[k].zpos = v
            end
        end

        function control:EditVariable(varname, item)
            if not istable(item) then return end

            local edit = item.Edit

            local row = self:CreateRow(edit.category or "#entedit.general", edit.title or varname)
            row.Type = item.PropertyType
            row.order = edit.order

            if item.PropertyType == "Property" then
                row:Setup(edit.type, edit)
                
                row.DataUpdate = function(_)
                    if not IsValid(self.m_Entity) then self:EntityLost() return end
                    row:SetValue(self.m_Entity:GetNetworkKeyValue(varname))
                end

                row.DataChanged = function(_, val)
                    if not IsValid(self.m_Entity) then self:EntityLost() return end
                    self.m_Entity:EditValue(varname, tostring(val))
                end
            elseif item.PropertyType == "Trigger" then
                row.Label:Remove()
                local p = row:Add("DPanel")
                row.Inner = p
                p:Dock(FILL)
                p.Paint = function() end

                local b = p:Add("DButton")
                b:Dock(FILL)
                b:SetText("")
                p:SetText("")
                b.Text = edit.title
                row.Inner = p
                p.IsEditing = function() return false end
                row.Label = {}
                row.Label.SetTextColor = function() end
                row.Label.SetWide = function() end

                function b.DoClick(_)
                    if not IsValid(self.m_Entity) then self:EntityLost() return end
                    
                    local shf, clf = ent.__propertiesandtriggers[varname].DoShared, ent.__propertiesandtriggers[varname].DoClientside
                    if shf then shf(ent) end
                    if clf then clf(ent) end

                    net.Start("march.imagestickers.enttriggers")
                    net.WriteEntity(self.m_Entity)
                    net.WriteString(varname)
                    net.SendToServer()
                end
            else
                print("unexpected item type '" .. item.PropertyType .. "'")
            end
        end

		control:SetEntity(ent)
		control:Dock(FILL)
        window.Properties = control

		control.OnEntityLost = function()
			window:Remove()
		end

        ImageStickers.NicerProperties(window, control, ent) 

        local notice = control:GetCanvas():Add(textNotice)
        notice.window = window
        notice.renderOffset = window.offsetRender()
        notice.Label:SetText(ImageStickers.Language.GetPhrase("imagesticker.ui.notify_imagelinks"))
        notice.Label:Dock(BOTTOM)

        local notice2 = control:GetCanvas():Add(textNotice)
        notice2.window = window
        notice2.renderOffset = window.offsetRender()
        notice2.Label:SetText(ImageStickers.Language.GetPhrase("imagesticker.ui.notify_colorswork"))
        notice2.Label:Dock(BOTTOM)

        local notice3 = control:GetCanvas():Add(textNotice)
        notice3.window = window
        notice3.renderOffset = window.offsetRender()
        notice3.Label:SetText(ImageStickers.Language.GetPhrase("imagesticker.ui.notify_transpencytip"))
        notice3.Label:Dock(BOTTOM)
	end
}

properties.Add("edit.imagestickers", edit_imagestickers)