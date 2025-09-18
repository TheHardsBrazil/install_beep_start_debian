#!/bin/bash
set -euo pipefail

# script_auto_config_install_beep_start_debian.sh (standalone atualizado)
# Uso: coloque na mesma pasta o arquivo .deb, o .tar.gz e execute este script.
# Ele extrai primeiro, instala o .deb e depois cria/configura o serviço systemd.

SERVICE_NAME="beep_start"
DEB_FILE=""
PACKAGE_TAR=""
EXECUTABLE_PATH=""

usage() {
  cat <<EOF
Uso: $0 [-d deb_file] [-t tar_gz] [-e exec_path] [-s service_name] [-h]
  -d arquivo .deb (default: detecta beep*.deb ou primeiro *.deb)
  -t arquivo .tar.gz (default: detecta INSTALL_BEEP_START_DEBIAN*.tar.gz ou primeiro *.tar.gz)
  -e caminho completo do executável (se não informado o script tenta detectar)
  -s nome do serviço systemd (default: beep_start)
  -h mostra esta ajuda
EOF
  exit 1
}

while getopts "d:t:e:s:h" opt; do
  case "$opt" in
    d) DEB_FILE="$OPTARG" ;;
    t) PACKAGE_TAR="$OPTARG" ;;
    e) EXECUTABLE_PATH="$OPTARG" ;;
    s) SERVICE_NAME="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

shopt -s nullglob

# Detecta .deb se não passado
if [ -z "$DEB_FILE" ]; then
  candidates=(./beep*.deb)
  if [ ${#candidates[@]} -gt 0 ]; then
    DEB_FILE="${candidates[0]}"
  else
    all=(./*.deb)
    if [ ${#all[@]} -gt 0 ]; then
      DEB_FILE="${all[0]}"
    fi
  fi
fi

# Detecta .tar.gz se não passado
if [ -z "$PACKAGE_TAR" ]; then
  candidates=(./INSTALL_BEEP_START_DEBIAN*.tar.gz)
  if [ ${#candidates[@]} -gt 0 ]; then
    PACKAGE_TAR="${candidates[0]}"
  else
    all=(./*.tar.gz)
    if [ ${#all[@]} -gt 0 ]; then
      PACKAGE_TAR="${all[0]}"
    fi
  fi
fi

echo "== ETAPA 1: Extraindo pacotes =="
if [ -n "$PACKAGE_TAR" ] && [ -f "$PACKAGE_TAR" ]; then
  echo "Extraindo $PACKAGE_TAR ..."
  tar -xvzf "$PACKAGE_TAR"
  package_dir_guess=$(basename "$PACKAGE_TAR" .tar.gz)
  if [ -d "$package_dir_guess" ]; then
    PACKAGE_DIR="$package_dir_guess"
  else
    first_dir=$(tar -tzf "$PACKAGE_TAR" | head -1 | cut -f1 -d"/" )
    PACKAGE_DIR="$first_dir"
  fi
  echo "Pasta extraída: $PACKAGE_DIR"
else
  echo "Aviso: nenhum arquivo .tar.gz encontrado para extrair."
fi

if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
  echo "Erro: arquivo .deb não encontrado. Coloque-o na mesma pasta ou use -d caminho/do/arquivo.deb"
  exit 1
fi

echo "== ETAPA 2: Instalando o .deb =="
echo "Instalando pacote $DEB_FILE ..."
sudo dpkg -i "$DEB_FILE" || {
  echo "dpkg encontrou problemas; tentando corrigir dependências com apt-get..."
  sudo apt-get update
  sudo apt-get install -f -y
}

PKG_NAME=$(dpkg-deb -f "$DEB_FILE" Package 2>/dev/null || true)
FOUND_EXEC=""
if [ -n "$PKG_NAME" ]; then
  installed_files=$(dpkg -L "$PKG_NAME" 2>/dev/null || true)
  while IFS= read -r f; do
    if [ -f "$f" ] && [ -x "$f" ]; then
      bn=$(basename "$f")
      if [[ "$bn" == beep* ]] || [[ "$bn" == *beep* ]]; then
        FOUND_EXEC="$f"
        break
      fi
    fi
  done <<<"$installed_files"
fi

if [ -z "$FOUND_EXEC" ]; then
  for d in "./${PACKAGE_DIR:-.}" /opt /usr/bin /usr/local/bin /opt/beep_start; do
    if [ -d "$d" ]; then
      candidate=$(find "$d" -maxdepth 4 -type f -executable -name "*beep*" 2>/dev/null | head -1 || true)
      if [ -n "$candidate" ]; then
        FOUND_EXEC="$candidate"
        break
      fi
    fi
  done
fi

if [ -n "$EXECUTABLE_PATH" ]; then
  FOUND_EXEC="$EXECUTABLE_PATH"
fi

if [ -z "$FOUND_EXEC" ]; then
  echo "Não foi possível detectar automaticamente o executável, usando padrão /opt/beep_start/beep_start"
  FOUND_EXEC="/opt/beep_start/beep_start"
  sudo mkdir -p /opt/beep_start || true
fi

echo "Executável selecionado: $FOUND_EXEC"

RUN_USER=${SUDO_USER:-$(whoami)}
WORKING_DIR=$(dirname "$FOUND_EXEC")
[ -z "$WORKING_DIR" ] && WORKING_DIR="/opt/beep_start"

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "== ETAPA 3: Configurando serviço systemd =="
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Serviço Beep Start
After=graphical.target

[Service]
Type=simple
ExecStart=${FOUND_EXEC}
Restart=no
User=${RUN_USER}
WorkingDirectory=${WORKING_DIR}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${RUN_USER}/.Xauthority
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

echo "Recarregando systemd e habilitando serviço..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME" || true

echo
echo "== STATUS do serviço ${SERVICE_NAME} =="
sudo systemctl status "$SERVICE_NAME" --no-pager || true
echo "Concluído."
