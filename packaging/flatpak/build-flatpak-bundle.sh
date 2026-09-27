#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SOURCE_BUNDLE="${ROOT_DIR}/build/linux/x64/release/bundle"
OUTPUT_DIR="${ROOT_DIR}/dist"
OUTPUT_BUNDLE="${OUTPUT_DIR}/velix-local-linux-x86_64.flatpak"

if [ ! -d "${SOURCE_BUNDLE}" ]; then
  echo "Erro: Diretório ${SOURCE_BUNDLE} não encontrado. Compile o Linux antes (flutter build linux --release)."
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

BUILD_DIR=$(mktemp -d -t velix-fp-build-XXXXXX)
REPO_DIR=$(mktemp -d -t velix-fp-repo-XXXXXX)

cleanup() {
  rm -rf "${BUILD_DIR}" "${REPO_DIR}"
}
trap cleanup EXIT

echo "=== 1. Inicializando ambiente Flatpak ==="
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if ! flatpak list --user | grep -q "org.freedesktop.Platform.*24.08"; then
  echo "Instalando runtime org.freedesktop.Platform 24.08..."
  flatpak install --user -y --noninteractive flathub org.freedesktop.Platform//24.08
fi

flatpak build-init "${BUILD_DIR}" io.github.alefdias.VelixLocal org.freedesktop.Platform org.freedesktop.Platform 24.08

echo "=== 2. Copiando arquivos do aplicativo ==="
mkdir -p "${BUILD_DIR}/files/lib/velix-local"
cp -r "${SOURCE_BUNDLE}"/* "${BUILD_DIR}/files/lib/velix-local/"

mkdir -p "${BUILD_DIR}/files/bin"
cat << 'EOF' > "${BUILD_DIR}/files/bin/velix-local"
#!/bin/bash
exec /app/lib/velix-local/velix_local "$@"
EOF
chmod +x "${BUILD_DIR}/files/bin/velix-local"

mkdir -p "${BUILD_DIR}/files/share/applications" \
         "${BUILD_DIR}/files/share/metainfo" \
         "${BUILD_DIR}/files/share/icons/hicolor/192x192/apps"

cp "${SCRIPT_DIR}/io.github.alefdias.VelixLocal.desktop" "${BUILD_DIR}/files/share/applications/"
cp "${SCRIPT_DIR}/io.github.alefdias.VelixLocal.png" "${BUILD_DIR}/files/share/icons/hicolor/192x192/apps/"

# Atualizar versão dinamicamente no metainfo temporário
APP_VERSION=$(grep "^version:" "${ROOT_DIR}/pubspec.yaml" | head -n1 | cut -d' ' -f2 | cut -d'+' -f1)
TODAY=$(date +%Y-%m-%d)
sed -e "s/<release version=\"[^\"]*\" date=\"[^\"]*\"/<release version=\"${APP_VERSION}\" date=\"${TODAY}\"/" \
    "${SCRIPT_DIR}/io.github.alefdias.VelixLocal.metainfo.xml" > "${BUILD_DIR}/files/share/metainfo/io.github.alefdias.VelixLocal.metainfo.xml"

echo "=== 3. Configurando permissões do Flatpak ==="
flatpak build-finish "${BUILD_DIR}" \
  --command=velix-local \
  --share=network \
  --share=ipc \
  --socket=fallback-x11 \
  --socket=wayland \
  --device=dri \
  --filesystem=xdg-download \
  --filesystem=home:ro \
  --talk-name=org.freedesktop.Notifications

echo "=== 4. Exportando para repositório OSTree ==="
flatpak build-export "${REPO_DIR}" "${BUILD_DIR}"

echo "=== 5. Gerando pacote Flatpak (.flatpak bundle) ==="
flatpak build-bundle "${REPO_DIR}" "${OUTPUT_BUNDLE}" io.github.alefdias.VelixLocal --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

echo " Pacote Flatpak gerado com sucesso em: ${OUTPUT_BUNDLE}"
ls -lh "${OUTPUT_BUNDLE}"
