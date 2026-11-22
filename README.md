# saltic-soft

Программы на языке [Saltic](https://github.com/zephyr-m/saltic): окна на
Linux, APK для Android, стенд и программы Acer через UEFI, плата ESP32, стол
qemu-virt.

```
soft/<категория>/<программа>/   одна программа — одна папка: общее в корне,
                                отличия платформ — в подпапках android, linux,
                                uefi, esp32; проверки — checks/
tools/                          install — поставить программу на этот ноут
```

Язык, полка компиляторов и инструменты берутся из дома Saltic: `SALTIC_HOME`,
по умолчанию соседняя папка `../saltic`. Библиотеки и драйверы — пакеты
реестра [saltic-registry](https://github.com/zephyr-m/saltic-registry),
их привозит tarantul (`tarantul.json`, замок `tarantul.lock`) в `tarantul/`;
программы пишут `use tarantul.<пакет>.…`.

- `just tarantul` — привезти пакеты;
- `just build <исходник>` — собрать родным x86-64;
- `just entries` — все входы через чекер, без сборки;
- `just checks` — проверки программ;
- `just install <имя>` — поставить на ноут (меню и рабочий стол);
- `just qemu-graphics` — стол qemu-virt в окне QEMU;
- `just android <имя>` — APK; `just esp32-flash <имя>` — на плату ESP32.

История программ до 22.11.2026 — в репозитории Saltic (там они жили в
`os/` и `soft/`).
