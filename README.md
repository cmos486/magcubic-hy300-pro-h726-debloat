# magcubic-hy300-pro-h726-debloat

Limpiar y liberar el Magcubic HY300 Pro (Allwinner H726, Android 14, board p2).

## 1. Qué es esto

Es una guía reproducible, con scripts, para **neutralizar el malware de fábrica** del proyector Magcubic HY300 Pro con SoC **Allwinner H726** y Android 14, y dejarlo **usable sin depender del fabricante**.
- **Nivel 1:** se hace por ADB y sin root. Lo puede seguir cualquiera.
- **Nivel 2:** opcional. Añade root con Magisk y un módulo *systemless* que oculta el backdoor `su` de fábrica y los APK maliciosos. También sustituye el launcher.

> **Alcance.** Esto se ha documentado en la variante **`com.hy.*`** del firmware, en la build `Projector.20260817.160250` con flavor **`h726_p2-user`**.
> En esta variante **NO existen** los paquetes `com.hotack.silentsdk`, `com.hotack.writesn` ni `com.htc.htclauncherhighenglishd08` que describen otras guías. El malware vive en `com.hy.storeos`, `com.hy.hyotaupdate` y el backdoor `/system/xbin/hotacksu`. Si tu inventario es distinto, **adapta la lista y no ejecutes nada a ciegas**.

---

## 2. ⚠️ Avisos antes de empezar

- **Comprueba tu board.** p1 = HY350Max, p2 = HY300 Pro. Tocar particiones de la board equivocada **brickea** el aparato:
  ```
  adb shell getprop ro.build.flavor        # debe dar: h726_p2-user
  ```
  No te fíes de `ro.product.model` ni de `ro.product.device`. En este firmware **mienten**: dicen `rk3566_rgo` y el fingerprint dice `rockchip/rk3566_rgo/rk3566_rgo:13/...`. El chip real se ve en `ro.hardware=sun50iw15p1`, `ro.board.platform=hermes` y en `/proc/device-tree/compatible` → `allwinner,h726 arm,sun50iw15p1`.
- **Probado en UNA sola unidad.** Tu firmware, tus rutas y tus offsets pueden ser distintos. Los offsets de partición del Nivel 2 **hay que leerlos de tu aparato**, nunca copiarlos de aquí.
- **No existe `system_a`.** El dispositivo es A/B, pero `super` solo contiene las particiones lógicas `*_b` (lo muestra `lpdump`). El slot A solo duplica `boot`, `init_boot`, `vendor_boot`, `dtbo` y `vbmeta`. **Cambiar al slot A no te salva si algo rompe `super`.** La red de seguridad real es **tu propio backup del eMMC** (Nivel 2, paso 1).
- **No redistribuimos el firmware de Magcubic**, porque tiene copyright. Enlazamos su web oficial (sección 6). Ten en cuenta que **el firmware oficial también trae el backdoor**: sirve para recuperar un aparato brickeado, no para limpiarlo.
- **No conectes el proyector a internet** hasta terminar el Nivel 1. En la unidad probada, `com.hy.storeos` **se autoactualizó en silencio** en los minutos que tuvo red (lo instaló en `/data/app`, `installerPackageName=null`, con un `lastUpdateTime` de ese mismo momento).

---

## 3. Indicadores de compromiso (IOCs)

### Paquetes y ficheros (verificados en la unidad probada)
| Indicador | Qué es |
|---|---|
| `com.hy.storeos` (`/product/app/HY_StoreOs_QZ/`) | Instalador silencioso. Corre con `sharedUserId=android.uid.system` y permisos `INSTALL_PACKAGES`, `DELETE_PACKAGES`, `WRITE_SECURE_SETTINGS`, `RECEIVE_BOOT_COMPLETED`. **Se autoactualiza** cuando tiene red |
| `com.hy.hyotaupdate` (`/product/app/HY_OtaUpdate_QZ/`) | OTA del fabricante: puede volver a instalar el malware |
| `com.android.vending` → **`/product/priv-app/Tubesky/Tubesky.apk`** | "Play Store" renombrado, de procedencia dudosa |
| `com.android.toofifi` (`/system/app/HanYingH713TVApp_HY/`) | Receptor de proyección (SDK `com.mphotool`) que corre como uid system. **Al arrancar se concede a sí mismo el permiso de grabar la pantalla** (`RecordScreenPermissionActivity` → `RecordScreenForegroundService`) |
| **`/system/xbin/hotacksu`** `-rwsr-sr-x root shell`, sha256 `eaa3af208ee0ec0a4d84bd13943cf15fb0f1f271936c6d18a54f2667eabba589` | **Backdoor**: es el `su` de AOSP renombrado, con setuid root y **sin pedir ninguna autorización**. Cualquier proceso que lo ejecute obtiene root |
| `/vendor/etc/ueventd.rc`: `/dev/block/mmcblk0 0666 system system` | **El eMMC entero se puede leer y escribir desde cualquier app** |
| `getenforce` → `Permissive` | SELinux no aplica ninguna restricción |

