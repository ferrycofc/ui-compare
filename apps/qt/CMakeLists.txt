cmake_minimum_required(VERSION 3.21)
project(Nova LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)
qt_standard_project_setup()  # 打开 AUTOMOC：togglesw.h 里的 Q_OBJECT 自动生成元对象代码

qt_add_executable(Nova WIN32
    main.cpp
    togglesw.h
    togglesw.cpp
)

target_link_libraries(Nova PRIVATE Qt6::Widgets)

if(MSVC)
    target_compile_options(Nova PRIVATE /utf-8)  # 源码里有中文字面量
endif()
if(WIN32)
    target_link_libraries(Nova PRIVATE dwmapi)   # DwmSetWindowAttribute：深色标题栏
endif()
