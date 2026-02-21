cmake_minimum_required(VERSION 3.16)
project(FlightPicker VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 COMPONENTS Quick QuickControls2 Widgets QUIET)
if(NOT Qt6_FOUND)
    find_package(Qt5 5.15 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
endif()

add_executable(FlightPicker
    main.cpp
    appsettings.h
    projectdata.h
    qml.qrc
)

target_compile_definitions(FlightPicker PRIVATE
    $<$<CONFIG:Debug>:QML_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}">
)

target_link_libraries(FlightPicker PRIVATE
    Qt::Quick
    Qt::QuickControls2
    Qt::Widgets
)
