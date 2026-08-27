# Terraform IaC Essential Hands-on

개인 노트북의 VS Code와 Local Terminal에서 Terraform으로 AWS Highly Available Web Service를 구축하고 Kiro CLI로 코드를 분석하는 4시간 Hands-on Lab입니다.

## Lab Overview

```text
Terraform Code
      ↓
Custom VPC
      ↓
Public Subnet A/C: Internet-facing ALB
      ↓
Target Group
      ↓
Private Subnet A/C: Golden AMI 기반 Auto Scaling Web EC2
      ↓
ALB DNS로 Web Service 확인
      ↓
Kiro CLI AI-assisted IaC
```

Region은 `ap-northeast-2`, VPC는 `10.0.0.0/16`입니다. Public Subnet은 `10.0.0.0/24`, `10.0.2.0/24`, Private Subnet은 `10.0.1.0/24`, `10.0.3.0/24`입니다.

Golden AMI에 Web Server와 Application을 포함하므로 Private EC2의 Internet Outbound가 필요하지 않습니다. 따라서 NAT Gateway를 구성하지 않습니다. 실제 환경에서는 요구사항에 따라 NAT Gateway나 VPC Endpoint를 검토해야 합니다. RDS, Bastion, Module, Remote Backend와 CI/CD도 4시간 범위에서 제외합니다.

> 기본 Workflow: Read → Modify → `fmt` → `validate` → `plan` → Human Review → `apply` → Verify

## 0. 교육 전 준비

환경 구성, IAM, Kiro CLI도 본 과정의 필수 범위입니다. 교육 당일 시간을 확보하려면 가능하면 사전에 완료합니다.

지원 환경:

- Windows 11: PowerShell 또는 Windows Terminal에서 Native CLI 사용
- Windows 10: Kiro CLI 필수 실습을 위해 WSL2 Ubuntu 사용
- macOS
- Ubuntu Linux

필수 도구:

1. Visual Studio Code
2. Git
3. Terraform CLI
4. AWS CLI v2
5. Kiro CLI
6. VS Code의 HashiCorp Terraform Extension 권장

### 0-1. Windows 11

다음 공식 Installer를 사용합니다.

