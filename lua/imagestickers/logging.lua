ImageStickers.Logging = {
    filepath = "imagesticker_logs.csv"
}
local image_stickers_enablelogging = CreateConVar("imagestickers_enablelogging", 0, FCVAR_ARCHIVE, "Enables/disables logging of image URLs. By default, this is saved to data/imagesticker_logs.csv.")

if not file.Exists(ImageStickers.Logging.filepath, "DATA") then
    file.CreateDir(string.GetPathFromFilename(ImageStickers.Logging.filepath))
    file.Write(ImageStickers.Logging.filepath, "")
end

function ImageStickers.Logging.LogImageURLChange(self, link)
    if link == "" then return end
    local isImgur, imgurID, linkorerr = ImageStickers.IsImgurLink(link)

    if not isImgur then 
        hook.Run("march.imagesticker.badimageURL", owner, self, link, linkorerr)
    else
        local owner = self.StickerOwner
        local allowed = hook.Run("march.imagesticker.imageURLchanged", owner, self, link)

        if allowed == false then
            self:SetImageURL("[blocked]")
        end

        if image_stickers_enablelogging:GetBool() then
            local date = os.date("%Y-%m-%dT%H:%M:%S%z")
            local date2 = string.sub(date, 1, #date-2) .. ":" .. string.sub(date, #date-1)
            file.Append(ImageStickers.Logging.filepath, "image.urlchanged," .. date2 .. "," .. (IsValid(owner) and owner:SteamID() or "N/A") .. "," .. link .. "," .. (allowed or "no objection") .. "\n" )
        end
    end
end