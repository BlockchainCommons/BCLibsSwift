#!/usr/bin/env sh
set -e # abort if any command fails

MIN_IOS_VERSION="13.6"
MIN_MAC_VERSION="10.15"
PROJ_ROOT=${PWD}
DEPS_ROOT=${PROJ_ROOT}/deps
BUILD_ROOT=${PROJ_ROOT}/build

build_init()
{
  LIB_NAME=$1
  PLATFORM=$2
  ARCH=$3
  TARGET=$4
  HOST=$5
  SDK=$6
  BITCODE=$7
  VERSION=$8
  SDK_PATH=`xcrun -sdk ${SDK} --show-sdk-path`
  BUILD_ARCH_DIR=${BUILD_ROOT}/${PLATFORM}-${ARCH}
  PREFIX=${BUILD_ARCH_DIR}/${LIB_NAME}

  export CFLAGS="-O3 -arch ${ARCH} -isysroot ${SDK_PATH} ${BITCODE} ${VERSION} -target ${TARGET} -Wno-overriding-t-option"
  export CXXFLAGS="-O3 -arch ${ARCH} -isysroot ${SDK_PATH} ${BITCODE} ${VERSION} -target ${TARGET} -Wno-overriding-t-option"
  export LDFLAGS="-arch ${ARCH} ${BITCODE}"
  export CC="$(xcrun --sdk ${SDK} -f clang) -arch ${ARCH} -isysroot ${SDK_PATH}"
  export CXX="$(xcrun --sdk ${SDK} -f clang++) -arch ${ARCH} -isysroot ${SDK_PATH}"
}

build_bc_crypto_base()
{
  build_init bc-crypto-base $@

  pushd ${DEPS_ROOT}/bc-crypto-base

  cp ${PROJ_ROOT}/CCryptoBase.modulemap src/module.modulemap

  ./configure \
    --host=${HOST} \
    --prefix=${PREFIX}

  make clean
  make install
  make clean

  popd

  # Add the modulemap
  pushd ${PREFIX}/include/bc-crypto-base
  cp ${PROJ_ROOT}/CCryptoBase.modulemap module.modulemap
  popd
}

build_bc_shamir()
{
  build_init bc-shamir $@

  pushd ${DEPS_ROOT}/bc-shamir

  export CFLAGS+=" -I${BUILD_ARCH_DIR}/bc-crypto-base/include"
  export LDFLAGS+=" -L${BUILD_ARCH_DIR}/bc-crypto-base/lib"

  cp ${PROJ_ROOT}/CShamir.modulemap src/module.modulemap

  ./configure \
    --host=${HOST} \
    --prefix=${PREFIX}

  make clean
  make install
  make clean

  popd

  # Add the modulemap
  pushd ${PREFIX}/include/bc-shamir
  cp ${PROJ_ROOT}/CShamir.modulemap module.modulemap
  popd
}

build_csskr()
{
  build_init bc-sskr $@

  pushd ${DEPS_ROOT}/bc-sskr

  export CFLAGS+=" \
    -I${BUILD_ARCH_DIR}/bc-crypto-base/include \
    -I${BUILD_ARCH_DIR}/bc-shamir/include \
  "
  export LDFLAGS+=" \
    -L${BUILD_ARCH_DIR}/bc-crypto-base/lib \
    -L${BUILD_ARCH_DIR}/bc-shamir/lib \
  "

  cp ${PROJ_ROOT}/CSSKR.modulemap src/module.modulemap

  ./configure \
    --host=${HOST} \
    --prefix=${PREFIX}

  make clean
  make install
  make clean

  popd

  # Add the modulemap
  pushd ${PREFIX}/include/bc-sskr
  cp ${PROJ_ROOT}/CSSKR.modulemap module.modulemap
  popd
}

build_c_libraries()
(
  git submodule update --init

  IOS_ARM64_PARAMS=("ios" "arm64" "aarch64-apple-ios" "arm-apple-darwin" "iphoneos" "-fembed-bitcode" "-mios-version-min=${MIN_IOS_VERSION}")
  MAC_CATALYST_X86_64_PARAMS=("mac-catalyst" "x86_64" "x86_64-apple-ios13.0-macabi" "x86_64-apple-darwin" "macosx" "-fembed-bitcode" "-mmacosx-version-min=${MIN_MAC_VERSION}") # This is the build that runs under Catalyst
  IOS_SIMULATOR_X86_64_PARAMS=("ios-simulator" "x86_64" "x86_64-apple-ios" "x86_64-apple-darwin" "iphonesimulator" "-fembed-bitcode-marker" "-mios-simulator-version-min=${MIN_IOS_VERSION}")

  build_bc_crypto_base ${IOS_ARM64_PARAMS[@]}
  build_bc_crypto_base ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_bc_crypto_base ${IOS_SIMULATOR_X86_64_PARAMS[@]}

  build_bc_shamir ${IOS_ARM64_PARAMS[@]}
  build_bc_shamir ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_bc_shamir ${IOS_SIMULATOR_X86_64_PARAMS[@]}

  build_csskr ${IOS_ARM64_PARAMS[@]}
  build_csskr ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_csskr ${IOS_SIMULATOR_X86_64_PARAMS[@]}
)

