# UN1CA SELinux 엔트리 제거 목록
# - 새로운 타입 엔트리는 ENTRIES 목록에 추가하세요.
# - 축약된 패턴이 아닌 '정확한' 타입 엔트리를 입력해야 합니다. (예: "fabriccrypto" 및 "fabriccrypto_exec" 등록 / "fabriccrypto" 하나만 등록하면 안 됨)
# - 엔트리 끝에 API 버전을 붙이지 마세요. (예: "fabriccrypto" 등록 / "fabriccrypto_30_0" 형태로 등록하면 안 됨)
# - 괄호나 다른 구문을 포함하지 마세요. (예: "fabriccrypto" 등록 / "expanttypeattribute ... (fabriccrypto)" 형태로 등록하면 안 됨)
# - 불필요한 타입을 추가하거나, 모든 기기에서 여전히 필요한 기존 타입을 함부로 제거하지 마세요.

# One UI 8.0 추가분
ENTRIES+="
heatmap_default
heatmap_default_exec
"

DUPLICATES+="
init.svc.vendor.wvkprov_server_hal
"

# One UI 7.0 추가분
ENTRIES+="
attiqi_app
attiqi_app_data_file
ker_app
kpp_app
kpp_data_file
"

# One UI 6.1.1 추가분
ENTRIES+="
hal_dsms_default
hal_dsms_default_exec
proc_compaction_proactiveness
sbauth
sbauth_exec
"

# One UI 5.1.1 추가분
ENTRIES+="
audiomirroring
audiomirroring_exec
audiomirroring_service
fabriccrypto
fabriccrypto_exec
fabriccrypto_data_file
hal_dsms_service
uwb_regulation_skip_prop
"

# [ 시스템 확장 파티션 경로 확보 및 변수 초기화 ]
GET_SYSTEM_EXT()
{
    if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
        echo "system_ext"
    else
        echo "system/system/system_ext"
    fi
}

CIL_NAME="$(head -n 1 "$WORK_DIR/vendor/etc/selinux/plat_sepolicy_vers.txt")"
PATCHED=false
VENDOR_API_LIST="$(find "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/mapping" -type f -printf "%f\n" | \
                    sed '/.compat./d' | sed 's/.cil//' | sed 's/\./_/' | sort)"
# ]

# 미지원 SELinux 엔트리 감지 및 제거 루프
for e in $ENTRIES; do
    if grep -q -F "($e)" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/mapping/$CIL_NAME.cil" || \
         grep -q -F "${e}_${CIL_NAME//./_}" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/mapping/$CIL_NAME.cil"; then
        # 문제가 될 수 있는 엔트리가 현재 system_ext에 존재함. 제거가 필요한지 확인
        if ! grep -q -F "(type $e)" "$WORK_DIR/vendor/etc/selinux/plat_pub_versioned.cil"; then
            PATCHED=true
            # 타겟 디바이스에서 해당 엔트리를 지원하지 않는 경우 제거 진행
            LOG "- \"$e\" SELinux 엔트리가 지원되지 않습니다. 제거하는 중..."
            sed -i "/($e)/d" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/mapping/$CIL_NAME.cil"
            for a in $VENDOR_API_LIST; do
                sed -i "/${e}_${a}/d" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/mapping/$CIL_NAME.cil"
            done
            if grep -q "genfscon.*$e" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/system_ext_sepolicy.cil"; then
                sed -i "/genfscon.*$e/d" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/system_ext_sepolicy.cil"
            fi
            if grep -q "genfscon.*$e" "$WORK_DIR/system/system/etc/selinux/plat_sepolicy.cil"; then
                sed -i "/genfscon.*$e/d" "$WORK_DIR/system/system/etc/selinux/plat_sepolicy.cil"
            fi
        fi
    fi
done

# 중복 프로퍼티 컨텍스트 감지 및 주석 처리 루프
for e in $DUPLICATES; do
    if grep -q "^$e.*" "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/selinux/system_ext_property_contexts"; then
        # 문제가 될 수 있는 엔트리가 현재 system_ext에 존재함. 제거가 필요한지 확인
        if grep -q "^$e.*" "$WORK_DIR/vendor/etc/selinux/vendor_property_contexts"; then
            PATCHED=true
            # 타겟 벤더 파티션에서 중복 엔트리가 발견된 경우 주석 처리
            LOG "- \"$e\" SELinux 중복 엔트리가 존재합니다. 제거하는 중..."
            sed -i "s/^$e/#SEC_DUPLICATE: $e/g" "$WORK_DIR/vendor/etc/selinux/vendor_property_contexts"
        fi
    fi
done

if ! $PATCHED; then
    LOG "\033[0;33m! 아무 작업도 하지 않습니다\033[0m"
fi

# 사용 후 변수 및 함수 해제(메모리 정리)
unset ENTRIES DUPLICATES CIL_NAME PATCHED VENDOR_API_LIST
unset -f GET_SYSTEM_EXT