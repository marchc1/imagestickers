local includeCS = function(file)
    file = "imagestickers/" .. file
    if SERVER then AddCSLuaFile(file) else return include(file) end
end
local includeSH = function(file)
    file = "imagestickers/" .. file
    if SERVER then AddCSLuaFile(file) return include(file) else return include(file) end
end
local includeSV = function(file)
    file = "imagestickers/" .. file
    if SERVER then return include(file) end
end

ImageStickers = {}
ImageStickers.AddonInfo = {
    name = "Image Stickers",
    author = "March"
}
ImageStickers.SizeMagicNumber = 6.252

ImageStickers.PrintDebugMessages = false

function ImageStickers.Log(...)
    MsgC(Color(155, 155, 155), "[", Color(255, 255, 255), os.date("%Y-%m-%d %H:%M:%S"), Color(155, 155, 155), "]")
    MsgC(Color(155, 155, 155), "[", Color(225, 128, 0), ImageStickers.AddonInfo.name, Color(155, 155, 155), "] ", Color(255, 255, 255), ..., "\n")
end

function ImageStickers.Debug(...)
    if not ImageStickers.PrintDebugMessages then return end
    ImageStickers.Log(...)
end

includeSH("bytestream.lua")
includeSH("imgur.lua")
includeCS("filemanagement.lua")
includeSH("assignment.lua")
includeSV("logging.lua")
includeCS("renderer.lua")
includeSH("language.lua")
includeSH("shrinkwrap.lua")
includeCS("properties.lua")

local load_queue = {}

hook.Add("PlayerInitialSpawn", "march.imagestickers.newplayer", function(ply)
	load_queue[ply] = true
end)

hook.Add("SetupMove", "march.imagestickers.newplayer", function( ply, _, cmd)
	if load_queue[ply] and not cmd:IsForced() then
		load_queue[ply] = nil

		hook.Run("march.imagestickers.newplayer", ply, ents.FindByClass("image_sticker")) -- Send what you need here!
	end
end )

ImageStickers.Log("Loaded!")
