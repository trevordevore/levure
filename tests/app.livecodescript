script "app"
command InitializeApplication
  put levureAppFolder() & "/unit_test" into tFolder
  start using stack (tFolder & "/libUnitTest.livecodescript")
  put there is a stack (tFolder & "/show_test_results.livecode") into tStackLoaded
end InitializeApplication


command OpenApplication
  RunTests
end OpenApplication


command ProcessFiles pFiles

end ProcessFiles


command ProcessURLs pURLs

end ProcessURLs