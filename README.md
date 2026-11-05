# Microsoft Surface Book 2 (13.5" i7 / GTX 1050) - Fedora Silverblue 40 Unattended ISO

Repositorio y pipeline CI/CD con **GitHub Actions** para generar una imagen OCI y una **ISO desatendida booteable** de **Fedora Silverblue 40 (Atomic Desktop con GNOME)** adaptada para hardware **Microsoft Surface Book 2** con baterías degradadas/muertas (operación 100% fija a corriente alterna).

---

## 💻 Hardware Objetivo y Contexto Crítico

* **Dispositivo:** Microsoft Surface Book 2 (13.5 pulgadas).
* **CPU:** Intel Core i7-8650U (4C/8T, 1.9 GHz base, hasta 4.2 GHz Turbo).
* **dGPU:** NVIDIA GeForce GTX 1050 Mobile (2GB GDDR5).
* **Estado Energético:** **Ambas baterías (pantalla y base) muertas / no cargan (0% persistente)**.

### Mitigaciones de Hardware Implementadas:
1. **Bloqueo a 400 MHz por `BDPROCHOT` (Bi-Directional Processor Hot):**
   * *Problema:* El controlador embebido (EC / Surface Aggregator Module) detecta el fallo/ausencia de batería y activa la señal `BDPROCHOT` hacia la CPU, congelando el reloj a la frecuencia mínima de emergencia (**400 MHz / 0.4 GHz**).
   * *Solución:* Integración de **`throttled`** preconfigurado con `BDPROCHOT: False` en los perfiles `[AC]` y `[BATTERY]`, respaldado por el servicio de contingencia a nivel de kernel **`surface-bdprochot-fallback.service`** que limpia directamente el bit 0 del registro MSR `0x1FC` en el arranque y tras cada ciclo de suspensión/reanudación.
2. **Caídas Súbitas del Sistema por Picos de Consumo (Power Spikes / Brownouts):**
   * *Problema:* El cargador estándar (102W Surface Connect o cargadores USB-C PD de 65W–100W) no cuenta con el amortiguador químico de la batería (*battery boosting*). Un pico simultáneo de CPU + GPU supera el límite de corriente del adaptador y activa la protección contra sobrecorriente (OCP), apagando la máquina de golpe.
   * *Solución:* Servicio systemd **`surface-nvidia-power-limit.service`** ejecutado en el arranque que activa el modo de persistencia (`nvidia-smi -pm 1`) y capa el consumo de la GTX 1050 a **45W** (`nvidia-smi -pl 45`).

---

## 📦 Software Integrado y Preconfigurado

* **Navegador Web:** **LibreWolf** instalado de forma nativa vía su repositorio oficial (`https://repo.librewolf.net/librewolf.repo`).
* **Compartición de periféricos (Software KVM):** **Deskflow** preinstalado nativamente vía RPM / Flatpak (`org.deskflow.Deskflow`) con soporte completo para Wayland (`libei`).
* **Transferencia de archivos local:** **LocalSend** (`org.localsend.localsend_app`) integrado vía Flathub, provisionado automáticamente al primer arranque mediante el servicio desatendido `surface-firstboot.service`.

---

## 🛠️ Pila Tecnológica & Arquitectura

* **Distribución Base:** Fedora Silverblue 40 (Atomic Desktop) vía `ghcr.io/ublue-os/silverblue-nvidia:40`.
* **Kernel y Controladores:**
  * Repositorio oficial de **`linux-surface`**.
  * Paquetes: `kernel-surface`, `kernel-surface-devel`, `kernel-surface-default-watchdog`.
  * `iptsd`: Demonio de procesamiento multitouch y lápiz óptico (Surface Pen).
  * `surface-dtx-daemon`: Demonio de control y desbloqueo del pestillo de desacoplamiento de la pantalla (detachable base).
  * `libwacom-surface`: Soporte calibrado para tabletas Wacom en GNOME Control Center.
  * `surface-secureboot`: Certificados MOK para compatibilidad con Secure Boot.
