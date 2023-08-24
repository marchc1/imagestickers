ImageStickers.Language = {}

function ImageStickers.Language.GetPhrase(phrase, default)
    local result = language.GetPhrase(phrase)

    if result == phrase and default ~= nil then
        return default
    end

    return phrase
end