build_c_xcframework()
{
  XC_FRAMEWORK=$1
  LIB_NAME=$2

  rm -rf "${BUILD_ROOT}/${XC_FRAMEWORK}.xcframework"
  xcodebuild -create-xcframework \
    -library "${BUILD_ROOT}/ios-arm64/${LIB_NAME}/lib/lib${LIB_NAME}.a" -headers "${BUILD_ROOT}/ios-arm64/${LIB_NAME}/include/" \
    -library "${BUILD_ROOT}/mac-catalyst-x86_64/${LIB_NAME}/lib/lib${LIB_NAME}.a" -headers "${BUILD_ROOT}/mac-catalyst-x86_64/${LIB_NAME}/include/" \
    -library "${BUILD_ROOT}/ios-simulator-x86_64/${LIB_NAME}/lib/lib${LIB_NAME}.a" -headers "${BUILD_ROOT}/ios-simulator-x86_64/${LIB_NAME}/include/" \
    -output "${BUILD_ROOT}/${XC_FRAMEWORK}.xcframework"
}

build_c_xcframeworks()
(
  build_c_xcframework CCryptoBase bc-crypto-base
  build_c_xcframework CShamir bc-shamir
  build_c_xcframework CSSKR bc-sskr
)

build_swift_framework()
{
  XC_FRAMEWORK=$1
  XC_ARCH=$2
  XC_BUILD_DIR_NAME=$3
  XC_SDK=$4
  XC_CATALYST=$5
  XC_VERSION=$6

  FRAMEWORK_ROOT=${PROJ_ROOT}/${XC_FRAMEWORK}

  XC_PROJECT=${FRAMEWORK_ROOT}/${XC_FRAMEWORK}.xcodeproj
  XC_SCHEME=${XC_FRAMEWORK}
  XC_BUILD_DIR=${BUILD_ROOT}/${XC_BUILD_DIR_NAME}
  XC_ARCHIVE_PATH=${XC_BUILD_DIR}/${XC_FRAMEWORK}.xcarchive
  rm -rf ${ARCHIVE_PATH}
  xcodebuild clean archive \
    -project ${XC_PROJECT} \
    -scheme ${XC_SCHEME} \
    -archivePath ${XC_ARCHIVE_PATH} \
    -sdk ${XC_SDK} \
    ${XC_VERSION} \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=${XC_ARCH} \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    SUPPORTS_MACCATALYST=${XC_CATALYST} \
    FRAMEWORK_SEARCH_PATHS="${BUILD_ROOT}/"
}

build_swift_frameworks()
(
  IOS_ARM64_PARAMS=("arm64" "ios-arm64" "iphoneos" "NO" "IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION}")
  MAC_CATALYST_X86_64_PARAMS=("x86_64" "mac-catalyst-x86_64" "macosx" "YES" "MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION}")
  IOS_SIMULATOR_X86_64_PARAMS=("x86_64" "ios-simulator-x86_64" "iphonesimulator" "NO" "IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION}")

  build_swift_framework CryptoBase ${IOS_ARM64_PARAMS[@]}
  build_swift_framework CryptoBase ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_swift_framework CryptoBase ${IOS_SIMULATOR_X86_64_PARAMS[@]}

  build_swift_framework Shamir ${IOS_ARM64_PARAMS[@]}
  build_swift_framework Shamir ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_swift_framework Shamir ${IOS_SIMULATOR_X86_64_PARAMS[@]}

  build_swift_framework SSKR ${IOS_ARM64_PARAMS[@]}
  build_swift_framework SSKR ${MAC_CATALYST_X86_64_PARAMS[@]}
  build_swift_framework SSKR ${IOS_SIMULATOR_X86_64_PARAMS[@]}
)

build_swift_xcframework()
{
  XC_FRAMEWORK=$1

  FRAMEWORK_PATH=${XC_FRAMEWORK}.xcarchive/Products/Library/Frameworks/${XC_FRAMEWORK}.framework

  rm -rf ${BUILD_ROOT}/${XC_FRAMEWORK}.xcframework
  xcodebuild -create-xcframework \
  -framework ${BUILD_ROOT}/ios-arm64/${FRAMEWORK_PATH} \
  -framework ${BUILD_ROOT}/mac-catalyst-x86_64/${FRAMEWORK_PATH} \
  -framework ${BUILD_ROOT}/ios-simulator-x86_64/${FRAMEWORK_PATH} \
  -output ${BUILD_ROOT}/${XC_FRAMEWORK}.xcframework
}

build_swift_xcframeworks()
(
  build_swift_xcframework CryptoBase
  build_swift_xcframework Shamir
  build_swift_xcframework SSKR
)

build_c_libraries
build_c_xcframeworks
build_swift_frameworks
build_swift_xcframeworks
