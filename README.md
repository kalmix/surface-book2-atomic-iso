# Microsoft Surface Book 2 (13.5" i7 / GTX 1050) - Fedora Silverblue 40 Unattended ISO

Repositorio y pipeline CI/CD con **GitHub Actions** para generar una imagen OCI y una **ISO desatendida booteable** de **Fedora Silverblue 40 (Atomic Desktop con GNOME)** adaptada para hardware **Microsoft Surface Book 2** operando con **cargador USB-C de 65W** y baterías degradadas/muertas (operación 100% fija a corriente alterna).

---

## ⚡ Presupuesto Eléctrico Estricto: Cargador USB-C de 65W

Cuando un Surface Book 2 opera con un cargador USB-C de 65W y **baterías muertas al 0%**, no existe buffer químico de respaldo (*battery discharge assist*). Cualquier consumo momentáneo que exceda los 65W provoca la caída de voltaje en la línea PD o dispara el OCP (Over-Current Protection), provocando el **apagado súbito inmediato (blackout)**.

### Desglose del Presupuesto Energético Dinámico (~60W):
* **Plataforma Base:** Pantalla PixelSense 3000x2000, placa base, memoria RAM, SSD NVMe, ventiladores y Wi-Fi: **~15W**.
* **CPU Intel Core i7-8650U:** Limitado sostenido a **15W** (PL1) con picos cortos de **22W** (PL2) vía `throttled`.
* **GPU NVIDIA GeForce GTX 1050 Mobile:** Capada a **30W** vía `nvidia-smi -pl 30`, techo de reloj a **1100 MHz** y PowerMizer en modo *Adaptive* (`0x2`).
* **Consumo Pico Máximo Total:** 15W (base) + 15W (CPU) + 30W (GPU) = **~60W** (margen de seguridad de 5W frente al límite de 65W).

---

## 💻 Hardware Objetivo y Mitigaciones Críticas

* **Dispositivo:** Microsoft Surface Book 2 (13.5 pulgadas).
* **CPU:** Intel Core i7-8650U (4C/8T, 1.9 GHz base, Turbo ajustado a 22W).
* **dGPU:** NVIDIA GeForce GTX 1050 Mobile (2GB GDDR5).
* **Alimentación:** Cargador USB-C PD de 65W.

### Mitigaciones de Hardware Implementadas:
1. **Bypass del Bloqueo a 400 MHz (`BDPROCHOT`):**
   * El controlador embebido (EC / SAM) al ver 0% de batería activa la señal de alarma `BDPROCHOT` a la CPU.
   * `throttled` preconfigurado con `BDPROCHOT: False` en `/etc/throttled.conf`.
   * Servicio systemd de contingencia `surface-bdprochot-fallback.service` que limpia directamente el bit 0 de MSR `0x1FC` en arranque y reanudación.
2. **Protección Anti-Brownout para 65W USB-C (`surface-nvidia-power-limit.service`):**
   * Configuración central en `/etc/surface-power.conf`.
   * Fuerza el modo de persistencia (`nvidia-smi -pm 1`).
   * Capa el consumo de la GTX 1050 a **30W** (`nvidia-smi -pl 30`).
   * Fija un techo de reloj gráfico a **1100 MHz** (`nvidia-smi -lgc 300,1100`) para frenar picos transitorios de boost.
   * Modprobe en `/etc/modprobe.d/nvidia-power.conf` forzando PowerMizer Adaptive para evitar el estado P0 a máxima potencia.

---

## 📦 Software Integrado y Preconfigurado

* **Navegador Web:** **LibreWolf** instalado de forma nativa vía su repositorio oficial (`https://repo.librewolf.net/librewolf.repo`).
* **Compartición de periféricos (Software KVM):** **Deskflow** preinstalado nativamente vía RPM / Flatpak (`org.deskflow.Deskflow`) con soporte nativo para Wayland (`libei`).
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
  * Particionado NVMe: Wiping completo automático (`zerombr`, `clearpart --all`), asignación generosa para `/boot/efi` (1GB) y `/boot` (2GB).
  * Reinicio automático al terminar (`reboot`).
* **Generación de ISO:**
  * **`bootc-image-builder`** (`quay.io/centos-bootc/bootc-image-builder:latest`) con `--type anaconda-iso` y `--local`.

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
│   ├── modprobe-nvidia-power.conf  # Opciones del kernel NVIDIA para PowerMizer Adaptive
│   ├── recipe.yml                  # Receta declarativa BlueBuild v1
│   ├── surface-dtx.conf            # Configuración del demonio de desacoplamiento de pantalla
│   ├── surface-power.conf          # Configuración del perfil de energía (65W USB-C)
│   └── throttled.conf              # Perfil térmico CPU (PL1=15W, PL2=22W) y bypass BDPROCHOT
├── scripts/
│   ├── disable-bd-prochot.sh       # Script de override directo MSR 0x1FC
│   ├── setup-surface-kernel.sh     # Preparación y compilación de akmods
│   ├── surface-firstboot.sh        # Aprovisionamiento desatendido de Flatpaks (LocalSend, Deskflow)
│   └── surface-nvidia-power-limit.sh # Script de limitación de la GPU a 30W / 1100 MHz
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

## 🔧 Personalización del Cargador en el Futuro

Si en el futuro adquieres un cargador de 100W USB-C PD o el cargador original Surface Connect de 102W, puedes aumentar el límite de la GPU simplemente editando `/etc/surface-power.conf`:

```bash
sudo nano /etc/surface-power.conf
# Cambiar GPU_TARGET_POWER_W=45
# Cambiar GPU_MAX_CLOCK_MHZ=""
sudo systemctl restart surface-nvidia-power-limit.service
```

---

## 🔑 Credenciales y Primer Arranque

* **Usuario:** `jsl`
* **Contraseña predeterminada:** `123123`
* **Privilegios:** Sudo total sin contraseña configurado en `/etc/sudoers.d/01-wheel-jsl`.

---

## 🚀 Cómo Lanzar la Compilación (GitHub Actions)

El workflow `.github/workflows/build.yml` está en espera manual (`workflow_dispatch`).

### Opción A: Desde GitHub CLI (`gh`) en tu terminal
```powershell
gh workflow run "Build Surface Book 2 Atomic ISO"
gh run watch
```

### Opción B: Desde GitHub Web
1. Abre tu repositorio: [https://github.com/kalmix/surface-book2-atomic-iso/actions](https://github.com/kalmix/surface-book2-atomic-iso/actions)
2. Selecciona **Build Surface Book 2 Atomic ISO** en la barra lateral.
3. Pulsa **Run workflow** -> botón verde **Run workflow**.