### Red: ⚠️ reportados por terceros, NO verificados en esta unidad
> Lo que sigue lo publican **micha102** ([hy300pro-debloat](https://github.com/micha102/hy300pro-debloat)) y **det-peralta** (*hy300pro-badbox-audit*, ahora no disponible). Corresponde a la variante **`com.hotack.*`** (`com.hotack.silentsdk`, `com.hotack.writesn`, `com.htc.htclauncherhighenglishd08`). **No lo hemos observado en esta unidad**, que es la variante `com.hy.*`.

Según micha102:
- **Proxy residencial SOAX**: `com.hotack.silentsdk` convierte el dispositivo en un nodo de salida de SOAX.com.
- Miles de consultas DNS bloqueadas a **`app.appsflyer.com`**, **`*.onelink.me`** e **`iforgot.apple.com`** en Pi-hole.
- Conexiones a los puertos **12341/12342**.
- Conexiones APIPA (169.254.x.x).
- `com.htc.htclauncherhighenglishd08` accede a `shortx.srafx.com` y a `imasdk.googleapis.com`.

### Telemetría observada en ESTA unidad tras la limpieza (AdGuard Home, cliente 192.168.X.Y, 13/11/2026)
> Datos **verificados por el autor** en la unidad probada (variante `com.hy.*`), después de los Niveles 1 y 2. Van aparte de los IOCs de terceros de arriba.

**Bloqueado por las listas DNS** (AdGuard DNS filter / hagezi):

| Dominio | Qué es |
|---|---|
| `app-measurement.com` | Telemetría de Google / Firebase Analytics |
| `hmma.baidu.com` | Telemetría de Baidu |
| `firebase-settings.crashlytics.com` | Crashlytics |

**Resuelto y permitido** (sale a internet):

| Dominio | Qué es |
|---|---|
| `relay.luminago.app` | Relay de la app de control del fabricante, **LuminaGo**. **No es el BADBOX**: es telemetría o conexión del fabricante, y sigue activa. En el firmware está `/product/app/luminago_receiver/luminago_receiver.apk` (paquete `com.htc.btremote.receiver`, relacionado con el mando), aunque no se ha comprobado que sea este paquete el que hace la consulta. **El autor ha decidido no bloquearlo, solo documentarlo** |
| `firebaseinstallations.googleapis.com`, `www.google.cn`, `www.googleapis.com` | Servicios de Google / Firebase |
| `ntp.ntsc.ac.cn` | Servidor NTP chino. Normal |

**Conclusión**
- **Tras la limpieza no se observa ningún C2 del BADBOX**: ni dominios de SOAX, ni conexiones a los puertos 12341/12342, ni `storeos` llamando a casa. **El dropper está neutralizado.**
- **Pero el aparato no queda en silencio.** Sigue enviando telemetría del fabricante (`relay.luminago.app`) y de Google, Baidu y Firebase. Las listas DNS bloquean la mayor parte, pero no todo.
- **La recomendación final no cambia:** mantén el proyector en una **VLAN aislada con DNS filtrado**. Quitar el BADBOX no lo convierte en un dispositivo de confianza.

### Síntomas
- Aparecen o se actualizan apps sin que lo pidas (mira `lastUpdateTime` de `com.hy.storeos`).
- (Según micha102, variante `com.hotack.*`) tráfico sospechoso, como si desconocidos navegaran a través del dispositivo, y registro en redes de proxy al arrancar.
- Al arrancar se abre durante un instante una pantalla de permiso de grabación de pantalla (`toofifi`).
- `adb shell ls -l /system/xbin/hotacksu` existe y tiene la `s` de setuid.

---

## 4. NIVEL 1: Limpieza sin root (para todos)

### Requisitos
- Cable **USB-A a USB-A** y `adb` en el PC. En Debian/Ubuntu: `sudo apt install adb`.
- El proyector **sin red**. En el asistente de primer arranque, **salta el paso de la Wi‑Fi**.
- **ADB por Wi‑Fi no sirve sin emparejar.** El puerto 5555 responde con `STLS` (exige TLS), así que `adb connect IP:5555` falla hasta que emparejas con *Depuración inalámbrica → Vincular con código* (`adb pair <IP>:<PUERTO_DE_VINCULACIÓN> <CÓDIGO>`). Por USB no hace falta nada de esto.

### Activar ADB
1. **Modo desarrollador:** *Ajustes → Información del sistema → "Modelo del equipo"*. Púlsalo varias veces (unas 7) hasta que se active el modo desarrollador.
2. **ADB:** *Ajustes → Otras configuraciones → Modo desarrollador* → activa **"ADB debug"**.

> **"ADB debug" y "USB debug" no son lo mismo.**
> - **"USB debug"** pasa el puerto USB del proyector a **modo dispositivo**: deja de reconocer ratón o pendrive.
> - En esta guía el PC se conecta al proyector **por cable USB-A a USB-A**, y el proyector aparece en `adb devices` como `usb:...`. Las notas originales **no registran cuál de los dos interruptores hizo falta para el cable**.
> - Si con "ADB debug" no aparece el dispositivo por USB, activa también "USB debug" mientras dure el trabajo, y desactívalo al acabar para recuperar el USB para pendrive o ratón.

Conecta el cable y ejecuta:
```
adb devices
```
Si sale `unauthorized`, acepta el aviso en el proyector y marca **"Permitir siempre"**.

### Inventario (solo lectura)
```
adb shell getprop ro.build.flavor            # h726_p2-user
adb shell getprop ro.build.display.id
adb shell pm list packages -3
adb shell pm list packages | grep -iE "hotack|silent|writesn|htclauncher|storeos|hyota|badbox|proxy|tubesky|vending"
adb shell dumpsys package com.hy.storeos | grep -iE "versionName|installerPackageName|firstInstallTime|lastUpdateTime|codePath"
```
Salida de referencia en la unidad probada:
```
package:com.hy.storeos
package:com.hy.hyotaupdate
package:com.android.proxyhandler     ← parte normal de AOSP: NO tocar
package:com.android.vending          ← es /product/priv-app/Tubesky
```

### Limpieza
Todo lo que sigue va en [`scripts/nivel1-limpieza.sh`](scripts/nivel1-limpieza.sh), comentado y pidiendo confirmación paso a paso. **Léelo antes de ejecutarlo.**
```
./scripts/nivel1-limpieza.sh inventario
./scripts/nivel1-limpieza.sh limpiar
./scripts/nivel1-limpieza.sh verificar
```
Los comandos exactos, con su explicación:

```bash
# 1) storeos: quitarlo para el usuario 0 y BORRAR la actualización que se bajó de internet.
adb shell pm uninstall --user 0 com.hy.storeos
adb shell pm uninstall-system-updates com.hy.storeos
#    Ojo: "pm uninstall --user 0" por sí solo NO vuelve a la versión de fábrica. Deja la
#    actualización en /data/app, y un "pm install-existing" la volvería a activar.
#    uninstall-system-updates la borra y codePath vuelve a /product/app/HY_StoreOs_QZ
#    (en la unidad probada: v2609042030 → v2606150950 de fábrica).

# 2) OTA del fabricante, "Play Store" Tubesky y apps de prueba de fábrica: desactivar (reversible).
adb shell pm disable-user --user 0 com.hy.hyotaupdate
adb shell pm disable-user --user 0 com.android.vending
adb shell pm disable-user --user 0 com.htc.hyk_test
adb shell pm disable-user --user 0 com.htc.hyk_pcba

# 3) Opcional: toofifi (pierdes la proyección desde el móvil a través de esta app).
adb shell pm disable-user --user 0 com.android.toofifi

adb reboot
```
**No toques:** `com.htc.magcubicos` (es el launcher y además los ajustes de Wi‑Fi y Bluetooth), `com.android.proxyhandler` (AOSP), `com.hysd.vafocus` (enfoque), `com.htc.htcbluetoothremotecontrol` y `com.htc.btremote.receiver` (mando), `com.softwinner.*` (HDMI y fuentes).

### Verificación
```
adb shell pm list packages -e | grep -iE "storeos|hyota|vending|hyk_"   # vacío
adb shell ps -A | grep -iE "storeos|hyota|hy\."                          # vacío
adb shell pm list packages -d                                            # revisa la lista
adb shell dumpsys package com.hy.storeos | grep -iE "versionName|codePath|User 0:"
#   esperado: codePath=/product/app/HY_StoreOs_QZ, versionName=2606150950, User 0: installed=false
```
> ⚠️ En la unidad probada, `com.android.toofifi` **se reactivó solo una vez** después de un reinicio, sin causa identificada. Al volver a desactivarlo aguantó en los siguientes reinicios. Repite la verificación tras unos cuantos arranques.

**Lo que el Nivel 1 NO arregla:** el backdoor `/system/xbin/hotacksu` sigue ahí, porque está en una partición de solo lectura. Para eso está el Nivel 2.

---

## 5. NIVEL 2: Root y sistema usable (avanzado)

> Requiere **bootloader desbloqueado** y **eMMC escribible**. Este firmware viene así de fábrica, pero **compruébalo en el tuyo**:
> ```
> adb shell getprop ro.boot.verifiedbootstate   # orange = desbloqueado
> adb shell getprop ro.boot.flash.locked        # 0
> adb shell getprop ro.boot.slot_suffix         # _b en la unidad probada
> adb shell ls -l /dev/block/mmcblk0            # brw-rw-rw- system system  (0666)
> adb shell getenforce                          # Permissive
> ```
> Si `verifiedbootstate` no es `orange` o `mmcblk0` no tiene permisos `rw-rw-rw-`, **este método no aplica. Para.**

### 5.1 Backup del eMMC (sin root)
Las particiones (`/dev/block/by-name/*`) son `brw------- root`, pero el disco entero `mmcblk0` tiene permisos 0666. Primero obtén el mapa de particiones **de tu aparato**:
```
adb shell 'for d in /sys/class/block/mmcblk0p*; do echo "$(basename $d) $(cat $d/start) $(cat $d/size) $(grep PARTNAME $d/uevent | cut -d= -f2)"; done' > partition-offsets.txt
adb shell cat /sys/class/block/mmcblk0/size
```
Vuelca todo hasta el inicio de `userdata`. `<USERDATA_START>` es el *start* de `userdata` en `partition-offsets.txt`. En la unidad probada era 5653504, así que `count = 5653504 / 1024 = 5521` bloques de 512 KiB:
```
adb exec-out 'dd if=/dev/block/mmcblk0 bs=524288 count=<USERDATA_START/1024> 2>/dev/null' > mmcblk0_0-userdata.raw
# GPT de respaldo (últimos 33 sectores; <DISK_SIZE> = /sys/class/block/mmcblk0/size)
adb exec-out 'dd if=/dev/block/mmcblk0 bs=512 skip=<DISK_SIZE-33> count=33 2>/dev/null' > mmcblk0_gpt-backup-last33.raw
sha256sum *.raw > SHA256SUMS-raw.txt
```
Comprueba que el tamaño coincide **exactamente** y que en el offset 512 está la firma `EFI PART`. Después trocea por particiones (`dd ... skip=<start> count=<size>`) y guarda los hashes.

> 🔒 **`private.img` (y el volcado bruto que la contiene) lleva el número de serie y las MAC de tu aparato. NO lo publiques ni lo subas a ningún sitio.** El `.gitignore` de este repo excluye `*.img`, `*.raw` y `backup-*`.

### 5.2 Root: parchear `init_boot` con Magisk ⚠️ **PASO DE RIESGO**
Si Android no arranca después de este paso, **ya no podrás arreglarlo por ADB**. Solo quedarían FEL/PhoenixSuit y tu backup (sección 6).

**a) Copia fresca de `init_boot` del slot activo**, por offset. `<INIT_BOOT_START>` y `<INIT_BOOT_SIZE>` son los de `init_boot<SLOT>` en tu `partition-offsets.txt`. En la unidad probada: `init_boot_b` = `mmcblk0p10`, start 615424, size 16384, es decir 8 MiB.
```
adb shell getprop ro.boot.slot_suffix
adb shell readlink /dev/block/by-name/init_boot_b
adb exec-out 'dd if=/dev/block/mmcblk0 bs=512 skip=<INIT_BOOT_START> count=<INIT_BOOT_SIZE> 2>/dev/null' > init_boot_b.PRE.img
sha256sum init_boot_b.PRE.img       # anota este hash: <HASH_ORIGINAL>
```

**b) Parcheo** con el `boot_patch.sh` oficial de **Magisk v31.1** (`gh release download v31.1 -R topjohnwu/Magisk -p Magisk-v31.1.apk`, sha256 `89cefac0a318afa39fb3880c45c87b036c05bc1ebf02a7a715b7f8d7c26ac6e7`).
- Se ejecuta **en el propio proyector**, sobre una copia en `/data/local/tmp`. Los binarios `magiskboot` del APK son de Android y no corren en un Linux de escritorio.
- El userspace es **armeabi-v7a** (32 bits).
- Con un fichero como origen, `boot_patch.sh` no escribe en ninguna partición.
```bash
unzip Magisk-v31.1.apk 'assets/*' 'lib/armeabi-v7a/*' -d apk
mkdir stage; L=apk/lib/armeabi-v7a
cp $L/libmagiskboot.so stage/magiskboot; cp $L/libmagiskinit.so stage/magiskinit
cp $L/libmagisk.so stage/magisk;         cp $L/libinit-ld.so stage/init-ld
cp $L/libbusybox.so stage/busybox;       cp apk/assets/{boot_patch.sh,util_functions.sh} stage/
cp init_boot_b.PRE.img stage/
adb shell 'mkdir /data/local/tmp/mp'; adb push stage/. /data/local/tmp/mp/
adb shell 'cd /data/local/tmp/mp && chmod 755 * && KEEPVERITY=true KEEPFORCEENCRYPT=true ./busybox sh boot_patch.sh init_boot_b.PRE.img'
adb pull /data/local/tmp/mp/new-boot.img magisk_patched-init_boot_b.img
sha256sum magisk_patched-init_boot_b.img   # <HASH_PARCHEADO>
```
**El parcheado debe ocupar exactamente lo mismo que la partición (8 388 608 bytes) o menos. Nunca más.**

