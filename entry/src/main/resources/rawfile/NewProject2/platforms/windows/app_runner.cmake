#
# Copyright (C) 2023 Huawei Technologies Co, Ltd.
#

set(_PROJECT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../")

function(readProjectProperty outputVariable propertyName defaultValue)
  string(JSON _output ERROR_VARIABLE _error GET ${_PROJECT_SETTINGS_JSON} project ${propertyName})
  if(_error)
    # Use the default if value was not found from the json.
    set(${outputVariable} ${defaultValue} PARENT_SCOPE)
  else()
    set(${outputVariable} ${_output} PARENT_SCOPE)
  endif()
endfunction()

# Load project settings json.
set(_PROJECT_SETTINGS_FILE "${_PROJECT_DIR}/projectsettings.json")
file(READ ${_PROJECT_SETTINGS_FILE} _PROJECT_SETTINGS_JSON)
readProjectProperty(STARTUP_URI startupUri "")
readProjectProperty(OUTPUT_COLORSPACE outputColorSpace "Default")
readProjectProperty(DEFAULT_SCENE_URI defaultScene "")
readProjectProperty(DEFAULT_FONT_URI defaultFontUri "")
readProjectProperty(DEFAULT_PALETTE_URI defaultPaletteUri "")
readProjectProperty(DEFAULT_LOCALE defaultLocale "en")
readProjectProperty(APP_UID appUid "")
readProjectProperty(APP_PATH appPath "")
readProjectProperty(CLEAR_ENABLED clearEnabled "0")
readProjectProperty(CLEAR_COLOR clearColor "00000000")

# parse localizations in use to a list
string(JSON LOC_LEN           ERROR_VARIABLE LOC_LEN_ERROR          LENGTH ${_PROJECT_SETTINGS_JSON} project localizations)
if(${LOC_LEN} GREATER 0)
  math(EXPR MAX_LOC_INDEX "${LOC_LEN} - 1")
  # Loop through each element of the JSON array.
  foreach(IDX RANGE ${MAX_LOC_INDEX})
      # Get the name from the current JSON element.
      string(JSON CUR_LOC GET ${_PROJECT_SETTINGS_JSON} project localizations ${IDX})
      list(APPEND LOCALIZATIONS_IN_USE_ARRAY ${CUR_LOC})
  endforeach()
endif()

# Load user SDK settings from an optional json file.
set(_SDK_SETTINGS_FILE "${_PROJECT_DIR}/usersettings.json")

if(NOT EXISTS ${_SDK_SETTINGS_FILE})
    set(_SDK_SETTINGS_FILE "${_PROJECT_DIR}/cache/sdk.json")
endif()

if(EXISTS ${_SDK_SETTINGS_FILE})
    file(READ ${_SDK_SETTINGS_FILE} _SDK_SETTINGS_JSON)

    # Read an array of strings "sdkPaths" to SDK_PATHS variable.
    string(JSON SDK_PATHS_LEN
        ERROR_VARIABLE SDK_PATHS_ERROR
        LENGTH ${_SDK_SETTINGS_JSON} sdkPaths)
    if(${SDK_PATHS_LEN} GREATER 0)
        math(EXPR MAX_SDK_PATHS_INDEX "${SDK_PATHS_LEN} - 1")
        foreach(IDX RANGE ${MAX_SDK_PATHS_INDEX})
            string(JSON CUR_SDK_PATH GET ${_SDK_SETTINGS_JSON} sdkPaths ${IDX})
            list(APPEND SDK_PATHS "${CUR_SDK_PATH}")
        endforeach()
    else()
        # Try the "sdkRootPath" property instead (to support old projects).
        string(JSON SDK_PATHS
            ERROR_VARIABLE SDK_PATHS_ERROR
            GET ${_SDK_SETTINGS_JSON} sdkRootPath)
    endif()
endif()

# Reconfigure if settings have changed.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_PROJECT_SETTINGS_FILE})

#
# Find the SDK.
#
if(DEFINED SDK_PATHS)
    foreach(_SDK_PATH ${SDK_PATHS})
        message(STATUS "SDK_PATH: ${_SDK_PATH}")
        if(EXISTS "${_SDK_PATH}/external")
            list(APPEND CMAKE_MODULE_PATH "${_SDK_PATH}/external")
            if(EXISTS "${_SDK_PATH}/external/sdkModules.cmake")
                include("${_SDK_PATH}/external/sdkModules.cmake")
            endif()
        else()
            list(APPEND CMAKE_MODULE_PATH "${_SDK_PATH}")
            if(EXISTS "${_SDK_PATH}/sdkModules.cmake")
                include("${_SDK_PATH}/sdkModules.cmake")
            endif()
        endif()
    endforeach()
    find_package(LumeSDK REQUIRED)
endif()

#
# Define required application dependencies.
#

find_package(AGPEngineDLL REQUIRED)
find_package(LumeUiToolkit REQUIRED)
find_package(LumeScene REQUIRED)
find_package(AppRunner REQUIRED)
find_package(PluginParticleSystem REQUIRED)

# Packaging will gather all the binaries that are listed in the global packaging properties.
# Not the nicest way but works for now.
set_property(GLOBAL APPEND PROPERTY APP_BINARIES
    # Runner executable and core engine.
    $<TARGET_FILE:Runtime::AppRunner>
    $<TARGET_FILE:AGPEngine::AGPEngineDLL>
)
set_property(GLOBAL APPEND PROPERTY APP_PLUGIN_BINARIES
    # SDK default plugins.
    $<TARGET_FILE:AGPRender::PluginAGPRender>
    $<TARGET_FILE:PluginFont::PluginFont>
    $<TARGET_FILE:AGP2D::PluginAGP2D>
    $<TARGET_FILE:AGP3D::PluginAGP3D>
    $<TARGET_FILE:PluginTXT::PluginTXT>
    $<TARGET_FILE:LumeMeta::Plugin>
    $<TARGET_FILE:LumeUi::Toolkit>
    $<TARGET_FILE:LumeScene::Plugin>
    # Editor extra plugins.
    # Other. Should be made a package instead.
    $<TARGET_FILE:PluginParticleSystem::PluginParticleSystem>
)
set_property(GLOBAL APPEND PROPERTY PACKAGE_PLUGIN_UIDS
    ad98b964-a219-4b65-8033-209f44ba3b24 # LumeScene
)

if(CORE_PERF_ENABLED)
    if(NOT TARGET PluginAGPPerfTrace)
        find_package(AGPPerfTrace REQUIRED)
    endif()
    set_property(GLOBAL APPEND PROPERTY APP_PLUGIN_BINARIES
        $<TARGET_FILE:AGPPerfTrace::PluginAGPPerfTrace>
    )
    set_property(GLOBAL APPEND PROPERTY PACKAGE_PLUGIN_UIDS
        6151083a-d86f-4037-9059-97f8d0616161 # PluginAGPPerfTrace
    )
endif()
