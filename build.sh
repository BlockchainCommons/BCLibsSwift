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

mkdir -p ${BUILD_ROOT}
echo -n > ${BUILD_LOG}

source ./message_utils.sh

build_crypto_base() {
  pushd ${DEPS_ROOT}/bc-crypto-base

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  cp ${PROJ_ROOT}/CryptoBase/CCryptoBase.modulemap ${PREFIX}/include/${LIB_NAME}/module.modulemap

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

  cp ${PROJ_ROOT}/BIP39/CBIP39.modulemap ${PREFIX}/include/${LIB_NAME}/module.modulemap

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

  cp ${PROJ_ROOT}/Shamir/CShamir.modulemap ${PREFIX}/include/${LIB_NAME}/module.modulemap

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

  cp ${PROJ_ROOT}/SSKR/CSSKR.modulemap ${PREFIX}/include/${LIB_NAME}/module.modulemap

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
    IFS=":" read -r TARGET SDK VERSION <<< "$TARGET_INFO"

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
  FAT_TARGET=$2

  progress_item "Creating fat binary for ${LIB_NAME} ${FAT_TARGET}"

  ARCHS=("arm64" "x86_64")
  ARCHIVE_NAME="lib${LIB_NAME}.a"

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

  progress_subsection "Creating fat binaries for ${LIB_NAME}"

  FAT_TARGETS=(
    "apple-macos"
    "apple-ios-macabi"
    "apple-ios-simulator"
  )

  for FAT_TARGET in "${FAT_TARGETS[@]}"; do
    lipo_lib ${LIB_NAME} ${FAT_TARGET}
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
  LOCAL_LIBS=$9

  progress_item "Building ${FRAMEWORK} scheme ${SCHEME} for ${ARCHIVE_PLATFORM}"

  SEARCH_PATH_BASE=${LIBS_ROOT}/${ARCHS}-apple-${SHALLOW_BUNDLE_TRIPLE}

  IFS=',' LOCAL_LIBS=(${(s.,.)LOCAL_LIBS})
  LIBS=("${LIB_NAME}" "${(@)LOCAL_LIBS}")

  HEADER_SEARCH_PATHS=""
  LIBRARY_SEARCH_PATHS=""
  for LIB in "${LIBS[@]}"; do
    HEADER_SEARCH_PATHS="${HEADER_SEARCH_PATHS} \"${SEARCH_PATH_BASE}/${LIB}/include/${LIB}\""
    LIBRARY_SEARCH_PATHS="${LIBRARY_SEARCH_PATHS} \"${SEARCH_PATH_BASE}/${LIB}/lib\""
  done

  xcodebuild -project ${FRAMEWORK}/${FRAMEWORK}.xcodeproj \
    -scheme ${SCHEME} \
    -destination generic/platform=${XCODE_PLATFORM} \
    -archivePath "${ARCHIVES_ROOT}/${FRAMEWORK}-${ARCHIVE_PLATFORM}" \
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
  LOCAL_LIBS=$4

  progress_subsection "Building ${FRAMEWORK} frameworks"

  PLATFORMS=(
    "iOS:iOS:iphoneos:arm64:ios"
    "iOS Simulator:iOS_Simulator:iphoneos:arm64 x86_64:ios-simulator"
    "macOS:Mac_Catalyst:iphoneos:arm64 x86_64:ios-macabi"
    "macOS:macOS:macosx:arm64 x86_64:macos"
  )

  for PLATFORM_INFO in "${PLATFORMS[@]}"; do
    IFS=":" read -r XCODE_PLATFORM ARCHIVE_PLATFORM SDKROOT ARCHS SHALLOW_BUNDLE_TRIPLE <<< "$PLATFORM_INFO"

    build_framework ${FRAMEWORK} ${SCHEME} ${XCODE_PLATFORM} ${ARCHIVE_PLATFORM} \
      ${SDKROOT} ${ARCHS} ${SHALLOW_BUNDLE_TRIPLE} ${LIB_NAME} ${LOCAL_LIBS}
  done
)

build_xcframework() (
  FRAMEWORK=$1

  progress_subsection "Building ${FRAMEWORK} xcframework"

  xcodebuild -create-xcframework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-iOS.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-iOS_Simulator.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-Mac_Catalyst.xcarchive" -framework ${FRAMEWORK}.framework \
    -archive "${ARCHIVES_ROOT}/${FRAMEWORK}-macOS.xcarchive" -framework ${FRAMEWORK}.framework \
    -output "${BUILD_ROOT}/${FRAMEWORK}.xcframework"
)

(
  exec 3>/dev/tty

  CONTEXT=subshell

  get_dependencies

  PROJECTS=(
    "bc-crypto-base:build_crypto_base:CryptoBase:CryptoBase"
    "bc-bip39:build_bip39:BIP39:BIP39:bc-crypto-base"
    "bc-shamir:build_shamir:Shamir:Shamir:bc-crypto-base"
    "bc-sskr:build_sskr:SSKR:SSKR:bc-crypto-base,bc-shamir"
  )

  for PROJECT_INFO in "${PROJECTS[@]}"; do
    IFS=":" read -r LIB_NAME BUILD_FUNC FRAMEWORK SCHEME LOCAL_LIBS <<< "$PROJECT_INFO"

    progress_section "Building ${LIB_NAME} and ${FRAMEWORK}"

    build_libs ${LIB_NAME} ${BUILD_FUNC}
    lipo_libs ${LIB_NAME}
    build_frameworks ${FRAMEWORK} ${SCHEME} ${LIB_NAME} ${LOCAL_LIBS}
    build_xcframework ${FRAMEWORK}
  done

  progress_success "Done!"
) >>&| ${BUILD_LOG}
