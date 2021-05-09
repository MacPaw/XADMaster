#!/bin/bash

# BSD 3-Clause License
# 
# Copyright (c) 2021, Tim Oliver
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -e

# Main Definitions
UD_REPO="https://www.github.com/icomics/universal-detector.git"
FRAMEWORK_NAME="XADMaster"
BUILD_PATH="build/Build/Products"
DEVICE_PATH="Release-iphoneos"
CATALYST_PATH="Release-maccatalyst"
SIMULATOR_PATH="Release-iphonesimulator"

# Add a module map to a target directory
add_module_map() {
    TARGET_DIR=$1

    mkdir -p "${TARGET_DIR}/Modules"
cat <<EOT >> ${TARGET_DIR}/Modules/module.modulemap
framework module XADMaster {
  header "XADArchive.h"
  header "CSHandle.h"
  header "XADException.h"
  header "ClangAnalyser.h"
  export *
}
EOT
}

make_framework() {
    # If it doesn't exist, pull down the UniversalDetector repo
    if [ ! -d "../UniversalDetector" ]; then
        git clone ${UD_REPO} ../UniversalDetector
    fi

    # Delete the folder if present
    rm -rf build
    mkdir -p build

    # Build the simulator slice (But only Intel since we need XCFramework to support Apple Silicon)
    xcodebuild -project XADMaster.xcodeproj -scheme XADMaster-iOS -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
                -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES -derivedDataPath build clean build

    # Add the module map for Swift compatibility
    add_module_map "${BUILD_PATH}/${SIMULATOR_PATH}/${FRAMEWORK_NAME}.framework"

    # Build the Mac Catalyst slice
    xcodebuild -project XADMaster.xcodeproj -scheme XADMaster-iOS -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
                -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES -derivedDataPath build build

    # Add the module map for Swift compatibility
    add_module_map "${BUILD_PATH}/${CATALYST_PATH}/${FRAMEWORK_NAME}.framework"

    # Build all of the iOS slices of the framework
    xcodebuild -project XADMaster.xcodeproj -scheme XADMaster-iOS -sdk iphoneos -destination "generic/platform=iOS" \
                -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES -derivedDataPath build build

        # Add the module map for Swift compatibility
    add_module_map "${BUILD_PATH}/${DEVICE_PATH}/${FRAMEWORK_NAME}.framework"

    #Convert the library into an xcframework
    xcodebuild -create-xcframework \
            -framework ${BUILD_PATH}/${DEVICE_PATH}/${FRAMEWORK_NAME}.framework \
            -framework ${BUILD_PATH}/${CATALYST_PATH}/${FRAMEWORK_NAME}.framework \
            -framework ${BUILD_PATH}/${SIMULATOR_PATH}/${FRAMEWORK_NAME}.framework \
            -output build/${FRAMEWORK_NAME}.xcframework

    # Open the folder for us to see if
    open build
}

# Start the build process
make_framework
