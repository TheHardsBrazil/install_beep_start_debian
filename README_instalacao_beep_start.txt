README - Instalação do Beep Start (resumido)

Coloque na mesma pasta:
 - o arquivo .deb do Beep Start (ex: beepstart_linux_amd64.deb)
 - o arquivo .tar.gz (INSTALL_BEEP_START_DEBIAN_SEM_MAIN.tar.gz)
 - o script principal (script_auto_config_install_beep_start_debian.sh) que você recebeu separado
 - este README (opcional)

Exemplo de uso:
mkdir ~/install-beep && cd ~/install-beep
# coloque os 3 arquivos dentro dessa pasta
chmod +x script_auto_config_install_beep_start_debian.sh
./script_auto_config_install_beep_start_debian.sh

Se quiser especificar arquivos manualmente:
./script_auto_config_install_beep_start_debian.sh -d beepstart_linux_amd64.deb -t INSTALL_BEEP_START_DEBIAN_SEM_MAIN.tar.gz

Verifique o serviço: systemctl status beep_start
