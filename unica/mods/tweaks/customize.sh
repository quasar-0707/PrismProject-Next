# 앱 압축 비활성화
# 원본 펌웨어에서 이 기능이 이미 비활성화되어 있을 수 있으므로 패치 적용 여부 확인
LOG "- /system/system/framework/services.jar에 \"앱 압축 비활성화\" 적용 중"
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/appcompactor/services.jar/0001-Disable-app-compaction.patch" | true \
    > /dev/null

# 설정에서 배터리 규제 정보 표시
# SEM_BATTERY_PROPERTY_IC_AUTHENTICATION_RESULT 지원 필요
if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS")" ]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS" --delete
fi
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY" "true"

# One UI 마이너 버전 항상 표시
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/deviceinfo/softwareinfo/OneUIVersionPreferenceController.smali" "replace" \
    'isDeviceWithMicroVersion()Z' \
    'move-result p0' \
    'const/4 p0, 0x1'

# 디바이스 순정 모델 번호 표시
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/deviceinfo/aboutphone/ModelNameGetter.smali" "replace" \
    'getModelName()Ljava/lang/String;' \
    'ro.product.model' \
    'ro.boot.em.model'