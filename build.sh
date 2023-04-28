#!/bin/zsh
set -e # abort if any command fails

MIN_IOS_VERSION=11
MIN_MAC_VERSION=11
PROJ_ROOT=${PWD}
DEPS_ROOT=${PROJ_ROOT}/deps
BUILD_ROOT=${PROJ_ROOT}/build
LIBS_ROOT=${BUILD_ROOT}/libs
ARCHIVES_ROOT=${BUILD_ROOT}/archives
BUILD_LOG=${PROJ_ROOT}/buildlog.txt
CPU_COUNT=$(sysctl hw.ncpu | awk '{print $2}')

source ./message_utils.sh

build_wally() {
  pushd ${DEPS_ROOT}/bc-libwally-core

  ./tools/cleanup.sh
  ./tools/autogen.sh

  if [[ ${TARGET} == arm64* ]]
  then
    HOST=arm-apple-darwin
  else
    HOST=x86_64-apple-darwin
  fi

  PKG_CONFIG_ALLOW_CROSS=1 \
  PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig \
  ./configure \
    --disable-shared \
    --enable-static \
    --host=${HOST} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  popd

  cp "${PROJ_ROOT}/BCWally/CBCWally.modulemap" "${PREFIX}/include/module.modulemap"

  # Remove unused headers
  pushd ${PREFIX}/include
  rm secp256k1*.h
  rm wally_elements.h
  rm wally.hpp
  popd
}

build_crypto_base() {
  pushd ${DEPS_ROOT}/bc-crypto-base

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  cp "${PROJ_ROOT}/CryptoBase/CCryptoBase.modulemap" "${PREFIX}/include/${LIB_NAME}/module.modulemap"

  popd
}

build_bip39()
{
  pushd ${DEPS_ROOT}/bc-bip39

  export CFLAGS="${CFLAGS} -I${BUILD_ARCH_DIR}/bc-crypto-base/include"
  export LDFLAGS="${LDFLAGS} -L${BUILD_ARCH_DIR}/bc-crypto-base/lib"

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  cp "${PROJ_ROOT}/BIP39/CBIP39.modulemap" "${PREFIX}/include/${LIB_NAME}/module.modulemap"

  popd
}

build_shamir()
(
  pushd ${DEPS_ROOT}/bc-shamir

  export CFLAGS="${CFLAGS} -I${BUILD_ARCH_DIR}/bc-crypto-base/include"
  export LDFLAGS="${LDFLAGS} -L${BUILD_ARCH_DIR}/bc-crypto-base/lib"

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  cp "${PROJ_ROOT}/Shamir/CShamir.modulemap" "${PREFIX}/include/${LIB_NAME}/module.modulemap"

  popd
)

build_sskr()
(
  pushd ${DEPS_ROOT}/bc-sskr

  export CFLAGS="${CFLAGS} \
    -I${BUILD_ARCH_DIR}/bc-crypto-base/include \
    -I${BUILD_ARCH_DIR}/bc-shamir/include \
  "

  export LDFLAGS="${LDFLAGS} \
    -L${BUILD_ARCH_DIR}/bc-crypto-base/lib \
    -L${BUILD_ARCH_DIR}/bc-shamir/lib \
  "

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  cp "${PROJ_ROOT}/SSKR/CSSKR.modulemap" "${PREFIX}/include/${LIB_NAME}/module.modulemap"

  popd
)

