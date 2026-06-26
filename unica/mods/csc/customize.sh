# 전원 끌 때 잠금 기능 활성화
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali_classes6/com/samsung/android/globalactions/util/SystemPropertiesWrapper.smali" "return" \
    'isBrazilianCountryISO()Z' 'true'
SMALI_PATCH "system_ext" "priv-app/SystemUI/SystemUI.apk" \
    "smali/com/android/systemui/bixby2/controller/DeviceController.smali" "return" \
    'isSupportPowerOffLock()Z' 'true'

# 설정에서 Remote management 타일 숨기기
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/homepage/TopLevelRemoteSupportPreferenceController.smali" "return" \
    'getAvailabilityStatus()I' '3'