**c) Escritura con dos comprobaciones de hash.** Si cualquiera falla, el comando aborta **antes** de escribir:
1. que el fichero en el proyector es el parcheado
2. que el destino contiene **exactamente** el `init_boot` original

Es la única protección contra un error de offset.
```sh
adb shell 'set -e; cd /data/local/tmp/mp
  [ "$(sha256sum new-boot.img | cut -d" " -f1)" = <HASH_PARCHEADO> ]
  [ "$(dd if=/dev/block/mmcblk0 bs=512 skip=<INIT_BOOT_START> count=<INIT_BOOT_SIZE> 2>/dev/null | sha256sum | cut -d" " -f1)" = <HASH_ORIGINAL> ]
  dd if=new-boot.img of=/dev/block/mmcblk0 bs=512 seek=<INIT_BOOT_START> count=<INIT_BOOT_SIZE> conv=fsync'
# relectura:
adb exec-out 'dd if=/dev/block/mmcblk0 bs=512 skip=<INIT_BOOT_START> count=<INIT_BOOT_SIZE> 2>/dev/null' | sha256sum   # = <HASH_PARCHEADO>
```

**d) Reinicio.**
- `vbmeta` verifica el hash de `init_boot` y deja de coincidir, pero con el bootloader en *orange* arranca igualmente. **No hizo falta tocar `vbmeta`.**
```
adb reboot; adb wait-for-device
adb shell getprop ro.boot.verifiedbootstate    # orange
adb shell /debug_ramdisk/magisk -v             # 31.1:MAGISK:R
```
- **Magisk v31 ya no muestra el aviso de "¿conceder root?"**. Instala la app (`adb install Magisk-v31.1.apk`) y ábrela con el mando: completa el *Additional setup*, que reinicia el proyector, y después ve a **Superuser** y activa **Shell**.
```
adb shell su -c id     # uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

### 5.3 Módulo Magisk `hy300-clean`
`/system`, `/product` y `/vendor` son ext4, pero sus dispositivos dm están marcados como solo lectura (`blockdev --getro` → 1), y `mount -o rw,remount` falla. En lugar de forzar escrituras en `super`, el módulo **oculta** los ficheros con *whiteouts* de Magisk:
- Un nodo de carácter **`c 0 0`** con el mismo nombre que un fichero o directorio hace que ese elemento **desaparezca** del sistema visible al arrancar.
- Funciona también con directorios en Magisk 31.1 (verificado).
- No escribe nada en `super`, y desactivar el módulo lo revierte.

Contenido de [`modulo-hy300-clean/`](modulo-hy300-clean/):
- `module.prop`
- `build-on-device.sh`: crea los nodos. Hay que ejecutarlo en el proyector como root, porque en un PC no se pueden crear como usuario normal.

```
hy300-clean/
├── module.prop
└── system/
    ├── xbin/hotacksu                     c 0 0   (backdoor)
    └── product/                          (Magisk exige system/product/ para /product)
        ├── app/HY_StoreOs_QZ             c 0 0
        ├── app/HY_OtaUpdate_QZ           c 0 0
        └── priv-app/Tubesky              c 0 0
