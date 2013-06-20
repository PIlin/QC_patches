
#set(APPS "/Users/pavel/Library/Graphics/Quartz Composer Plug-Ins/GoogleSpeechPlugin.plugin/")
set(APPS "/Users/pavel/code/QC_patches/GoogleSpeechPlugin 20.06.13 16.09/Users/pavel/Library/Graphics/Quartz Composer Plug-Ins/GoogleSpeechPlugin.plugin")

set(BU_CHMOD_BUNDLE_ITEMS 1)

include(${CMAKE_CURRENT_SOURCE_DIR}/BundleUtilities.cmake)

fixup_bundle("${APPS}" "" "")

is_file_executable("/usr/bin/file" is_executable)