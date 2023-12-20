file.CreateDir("temp/imagesticker")

local function cleanup()
    local files = file.Find("temp/imagesticker/*", "DATA")
    for _, v in ipairs(files) do
        local file_time = file.Time("temp/imagesticker/" .. v, "DATA")
        if os.time() - file_time > 5 then
            file.Delete("temp/imagesticker/" .. v)
        end
    end
end

--timer.Create("march.imagestickers.cleanup", 5, 0, function() end)
cleanup()