# [
EXTREMEKRNL_REPO="https://github.com/Ocin4ever/ExtremeKernel/releases"

REPLACE_KERNEL_BINARIES()
{
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    ZIP_LINK="$EXTREMEKRNL_REPO/download/v1.0/ExtremeKRNL-Nexus-${TARGET_CODENAME}.zip"
    LOG "$(basename "$ZIP_LINK") 다운로드 중..."
    curl -L -s -o "$TMP_DIR/krnl.zip" "$ZIP_LINK"

    LOG "커널 바이너리 압축 해제 중..."
    echo $WORK_DIR
    rm -f "$WORK_DIR/kernel/"*.img
    unzip -q -j "$TMP_DIR/krnl.zip" \
        "files/boot.img" "files/dtbo.img" "files/dtb.img" \
        -d "$WORK_DIR/kernel"

    rm -rf "$TMP_DIR"
}

REPLACE_KERNEL_BINARIES