```
> Las carpetas `HY_*` pueden llamarse distinto en tu firmware. Compruébalo con `adb shell ls -d /product/app/HY_* /product/priv-app/*` y ajusta `build-on-device.sh`.

Instalación:
```
adb shell 'rm -rf /data/local/tmp/hy300-clean-src; mkdir /data/local/tmp/hy300-clean-src'
adb push modulo-hy300-clean/module.prop modulo-hy300-clean/build-on-device.sh /data/local/tmp/hy300-clean-src/
adb shell 'su -c "sh /data/local/tmp/hy300-clean-src/build-on-device.sh /data/local/tmp/hy300-clean-staging"'
adb shell su -c 'cp -a /data/local/tmp/hy300-clean-staging /data/adb/modules/hy300-clean'
adb reboot
```
Verificación:
```
adb shell 'ls -l /system/xbin/hotacksu'      # No such file or directory
adb shell 'ls -ld /product/app/HY_StoreOs_QZ /product/app/HY_OtaUpdate_QZ /product/priv-app/Tubesky'   # No such file (los tres)
adb shell su -c 'find / -xdev -perm -4000'   # solo /system/apex/com.android.tethering/bin/for-system/clatd (AOSP, propietario clat)
adb shell 'pm list packages -u | grep -iE "storeos|hyotaupdate|vending"'   # vacío
```
> Los ficheros siguen **físicamente** en `super`. Si arrancas sin Magisk, vuelven a aparecer.

### 5.4 Launcher y apps
Descárgalas **de sus fuentes oficiales**: este repo no incluye APKs. Elige variantes **armeabi-v7a** o universales, porque el userspace es de 32 bits. Los hashes son los de las versiones probadas, como referencia:

| App | Versión probada | Fuente oficial | sha256 |
|---|---|---|---|
| FLauncher | 0.18.0 | <https://gitlab.com/flauncher/flauncher> (releases) | `376fc528c880cdf7c7c04b2d3708c69f911144498218babb6300808b772af32e` |
| Obtainium | 1.7.3 (`app-armeabi-v7a-release.apk`) | <https://github.com/ImranR98/Obtainium/releases> | `db52cf7c9739bf035714f270bd7369ec8d93592555883b3a8d479fb3890301ee` |
| F-Droid | 1.23.2 | <https://f-droid.org/F-Droid.apk> | `dac55a0d17b1edf7e7286b48cfbd70c7c52fbb32a00af062c68830a437c47959` |
| Jellyfin Android TV | 0.19.10 | <https://github.com/jellyfin/jellyfin-androidtv/releases> | `8510a517c99927076082917f41bf306dd7a2546c59d492dd11bde18d6e2e4628` |
| SmartTube stable | 32.68 (`SmartTube_stable_32.68_armeabi-v7a.apk`) | <https://github.com/yuliskov/SmartTube/releases> | `2130b23b17ed5cfd324baec81750a2be22059212b6ee17449f21cae2cb3a60d9` |
| VLC | 3.7.1 (`VLC-Android-3.7.1-armeabi-v7a.apk`) | <https://get.videolan.org/vlc-android/> | `a6a7f940e4bd190c9a70f3f0dc97c1c402c10200af20edac7a1d452b24abd8a0` |
| Kodi | 21.3 Omega (`kodi-21.3-Omega-armeabi-v7a.apk`) | <https://mirrors.kodi.tv/releases/android/arm/> | `12d75e895649f68f217e42c2d881a94fd3177d7b9a7937825852aed545520cc8` |

FLauncher no está en GitHub ni en F-Droid, y su última versión es de 2023.

```
adb install -r <app>.apk
adb shell cmd package set-home-activity me.efesser.flauncher/.MainActivity
```
**Al arrancar seguirá saliendo `magcubicos`.** Está marcado para el arranque directo (`DIRECT_BOOT_AWARE`) y FLauncher no, así que el sistema lo elige en el primer arranque. **No desactives `magcubicos` entero**: también es la pantalla de **ajustes de Wi‑Fi y Bluetooth**. Desactiva solo su actividad de launcher:
```
adb shell "su -c 'pm disable --user 0 com.htc.magcubicos/.activity.MainActivity'"
# revertir: su -c 'pm enable --user 0 com.htc.magcubicos/.activity.MainActivity'
```

**HDMI:**
- `com.softwinner.awlivetv/.MainActivity` muestra la entrada, pero no se puede lanzar desde un launcher.
- Usa el tile **AwSource** (`com.softwinner.awsource/.MainActivity`) de FLauncher. Abre un selector con **HDMI1, HDMI2, HDMI3, CVBS1 y CVBS2**.

**Obtainium**, una vez el proyector esté en una red controlada:
```
adb shell am start -a android.intent.action.VIEW -d "obtainium://add/https://github.com/yuliskov/SmartTube"
adb shell am start -a android.intent.action.VIEW -d "obtainium://add/https://github.com/jellyfin/jellyfin-androidtv"
adb shell am start -a android.intent.action.VIEW -d "obtainium://add/https://gitlab.com/flauncher/flauncher"
```
En SmartTube, filtra por `armeabi-v7a` y solo versiones *Stable*.

---

## 6. Recuperación y rollback

| Qué revertir | Cómo |
|---|---|
| Un paquete desactivado | `adb shell pm enable <pkg>` |
| `pm uninstall --user 0` | `adb shell pm install-existing <pkg>` |
| Módulo `hy300-clean` | `adb shell su -c 'touch /data/adb/modules/hy300-clean/disable'` y reiniciar, o `rm -rf /data/adb/modules/hy300-clean` |
| Launcher | `su -c 'pm enable --user 0 com.htc.magcubicos/.activity.MainActivity'` |
| **Root (init_boot)**, con Android arrancando | El mismo `dd` de 5.2c con los hashes invertidos: comprobar que el destino tiene `<HASH_PARCHEADO>` y escribir `init_boot_b.PRE.img` |
| **Android no arranca** | **Último recurso: FEL / PhoenixSuit**, restaurando tu backup o el firmware oficial. ⚠️ **NO verificado en esta unidad.** Según [androidpctv](https://androidpctv.com/firmware-magcubic-hy300-pro-ultra-h726/), se entra en modo flasheo sujetando con un clip el botón que hay sobre el puerto HDMI, con el cable USB-A a USB-A conectado, y después se conecta la alimentación. No lo hemos probado: tómalo como una pista, no como un procedimiento seguro |

Firmware oficial del HY300PRO (H726): en <https://magcubic-support.com/xw>, entra en *"How to Update the Firmware on the HY300PRO Projector via a USB Drive? (H726 Chip)"*, que lleva a una carpeta de Google Drive con `update.img` y `auto_update.txt`.
- Contenido verificado con [`tools/imagewty_list.py`](tools/imagewty_list.py), un lector de solo lectura de imágenes IMAGEWTY v0x417.
- Es `h726_p2`, pero de una **build anterior** (`Projector.20260318`), así que flashearlo es volver atrás.
- **Trae el mismo backdoor `hotacksu`.**
- Magcubic avisa de que solo es compatible con unidades compradas en sus tiendas autorizadas.

---

## 7. Créditos

- micha102: <https://github.com/micha102/hy300pro-debloat>
- battleof3: <https://github.com/battleof3/magcubic-h726-cleanup>
- hoangphi01: <https://github.com/hoangphi01/hy300ultra-h726-allinone>
- maximilian-sh: <https://github.com/maximilian-sh/hy350max-badbox-removal>
- det-peralta: *hy300pro-badbox-audit* (repo no disponible: GitHub devolvía 404 al consultarlo en 2026-11)
- topjohnwu: <https://github.com/topjohnwu/Magisk>

## 8. Licencia

Los scripts y el módulo de este repositorio se publican bajo licencia **MIT** (ver [`LICENSE`](LICENSE)).
El firmware, los APK y las marcas citadas son de sus respectivos propietarios, y no se distribuyen aquí.
