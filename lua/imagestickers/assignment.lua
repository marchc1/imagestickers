local classname = "image_sticker"
hook.Add("PlayerSpawnedSENT", "march.imagesticker.playerspawned", function(ply, ent)
    if ent:GetClass() == classname then
        ent.StickerOwner = ply
    end
end)