- [Visual Studio Code](https://code.visualstudio.com/download): User Installer 실행
- [Git for Windows](https://git-scm.com/install/windows): Installer 실행
- [Terraform CLI](https://developer.hashicorp.com/terraform/install): Windows AMD64 ZIP 압축을 풀고 `terraform.exe`가 있는 Directory를 사용자 `Path`에 추가
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html): Windows MSI Installer 실행
- [Kiro CLI](https://kiro.dev/docs/cli/): Windows 항목을 선택하여 현재 공식 PowerShell 설치 절차 실행

설치 후 새 PowerShell을 열어 확인합니다.

```powershell
git --version
terraform version
aws --version
kiro-cli --version
```

명령을 찾지 못하면 Terminal을 완전히 닫았다가 다시 열고 Installer의 `Add to PATH` 또는 Windows 환경 변수 `Path` 설정을 확인합니다.

### 0-2. Windows 10

Kiro CLI는 현재 Windows 11을 Native 지원합니다. Windows 10에서는 [WSL 설치 안내](https://learn.microsoft.com/windows/wsl/install)에 따라 WSL2와 Ubuntu를 설치하고, 이후 Git/Terraform/AWS CLI/Kiro CLI 명령은 모두 Ubuntu Terminal 안에서 실행합니다.

관리자 PowerShell에서:

```powershell
wsl --install -d Ubuntu
```

재부팅 후 Ubuntu Terminal을 열고 아래의 `0-4. Ubuntu Linux` 중 CLI 설치 절차를 따릅니다. Linux용 VS Code `.deb`는 WSL 안에 설치하지 않습니다. VS Code에는 `WSL` Extension과 `HashiCorp Terraform` Extension을 설치합니다. Repository를 WSL Home Directory에 Clone한 뒤 WSL Terminal에서 `code .`를 실행하거나 VS Code의 `WSL: Open Folder in WSL`을 사용합니다.

> Windows 10에서 WSL2를 처음 설치하는 과정은 재부팅이 필요할 수 있으므로 반드시 교육 전에 완료합니다.

### 0-3. macOS

- [Visual Studio Code](https://code.visualstudio.com/docs/setup/mac): DMG를 열고 Applications로 이동
- [Git](https://git-scm.com/install/mac): 공식 안내에 따라 설치
- [Homebrew](https://brew.sh/)가 있다면 Terraform을 다음과 같이 설치

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

AWS CLI v2와 Kiro CLI는 공식 설치 스크립트를 사용합니다.

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
curl -fsSL https://cli.kiro.dev/install | bash
```

새 Terminal을 열고 확인합니다.

```bash
git --version
terraform version
aws --version
kiro-cli --version
```

`aws` 또는 `kiro-cli`를 찾지 못하면 `export PATH="$HOME/.local/bin:$PATH"`를 `~/.zshrc`에 추가하고 새 Terminal을 엽니다.

macOS에서 `code` 명령이 필요하면 VS Code의 Command Palette에서 `Shell Command: Install 'code' command in PATH`를 실행합니다. 이 설정이 없어도 VS Code GUI의 `File → Open Folder`로 실습할 수 있습니다.

### 0-4. Ubuntu Linux

VS Code는 [공식 Linux 설치 안내](https://code.visualstudio.com/docs/setup/linux)에 따라 `.deb` Package를 설치합니다. Git과 설치 도구를 준비합니다.

```bash
sudo apt update
sudo apt install -y git curl wget gpg unzip
```

HashiCorp 공식 APT Repository에서 Terraform을 설치합니다.

```bash
wget -O - https://apt.releases.hashicorp.com/gpg |
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" |
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform
```

AWS CLI v2와 Kiro CLI를 설치합니다.

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
curl -fsSL https://cli.kiro.dev/install | bash
```

새 Terminal을 열고 확인합니다.

```bash
git --version
terraform version
aws --version
kiro-cli --version
```

`aws` 또는 `kiro-cli`를 찾지 못하면 다음을 실행하고 새 Terminal을 엽니다.

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 0-5. VS Code Extension

VS Code → Extensions (`Ctrl+Shift+X` 또는 macOS `Cmd+Shift+X`)에서 `HashiCorp Terraform`을 검색하여 Publisher가 HashiCorp인지 확인하고 설치합니다. Terraform Syntax Highlighting, Formatting과 기본 오류 확인에 도움을 줍니다.

## 1. AWS IAM 실습 사용자 준비

### 1-1. Root User 사용 원칙

> AWS Root User는 계정 수준의 관리 작업에만 사용하고, Terraform과 AWS CLI에서 Root Access Key를 사용하지 않습니다.

Root User로 처음 로그인하여 `tf-user`를 만든 뒤 즉시 로그아웃합니다. Root Access Key는 과정 전체에서 생성하지 않습니다. Root User에는 MFA 설정을 권장합니다.

### 1-2. `tf-user`와 Console Access 생성

Root User로 AWS Console에 로그인한 뒤:

1. IAM → Users → Create user
2. User name에 `tf-user` 입력
3. `Provide user access to the AWS Management Console` 선택
4. `I want to create an IAM user` 선택
5. Console Password를 자동 생성하거나 강사가 안내한 규칙으로 설정
6. 필요에 따라 `User must create a new password at next sign-in` 선택
7. Permissions에서 `Attach policies directly` 선택
8. AWS Managed Policy `AdministratorAccess` 선택
9. Review 후 Create user
10. Console Sign-in URL, User name과 초기 Password를 안전한 곳에 보관

> 이번 과정에서는 제한된 시간 동안 개인 실습 계정에서 Terraform의 여러 AWS Resource를 생성하기 위해 `AdministratorAccess`를 사용합니다. 실제 운영 환경에서는 필요한 작업에 맞는 최소 권한(Least Privilege)을 적용해야 합니다.

Root User에서 로그아웃한 뒤 IAM User Sign-in URL을 열어 `tf-user`로 로그인합니다. Account ID, 실제 Password 또는 Sign-in URL을 Repository에 기록하지 않습니다.

### 1-3. `tf-user` Access Key 생성

`tf-user`로 Console에 로그인한 상태에서:

1. 우측 상단 User menu → Security credentials 또는 IAM → Users → `tf-user`
2. Security credentials Tab → Access keys → Create access key
3. Use case에서 `Command Line Interface (CLI)` 선택
4. 보안 권고를 확인하고 Create access key
5. Access Key ID와 Secret Access Key를 안전하게 보관하거나 CSV Download

Secret Access Key는 이 화면에서만 확인할 수 있습니다.

- Root User Access Key를 만들지 않습니다.
- Access Key를 `.tf`, `.tfvars`, README, Source Code에 입력하지 않습니다.
- Access Key/Secret Key, `.aws/credentials`를 GitHub에 Commit하지 않습니다.
- Key가 노출되었다면 즉시 비활성화 또는 삭제하고 새 Key를 생성합니다.

## 2. Local AWS CLI Credential 설정

VS Code의 Local Terminal 또는 OS Terminal에서 실행합니다.

```bash
aws configure
```

Windows PowerShell에서도 동일한 명령입니다.

```text
AWS Access Key ID: <tf-user Access Key>
AWS Secret Access Key: <tf-user Secret Access Key>
Default region name: ap-northeast-2
Default output format: json
```

AWS CLI는 기본 Profile의 Credential을 사용자 Home의 `.aws/credentials`에, Region과 Output 설정을 `.aws/config`에 저장합니다. 이 파일을 프로젝트로 복사하거나 Git에 추가하지 않습니다.

인증을 확인합니다.

```bash
aws sts get-caller-identity
```

성공 조건:

- 자신의 AWS Account ID가 출력됨
- ARN이 `user/tf-user`를 포함함
- `InvalidClientTokenId`, `SignatureDoesNotMatch`, `AccessDenied`가 없음

## 3. 개발환경 준비 Checkpoint

다음이 모두 성공해야 Terraform Lab으로 이동합니다.

```bash
git --version
terraform version
aws --version
aws sts get-caller-identity
kiro-cli --version
```

```text
VS Code          OK
Git              OK
Terraform        OK
AWS CLI          OK
AWS Credential   OK (tf-user)
Kiro CLI         OK
```

Kiro 로그인도 미리 완료합니다.

```bash
kiro-cli login
kiro-cli whoami
```

Browser 인증 화면에서 Builder ID, GitHub, Google 또는 교육에서 지정한 조직 계정을 사용합니다. Kiro 인증과 AWS `tf-user` Credential은 서로 다른 인증입니다.

## 4. Repository Clone과 VS Code

Public Repository이므로 Clone에 GitHub Account나 Credential이 필요하지 않습니다.

```bash
git clone https://github.com/seungsuk-training/terraform-iac-essential.git
cd terraform-iac-essential
```

VS Code에서 엽니다.

```bash
code .
```

`code` 명령이 없으면 VS Code GUI에서 `File → Open Folder`를 선택하고 `terraform-iac-essential` Directory를 엽니다.

구조:

```text
terraform-iac-essential/
├── README.md
├── userdata/
│   └── image-builder.sh
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── vpc.tf
│   ├── security_groups.tf
│   ├── asg.tf
│   ├── load_balancer.tf
│   └── outputs.tf
└── ai/
    └── prompts.md
```

## 5. Terraform Workflow와 Network Bootstrap

VS Code에서 `terraform/`의 `.tf` 파일을 읽습니다. 전체 코드를 직접 입력하지 않고 제공 코드를 Read → Modify → Plan → Apply → Verify합니다.

```bash
cd terraform
terraform init
terraform fmt
terraform validate
```

- `init`: AWS Provider를 내려받고 Working Directory 초기화
- `fmt`: Terraform 표준 형식으로 코드 정렬
- `validate`: 문법과 Resource Reference의 정적 오류 검사
- `plan`: AWS에 적용될 생성/변경/삭제를 미리 계산하여 사람이 검토
- `apply`: 검토한 변경을 실제 AWS에 적용

특히 다음 참조를 찾습니다.

```hcl
vpc_id = aws_vpc.main.id
```

이 Reference로 Terraform은 VPC를 먼저 만든 뒤 그 ID를 Subnet, Security Group과 Target Group에 전달하는 Implicit Dependency를 구성합니다.

Golden AMI Image Builder를 실습 VPC의 Public Subnet에 배치하기 위해 최초 한 번만 Network를 Bootstrap합니다.

```bash
terraform plan \
  -target=aws_vpc.main \
  -target=aws_internet_gateway.main \
  -target=aws_subnet.pub_a \
  -target=aws_subnet.pub_c \
  -target=aws_subnet.pri_a \
  -target=aws_subnet.pri_c \
  -target=aws_route_table.pub \
  -target=aws_route_table_association.pub_a \
  -target=aws_route_table_association.pub_c

terraform apply \
  -target=aws_vpc.main \
  -target=aws_internet_gateway.main \
  -target=aws_subnet.pub_a \
  -target=aws_subnet.pub_c \
  -target=aws_subnet.pri_a \
  -target=aws_subnet.pri_c \
  -target=aws_route_table.pub \
  -target=aws_route_table_association.pub_a \
  -target=aws_route_table_association.pub_c
```

`-target`은 일반 Workflow가 아니라 Golden AMI 제작을 위한 일회성 Bootstrap입니다. 이후에는 전체 `terraform plan/apply`를 사용합니다.

AWS Console의 VPC → Your VPCs/Subnets/Route tables에서 VPC, Subnet 4개와 Public Route `0.0.0.0/0 → igw-...`를 확인합니다. Private Subnet에는 Default Route가 없어야 합니다.

## 6. Golden AMI 생성

Golden Image Builder EC2는 Terraform으로 만들지 않습니다. `tf-user`로 로그인한 AWS Console에서 진행합니다.

EC2 → Instances → Launch instances:

- Name: `terraform-iac-essential-image-builder`
- AMI: Amazon Linux 2023, x86_64
- Instance type: `t3.micro`
- Network: `terraform-iac-essential-lab-vpc`
- Subnet: Public Subnet C (`10.0.2.0/24`)
- Auto-assign Public IP: Enable
- 새 Security Group: HTTP 80 허용
- Advanced details → User data: `userdata/image-builder.sh` 전체 내용 붙여넣기

Instance가 Running이 된 뒤 Public IPv4 주소를 Browser에서 열어 `Terraform IaC Essential`을 확인합니다. 실패하면 Status checks, Public IP, Security Group 80과 `/var/log/cloud-init-output.log`를 확인합니다.

Image Builder를 선택하고 Actions → Image and templates → Create image:

- Image name: `terraform-iac-essential-golden-<YYYYMMDD-HHMM>`
- Tags: `Project=terraform-iac-essential`, `Environment=lab`, `Purpose=GoldenImage`, `BuiltBy=Manual`

EC2 → AMIs에서 상태가 `Available`이 되면 AMI ID를 복사합니다. VS Code에서 `terraform/terraform.tfvars`를 수정합니다.

```hcl
golden_ami_id = "ami-xxxxxxxxxxxxxxxxx"
```

AMI ID와 필요 시 `project_name`만 교육생이 수정합니다. Access Key나 Secret Key를 이 파일에 넣지 않습니다.

## 7. Private Web Infrastructure와 ALB 구축

VS Code에서 다음 관계를 확인합니다.

```text
Internet → ALB Security Group
         → Web Security Group
         → Private Web EC2
```

- `security_groups.tf`: Web HTTP Source가 `aws_security_group.alb.id`
- `asg.tf`: Golden AMI Launch Template, Public IP 없음, Private Subnet A/C, desired/min 2, max 4
- `load_balancer.tf`: Public Subnet A/C, Internet-facing ALB, HTTP 80 Listener, `/` Health Check
- ASG의 `target_group_arns`: Web EC2를 Target Group에 등록

Workflow를 실행합니다.

```bash
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Plan은 실행을 위한 형식적 단계가 아닙니다. 생성, 변경, 교체, 삭제가 요구사항과 일치하는지 사람이 확인한 뒤 Apply합니다.

AWS Console에서 확인합니다.

- EC2 → Instances: Web EC2 두 대, Public IPv4 없음
- EC2 → Auto Scaling Groups: Desired 2
- EC2 → Target Groups → Targets: 두 Target이 Healthy
- EC2 → Load Balancers: 두 Public Subnet과 HTTP Listener

```bash
terraform output
terraform output -raw alb_url
```

출력 URL을 Browser에서 열어 Web Page가 표시되면 Infrastructure Lab 성공입니다.

## 8. Kiro CLI 필수 AI-assisted IaC Lab

Infrastructure 완성 후 Repository Root에서 Kiro CLI를 실행합니다.

```bash
cd ..
kiro-cli
```

[`ai/prompts.md`](ai/prompts.md)의 Prompt를 순서대로 사용합니다.

```text
Terraform Architecture 완성
→ Kiro CLI 실행
→ 현재 Project 분석
→ AI 개선안 제안
→ Human Review
→ 필요한 작은 변경
→ terraform fmt
→ terraform validate
→ terraform plan
→ Human Verification
→ terraform apply
```

AI가 만든 코드를 바로 Apply하지 않습니다.

```text
Human
  ↓
Architecture / Requirement
  ↓
AI Assistance
  ↓
Terraform Code
  ↓
terraform plan
  ↓
Human Verification
  ↓
terraform apply
```

> AI는 Terraform과 Architecture를 대신 이해해 주는 도구가 아닙니다. Terraform과 Architecture를 이해한 사람이 AI를 활용하면 코드 생성, 분석, Refactoring 및 검증을 더 빠르게 수행할 수 있습니다.

## 9. Cleanup — 비용 방지 필수

Terraform Working Directory에서 먼저 Plan을 검토하고 Terraform 관리 Resource를 삭제합니다.

```bash
cd terraform
terraform plan -destroy
terraform destroy
```

Console에서 EC2, Auto Scaling Group, Launch Template, ALB, Target Group, Security Group, VPC 관련 Resource가 삭제됐는지 확인합니다.

다음 수동 Resource는 Terraform State 밖에 있으므로 `terraform destroy`가 삭제하지 않습니다.

1. EC2 → Instances: Image Builder EC2 Terminate
2. EC2 → AMIs: Golden AMI Deregister
3. EC2 → Snapshots: 해당 AMI의 EBS Snapshot Delete
4. Image Builder용 수동 Security Group Delete

AMI Deregister만으로 EBS Snapshot은 삭제되지 않아 비용이 남을 수 있습니다.

## 10. 교육 종료 후 Credential 정리

개인 실습 계정에서 Access Key가 더 필요하지 않다면 IAM → Users → `tf-user` → Security credentials에서 Access Key를 Deactivate 또는 Delete합니다. `tf-user` 자체가 필요 없다면 수동 Resource와 비용 발생 Resource가 모두 제거됐는지 확인한 뒤 User도 삭제할 수 있습니다.

장기간 사용하는 개인 AWS 계정에서는 장기 Access Key보다 임시 Credential과 Least Privilege 구성을 별도로 검토합니다. Root Access Key는 만들지 않습니다.

## 4시간 진행 Checkpoint

권장 시간:

- Local Tool/IAM/Credential Checkpoint: 35분
- Terraform Workflow와 Network: 30분
- Golden AMI 생성: 50분
- Private ASG와 ALB: 45분
- Kiro CLI AI Lab: 35분
- Cleanup: 25분
- Buffer: 20분
- 이후 Optional Q&A: 1시간

가장 큰 병목은 Windows 10 WSL2 준비, Tool 설치/PATH, IAM 초기 로그인, AMI 생성 대기, Target Health 전환과 Kiro 로그인입니다. 사전 설치 Checkpoint와 강사용 예비 Golden AMI를 준비합니다.

## 공식 설치 및 보안 문서

- [VS Code Setup](https://code.visualstudio.com/docs/setup/setup-overview)
- [Git Install](https://git-scm.com/install/)
- [Terraform Install](https://developer.hashicorp.com/terraform/install)
- [AWS CLI v2 Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Kiro CLI](https://kiro.dev/docs/cli/)
- [AWS Root User Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html)
- [Create an IAM User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)
- [AWS CLI Configuration Files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
