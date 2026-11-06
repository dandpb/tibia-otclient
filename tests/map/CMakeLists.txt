set(MAP_TEST_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/map_spectators_test.cpp
)

if(TOGGLE_FRAMEWORK_PROTOBUF)
    list(APPEND MAP_TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/thingtype_corpse_test.cpp)
endif()

otclient_add_gtest(otclient_map_spectator_tests ${MAP_TEST_SOURCES})
if(TOGGLE_FRAMEWORK_PROTOBUF)
    target_compile_definitions(otclient_map_spectator_tests PRIVATE FRAMEWORK_PROTOBUF)
endif()
