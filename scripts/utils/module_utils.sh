# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/smali_utils.sh"
# ]

# ABORT <message>
# 빌드 프로세스를 중지하고, 제공된 경우 추가로 로그 메시지를 출력합니다.
ABORT()
{
    if [ "$1" ]; then
        LOGE "$1"
    fi
    return 1
}

# APPLY_PATCH <partition> <apk/jar> <patch>
# 제공된 APK/JAR 디코드된 디렉터리에 unified diff 패치를 적용합니다.
APPLY_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "PATCH" "$3" || return 1

    local PARTITION="$1"
    local FILE="$2"
    local PATCH="$3"

    if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\"은(는) 유효한 파티션 이름이 아닙니다."
        return 1
    fi

    if [ ! -f "$PATCH" ]; then
        LOGE "파일이 존재하지 않습니다: ${PATCH//$SRC_DIR\//}"
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    DECODE_APK "$PARTITION" "$FILE" || return 1

    LOG "- /$PARTITION/$FILE 에 \"$(grep "^Subject:" "$PATCH" | sed "s/.*PATCH] //")\" 패치를 적용합니다"
    EVAL "LC_ALL=C git apply --directory=\"$APKTOOL_DIR/$PARTITION/${FILE//system\//}\" --verbose --unsafe-paths \"$PATCH\"" || return 1
}

# DECODE_APK <partition> <apk/jar>
# `run_cmd apktool d <partition> <apk/jar>`와 사용법이 동일합니다.
DECODE_APK()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1

    if [ ! -d "$APKTOOL_DIR/$1/${2//system\/}" ]; then
        "$SRC_DIR/scripts/apktool.sh" d "$1" "$2"
        return $?
    fi

    return 0
}

# GET_GALAXY_STORE_DOWNLOAD_URL "<package name/id>"
# 삼성 서버에서 원하는 앱을 다운로드할 수 있는 URL을 반환합니다.
GET_GALAXY_STORE_DOWNLOAD_URL()
{
    _CHECK_NON_EMPTY_PARAM "PACKAGE" "$1" || return 1

    local PACKAGE="$1"
    local DEVICES
    local OS
    local ONEUI
    local PROTOCOL

    # Galaxy S25 Ultra EUR_OPENX
    # Galaxy S22 Ultra GBL_OPENX
    DEVICES=("SM-S938B" "SM-S901E")

    OS="$(GET_PROP "system" "ro.build.version.sdk")"
    ONEUI="$(GET_PROP "system" "ro.build.version.oneui")"

    if [ ! "$OS" ]; then
        # Android 16으로 대체(Fallback)
        OS="36"
    fi
    if [ ! "$ONEUI" ]; then
        # One UI 8.0으로 대체(Fallback)
        ONEUI="80000"
    fi

    PROTOCOL+="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"
    PROTOCOL+="<SamsungProtocol networkType=\"0\" openApiVersion=\"$OS\" deviceModel=\"DEVICE\""
    PROTOCOL+=" mcc=\"262\" mnc=\"01\" csc=\"EUX\" version=\"7.7\""
    PROTOCOL+=" deviceFeature=\"locale=en_GB||abi32=armeabi-v7a:armeabi||abi64=arm64-v8a||oneUiVersion=$ONEUI\">"
    PROTOCOL+="<request id=\"2303\" numParam=\"2\">"
    PROTOCOL+="<param name=\"stduk\">0</param>"
    PROTOCOL+="<param name=\"productID\">PRODUCTID</param>"
    PROTOCOL+="</request>"
    PROTOCOL+="</SamsungProtocol>"

    local OUT
    local REQUEST
    for i in "${DEVICES[@]}"; do
        if [[ "$PACKAGE" =~ ^[+-]?[0-9]+$ ]]; then
            OUT="$PACKAGE"
        else
            OUT="$(curl -L -s "https://vas.samsungapps.com/stub/stubUpdateCheck.as?appId=$PACKAGE&versionCode=0&deviceId=$i&mcc=262&mnc=01&csc=EUX&sdkVer=$OS&oneUiVersion=$ONEUI&systemId=0")"
            OUT="$(grep -o -P "(?<=<productId>)[^<]+" <<< "$OUT")"
            if [ ! "$OUT" ]; then
                continue
            fi
        fi

        REQUEST="$PROTOCOL"
        REQUEST="${REQUEST//DEVICE/$i}"
        REQUEST="${REQUEST//PRODUCTID/$OUT}"

        OUT="$(curl -L -s "https://uk-odc.samsungapps.com/ods.as" -H "Content-Type: text/plain" -d "$REQUEST")"
        OUT="$(grep -o -P "(?<=<value name=\"downLoadURI\">)[^<]+" <<< "$OUT")"
        if [ "$OUT" ]; then
            echo "${OUT//amp;/}"
            return 0
        fi
    done

    LOGE "\"$PACKAGE\" 앱의 다운로드 URI를 찾을 수 없습니다."
    return 1
}

