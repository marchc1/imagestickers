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

ImageStickers.PrintDebugMessages = false

function ImageStickers.Log(...)
    MsgC(Color(155, 155, 155), "[", Color(255, 255, 255), os.date("%Y-%m-%d %H:%M:%S"), Color(155, 155, 155), "]")
    MsgC(Color(155, 155, 155), "[", Color(225, 128, 0), ImageStickers.AddonInfo.name, Color(155, 155, 155), "] ", Color(255, 255, 255), ..., "\n")
end

function ImageStickers.Debug(...)
    if not ImageStickers.PrintDebugMessages then return end
    ImageStickers.Log(...)
end

includeSH("imgur.lua")
includeCS("filemanagement.lua")
includeSV("assignment.lua")
includeSV("logging.lua")
includeCS("renderer.lua")
includeSH("language.lua")
includeCS("properties.lua")

ImageStickers.Log("Loaded!")
