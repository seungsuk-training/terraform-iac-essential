#!/usr/bin/env bash
set -euo pipefail

terraform_version="${1:-1.15.8}"

case "$(uname -m)" in
  x86_64)
    terraform_arch="amd64"
    ;;
  aarch64|arm64)
    terraform_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

terraform_filename="terraform_${terraform_version}_linux_${terraform_arch}.zip"
terraform_base_url="https://releases.hashicorp.com/terraform/${terraform_version}"
terraform_bin_dir="${HOME}/.local/bin"
terraform_tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${terraform_tmp_dir}"
}
trap cleanup EXIT

echo "Downloading Terraform ${terraform_version} for linux_${terraform_arch}..."
curl -fsSLo "${terraform_tmp_dir}/${terraform_filename}" \
  "${terraform_base_url}/${terraform_filename}"
curl -fsSLo "${terraform_tmp_dir}/terraform_${terraform_version}_SHA256SUMS" \
  "${terraform_base_url}/terraform_${terraform_version}_SHA256SUMS"

(
  cd "${terraform_tmp_dir}"
  grep " ${terraform_filename}$" "terraform_${terraform_version}_SHA256SUMS" |
    sha256sum --check -
)

mkdir -p "${terraform_bin_dir}"
unzip -q -o "${terraform_tmp_dir}/${terraform_filename}" -d "${terraform_bin_dir}"

path_line='export PATH="$HOME/.local/bin:$PATH"'
touch "${HOME}/.bashrc"
if ! grep -qxF "${path_line}" "${HOME}/.bashrc"; then
  printf '\n%s\n' "${path_line}" >> "${HOME}/.bashrc"
fi

export PATH="${terraform_bin_dir}:${PATH}"

echo "Terraform installed in ${terraform_bin_dir}."
terraform version
echo "Run 'source ~/.bashrc' if a new shell cannot find terraform."
