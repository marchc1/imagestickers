if SERVER then
    util.AddNetworkString("march.imagestickers.assignowner")

    local classname = "image_sticker"
    hook.Add("PlayerSpawnedSENT", "march.imagesticker.playerspawned", function(ply, ent)
        if ent:GetClass() == classname then
            ImageStickers.AssignOwner(ent, ply)
        end
    end)

    net.Receive("march.imagestickers.assignowner", function(len, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        net.Start("march.imagestickers.assignowner")
        net.WriteEntity(ent)
        net.WriteString(ent.StickerOwnerID)
        net.Send(ply)
    end)

    function ImageStickers.SendOwner(ent, ply)
        net.Start("march.imagestickers.assignowner")
        net.WriteEntity(ent)
        net.WriteString(ent.StickerOwnerID)
        net.Send(ply)
    end
end

if CLIENT then
    function ImageStickers.AskOwner(ent)
        net.Start("march.imagestickers.assignowner")
        net.WriteEntity(ent)
        net.SendToServer()
    end
    
    net.Receive("march.imagestickers.assignowner", function()
        local ent, ply = net.ReadEntity(), net.ReadString()
        if ply == "" then return end

        ent.StickerOwner = ply
    end)
end

function ImageStickers.AssignOwner(ent, ply)
    if ply ~= nil then
        ent.StickerOwner = ply
        ent.StickerOwnerID = ply:SteamID()
    end

    --print(ent.StickerOwner)
end
