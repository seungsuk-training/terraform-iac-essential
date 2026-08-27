#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script supports Ubuntu Linux only." >&2
  exit 1
fi

if ! grep -qi ubuntu /etc/os-release; then
  echo "This script supports Ubuntu Linux only." >&2
  exit 1
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl git gnupg unzip wget

keyring_path="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
repository_path="/etc/apt/sources.list.d/hashicorp.list"

if [[ ! -f "${keyring_path}" ]]; then
  wget -qO- https://apt.releases.hashicorp.com/gpg |
    gpg --dearmor |
    sudo tee "${keyring_path}" >/dev/null
fi

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring_path}] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" |
  sudo tee "${repository_path}" >/dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y terraform

if ! command -v aws >/dev/null 2>&1 ||
  ! aws --version 2>&1 | grep -q '^aws-cli/2'; then
  case "$(uname -m)" in
    x86_64)
      aws_arch="x86_64"
      ;;
    aarch64|arm64)
      aws_arch="aarch64"
      ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac

  aws_tmp_dir="$(mktemp -d)"
  cleanup() {
    rm -rf "${aws_tmp_dir}"
  }
  trap cleanup EXIT

  curl -fsSLo "${aws_tmp_dir}/awscliv2.zip" \
    "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip"
  unzip -q "${aws_tmp_dir}/awscliv2.zip" -d "${aws_tmp_dir}"

  if [[ -d /usr/local/aws-cli ]]; then
    sudo "${aws_tmp_dir}/aws/install" --update
  else
    sudo "${aws_tmp_dir}/aws/install"
  fi
fi

kiro_cli_path="${HOME}/.local/bin/kiro-cli"
if [[ ! -x "${kiro_cli_path}" ]]; then
  curl -fsSL https://cli.kiro.dev/install | bash
fi

if [[ ! -x "${kiro_cli_path}" ]]; then
  echo "Kiro CLI installation did not create ${kiro_cli_path}." >&2
  exit 1
fi

# VS Code Remote-SSH terminals do not always reload ~/.profile. Expose the
# user-scoped installation through a directory already present on PATH.
sudo ln -sfn "${kiro_cli_path}" /usr/local/bin/kiro-cli
hash -r

echo
echo "Development environment is ready."
git --version
terraform version
aws --version
kiro-cli --version
