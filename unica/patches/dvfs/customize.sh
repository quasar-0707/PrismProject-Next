if [[ "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" == "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ]] && \
    [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" == "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]]; then
    LOG "\033[0;33m! 아무 작업도 하지 않습니다\033[0m"
    return 0
fi

_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

SDHMS_APK="system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"
ASSETS_DIR="$APKTOOL_DIR/$SDHMS_APK/assets"
RAW_DIR="$APKTOOL_DIR/$SDHMS_APK/res/raw"
SIOP_MODEL="$SRC_DIR/target/$TARGET_CODENAME/dvfs/siop_model.xml"

if [[ "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ]]; then
    # framework
    SMALI_PATCH "system" "system/framework/ssrm.jar" \
        "smali/com/android/server/ssrm/Feature.smali" \
        "replace" "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"

    DECODE_APK "system" "$SDHMS_APK"

    DVFS_XML="$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml"

    if [ -f "$SRC_DIR/target/$TARGET_CODENAME/dvfs/$DVFS_XML" ]; then
        LOG "- /$SDHMS_APK/res/raw/$DVFS_XML 추가 중..."
        EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/dvfs/$DVFS_XML\" \"$RAW_DIR/$DVFS_XML\""
    elif [ ! -f "$RAW_DIR/$DVFS_XML" ]; then
        _LOG "\"$DVFS_XML\" does not exist in SDHMS app"
    fi

    while IFS="|" read -r FILE METHOD; do
        SMALI_PATCH "system" "$SDHMS_APK" \
            "$FILE" \
            "replace" \
            "$METHOD" \
            "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" \
            "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"
    done <<EOF
smali/r1/c.smali|<clinit>()V
smali/z1/e.smali|<init>(Landroid/content/Context;)V
EOF
fi

# SEC_PRODUCT_FEATURE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME
if [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]]; then
    SET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"

    SMALI_PATCH "system" "system/framework/ssrm.jar" \
        "smali/com/android/server/ssrm/Feature.smali" \
        "replace" "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"

    DECODE_APK "system" "$SDHMS_APK"

    if [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "ssrm_default" ]] &&
       [[ "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" == "ssrm_default" ]]; then

        for FILE in siop_default siop_model ssrm_default; do
            if [[ -e "$ASSETS_DIR/$FILE" ]]; then
                LOG "- /$SDHMS_APK/assets/$FILE 제거 중..."
                EVAL "rm -f \"$ASSETS_DIR/$FILE\""
            fi
        done

        for FILE in siop_default.xml ssrm_default.xml; do
            LOG "- /$SDHMS_APK/assets/$FILE 추가 중..."
            EVAL "cp -a \"$MODPATH/assets/siop_default.xml\" \"$ASSETS_DIR/$FILE\""
        done
    fi

    # com/sec/android/sdhms/util/Feature
    SMALI_PATCH "system" "$SDHMS_APK" \
        "smali/U1/w.smali" \
        "replace" "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"
fi

if [ -f "$SIOP_MODEL" ]; then
    DECODE_APK "system" "$SDHMS_APK"

    for FILE in siop_default siop_model ssrm_default; do
        if [ -e "$ASSETS_DIR/$FILE" ]; then
            LOG "- /$SDHMS_APK/assets/$FILE 제거 중..."
            EVAL "rm -f \"$ASSETS_DIR/$FILE\""
        fi
    done

    while IFS=":" read -r SRC DST; do
        LOG "- /$SDHMS_APK/assets/$DST 추가 중..."
        EVAL "cp -a \"$SRC\" \"$ASSETS_DIR/$DST\""
    done <<EOF
$MODPATH/assets/siop_default.xml:siop_default.xml
$SIOP_MODEL:$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME.xml
$MODPATH/assets/siop_default.xml:ssrm_default.xml
EOF

elif [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" &&
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "ssrm_default" ]]; then
    _LOG "파일이 존재하지 않습니다: $SIOP_MODEL"
fi

unset -f _LOG
