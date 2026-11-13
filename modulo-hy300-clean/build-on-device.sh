#!/system/bin/sh
# Construye el esqueleto del modulo en un directorio de staging (NO activo).
# Uso (como root): sh build-on-device.sh <dir_staging>
set -e
M="$1"
[ -n "$M" ] || { echo "falta dir"; exit 1; }
rm -rf "$M"; mkdir -p "$M"
cp /data/local/tmp/hy300-clean-src/module.prop "$M/"
# Whiteouts de Magisk: nodo de caracter 0:0 con el mismo nombre = el fichero/directorio desaparece
mkdir -p "$M/system/xbin" "$M/system/product/app" "$M/system/product/priv-app"
mknod "$M/system/xbin/hotacksu"                 c 0 0
mknod "$M/system/product/app/HY_StoreOs_QZ"     c 0 0
mknod "$M/system/product/app/HY_OtaUpdate_QZ"   c 0 0
mknod "$M/system/product/priv-app/Tubesky"      c 0 0
chown -R 0:0 "$M"
chmod 0644 "$M/module.prop"
find "$M" -exec ls -ld {} \;
