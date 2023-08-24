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

function ENT:ProcessImageURL(new)
    if SERVER then return end

    self.image = {loading = true}

    local final_link = string.Replace(new, ".jpeg", ".jpg")
    local isImgur, imgurID, linkorerr = ImageStickers.IsImgurLink(final_link)
    local animated = string.EndsWith(imgurID, ".gif")

    if not isImgur then
        self.image = {errored = true, error = linkorerr}
    else
        if imagecache[imgurID] == nil then
            http.Fetch("https://" .. linkorerr, 
                function(body, size, headers, code)
                    if code == 404 then
                        self.image = {errored = true, error = "Not found [404]"}
                        return
                    end

                    self.image = {
                        loading = true,
                        errored = false,
                        animated = animated,
                        link = new
                    }
                    file.CreateDir("temp/imagesticker/")
                    local saved_data = string.Replace("temp/imagesticker/" .. imgurID, ".gif", ".dat")
                    file.Write(saved_data, body)

                    if not animated then
                        --Load file as material
                        local mat = Material("../data/temp/imagesticker/" .. imgurID, "nocull")
                        self.image.width = mat:GetInt("$realwidth")
                        self.image.height = mat:GetInt("$realheight")
                        
                        
                        mat = CreateMaterial("imageloader_" .. imgurID .. SysTime(), "VertexLitGeneric", {
                            ["$alpha"] = 1,
                            ["$basetexture"] = mat:GetString("$basetexture"),
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
                        self:ForceGPU()
                    else
                        self.image.loading = false
                        self.image.errored = true
                        self.image.error = ImageStickers.Language.GetPhrase("imagesticker.gifnotsuppported", "GIF files are currently not supported.")
                    end
                    imagecache[imgurID] = self.image
                    self.image.loading = false
                end,
                function(err)
                    self.image = {
                        errored = true,
                        error = "Bad HTTP: " .. err
                    }
                end, 
            {})
        else
            self.image = imagecache[imgurID]
        end
    end

    self:ForceGPU()
end

function ENT:Draw()
    local m = Matrix()
    if self.image ~= nil and (self.image.errored == false and self.image.loading == false) then
        m:Scale(Vector(0, 0, 0))
    else
        m:Scale(Vector(1, 1, 0.1))
    end
    self:EnableMatrix("RenderMultiply", m)
    self:DrawModel()

    ImageStickers.RenderImageOntoSticker(self)

    --allows flashlights to work on the images
    if not self:GetShouldImageGlow() then
        render.RenderFlashlights(function() ImageStickers.RenderImageOntoSticker(self) end)
    end
end

function ENT:GetBorderRect3D()
    return ImageStickers.GetBorderRect3D(self)
end