build_libs() (
  LIB_NAME=$1
  BUILD_FUNC=$2

  progress_subsection "Building C libraries for ${LIB_NAME}"

  TARGETS=(
    "arm64-apple-ios:iphoneos:-mios-version-min=${MIN_IOS_VERSION}"

    "arm64-apple-ios-macabi:macosx:-mmacosx-version-min=${MIN_MAC_VERSION}"
    "x86_64-apple-ios-macabi:macosx:-mmacosx-version-min=${MIN_MAC_VERSION}"

    "arm64-apple-ios-simulator:iphonesimulator:-mios-simulator-version-min=${MIN_IOS_VERSION}"
    "x86_64-apple-ios-simulator:iphonesimulator:-mios-simulator-version-min=${MIN_IOS_VERSION}"

    "arm64-apple-macos:macosx:-mmacosx-version-min=${MIN_MAC_VERSION}"
    "x86_64-apple-macos:macosx:-mmacosx-version-min=${MIN_MAC_VERSION}"
  )

  for TARGET_INFO in "${TARGETS[@]}"; do
    TARGET_INFO_PARTS=("${(@s/:/)TARGET_INFO}")
    TARGET=${TARGET_INFO_PARTS[1]}
    SDK=${TARGET_INFO_PARTS[2]}
    VERSION=${TARGET_INFO_PARTS[3]}

    progress_item "Building C library for ${LIB_NAME} ${TARGET} ${SDK}"

    SYSROOT=`xcrun -sdk ${SDK} --show-sdk-path`
    PREFIX="$LIBS_ROOT/$TARGET/$LIB_NAME"
    BUILD_ARCH_DIR=${BUILD_ROOT}/libs/${TARGET}

    export CFLAGS="-O3 -isysroot ${SYSROOT} -target ${TARGET} ${VERSION} -Wno-overriding-t-option"
    export CXXFLAGS="-O3 -isysroot ${SYSROOT} -target ${TARGET} -Wno-overriding-t-option ${VERSION}"
    export LDFLAGS="-target ${TARGET}"
    export CC="$(xcrun --sdk ${SDK} -f clang) -isysroot ${SYSROOT} -target ${TARGET} ${VERSION}"
    export CXX="$(xcrun --sdk ${SDK} -f clang++) -isysroot ${SYSROOT} -target ${TARGET} ${VERSION}"

    ${BUILD_FUNC} ${LIB_NAME} ${TARGET} ${SDK} ${SYSROOT}
  done
)

