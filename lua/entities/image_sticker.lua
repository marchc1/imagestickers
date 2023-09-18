AddCSLuaFile()
local imagecache = {}

local classname = "image_sticker"
local renderItems = {}

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Fun + Games"
ENT.PrintName		= "Image Sticker"
ENT.Author			= "March"
ENT.Purpose			= "Projects images in 3D space, attached to a physical entity"

ENT.Editable        = false
ENT.Spawnable		= true
ENT.AdminOnly       = false

function ENT:SpawnFunction(ply, tr, classname)
	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 16

	local ent = ents.Create(classname)
	ent:SetPos(SpawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	ent:Spawn()
	ent:Activate()
	return ent
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ImageURL", { 
        KeyName = "imageurl",
        Edit = {
            title = "Image URL",
            category = "Image Settings",
            type = "Generic",
            order = 1,
            waitforenter = true
        } 
    })

    self:NetworkVar("Float", 0, "ImageAngle", { 
        KeyName = "imageangle",
        Edit = {
            title = "Image Angle",
            category = "Image Settings",
            type = "Float",
            order = 2,
            min = 0,
            max = 360
        } 
    })

    self:NetworkVar("Float", 1, "ImageScale", { 
        KeyName = "imagescale",
        Edit = {
            title = "Image Scale",
            category = "Image Settings",
            type = "Float",
            order = 3,
            min = 0.01,
            max = 32
        } 
    })
    self:NetworkVar("Float", 2, "ImageScaleX", { 
        KeyName = "imagescalex",
        Edit = {
            title = "Image Scale X",
            category = "Image Settings",
            type = "Float",
            order = 4,
            min = 0.01,
            max = 32
        } 
    })
    self:NetworkVar("Float", 3, "ImageScaleY", { 
        KeyName = "imagescaley",
        Edit = {
            title = "Image Scale Y",
            category = "Image Settings",
            type = "Float",
            order = 5,
            min = 0.01,
            max = 32
        } 
    })
    self:NetworkVar("Bool", 0, "ShouldImageGlow", { 
        KeyName = "imageglow",
        Edit = {
            title = "Should the image glow in the dark?",
            category = "Look & Feel",
            type = "Boolean"
        } 
    })
    self:NetworkVar("Bool", 1, "ShouldImageTestAlpha", {
        KeyName = "testalpha",
        Edit = {
            title = "Enable alphatest?",
            category = "Look & Feel",
            type = "Boolean"
        }
    })

    self:NetworkVar("Bool", 2, "Translucency", {
        KeyName = "translucent",
        Edit = {
            title = "Enable translucency?",
            category = "Look & Feel",
            type = "Boolean"
        }
    })

    self:NetworkVar("Bool", 3, "Additive", {
        KeyName = "additive",
        Edit = {
            title = "Enable additive rendering?",
            category = "Look & Feel",
            type = "Boolean"
        }
    })
    self:NetworkVar("Bool", 4, "Nocull", {
        KeyName = "nocull",
        Edit = {
            title = "Render the image on the back side of the entity?",
            category = "Look & Feel",
            type = "Boolean"
        }
    })
 end

 function ENT:Initialize()
    if SERVER then
        self:SetModel("models/hunter/plates/plate05x05.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end
    end
    self:NetworkVarNotify("ImageURL", self.OnImageURLChange)
    if CLIENT then
        self.LastUpdateCheck = CurTime()

        self.Updates = {
            {
                check = function(x) return x:GetColor() end, change = function(self, ent) 
                    local c = self.value
                    
                    ent.image.material:SetVector("$color", Vector(c.r / 255, c.g / 255, c.b / 255))
                    ent.image.material:SetFloat("$alpha", c.a / 255)
                end
            },
            {   check = function(x) return x:GetAdditive() end, change = function(self, ent) 
                    ent.image.material:SetInt("$flags", ImageStickers.GetFlags(ent))
                end 
            },
            {   check = function(x) return x:GetShouldImageTestAlpha() end, change = function(self, ent) 
                    ent.image.material:SetInt("$flags", ImageStickers.GetFlags(ent))
                end 
            },
            {   check = function(x) return x:GetTranslucency() end, change = function(self, ent) 
                    ent.image.material:SetInt("$flags", ImageStickers.GetFlags(ent))
                end 
            },
            {   check = function(x) return x:GetNocull() end, change = function(self, ent) 
                    ent.image.material:SetInt("$flags", ImageStickers.GetFlags(ent))
                end 
            }
        }

        local scale = Vector(1,1,0.1)

        local mat = Matrix()
        mat:Scale(scale)
        self:EnableMatrix("RenderMultiply", mat)
        self:CheckIfURLCached()
    end

    if self:GetImageURL() ~= "" then
        self:OnImageURLChange("ImageURL", "", self:GetImageURL())
    else
        self:SetImageAngle(0) self:SetImageScale(1) self:SetImageScaleX(1) self:SetImageScaleY(1) self:SetShouldImageGlow(false)
    end
    
end

--Trick to make Wiremod think this is a GPU renderscreen.
--Only really made for EGP:egpMaterialFromScreen() 

function ENT:ForceGPU()
    if not self.image or self.image.errored or self.image.loading then return end
    self.GPU = {RT = self.image.material:GetName()}
end

if CLIENT then
    function ENT:Invalidate()
        if not self.image then return end

        for _, v in ipairs(self.Updates) do
            v.value = v.check(self)
            if self.image:readytodraw() then
                v:change(self)
            end
        end
    end
end

function ENT:OnImageURLChange(name, old, new)
    if CLIENT then
        self:ProcessImageURL(new)
    end

    if SERVER and old ~= new then
        ImageStickers.Logging.LogImageURLChange(self, new)
    end
end

function ENT:CheckIfURLCached()
    if not IsValid(self) then return end
    local isImgur, imgurID, linkorerr = ImageStickers.IsImgurLink(string.Replace(self:GetImageURL(), ".jpeg", ".jpg"))
    if isImgur then
        if imagecache[imgurID] == nil then
            self:ProcessImageURL(self:GetImageURL())
        end
    end
    timer.Simple(1, function() if not IsValid(self) then return end self.CheckIfURLCached(self) end)
end

function ENT:NewImageStruct(errored, loading)
    local ret = {
        errored = errored or false,
        loading = loading,

        readytodraw = function(self)
            return self.errored == false and self.loading == false
        end,
        setError = function(self, reason)
            self.errored = true
            self.error = reason
        end
    }
    return ret
end

function ENT:CreateImage(materialData, animated, link, imgurID)
    self.image = self:NewImageStruct(false, true)
    self.image.animated = animated
    self.image.link = link
    self.image.width = materialData.width
    self.image.height = materialData.height

    mat = CreateMaterial("imageloader_" .. imgurID .. SysTime(), "VertexLitGeneric", {
        ["$alpha"] = 1,
        ["$basetexture"] = materialData.raw:GetString("$basetexture"),
        ["$model"] = 1,
        ["$translucent"] = 1,
        ["$nocull"] = 0,
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1,
        ["$vertexalphatest"] = 1,
      } 
    )
    mat:SetInt("$flags", 0)

    ImageStickers.Debug(mat:GetString("$basetexture"))
    mat:Recompute()
    self.image.material = mat

    self.image.loading = false
    self:Invalidate()
    self:ForceGPU()
end

function ENT:ProcessImageURL(new)
    if SERVER then return end

    self.image = self:NewImageStruct(false, true)

    local final_link = string.Replace(new, ".jpeg", ".jpg")
    local isImgur, imgurID, linkorerr = ImageStickers.IsImgurLink(final_link)
    local animated = string.EndsWith(imgurID, ".gif")

    if not isImgur then
        self.image = self:NewImageStruct()
        self.image:setError(linkorerr)
    else
        if imagecache[imgurID] == nil then
            http.Fetch("https://" .. linkorerr, 
                function(body, size, headers, code)
                    if code == 404 then
                        self.image = self:NewImageStruct()
                        self.image:setError("Not found [404]") 
                        return
                    end

                    file.CreateDir("temp/imagesticker/")
                    local saved_data = string.Replace("temp/imagesticker/" .. imgurID, ".gif", ".dat")
                    file.Write(saved_data, body)

                    if not animated then
                        --Load file as material
                        local rawMaterial = Material("../data/temp/imagesticker/" .. imgurID, "nocull")
                        local materialData = {}

                        materialData.raw = rawMaterial
                        materialData.width = rawMaterial:GetInt("$realwidth")
                        materialData.height = rawMaterial:GetInt("$realheight")
                        imagecache[imgurID] = materialData
                        self:CreateImage(materialData, animated, new, imgurID)
                    else
                        self.image = self:NewImageStruct()
                        self.image:setError(ImageStickers.Language.GetPhrase("imagesticker.gifnotsuppported", "GIF files are currently not supported."))
                    end
                end,
                function(err)
                    self.image = self:NewImageStruct()
                    self.image:setError("Bad HTTP: " .. err)
                end, 
            {})
        else
            local materialData = imagecache[imgurID]
            self:CreateImage(materialData, animated, new, imgurID)
        end
    end

    self:ForceGPU()
end

function ENT:Draw()
    --local stopwatchStart = SysTime()
    self:DrawModel()

    ImageStickers.RenderImageOntoSticker(self)

    --allows flashlights to work on the images
    if not self:GetShouldImageGlow() then
        render.RenderFlashlights(function() ImageStickers.RenderImageOntoSticker(self) end)
    end
    --print("Time taken to render entity:", (SysTime() - stopwatchStart) * 1000,"ms")
end

function ENT:GetBorderRect3D()
    return ImageStickers.GetBorderRect3D(self)
end

function ENT:Think()
    if SERVER then return end

    local now = CurTime()
    if now - (self.LastUpdateCheck or 0) < 0.1 then return end

    local imageStatus = false
    if self.image ~= nil and self.image:readytodraw() then
        imageStatus = true
        for _, v in ipairs(self.Updates) do
            local last = v.value
            v.value = v.check(self)
            if last ~= v.value then
                v:change(self)
            end
        end
    else
        imageStatus = false
    end

    if self.LastUpdateImageStatus ~= imageStatus then
        local m = Matrix()
        if imageStatus then
            m:Scale(Vector(0, 0, 0))
        else
            m:Scale(Vector(1, 1, 0.1))
        end
        self:EnableMatrix("RenderMultiply", m)
    end

    self.LastUpdateImageStatus = imageStatus
    self.LastUpdateCheck = now
end