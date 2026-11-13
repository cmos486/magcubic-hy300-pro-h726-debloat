#!/usr/bin/env bash
# Nivel 1 — Limpieza SIN root del Magcubic HY300 Pro (Allwinner H726, board p2, variante com.hy.*)
#
# LEE ESTE SCRIPT ENTERO ANTES DE EJECUTARLO.
#
# Uso:
#   ./nivel1-limpieza.sh inventario   # solo lectura: identifica la board y lista paquetes sospechosos
#   ./nivel1-limpieza.sh limpiar      # pide confirmación paquete a paquete (todo reversible)
#   ./nivel1-limpieza.sh verificar    # comprueba el resultado
#
# Todo lo que hace "limpiar" es reversible:
#   - pm disable-user --user 0 <pkg>   ->  revertir con: adb shell pm enable <pkg>
#   - pm uninstall --user 0 <pkg>      ->  revertir con: adb shell pm install-existing <pkg>
#   - pm uninstall-system-updates <pkg> borra la actualización instalada en /data/app y vuelve a la
#     versión de fábrica. ESO NO tiene vuelta atrás (la actualización no se puede recuperar sin red),
#     y es justo lo que queremos: la actualización de com.hy.storeos llegó sola por internet.
#
# Requisitos: adb en el PC, proyector conectado por USB (cable USB-A a USB-A) y SIN red.
# Probado en UNA unidad (build Projector.20260817.160250). Tu firmware puede ser distinto.

set -u

ADB="${ADB:-adb}"

die() { echo "ERROR: $*" >&2; exit 1; }

confirmar() {  # confirmar "pregunta" -> 0 si el usuario responde s/S
  local r
  read -r -p "$1 [s/N] " r
  [[ "$r" == "s" || "$r" == "S" ]]
}

comprobar_conexion() {
  local estado
  estado=$($ADB get-state 2>/dev/null) || true
  case "$estado" in
    device) ;;
    unauthorized) die "Dispositivo 'unauthorized': acepta el aviso de depuración USB en el proyector (marca 'Permitir siempre')." ;;
    *) die "No hay dispositivo ADB ('adb devices'). Revisa el cable USB-A a USB-A y que la depuración USB esté activada." ;;
  esac
}

comprobar_board() {
  local flavor
  flavor=$($ADB shell getprop ro.build.flavor | tr -d '\r')
  echo "ro.build.flavor = $flavor"
  if [[ "$flavor" != "h726_p2-user" ]]; then
    echo "!! Esta guía es para h726_p2-user (HY300 Pro). Tu board es '$flavor'."
    echo "!! p1 = HY350Max. NO sigas sin revisar que tus paquetes y rutas coinciden."
    confirmar "¿Continuar de todas formas?" || exit 1
  fi
}

inventario() {
  comprobar_conexion
  echo "=== Identificación"
  for p in ro.build.flavor ro.product.device ro.product.model ro.build.display.id ro.board.platform ro.hardware ro.build.version.release; do
    echo "$p = $($ADB shell getprop $p | tr -d '\r')"
  done
  # En la unidad probada: model/device = rk3566_rgo (FALSO, se hace pasar por un Rockchip),
  # hardware = sun50iw15p1, platform = hermes, flavor = h726_p2-user

  echo "=== Apps de terceros (pm list packages -3)"
  $ADB shell pm list packages -3

  echo "=== Paquetes sospechosos"
  $ADB shell pm list packages | grep -iE "hotack|silent|writesn|htclauncher|storeos|hyota|badbox|proxy|tubesky|vending|toofifi|hyk_"
  # Nota: com.android.proxyhandler es parte normal de AOSP. NO lo toques.

  echo "=== Detalle de cada sospechoso"
  for pkg in com.hy.storeos com.hy.hyotaupdate com.android.vending com.android.toofifi com.htc.hyk_test com.htc.hyk_pcba; do
    echo "----- $pkg"
    $ADB shell dumpsys package "$pkg" | grep -iE "codePath|versionName|installerPackageName|firstInstallTime|lastUpdateTime|pkgFlags=|User 0:" | head -12
  done
  # Señal de alarma: com.hy.storeos con codePath en /data/app y un lastUpdateTime reciente
  # significa que se actualizó solo por internet (le pasó a la unidad probada en cuanto tuvo red).
  # com.android.vending: el APK se llama Tubesky.apk (/product/priv-app/Tubesky). No es el Play Store normal.

  echo "=== Launcher actual"
  $ADB shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
}

limpiar() {
  comprobar_conexion
  comprobar_board

  echo
  echo "=== 1/6 com.hy.storeos (instalador silencioso; se autoactualiza al tener red)"
  if confirmar "¿Desinstalar storeos para el usuario 0 y borrar su actualización de /data/app?"; then
    $ADB shell pm uninstall --user 0 com.hy.storeos
    $ADB shell pm uninstall-system-updates com.hy.storeos
    # Si nunca se actualizó, uninstall-system-updates puede fallar: es inofensivo.
  fi

  echo
  echo "=== 2/6 com.hy.hyotaupdate (OTA del fabricante: puede reinstalar el malware)"
  confirmar "¿Desactivar?" && $ADB shell pm disable-user --user 0 com.hy.hyotaupdate

  echo
  echo "=== 3/6 com.android.vending (Tubesky.apk, un Play Store renombrado de procedencia dudosa)"
  echo "    Si lo desactivas, pierdes 'Play Store'. Usa F-Droid u Obtainium (ver README)."
  confirmar "¿Desactivar?" && $ADB shell pm disable-user --user 0 com.android.vending

  echo
  echo "=== 4/6 com.htc.hyk_test y com.htc.hyk_pcba (apps de prueba de fábrica)"
  if confirmar "¿Desactivar ambas?"; then
    $ADB shell pm disable-user --user 0 com.htc.hyk_test
    $ADB shell pm disable-user --user 0 com.htc.hyk_pcba
  fi

  echo
  echo "=== 5/6 com.android.toofifi (receptor de proyección, corre como uid system)"
  echo "    En la unidad probada se concedía a sí mismo permiso de GRABAR LA PANTALLA al arrancar."
  echo "    Si lo desactivas, pierdes la proyección desde el móvil a través de esta app."
  confirmar "¿Desactivar?" && $ADB shell pm disable-user --user 0 com.android.toofifi

  echo
  echo "=== 6/6 Reinicio"
  if confirmar "¿Reiniciar ahora (recomendado)?"; then
    $ADB reboot
    $ADB wait-for-device
    until [[ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do sleep 3; done
    echo "Arrancado. Ejecuta: $0 verificar"
  fi
}

verificar() {
  comprobar_conexion
  echo "=== Activos que NO deberían aparecer (vacío = bien)"
  $ADB shell pm list packages -e | grep -iE "storeos|hyota|vending|hyk_|com.android.toofifi"

  echo "=== Procesos que NO deberían estar corriendo (vacío = bien)"
  $ADB shell ps -A | grep -iE "storeos|hyota|toofifi"

  echo "=== storeos: debe estar en la versión de fábrica y con installed=false"
  $ADB shell dumpsys package com.hy.storeos | grep -iE "codePath|versionName|User 0:"

  echo "=== Paquetes desactivados (revísalos)"
  $ADB shell pm list packages -d

  echo "=== toofifi: en la unidad probada se reactivó UNA vez sin causa identificada. Si aparece aquí abajo, desactívalo otra vez."
  $ADB shell pm list packages -e | grep -i "com.android.toofifi"
}

case "${1:-}" in
  inventario) inventario ;;
  limpiar)    limpiar ;;
  verificar)  verificar ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
