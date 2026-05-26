include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(se_tests
  test_encryption.cpp
  test_fall_detector.cpp
  test_pattern_matcher.cpp
  test_sms_analyzer.cpp
  test_phone_analyzer.cpp
)

target_link_libraries(se_tests PRIVATE
  security_engine
  GTest::gtest_main
)

target_include_directories(se_tests PRIVATE
  ${CMAKE_SOURCE_DIR}/include
)

include(GoogleTest)
gtest_discover_tests(se_tests)
