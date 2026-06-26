# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || return 1
# ]

# COMPARE_SEC_BUILD_VERSION <string1> <string2>
# `string1` 빌드 번호가 `string2` 빌드 번호보다 이전(과거) 버전인지 여부를 반환합니다.
COMPARE_SEC_BUILD_VERSION()
{
    local STRING1="$1"
    local STRING2="$2"

    STRING1="$(cut -d "/" -f 1 -s <<< "$STRING1")"
    STRING2="$(cut -d "/" -f 1 -s <<< "$STRING2")"

    # 삼성 안드로이드 OS 빌드 버전 규칙은 다음과 같이 구성됩니다 (예: A528BXXU1DWA4):
    # - A528B: 모델 번호 (Model number)
    # - XX: 지역 코드 (Region / XX = EUR_OPEN)
    # - U: 펌웨어 타입 (Firmware type / U = 전체 업데이트, S = 보안 업데이트)
    # - 1: 롤백 방지 비트 (Rollback protection bit)
    # - D: 주요 OS 버전 (Major OS version / D = 4번째 OS 출시 버전)
    # - W: 연도 (Year / W = 2023년)
    # - A: 월 (Month / A = 1월)
    # - 4: 순차 빌드 버전 (Incremental version)
    local STRING1_MAJOR="${STRING1:${#STRING1}-4:1}"
    local STRING1_YEAR="${STRING1:${#STRING1}-3:1}"
    local STRING1_MONTH="${STRING1:${#STRING1}-2:1}"
    local STRING1_INCREMENTAL="${STRING1:${#STRING1}-1:1}"

    local STRING2_MAJOR="${STRING2:${#STRING2}-4:1}"
    local STRING2_YEAR="${STRING2:${#STRING2}-3:1}"
    local STRING2_MONTH="${STRING2:${#STRING2}-2:1}"
    local STRING2_INCREMENTAL="${STRING2:${#STRING2}-1:1}"

    [[ "$STRING1_MAJOR" > "$STRING2_MAJOR" ]] && return 0
    [[ "$STRING1_MAJOR" < "$STRING2_MAJOR" ]] && return 1
    [[ "$STRING1_YEAR" > "$STRING2_YEAR" ]] && return 0
    [[ "$STRING1_YEAR" < "$STRING2_YEAR" ]] && return 1
    [[ "$STRING1_MONTH" > "$STRING2_MONTH" ]] && return 0
    [[ "$STRING1_MONTH" < "$STRING2_MONTH" ]] && return 1
    [[ "$STRING1_INCREMENTAL" > "$STRING2_INCREMENTAL" ]] && return 0
    [[ "$STRING1_INCREMENTAL" < "$STRING2_INCREMENTAL" ]] && return 1

    return 0
}

# EXTRACT_FILE_FROM_TAR <tar> <file>
# 지정한 tar 아카이브 파일에서 원하는 파일을 추출합니다.
EXTRACT_FILE_FROM_TAR()
{
    _CHECK_NON_EMPTY_PARAM "MODEL" "$MODEL" || return 1
    _CHECK_NON_EMPTY_PARAM "CSC" "$CSC" || return 1
    _CHECK_NON_EMPTY_PARAM "TAR" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1

    local TAR="$1"
    local FILE="$2"

    if [ ! -f "$TAR" ]; then
        LOGE "파일이 존재하지 않습니다: ${TAR//$SRC_DIR\//}"
        return 1
    fi

    [ -f "$FW_DIR/${MODEL}_${CSC}/$FILE" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}/$FILE"
    [ -f "$FW_DIR/${MODEL}_${CSC}/$FILE.ext4" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}/$FILE.ext4"
    [ -f "$FW_DIR/${MODEL}_${CSC}/$FILE.lz4" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}/$FILE.lz4"

    if FILE_EXISTS_IN_TAR "$TAR" "$FILE"; then
        LOG "- $FILE 추출 중..."
        EVAL "tar xf \"$TAR\" -C \"$FW_DIR/${MODEL}_${CSC}\" \"$FILE\"" || return 1
    elif FILE_EXISTS_IN_TAR "$TAR" "$FILE.ext4"; then
        LOG "- $FILE.ext4 추출 중..."
        EVAL "tar xf \"$TAR\" -C \"$FW_DIR/${MODEL}_${CSC}\" \"$FILE.ext4\"" || return 1
        EVAL "mv -f \"$FW_DIR/${MODEL}_${CSC}/$FILE.ext4\" \"$FW_DIR/${MODEL}_${CSC}/$FILE\"" || return 1
    elif FILE_EXISTS_IN_TAR "$TAR" "$FILE.lz4"; then
        LOG "- $FILE.lz4 추출 중..."
        EVAL "tar xf \"$TAR\" -C \"$FW_DIR/${MODEL}_${CSC}\" \"$FILE.lz4\"" || return 1
        LOG "- $FILE.lz4 압축 해제 중..."
        EVAL "lz4 -d --rm \"$FW_DIR/${MODEL}_${CSC}/$FILE.lz4\" \"$FW_DIR/${MODEL}_${CSC}/$FILE\"" || return 1
    fi

    return 0
}

