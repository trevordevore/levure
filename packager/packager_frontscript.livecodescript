script "Levure Framework Application Packager FrontScript"
on standaloneSaved pFolderSavedIn
  dispatch "packagerStandaloneSaved" to stack "Levure Framework Application Packager" with pFolderSavedIn

  pass standaloneSaved
end standaloneSaved


on mobileStandaloneSaved pTargetType, pAppBundle
  dispatch "packagerMobileStandaloneSaved" to stack "Levure Framework Application Packager" with pTargetType, pAppBundle

  pass mobileStandaloneSaved
end mobileStandaloneSaved
