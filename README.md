# Velix Local ⚡

> **Velix Local — Sincronize sem nuvem.**

O **Velix Local** é um software de sincronização e transferência inteligente de arquivos entre dispositivos na mesma rede local, **sem internet, sem nuvem, sem servidores externos e totalmente peer-to-peer (P2P)**.

Construído em **Flutter + Dart**, com interface moderna inspirada no **Windows 11 Fluent Design e Material 3**, com suporte nativo multiplataforma para **Windows (.exe)**, **Linux** e **Android**.

---

## 🌟 Diferenciais do Produto

Ao contrário de meras ferramentas de compartilhamento manual de arquivos, o diferencial primário do Velix Local é o **Velix Sync**:
* **Sincronização Bidirecional Automática:** Mantenha pastas inteiras sincronizadas continuamente entre computadores e celulares (ex: `PC: Documentos/Projetos` ↔ `Notebook: Documentos/Projetos`).
* **Detecção em Tempo Real:** Alterações, criações e exclusões são identificadas via File Watchers locais e propagadas em segundo plano.
* **Resolução Inteligente de Conflitos:** Edições simultâneas preservam os arquivos criando versões no padrão `arquivo (Notebook).pdf`.
* **Retomada de Transferência (Chunk Transfer Protocol):** Se uma transferência de 8 GB for interrompida em 95%, o Velix Local salva os blocos concluídos no banco SQLite e retoma exatamente do ponto onde parou. Nunca reinicia do zero!

---

## 🛠️ Tecnologias Utilizadas

* **Flutter 3.29+ & Dart 3.7+**
* **Material 3 & Windows 11 Fluent Design**
* **SQLite (via `sqflite` e `sqflite_common_ffi`)**
* **mDNS / UDP Broadcast & Multicast (Descoberta P2P Zero-Config)**
* **HTTP Server Local embutido com protocolo de blocos (Chunking)**
* **100% Offline & Local (Sem Firebase, sem telemetria externa)**

---

## 🚀 Funcionalidades

### 1. Descoberta Automática de Dispositivos (mDNS)
* Varredura contínua na sub-rede local.
* Exibição de Nome, Sistema Operacional, IP e Status Online em tempo real.

### 2. Pareamento Seguro com Código de 6 Dígitos
* Primeira conexão exige confirmação mútua de um PIN de 6 dígitos gerado aleatoriamente.
* Dispositivos confirmados são salvos como confiáveis no SQLite e nunca mais solicitam aprovação manual.

### 3. Velix Sync ⭐
* Gerenciamento de pastas sincronizadas com configuração em clique único.
* Estatísticas de arquivos e tamanho total.
* Botões de ação rápida: **Sincronizar Agora**, **Pausar/Retomar** e **Remover**.
* Status atualizado com tempo relativo (ex: *"Sincronizado há 8 segundos"*).

### 4. Transferência Inteligente
* Envio rápido por **Drag & Drop** (arrastar e soltar arquivos ou diretórios na janela).
* Seleção múltipla de arquivos, imagens, pastas completas ou texto/recortes.
* Monitoramento com velocidade em **MB/s**, tempo restante estimado (**ETA**), blocos concluídos e barra de progresso.

### 5. Histórico e Auditoria
* Armazenamento permanente em banco SQLite:
  * Nome do arquivo, origem, destino, data/hora, velocidade média, tempo total e status.
* Pesquisa instantânea por nome de arquivo ou dispositivos.
* Abertura direta do arquivo local ou pasta receptora.

---

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                      # Inicialização P2P, MultiProvider e layout responsivo
├── models/
│   ├── device.dart                # Modelo de dispositivo e plataformas
│   ├── sync_folder.dart           # Modelo de pastas sincronizadas
│   ├── transfer.dart              # Modelo de transferência e histórico
│   └── chunk_progress.dart        # Modelo de blocos e retomada
├── services/
│   ├── database_service.dart      # Persistência SQLite local
│   ├── settings_service.dart      # Configurações do app e ID persistente
│   ├── mdns_service.dart          # Descoberta local por broadcast/multicast
│   ├── pair_service.dart          # Pareamento de 6 dígitos seguro
│   ├── sync_service.dart          # Motor de sincronização em tempo real (Watchers)
│   └── chunk_transfer_service.dart# Servidor HTTP & protocolo de chunks
├── screens/
│   ├── home_screen.dart           # Visão geral, estatísticas e atividades
│   ├── devices_screen.dart        # Gerenciamento de dispositivos e pareamento
│   ├── sync_screen.dart           # Telas do Velix Sync
│   ├── transfer_screen.dart       # Drag & Drop e envio inteligente
│   ├── history_screen.dart        # Histórico SQLite com busca
│   └── settings_screen.dart       # Configurações do sistema
└── widgets/
    ├── device_card.dart           # Card estilizado de dispositivo
    ├── sync_card.dart             # Card oficial de sincronização PC ↔ Notebook
    ├── progress_widget.dart       # Barra de progresso com MB/s e blocos
    └── sidebar.dart               # Sidebar inspirada em Windows 11
```

---

## 💻 Como Compilar e Executar

### Pré-requisitos
* Flutter SDK (3.29 ou superior)

### Executar em Desenvolvimento
```bash
flutter pub get
flutter run
```

### Compilar para Windows (.exe)
```bash
flutter build windows --release
```
O executável final estará disponível em: `build/windows/x64/runner/Release/velix_local.exe`

### Compilar para Linux
```bash
flutter build linux --release
```
O executável final estará disponível em: `build/linux/x64/release/bundle/velix_local`

### Compilar para Android (.apk)
```bash
flutter build apk --release
```
O APK final estará disponível em: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 Licença

Distribuído sob a licença **MIT**. Veja o arquivo `LICENSE` para mais detalhes.