# GET_FLOATING_FEATURE_CONFIG "<file>" "<config>"
# 제공된 설정값을 반환하며, 파일은 생략할 수 있습니다.
GET_FLOATING_FEATURE_CONFIG()
{
    local FILE
    if [ "$2" ]; then
        FILE="$1"
        shift
    else
        FILE="$WORK_DIR/system/system/etc/floating_feature.xml"
    fi

    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1" || return 1

    local CONFIG="$1"

    if [ ! -f "$FILE" ]; then
        LOGE "파일을 찾을 수 없습니다: ${FILE//$WORK_DIR/}"
        return 1
    fi

    grep -o -P "(?<=<$CONFIG>)[^<]+" "$FILE" 2> /dev/null || true
}

# HEX_PATCH "<file>" "<old pattern>" "<new pattern>"
# 원하는 파일에 제공된 헥스(hex) 패치를 적용합니다.
HEX_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FROM" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "TO" "$3" || return 1

    local FILE="$1"
    local FROM="$2"
    local TO="$3"

    if [ ! -f "$FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FILE//$WORK_DIR/}"
        return 1
    fi

    FROM="${FROM// /}"
    TO="${TO// /}"

    FROM="$(tr "[:upper:]" "[:lower:]" <<< "$FROM")"
    TO="$(tr "[:upper:]" "[:lower:]" <<< "$TO")"

    if ! xxd -p -c 0 "$FILE" | grep -q "$FROM"; then
        LOGE "${FILE//$WORK_DIR/} 에 \"$FROM\"와 일치하는 항목이 없습니다."
        return 1
    fi

    if [[ "$(echo -n "$FROM" | wc -c)" != "$(echo -n "$TO" | wc -c)" ]]; then
        LOGE "바이트 문자열의 길이가 같아야 합니다."
        return 1
    fi

    LOG "- ${FILE//$WORK_DIR/} 에서 \"$FROM\"을(를) \"$TO\"(으)로 패치합니다."
    xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"

    return 0
}

# SET_FLOATING_FEATURE_CONFIG "<config>" "<value>"
# 제공된 설정을 원하는 값으로 설정합니다.
# 설정을 삭제하려면 값으로 "-d" 또는 "--delete"를 전달할 수 있습니다.
SET_FLOATING_FEATURE_CONFIG()
{
    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "VALUE" "$2" || return 1

    local CONFIG="$1"
    local VALUE="$2"
    local FILE="$WORK_DIR/system/system/etc/floating_feature.xml"

    if [ ! -f "$FILE" ]; then
        LOGE "파일을 찾을 수 없습니다: ${FILE//$WORK_DIR/}"
        return 1
    fi

    if grep -q "$CONFIG" "$FILE"; then
        if [[ "$VALUE" == "-d" ]] || [[ "$VALUE" == "--delete" ]]; then
            LOG "- /system/system/etc/floating_feature.xml 에서 \"$CONFIG\" 설정을 삭제합니다"
            sed -i "/<$CONFIG>/d" "$FILE"
        else
            LOG "- /system/system/etc/floating_feature.xml 에서 \"$CONFIG\" 설정을 \"$VALUE\"(으)로 교체합니다"
            sed -i "$(sed -n "/<${CONFIG}>/=" "$FILE") c\ \ \ \ <${CONFIG}>${VALUE}</${CONFIG}>" "$FILE"
        fi
    elif [[ "$VALUE" != "-d" ]] && [[ "$VALUE" != "--delete" ]]; then
        LOG "- /system/system/etc/floating_feature.xml 에 값이 \"$VALUE\"인 \"$CONFIG\" 설정을 추가합니다"
        sed -i "/<\/SecFloatingFeatureSet>/d" "$FILE"
        if ! grep -q "Added by scripts" "$FILE"; then
            echo "    <!-- Added by scripts/utils/module_utils.sh -->" >> "$FILE"
        fi
        echo "    <${CONFIG}>${VALUE}</${CONFIG}>" >> "$FILE"
        echo "</SecFloatingFeatureSet>" >> "$FILE"
    fi

    return 0
}

# SET_PROP_IF_DIFF "<partition>" "<prop>" "<value>"
# 현재 prop 값이 일치하지 않으면 SET_PROP을 호출합니다. 파티션 이름은 생략할 수 없습니다.
SET_PROP_IF_DIFF()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "PROP" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "EXPECTED" "$3" || return 1

    local PARTITION="$1"
    local PROP="$2"
    local EXPECTED="$3"

    if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\"은(는) 유효한 파티션 이름이 아닙니다."
        return 1
    fi

    local CURRENT
    CURRENT="$(GET_PROP "$PARTITION" "$PROP")"
    [ -z "$CURRENT" ] || [ "$CURRENT" = "$EXPECTED" ] || SET_PROP "$PARTITION" "$PROP" "$EXPECTED"
}
