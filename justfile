set shell := ["bash", "-uc"]
set positional-arguments

# saltic-soft — программы на Saltic. Язык, полка компиляторов и инструменты
# берутся из дома Saltic: SALTIC_HOME, по умолчанию соседняя папка ../saltic.
saltic := env_var_or_default("SALTIC_HOME", justfile_directory() + "/../saltic")
export SALTIC_HOME := saltic
compiler := saltic + "/bootstrap/saltic"

default:
    just --list

_dirs:
    mkdir -p .cache/build/tools .cache/build/workbench .cache/build/android

# Пакеты (tarantul.json, замок tarantul.lock) в tarantul/: get, update, list, check
tarantul command="get": _dirs
    {{compiler}} {{saltic}}/workbench/tarantul/main.saltic .cache/build/tools/tarantul 268435456 x86_64
    .cache/build/tools/tarantul "$1"

# Собрать программу родным x86-64: `just build soft/games/bastion/main.saltic`
build file output=".cache/build/tools/program": (tarantul "get")
    {{compiler}} "$1" "$2" 1073741824 x86_64

# Все входы через lens (чекер без сборки), по 6 разом: печатает только упавшие
entries: _dirs (tarantul "get")
    {{compiler}} {{saltic}}/workbench/agent/lens/main.saltic .cache/build/workbench/lens 1073741824 x86_64
    {{compiler}} {{saltic}}/workbench/check/entries.saltic .cache/build/tools/entries-check 268435456 x86_64
    SALTIC_ENTRIES="soft/*.saltic tools/*.saltic" .cache/build/tools/entries-check

# Проверки программ (soft/**/checks/*.saltic): собрать и прогнать каждую
checks: _dirs (tarantul "get")
    #!/usr/bin/env bash
    set -euo pipefail
    for f in $(git ls-files 'soft/*/checks/*.saltic'); do
        name=$(echo "$f" | tr '/' '_' | sed 's/\.saltic$//')
        echo "== $f"
        {{compiler}} "$f" ".cache/build/tools/$name" 1073741824 x86_64 > ".cache/build/tools/$name.log" 2>&1 || { tail -5 ".cache/build/tools/$name.log"; exit 1; }
        ".cache/build/tools/$name"
    done

# Поставить программу на ноут: бинарник в ~/.local/bin, иконка, визитка в меню
install name: _dirs (tarantul "get")
    {{compiler}} tools/install.saltic .cache/build/tools/install 268435456 x86_64
    .cache/build/tools/install "$1"

# Стол qemu-virt с программами в окне QEMU: сборщик qemu-virt родным x86-64
# (soul/toolchains/qemu_virt) собирает стол голым ELF
qemu-graphics: _dirs (tarantul "get")
    {{compiler}} {{saltic}}/soul/toolchains/qemu_virt/main.saltic .cache/build/tools/qemu-toolchain 536870912 x86_64
    .cache/build/tools/qemu-toolchain soft/system/qemu_desk/main.saltic .cache/build/tools/qemu-desk.elf 67108864
    nix --extra-experimental-features "nix-command flakes" develop {{saltic}} --command qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -device virtio-tablet-device -audiodev pipewire,id=saltic_audio -device virtio-sound-device,audiodev=saltic_audio -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/tools/qemu-desk.elf

# Залить программу на плату ESP32: `just esp32-flash` — куб,
# `just esp32-flash oled` — любая по имени: soft/<категория>/<имя>/esp32/main.saltic
esp32-flash name="cube": _dirs (tarantul "get")
    {{compiler}} {{saltic}}/soul/toolchains/esp32/main.saltic .cache/build/tools/esp32-toolchain 536870912 x86_64
    .cache/build/tools/esp32-toolchain soft/*/{{name}}/esp32/main.saltic .cache/build/tools/esp32-{{name}}.bin 65536
    nix-shell -p esptool --run "esptool --chip esp32 --port /dev/ttyUSB0 --no-stub write-flash 0x1000 .cache/build/tools/esp32-{{name}}.bin"

# APK для телефона: `just android` — hello, `just android имя` — программа по имени:
# soft/<категория>/<имя>/android/main.saltic. Ключ подписи — один раз в
# .cache/build/android; готовый APK — .cache/build/android/<имя>.apk
android name="hello": _dirs (tarantul "get")
    {{compiler}} {{saltic}}/soul/toolchains/android/main.saltic .cache/build/tools/android-toolchain 1073741824 x86_64
    .cache/build/tools/android-toolchain soft/*/{{name}}/android/main.saltic .cache/build/android/{{name}}-unsigned.apk 67108864
    test -f .cache/build/android/key.pk8 || (openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out .cache/build/android/key.pem && openssl pkcs8 -topk8 -nocrypt -outform DER -in .cache/build/android/key.pem -out .cache/build/android/key.pk8 && openssl req -new -x509 -key .cache/build/android/key.pem -days 10000 -subj "/CN=Saltic" -out .cache/build/android/cert.pem)
    nix-shell -p apksigner --run "apksigner sign --key .cache/build/android/key.pk8 --cert .cache/build/android/cert.pem --min-sdk-version 24 --out .cache/build/android/{{name}}.apk .cache/build/android/{{name}}-unsigned.apk && apksigner verify --verbose .cache/build/android/{{name}}.apk"
