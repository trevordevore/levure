script "appFontLoader"
on libraryStack
  if the target is me then
    if levurePropExists("fonts") then
      local tFontsA, i

      put levureAppGet("fonts") into tFontsA
      repeat with i = 1 to the number of elements of tFontsA
        if tFontsA[i]["global"] then
          start using font file tFontsA[i]["filename"] globally
        else
          start using font file tFontsA[i]["filename"]
        end if
      end repeat
    end if
  end if

  pass libraryStack
end libraryStack


on releaseStack
  if the target is me then
    if levurePropExists("fonts") then
      local tFontsA, i

      put levureAppGet("fonts") into tFontsA
      repeat with i = 1 to the number of elements of tFontsA
        stop using font file tFontsA[i]["filename"]
      end repeat
    end if
  end if

  pass releaseStack
end releaseStack
