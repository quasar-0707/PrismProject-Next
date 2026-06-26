SOURCE_PRODUCT_NAME="$(GET_PROP "system" "ro.product.system.name")"
TARGET_PRODUCT_NAME="$(GET_PROP "vendor" "ro.product.vendor.name")"

if [[ "$SOURCE_PRODUCT_NAME" == "$TARGET_PRODUCT_NAME" ]]; then
    LOG "\033[0;33m! 아무 작업도 하지 않습니다\033[0m"
    unset SOURCE_PRODUCT_NAME TARGET_PRODUCT_NAME
    return 0
fi

_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

while IFS= read -r f; do
    f="$(basename "$f")"

    DECODE_APK "product" "overlay/$f"
    LOG_STEP_IN "- $f 를 ${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}으로 변경하는 중..."
    DELETE_FROM_WORK_DIR "product" "overlay/$f"
    EVAL "mv -f \"$APKTOOL_DIR/product/overlay/$f\" \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}\""
    EVAL "sed -i \"s/${SOURCE_PRODUCT_NAME}/${TARGET_PRODUCT_NAME}/g\" \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/apktool.yml\""
    SET_METADATA "product" "overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}" 0 0 644 "u:object_r:system_file:s0"

    if [[ "$f" == "framework-res"* ]]; then
        if [ ! -d "$SRC_DIR/target/$TARGET_CODENAME/overlay" ]; then
            _LOG "폴더가 존재하지 않습니다: target/$TARGET_CODENAME/overlay"
            continue
        fi
        LOG_STEP_IN "- Applying target product overlay"
        EVAL "rm -rf \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res\""
        EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/overlay\" \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res\""
        if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_LCD_SUPPORT_EXTRA_BRIGHTNESS")" ] && \
                ! grep -q -w "config_Extra_Brightness_Display_Solution_Brightness_Value" "$SRC_DIR/target/$TARGET_CODENAME/overlay/values/arrays.xml" 2> /dev/null; then
            _LOG "SEC_FLOATING_FEATURE_LCD_SUPPORT_EXTRA_BRIGHTNESS가 설정되었으나 arrays.xml에 \"config_Extra_Brightness_Display_Solution_Brightness_Value\"가 존재하지 않습니다."
        fi
        if [[ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_AOD_ITEM")" =~ activeclock|clocktransition ]] && \
                ! grep -q -w "physical_power_button_center_screen_location_y" "$SRC_DIR/target/$TARGET_CODENAME/overlay/values/dimens.xml" 2> /dev/null; then
            _LOG "AOD 시계 효과가 활성화되었으나 dimens.xml에 \"physical_power_button_center_screen_location_y\"가 존재하지 않습니다."
        fi
        LOG_STEP_OUT
    elif [[ "$f" == "SystemUI"* ]]; then
        EVAL "rm -f \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res/values/public.xml\""
        if $TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION && \
                ! grep -q "config_enableDisplayCutoutProtection" "$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res/values/bools.xml" 2> /dev/null; \
                then
            LOG "- 카메라 컷아웃 보호 활성화 중..."
            EVAL "sed -i \"/<resources>/a \\\ \\\ \\\ \\\ <bool name=\\\"config_enableDisplayCutoutProtection\\\">true</bool>\" \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res/values/bools.xml\""
        elif ! $TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION && \
                grep -q "config_enableDisplayCutoutProtection" "$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res/values/bools.xml" 2> /dev/null; \
                then
            LOG "- 카메라 컷아웃 보호 비활성화 중..."
            EVAL "sed -i \"/config_enableDisplayCutoutProtection/d\" \"$APKTOOL_DIR/product/overlay/${f//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}/res/values/bools.xml\""
        fi
    fi

    LOG_STEP_OUT
done < <(find "$WORK_DIR/product/overlay" -maxdepth 1 -type f -name "*$SOURCE_PRODUCT_NAME*.apk")

unset SOURCE_PRODUCT_NAME TARGET_PRODUCT_NAME
unset -f _LOG