lipo_lib() (
  LIB_NAME=$1
  LIB=$2
  FAT_TARGET=$3

  progress_item "Creating fat binary for ${LIB} ${FAT_TARGET}"

  ARCHS=("arm64" "x86_64")
  ARCHIVE_NAME="lib${LIB}.a"

  FAT_TARGET_DIR="arm64 x86_64-${FAT_TARGET}"
  OUTPUT_DIR="${LIBS_ROOT}/${FAT_TARGET_DIR}"

  TARGET_LIB_DIR="${OUTPUT_DIR}/${LIB_NAME}/lib"
  TARGET_INCLUDE_DIR="${OUTPUT_DIR}/${LIB_NAME}/include"
  mkdir -p ${TARGET_LIB_DIR}
  mkdir -p ${TARGET_INCLUDE_DIR}

  INPUT_LIBS=()
  for ARCH in "${ARCHS[@]}"; do
    INPUT_LIBS+=("${LIBS_ROOT}/${ARCH}-${FAT_TARGET}/${LIB_NAME}/lib/${ARCHIVE_NAME}")
  done

  lipo -create -output "${TARGET_LIB_DIR}/${ARCHIVE_NAME}" ${INPUT_LIBS[@]}

  # Copy the header files and module.modulemap file
  SOURCE_INCLUDE_DIR="${LIBS_ROOT}/${ARCHS[1]}-${FAT_TARGET}/${LIB_NAME}/include"
  cp -r "${SOURCE_INCLUDE_DIR}"/* "${TARGET_INCLUDE_DIR}/"
)

lipo_libs() (
  LIB_NAME=$1
  BUILT_LIBS=$2

  progress_subsection "Creating fat binaries for ${LIB_NAME}"

  FAT_TARGETS=(
    "apple-macos"
    "apple-ios-macabi"
    "apple-ios-simulator"
  )

  # If BUILT_LIBS is not empty, then split it into A LIBS array at the commas.
  # If it's empty, then set LIBS to a single-element array containing LIB_NAME.
  LIBS=(${(s.,.)BUILT_LIBS:-${LIB_NAME}})

  for LIB in "${LIBS[@]}"; do
    for FAT_TARGET in "${FAT_TARGETS[@]}"; do
      lipo_lib ${LIB_NAME} ${LIB} ${FAT_TARGET}
    done
  done
)

build_framework() (
  FRAMEWORK=$1
  SCHEME=$2
  XCODE_PLATFORM=$3
  ARCHIVE_PLATFORM=$4
  SDKROOT=$5
  ARCHS=$6
  SHALLOW_BUNDLE_TRIPLE=$7
  LIB_NAME=$8
  ADD_LIB_TO_HEADER_SEARCH_PATH=$9
  LOCAL_LIBS=$10

  progress_item "Building ${FRAMEWORK} scheme ${SCHEME} for ${ARCHIVE_PLATFORM}"

  SEARCH_PATH_BASE=${LIBS_ROOT}/${ARCHS}-apple-${SHALLOW_BUNDLE_TRIPLE}

  LOCAL_LIBS_PARTS=(${(@s/,/)LOCAL_LIBS})
  LIBS=("${LIB_NAME}" "${(@)LOCAL_LIBS_PARTS}")

  HEADER_SEARCH_PATHS=""
  LIBRARY_SEARCH_PATHS=""
  for LIB in "${LIBS[@]}"; do
    HEADER_SEARCH_PATH=${SEARCH_PATH_BASE}/${LIB}/include
    if [[ ${ADD_LIB_TO_HEADER_SEARCH_PATH} == "true" ]]; then
      HEADER_SEARCH_PATH="${HEADER_SEARCH_PATH}/${LIB}"
    fi
    HEADER_SEARCH_PATHS="${HEADER_SEARCH_PATHS} \"${HEADER_SEARCH_PATH}\""

    LIBRARY_SEARCH_PATH=${SEARCH_PATH_BASE}/${LIB}/lib
    LIBRARY_SEARCH_PATHS="${LIBRARY_SEARCH_PATHS} \"${LIBRARY_SEARCH_PATH}\""
  done

  ARCHIVE_PATH="${ARCHIVES_ROOT}/${FRAMEWORK}-${ARCHIVE_PLATFORM}"
  rm -rf "${ARCHIVE_PATH}"

  xcodebuild -project ${FRAMEWORK}/${FRAMEWORK}.xcodeproj \
    -scheme ${SCHEME} \
    -destination generic/platform=${XCODE_PLATFORM} \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    SDKROOT=${SDKROOT} \
    ARCHS=${ARCHS} \
    HEADER_SEARCH_PATHS=${HEADER_SEARCH_PATHS} \
    LIBRARY_SEARCH_PATHS=${LIBRARY_SEARCH_PATHS} \
    SWIFT_INCLUDE_PATHS=${HEADER_SEARCH_PATHS} \
    IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION} \
    MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION} \
    clean archive
)

build_frameworks() (
  FRAMEWORK=$1
  SCHEME=$2
  LIB_NAME=$3
  ADD_LIB_TO_HEADER_SEARCH_PATH=$4
  LOCAL_LIBS=$5

  progress_subsection "Building ${FRAMEWORK} frameworks"

  PLATFORMS=(
    "iOS:iOS:iphoneos:arm64:ios"
    "iOS Simulator:iOS_Simulator:iphoneos:arm64 x86_64:ios-simulator"
    "macOS:Mac_Catalyst:iphoneos:arm64 x86_64:ios-macabi"
    "macOS:macOS:macosx:arm64 x86_64:macos"
  )

  for PLATFORM_INFO in "${PLATFORMS[@]}"; do
    PLATFORM_INFO_PARTS=("${(@s/:/)PLATFORM_INFO}")
    XCODE_PLATFORM=${PLATFORM_INFO_PARTS[1]}
    ARCHIVE_PLATFORM=${PLATFORM_INFO_PARTS[2]}
    SDKROOT=${PLATFORM_INFO_PARTS[3]}
    ARCHS=${PLATFORM_INFO_PARTS[4]}
    SHALLOW_BUNDLE_TRIPLE=${PLATFORM_INFO_PARTS[5]}

    build_framework ${FRAMEWORK} ${SCHEME} ${XCODE_PLATFORM} ${ARCHIVE_PLATFORM} \
      ${SDKROOT} ${ARCHS} ${SHALLOW_BUNDLE_TRIPLE} ${LIB_NAME} ${ADD_LIB_TO_HEADER_SEARCH_PATH} ${LOCAL_LIBS}
  done
)

build_xcframework() (
  FRAMEWORK=$1

  progress_subsection "Building ${FRAMEWORK} xcframework"

  OUTPUT_PATH="${BUILD_ROOT}/${FRAMEWORK}.xcframework"

  rm -rf "${OUTPUT_PATH}"

  xcodebuild -create-xcframework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-iOS.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-iOS_Simulator.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-Mac_Catalyst.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-macOS.xcarchive" -framework ${FRAMEWORK}.framework \
    -output "${OUTPUT_PATH}"
)

get_dependencies() (
  progress_section "Getting Dependencies"
  git submodule update --init --recursive
)

ignore() (
  IGNORE_PATH=$1
  if [ -e "${IGNORE_PATH}" ]; then
    echo "## Ignoring for Dropbox ${IGNORE_PATH}"
    xattr -w com.dropbox.ignored 1 "${IGNORE_PATH}" || true
    xattr -d com.dropbox.attrs "${IGNORE_PATH}" 2> /dev/null || true
  fi
)

(
  exec 3>/dev/tty

  export CONTEXT=subshell

  mkdir -p ${DEPS_ROOT}
  ignore ${DEPS_ROOT}

  mkdir -p ${BUILD_ROOT}
  ignore ${BUILD_ROOT}

  echo -n > ${BUILD_LOG}
  ignore ${BUILD_LOG}

  get_dependencies

  PROJECTS=(
    "bc-crypto-base:build_crypto_base:CryptoBase:CryptoBase:true"
    "bc-bip39:build_bip39:BIP39:BIP39:true:bc-crypto-base"
    "bc-shamir:build_shamir:Shamir:Shamir:true:bc-crypto-base"
    "bc-sskr:build_sskr:SSKR:SSKR:true:bc-crypto-base,bc-shamir"
    "bc-libwally-core/wallycore,secp256k1:build_wally:BCWally:BCWally:false"
  )

  for PROJECT_INFO in "${PROJECTS[@]}"; do
    PROJECT_INFO_PARTS=("${(@s/:/)PROJECT_INFO}")
    LIB_NAME=${PROJECT_INFO_PARTS[1]}
    BUILD_FUNC=${PROJECT_INFO_PARTS[2]}
    FRAMEWORK=${PROJECT_INFO_PARTS[3]}
    SCHEME=${PROJECT_INFO_PARTS[4]}
    ADD_LIB_TO_HEADER_SEARCH_PATH=${PROJECT_INFO_PARTS[5]}
    LOCAL_LIBS=${PROJECT_INFO_PARTS[6]}

    if [[ $LIB_NAME == */* ]]; then
      LIB_NAME_PARTS=("${(@s:/:)LIB_NAME}")
      LIB_NAME=${LIB_NAME_PARTS[1]}
      BUILT_LIBS=${LIB_NAME_PARTS[2]}
    fi

    progress_section "Building ${LIB_NAME} and ${FRAMEWORK}"

    build_libs ${LIB_NAME} ${BUILD_FUNC}
    lipo_libs ${LIB_NAME} ${BUILT_LIBS}
    build_frameworks ${FRAMEWORK} ${SCHEME} ${LIB_NAME} ${ADD_LIB_TO_HEADER_SEARCH_PATH} ${LOCAL_LIBS}
    build_xcframework ${FRAMEWORK}
  done

  progress_success "Done!"
) >>&| ${BUILD_LOG}
