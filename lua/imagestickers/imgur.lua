--TODO: provide more hosting providers? allow servers to disable imgur exclusivity in favor of a whitelist system?
function ImageStickers.IsImgurLink(link)
    if link == "" then
        return false, "", "No URL"
    end

    --I do not like working with lua patterns
    if string.StartWith(link, "https://") then link = string.sub(link, 9) end
    if string.StartWith(link, "http://") then link = string.sub(link, 8) end

    if string.StartWith(link, "i.imgur.com/") then
        local id = string.Replace(link, "i.imgur.com/", "")

        local character_pos = 1
        local file_name = ""
        while true do
            local character = id[character_pos]
            if character == nil or character == "" then break end
            local character_byte = string.byte(character)

            if (character_byte >= 48 and character_byte <= 57) or (character_byte >= 65 and character_byte <= 90) or (character_byte >= 97 and character_byte <= 122) or character_byte == 46 then
                file_name = file_name .. character
            else
                break
            end

            character_pos = character_pos + 1
        end

        return true, file_name, link
    else
        if string.StartWith(link, "imgur.com/") then 
            return false, "", "Bad Imgur link (you need to get the i.imgur.com link, not the imgur.com link)"
        else
            return false, "", "Bad link (needs to be a i.imgur.com link)"
        end
    end

    return false, "", "Unknown issue"
end