# FILE_EXISTS_IN_TAR <tar> <file>
# 지정한 tar 아카이브 파일 내에 원하는 파일이 존재하는지 여부를 반환합니다.
FILE_EXISTS_IN_TAR()
{
    _CHECK_NON_EMPTY_PARAM "TAR" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1

    tar tf "$1" "$2" &> /dev/null
    return $?
}

# GET_LATEST_FIRMWARE <model> <csc>
# 지정한 모델 및 CSC에 대해 이용 가능한 최신 펌웨어 버전을 PDA/CSC/MODEM 형식으로 반환합니다.
GET_LATEST_FIRMWARE()
{
    _CHECK_NON_EMPTY_PARAM "MODEL" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "CSC" "$2" || return 1

    curl -s --retry 3 -m 3 "https://fota-cloud-dn.ospserver.net/firmware/$2/$1/version.xml" \
        | perl -nE 'say $1 if /<latest[^>]*>(.*?)<\/latest>/'
}

# PARSE_FIRMWARE_STRING <string>
# 전달받은 문자열을 파싱하여 MODEL, CSC, IMEI, SERIAL_NO 변수에 각각 저장합니다.
# - 입력할 문자열은 반드시 다음 형식이어야 합니다: <MODEL>/<CSC>/<IMEI 또는 시리얼번호>
# - FUS 서버로부터 펌웨어를 다운로드하려면 해당 모델과 일치하는 IMEI 또는 시리얼번호(SN)가 필요합니다.
PARSE_FIRMWARE_STRING()
{
    local STRING="$1"

    if [ ! "$STRING" ]; then
        LOGE "펌웨어 값은 비어 있을 수 없습니다."
        return 1
    fi

    MODEL="$(cut -d "/" -f 1 -s <<< "$STRING")"
    if [ ! "$MODEL" ]; then
        LOGE "\"$STRING\" 문자열에서 디바이스 모델 값을 찾을 수 없습니다."
        return 1
    fi

    CSC="$(cut -d "/" -f 2 -s <<< "$STRING")"
    if [ ! "$CSC" ]; then
        LOGE "\"$STRING\" 문자열에서 CSC 값을 찾을 수 없습니다."
        return 1
    elif [[ "${#CSC}" != "3" ]]; then
        LOGE "\"$STRING\" 내의 CSC 값이 올바르지 않습니다: $CSC"
        return 1
    fi

    local THIRD
    THIRD="$(cut -d "/" -f 3 -s <<< "$STRING")"
    if [ ! "$THIRD" ]; then
        LOGE "\"$STRING\" 문자열에서 IMEI 또는 시리얼번호(SN) 값을 찾을 수 없습니다"
        return 1
    elif [[ "${#THIRD}" == "11" ]] && [[ "$THIRD" == "R"* ]]; then
        SERIAL_NO="$THIRD"
    elif [[ "${#THIRD}" -ge "8" ]] && [[ "${#THIRD}" -le "15" ]] && [[ "$THIRD" =~ ^[+-]?[0-9]+$ ]]; then
        # samloader가 앞 8자리 숫자(TAC)만으로도 나머지 자리를 생성할 수 있으므로, 불완전한 IMEI 형태도 허용합니다.
        IMEI="$THIRD"
    else
        LOGE "\"$STRING\" 내에 올바른 형신의 IMEI 또는 시리얼번호(SN)가 없습니다: $THIRD"
        return 1
    fi

    return 0
}

# UNSPARSE_IMAGE <file> [output]
# Sparse 형태의 안드로이드 이미지를 일반 이미지로 복원합니다. 선택적으로 별도의 출력 경로를 지정할 수 있습니다.
UNSPARSE_IMAGE()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || exit 1

    local FILE="$1"
    local OUTPUT_PATH="$2"
    local REPLACE=false

    if [ ! -f "$FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FILE//$SRC_DIR\//}"
        return 1
    fi

    if ! IS_SPARSE_IMAGE "$FILE"; then
        LOGW "올바른 안드로이드 sparse 이미지가 아닙니다: ${FILE//$SRC_DIR\//}"
        return 0
    fi

    if [ ! "$OUTPUT_PATH" ]; then
        OUTPUT_PATH="$(dirname "$FILE")/unsparse_$(basename "$FILE")"
        REPLACE=true
    fi

    LOG "- $(basename "$FILE") 파일 unsparse 중..."

    EVAL "simg2img \"$FILE\" \"$OUTPUT_PATH\"" || return 1
    if $REPLACE; then
        mv -f "$OUTPUT_PATH" "$FILE"
    fi

    return 0
}