* **Instalación Desatendida (Kickstart):**
  * Idioma: Inglés (`lang en_US.UTF-8`).
  * Distribución de teclado: Inglés (`keyboard us` / `--vckeymap=us`).
  * Zona horaria: `America/Santo_Domingo` (UTC).
  * Usuario predefinido: `jsl` (perteneciente a `wheel` con privilegios `sudo`).
  * Contraseña inicial: `123123`.
  * Particionado NVMe: Wiping completo automático (`zerombr`, `clearpart --all`), asignación generosa para `/boot/efi` (1GB) y `/boot` (2GB) para prevenir desbordamientos de initramfs.
  * Reinicio automático al terminar (`reboot`).
* **Generación de ISO:**
  * **`bootc-image-builder`** (`quay.io/centos-bootc/bootc-image-builder:latest`) ejecutado en contenedor con `--type anaconda-iso` y `--local`.

---

## 📁 Estructura del Repositorio

```text
├── .github/
│   └── workflows/
│       └── build.yml               # Pipeline de GitHub Actions (trigger manual)
├── bootc/
│   └── kargs.d/
│       └── 50-surface.toml         # Argumentos declarativos del kernel para bootc
├── config/
│   ├── config.toml                 # Configuración de bootc-image-builder con Kickstart embebido
│   ├── ks.cfg                      # Kickstart desatendido independiente
│   ├── recipe.yml                  # Receta declarativa BlueBuild v1
│   ├── surface-dtx.conf            # Configuración del demonio de desacoplamiento de pantalla
│   └── throttled.conf              # Configuración de energía y bypass BDPROCHOT
├── scripts/
│   ├── disable-bd-prochot.sh       # Script de override directo MSR 0x1FC
│   ├── setup-surface-kernel.sh     # Preparación y compilación de akmods
│   ├── surface-firstboot.sh        # Aprovisionamiento desatendido de Flatpaks (LocalSend, Deskflow)
│   └── surface-nvidia-power-limit.sh # Script de limitación de la GPU a 45W
├── systemd/
│   ├── surface-bdprochot-fallback.service # Servicio systemd para BDPROCHOT
│   ├── surface-firstboot.service          # Servicio systemd de primer arranque
│   └── surface-nvidia-power-limit.service # Servicio systemd para GPU Power Cap
├── Containerfile                   # Definición reproducible OCI para Podman/Docker
├── .gitattributes
├── .gitignore
└── README.md
```

---

## 🔑 Credenciales y Primer Arranque

* **Usuario:** `jsl`
* **Contraseña predeterminada:** `123123`
* **Privilegios:** Sudo total sin contraseña configurado en `/etc/sudoers.d/01-wheel-jsl`.

---

## 🚀 Cómo Lanzar la Compilación (GitHub Actions)

El flujo de trabajo `.github/workflows/build.yml` está configurado con **`workflow_dispatch`** para evitar ejecuciones automáticas accidentales en el push de Git.

### Opción A: Desde GitHub CLI (`gh`) en tu terminal
```powershell
# Lanzar la compilación con los parámetros por defecto
gh workflow run "Build Surface Book 2 Atomic ISO"

# Monitorear el progreso en tiempo real
gh run watch
```

### Opción B: Desde la interfaz web de GitHub
1. Abre tu repositorio: [https://github.com/kalmix/surface-book2-atomic-iso/actions](https://github.com/kalmix/surface-book2-atomic-iso/actions)
2. Selecciona **Build Surface Book 2 Atomic ISO** en la barra lateral.
3. Pulsa **Run workflow** -> botón verde **Run workflow**.

Al finalizar, la ISO (`surface-book-2-silverblue-40.iso`) y su suma SHA256 estarán disponibles como artefactos descargables listos para flashear en USB.
