#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

FORCE=false
BUILD_ROM=false
BUILD_TARGET_FILES=true
BUILD_FLASHABLE_ZIP=false

START_TIME="$(date +%s)"

SOURCE_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

GET_WORK_DIR_HASH()
{
    find "$SRC_DIR/unica" "$SRC_DIR/target/$TARGET_CODENAME" -type f -print0 | \
        sort -z | xargs -0 sha1sum | sha1sum | cut -d " " -f 1
}

PREPARE_SCRIPT()
{
    while [ "$#" != 0 ]; do
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--no-target-files" ]] || [[ "$1" == "-x" ]]; then
            BUILD_TARGET_FILES=false
            BUILD_FLASHABLE_ZIP=false
        elif [[ "$1" == "--build-rom-zip" ]] || [[ "$1" == "-z" ]]; then
            BUILD_TARGET_FILES=true
            BUILD_FLASHABLE_ZIP=true
        else
            if [[ "$1" == "-"* ]]; then
                LOGE "알 수 없는 옵션입니다: $1"
            fi
            PRINT_USAGE
            exit 1
        fi

        shift
    done
}

PRINT_BUILD_OUTCOME()
{
    local EXIT_CODE="$?"
    local END_TIME
    local ESTIMATED

    END_TIME="$(date +%s)"
    ESTIMATED="$((END_TIME - START_TIME))"

    if [ "$EXIT_CODE" != "0" ]; then
        echo -n -e '\n\033[1;31m'"빌드 실패 "'\033[0m'
    else
        echo -n -e '\n\033[1;32m'"빌드 완료 "'\033[0m'
    fi
    echo -e "$((ESTIMATED / 3600))시간 $(((ESTIMATED / 60) % 60))분 $((ESTIMATED % 60))초 소요됨.\n"
}

PRINT_USAGE()
{
    echo "사용 예제: make_rom [옵션]" >&2
    echo " -f, --force            : ROM 빌드를 강제합니다." >&2
    echo " -x, --no-target-files  : target-files zip을 빌드하지 않습니다." >&2
    echo " -z, --build-rom-zip    : 플래싱 가능한 zip 파일을 빌드합니다." >&2
}
# ]

PREPARE_SCRIPT "$@"

if $FORCE; then
    BUILD_ROM=true
else
    if [ -f "$WORK_DIR/.completed" ]; then
        if [[ "$(cat "$WORK_DIR/.completed")" == "$(GET_WORK_DIR_HASH)" ]]; then
            LOGW "빌드 환경에서 변경 사항이 감지되지 않았습니다."
            BUILD_ROM=false
        else
            LOGW "빌드 환경에서 변경 사항이 감지되었습니다."
            BUILD_ROM=true
        fi
    else
        BUILD_ROM=true
    fi
fi

trap 'PRINT_BUILD_OUTCOME' EXIT
trap 'echo' INT

if $BUILD_ROM; then
    [ -d "$APKTOOL_DIR" ] && rm -rf "$APKTOOL_DIR"
    [ -f "$WORK_DIR/.completed" ] && rm -f "$WORK_DIR/.completed"

    if [ ! -f "$FW_DIR/$SOURCE_FIRMWARE_PATH/.extracted" ] || [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/.extracted" ]; then
        if [ ! -f "$ODIN_DIR/$SOURCE_FIRMWARE_PATH/.downloaded" ] || [ ! -f "$ODIN_DIR/$TARGET_FIRMWARE_PATH/.downloaded" ]; then
            LOG_STEP_IN true "필요한 펌웨어 다운로드 중..."
            "$SRC_DIR/scripts/download_fw.sh" || exit 1
            LOG_STEP_OUT
        fi
        LOG_STEP_IN true "필요한 펌웨어 압축 해제 중..."
        "$SRC_DIR/scripts/extract_fw.sh" || exit 1
        LOG_STEP_OUT
    fi

    LOG_STEP_IN true "작업 디렉토리 생성 중..."
    "$SRC_DIR/scripts/internal/create_work_dir.sh" || exit 1
    LOG_STEP_OUT

    if [ -d "$SRC_DIR/platform/$TARGET_PLATFORM/patches" ]; then
        LOG_STEP_IN true "플랫폼 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/platform/$TARGET_PLATFORM/patches" || exit 1
        LOG_STEP_OUT
    fi
    if [ -d "$SRC_DIR/target/$TARGET_CODENAME/patches" ]; then
        LOG_STEP_IN true "타겟 디바이스 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/target/$TARGET_CODENAME/patches" || exit 1
        LOG_STEP_OUT
    fi
    if [ -d "$SRC_DIR/unica/patches" ]; then
        LOG_STEP_IN true "ROM 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/unica/patches" || exit 1
        LOG_STEP_OUT
    fi

    if [ -d "$SRC_DIR/unica/mods" ]; then
        LOG_STEP_IN true "ROM 모드 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/unica/mods" || exit 1
        LOG_STEP_OUT
    fi

    if [ -d "$APKTOOL_DIR" ]; then
        LOG_STEP_IN true "APK 및 JAR 파일 빌드 중..."

        while IFS= read -r f; do
            f="${f/$APKTOOL_DIR\//}"
            PARTITION="$(cut -d "/" -f 1 -s <<< "$f")"
            if [[ "$PARTITION" == "system" ]]; then
                "$SRC_DIR/scripts/apktool.sh" b "system" "$f" &
            else
                "$SRC_DIR/scripts/apktool.sh" b "$PARTITION" "$(cut -d "/" -f 2- -s <<< "$f")" &
            fi
        done < <(find "$APKTOOL_DIR" -type d \( -name "*.apk" -o -name "*.jar" \))

        # shellcheck disable=SC2046
        wait $(jobs -p) || exit 1

        LOG_STEP_OUT
    fi

    echo -n "$(GET_WORK_DIR_HASH)" > "$WORK_DIR/.completed"
fi

if $BUILD_TARGET_FILES || $BUILD_FLASHABLE_ZIP; then
    ZIP_FILE_NAME="${TARGET_CODENAME}_"
    if [ "$(GET_PROP "system" "ro.unica.version")" ]; then
        ZIP_FILE_NAME+="$(GET_PROP "system" "ro.unica.version")"
    else
        ZIP_FILE_NAME+="$ROM_VERSION"
    fi
    ZIP_FILE_NAME+="_target_files.zip"

    if [ ! -f "$OUT_DIR/$ZIP_FILE_NAME" ]; then
        LOG_STEP_IN true "target-files zip 생성 중..."
        "$SRC_DIR/scripts/internal/create_target_files_zip.sh" "$OUT_DIR/$ZIP_FILE_NAME" || exit 1
        LOG_STEP_OUT
    else
        LOGW "파일이 이미 존재합니다: ${OUT_DIR//$SRC_DIR\//}/$ZIP_FILE_NAME"
    fi

    if $BUILD_FLASHABLE_ZIP; then
        LOG_STEP_IN true "플래싱 가능한 zip 파일 생성 중..."
        "$SRC_DIR/scripts/build_flashable_zip.sh" "$OUT_DIR/$ZIP_FILE_NAME" || exit 1
        LOG_STEP_OUT
    fi
fi

exit 0