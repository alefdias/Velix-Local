# 💡 Velix Local — Roadmap de Ideias & Próximas Funcionalidades

Este documento reúne propostas e especificações de novos recursos planejados para enriquecer a experiência do **Velix Local**, fortalecendo sua posição como solução líder para transferência, sincronização e gerenciamento de frotas em redes locais sem dependência de nuvem.

---

## 1. 📋 Copiar & Colar Universal (Shared Clipboard)
* **Objetivo:** Sincronizar a área de transferência em tempo real entre computadores e celulares na mesma rede.
* **Como funciona:**
  - O usuário copia um texto, código ou link no celular (`Copiar`).
  - O Velix transmite o payload via socket local cifrado.
  - No computador ou notebook de destino, o texto já fica disponível instantaneamente no `Ctrl + V`.
* **Benefício:** Elimina a necessidade de enviar mensagens para si mesmo em mensageiros (WhatsApp, Telegram) apenas para transferir links ou trechos de código.

---

## 2. 🌐 Modo "Web Share" com QR Code (Compartilhamento sem App)
* **Objetivo:** Permitir que dispositivos sem o Velix instalado (iPhones, visitantes, smart TVs, PCs de terceiros) enviem e recebam arquivos.
* **Como funciona:**
  - O Velix inicia uma interface web leve embutida na porta local (ex: `http://192.168.1.15:53318/share`).
  - Um **QR Code** é exibido na tela do app.
  - Qualquer pessoa na mesma rede aponta a câmera do celular ou abre o link no navegador para baixar ou fazer upload de arquivos diretamente no seu computador.
* **Benefício:** Máxima acessibilidade sem obrigar terceiros a instalarem o aplicativo.

---

## 3. 💬 Chat & Mensagens Rápidas na Rede Local
* **Objetivo:** Comunicação direta e instantânea entre os dispositivos conectados na rede local.
* **Como funciona:**
  - Uma aba de chat no menu do aplicativo.
  - Notificações nativas na área de trabalho do sistema (Windows, Linux e Android).
  - Permite enviar recados rápidos (*"Reunião em 5 minutos"*, *"Reinicie sua máquina"*, *"Arquivo enviado na pasta X"*).
* **Benefício:** Comunicação corporativa interna e segura sem depender de internet externa ou servidores centrais.

---

## 4. 🖱️ Integração com o Botão Direito do Mouse ("Enviar com Velix")
* **Objetivo:** Acelerar o envio de arquivos diretamente do explorador do sistema operacional.
* **Como funciona:**
  - **No Windows:** Registro no menu de contexto do Explorer (`shell/VelixLocal`).
  - **No Linux (Fedora/Ubuntu):** Ação de extensão para Nautilus / Dolphin / Nemo.
  - O usuário clica com o botão direito em qualquer arquivo ou pasta → escolhe *"Enviar com Velix Local"* → seleciona o computador de destino em um mini popup rápido.
* **Benefício:** Fluxo de trabalho nativo e imediato sem precisar abrir a tela do aplicativo antes.

---

## 5. ⚡ Comandos & Scripts Remotos em Massa (Terminal Remoto)
* **Objetivo:** Gerenciamento centralizado de TI para automação de tarefas em múltiplos computadores.
* **Como funciona:**
  - Extensão corporativa do módulo **Velix Deploy**.
  - O administrador escolhe uma máquina ou todas da rede e dispara scripts (`.bat`, `.ps1`, `.sh`) ou comandos diretos (ex: `shutdown /r /t 0`, limpeza de cache, verificação de espaço em disco).
  - Retorno em tempo real da saída (stdout/stderr) de cada máquina.
* **Benefício:** Economia massiva de tempo para suporte técnico e administradores de rede.

---

## 6. 🕒 Velix Backup (Rotinas de Backup Automático)
* **Objetivo:** Proteção contínua e automatizada de dados críticos em rede local.
* **Como funciona:**
  - Definição de pastas de origem (ex: `Documentos/Projetos`) e destino em outra máquina (ex: `Servidor TI`).
  - Agendamento por gatilhos:
    - *Ao conectar na rede*: assim que o notebook chega na empresa/casa, o backup é disparado.
    - *Periódico*: diariamente ou semanalmente em horário programado.
  - Suporte a backup incremental (copia apenas arquivos modificados).
* **Benefício:** Segurança total contra perda de dados sem custos de armazenamento em nuvem.

---

## 7. 🔒 Modo Administrador com Senha Mestra (Proteção Corporativa)
* **Objetivo:** Proteger configurações críticas contra alterações não autorizadas.
* **Como funciona:**
  - Bloqueio por PIN/Senha para áreas sensíveis como **Velix Deploy**, exclusão de pastas no **Sync** e ajustes de rede.
  - Permite deixar o Velix rodando como serviço em máquinas de funcionários comuns sem risco de mau uso.
* **Benefício:** Adequação aos padrões de segurança da informação em ambientes empresariais.
