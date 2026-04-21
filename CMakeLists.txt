cmake_minimum_required(VERSION 3.11)
project(mmlgui LANGUAGES C CXX)

if(APPLE)
	set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build only for Apple Silicon" FORCE)
endif()

find_package(PkgConfig REQUIRED)
find_package(OpenGL REQUIRED)

find_package(glfw3 CONFIG QUIET)
if(NOT glfw3_FOUND)
	pkg_check_modules(GLFW3 REQUIRED glfw3)
endif()
pkg_check_modules(CPPUNIT cppunit)

if(MINGW)
	option(LINK_STATIC_LIBS "link with static runtime libraries (MinGW only)" ON)
	if(LINK_STATIC_LIBS)
		set(CMAKE_FIND_LIBRARY_SUFFIXES .a ${CMAKE_FIND_LIBRARY_SUFFIXES})
		set(CMAKE_CXX_STANDARD_LIBRARIES "-static-libgcc -static-libstdc++ -lwsock32 -lws2_32 ${CMAKE_CXX_STANDARD_LIBRARIES}")
		#This gets already set by libvgm...
		#set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive")
		set(GLFW3_LIBRARIES -static ${GLFW3_STATIC_LIBRARIES} -dynamic)
	endif()
else()
	option(LINK_STATIC_LIBS "link with static runtime libraries (MinGW only)" OFF)
endif()

add_subdirectory(ctrmml)

# These options are required by the libvgm submodule.
# Currently it cannot be updated because this results in no audio.
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
set(CMAKE_C_STANDARD 11)
add_subdirectory(libvgm)

add_library(gui
	imgui/imgui.cpp
	imgui/imgui_demo.cpp
	imgui/imgui_draw.cpp
	imgui/imgui_widgets.cpp
	imgui/examples/imgui_impl_glfw.cpp
	imgui/examples/imgui_impl_opengl3.cpp
	imgui/examples/libs/gl3w/GL/gl3w.c
	imgui/addons/imguifilesystem/imguifilesystem.cpp
	ImGuiColorTextEdit/TextEditor.cpp)

target_include_directories(gui PUBLIC
	imgui
	imgui/examples
	imgui/examples/libs/gl3w
	ImGuiColorTextEdit
	${GLFW3_INCLUDE_DIRS})

if(TARGET glfw)
	target_link_libraries(gui PUBLIC OpenGL::GL glfw)
elseif(TARGET glfw3)
	target_link_libraries(gui PUBLIC OpenGL::GL glfw3)
else()
	target_link_libraries(gui PUBLIC OpenGL::GL ${GLFW3_LIBRARIES})
endif()

if(APPLE)
	find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
	target_link_libraries(gui PUBLIC ${COREFOUNDATION_FRAMEWORK})
endif()

target_compile_definitions(gui PUBLIC -DIMGUI_IMPL_OPENGL_LOADER_GL3W)

set(MMLGUI_SOURCES
	src/main.cpp
	src/window.cpp
	src/main_window.cpp
	src/editor_window.cpp
	src/song_manager.cpp
	src/track_info.cpp
	src/track_view_window.cpp
	src/track_list_window.cpp
	src/audio_manager.cpp
	src/emu_player.cpp
	src/config_window.cpp
	src/dmf_importer.cpp
	src/miniz.c)

if(APPLE)
	set(MMLGUI_MACOS_ICON assets/macos/AppIcon.icns)
	set_source_files_properties(${MMLGUI_MACOS_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
	add_executable(mmlgui MACOSX_BUNDLE ${MMLGUI_SOURCES} ${MMLGUI_MACOS_ICON})
	set_target_properties(mmlgui PROPERTIES
		MACOSX_BUNDLE_BUNDLE_NAME "mmlgui"
		MACOSX_BUNDLE_GUI_IDENTIFIER "com.superctr.mmlgui"
		MACOSX_BUNDLE_BUNDLE_VERSION "0.1.0"
		MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.0"
		MACOSX_BUNDLE_LONG_VERSION_STRING "0.1.0"
		MACOSX_BUNDLE_COPYRIGHT "Copyright 2020-2021 Ian Karlsson"
		MACOSX_BUNDLE_ICON_FILE "AppIcon.icns")

	add_custom_target(mmlgui_dmg
		COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/scripts/package_macos_dmg.sh"
			"$<TARGET_BUNDLE_DIR:mmlgui>"
			"${CMAKE_CURRENT_SOURCE_DIR}/dist/mmlgui-mac-arm64.dmg"
		DEPENDS mmlgui
		COMMENT "Packaging mmlgui.app into a macOS DMG")
else()
	add_executable(mmlgui ${MMLGUI_SOURCES})
endif()

target_link_libraries(mmlgui PRIVATE ctrmml gui vgm-utils vgm-audio vgm-emu)
target_compile_definitions(mmlgui PRIVATE -DLOCAL_LIBVGM)

if(CPPUNIT_FOUND)
	add_executable(mmlgui_unittest
		src/track_info.cpp
		src/unittest/test_track_info.cpp
		src/unittest/main.cpp)
	target_link_libraries(mmlgui_unittest ctrmml)
	target_link_libraries(mmlgui_unittest ${CPPUNIT_LIBRARIES})
	enable_testing()
	add_test(NAME run_mmlgui_unittest COMMAND mmlgui_unittest WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endif()
