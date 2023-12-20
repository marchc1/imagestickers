ImageStickers.Language = {}

function ImageStickers.Language.GetPhrase(phrase, default)
    if SERVER then return default or phrase end
    
    local result = language.GetPhrase(phrase)

    if result == phrase then
        if default == nil then 
            return phrase 
        else 
            return default 
        end
    end

    return result
end