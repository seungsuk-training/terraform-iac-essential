# Terraform IaC Essential Hands-on

개인 노트북의 Visual Studio Code에서 Remote-SSH로 Ubuntu Development EC2에 접속하여 Terraform으로 AWS Highly Available Web Service를 구축하는 4시간 Hands-on 과정입니다. 마지막에는 강사가 Kiro CLI로 AI-assisted IaC Workflow를 시연합니다.

## Course Flow

```text
1교시
Terraform / IaC 개요와 Architecture
→ Ubuntu Development EC2
→ IAM Role 생성 및 연결
→ VS Code Remote-SSH
→ 개발환경 확인

2교시
GitHub Clone
→ Terraform Basics
→ Golden AMI 준비
→ Custom VPC / Network

3교시
Golden AMI 적용
→ Security Group
→ Launch Template
→ Auto Scaling Group
→ Target Group

4교시
Application Load Balancer
→ Web Service Verification
→ Kiro CLI Instructor Demo
→ Cleanup

5교시
Optional Q&A (희망자, 1시간)
```

> Terraform을 실행하기 전에 Infrastructure as Code 개발환경을 먼저 구성합니다. 이번 과정에서는 교육생의 Local OS 차이를 최소화하고 동일한 Linux 환경을 제공하기 위해 AWS Ubuntu EC2를 Terraform Development Environment로 사용합니다.

## Final Architecture

```text
교육생 PC
Windows / macOS / Ubuntu
        │
        │ VS Code Remote-SSH
        ▼
Ubuntu Development EC2
        │
        ├── Git / Terraform / AWS CLI
        └── TerraformLabRole의 Temporary Credential
                         │
                         ▼
                       AWS API

Internet
   ↓
Internet-facing ALB — Public Subnet A/C
   ↓
Target Group
   ↓
Auto Scaling Web EC2 — Private Subnet A/C
   ↑
Golden AMI
```

Region은 `ap-northeast-2`, VPC는 `10.0.0.0/16`입니다. Public Subnet은 `10.0.0.0/24`, `10.0.2.0/24`, Private Subnet은 `10.0.1.0/24`, `10.0.3.0/24`입니다.

이번 Lab에서는 Golden AMI로 Private Web Instance의 Runtime Internet 의존성을 제거했기 때문에 교육 범위와 비용을 고려하여 NAT Gateway를 제외합니다. Private Subnet에 NAT Gateway가 항상 불필요하다는 뜻은 아닙니다. 실제 환경에서는 Package Update, 외부 API와 운영 요구사항에 따라 NAT Gateway 또는 VPC Endpoint를 검토합니다. RDS, Module, Remote Backend와 CI/CD도 이번 과정에서 제외합니다.

## Lab 1. Development Environment

1교시 종료 목표:

```text
Local PC
   │
VS Code + Remote-SSH
   ▼
Ubuntu Development EC2
   ├── Git        OK
   ├── Terraform  OK
   ├── AWS CLI    OK
   └── IAM Role   OK
```

### 1-1. Visual Studio Code

교육생 PC에 [Visual Studio Code](https://code.visualstudio.com/download)를 설치합니다. Windows 10/11, macOS와 Ubuntu Linux의 자세한 설치 과정은 공식 페이지를 따릅니다.

VS Code → Extensions에서 설치합니다.

필수:

- `Remote - SSH` — Publisher: Microsoft

권장:

- `HashiCorp Terraform` — Publisher: HashiCorp

Terraform, Git과 AWS CLI는 Local PC에 설치하지 않아도 됩니다. 해당 CLI는 Ubuntu Development EC2에서 실행합니다.

### 1-2. Ubuntu Development EC2 생성

먼저 Development EC2를 배치할 Default VPC가 현재 Region에 있는지 확인합니다.

AWS Console 상단에서 Region을 `ap-northeast-2`로 선택한 후:

1. VPC → Your VPCs
2. `default` VPC가 있는지 확인
3. 없다면 Actions → Create default VPC
4. 생성이 완료되면 Default VPC와 Default Subnet이 준비되었는지 확인

Default VPC 확인이 끝나면 Terraform 개발환경으로 사용할 EC2를 생성합니다.

AWS Console → EC2 → Instances → Launch instances:

- Name: `terraform-iac-essential-dev`
- AMI: `Ubuntu Server 24.04 LTS`
- Architecture: x86_64 권장
- Instance type: `t3.medium`
- Key pair: 새 Key Pair `tfkey` 생성 후 Private Key 다운로드
- Network: Default VPC
- Public IPv4: Enabled
- Security Group name: `Code-Server-SG`
- Security Group rule: SSH / TCP 22 / Source `My IP`
- Storage: 30 GiB
- Advanced details → IAM instance profile: 이 단계에서는 선택하지 않아도 됨

`t3.medium`은 Tool 설치와 Terraform Provider 초기화가 지나치게 느려지는 것을 줄이기 위한 교육 권장 사양입니다. Free Tier 대상이라고 가정하지 말고 Launch 전에 예상 비용을 확인하며, 실습 종료 후 반드시 Terminate합니다.

다운로드한 `tfkey.pem` Private Key는 Git Repository나 일반 Download Folder에 계속 두지 말고 Local PC 사용자 Home Directory의 `.ssh` Folder에 저장하는 것을 권장합니다.

macOS/Linux 예:

```bash
mkdir -p ~/.ssh
mv ~/Downloads/tfkey.pem ~/.ssh/tfkey.pem
chmod 400 ~/.ssh/tfkey.pem
```

Windows에서는 `tfkey.pem`을 `%USERPROFILE%\.ssh\tfkey.pem`으로 이동합니다. 다른 Folder에 다운로드되었다면 실제 다운로드 경로에 맞게 이동합니다.

Development EC2는 Terraform으로 생성하지 않습니다.

```text
Development EC2
→ Terraform을 실행하는 개발환경

Golden Image Builder EC2
→ Web Server용 Golden AMI를 만드는 서버

Private Web EC2
→ Launch Template + Auto Scaling Group이 만드는 실제 Web Server
```

Instance가 `Running` 상태가 되고 Status checks가 통과할 때까지 기다립니다. Public IPv4 주소와 Key Pair 이름 `tfkey`를 기록합니다.

### 1-3. `TerraformLabRole` 생성과 EC2 연결

교육생 OS와 관계없이 동일하게 진행할 수 있도록 Role 생성과 연결은 모두 AWS Management Console에서 수행합니다.

Development EC2에서는 Access Key를 사용하지 않고 EC2 IAM Role의 Temporary Credential을 사용합니다.

다음 작업은 하지 않습니다.

- AWS Account Root Access Key 생성
- IAM User Access Key 생성
- `aws configure`
- Access Key를 Terraform Source나 Git에 저장

#### Role 생성

AWS Console에서:

1. IAM → Roles → Create role
2. Trusted entity type: `AWS service`
3. Use case: `EC2`
4. Permissions에서 `AdministratorAccess` 선택
5. Role name: `TerraformLabRole`
6. Review 후 Create role

EC2 Use Case로 Role을 생성하면 EC2에 연결할 Instance Profile도 함께 준비됩니다.

> 이번 과정에서는 제한된 시간 동안 개인 실습 계정에서 여러 AWS Resource를 생성하고 삭제하기 위해 교육 편의상 넓은 권한을 사용합니다. 실제 운영 환경에서는 필요한 작업에 맞는 최소 권한(Least Privilege)을 적용해야 합니다.

#### 실행 중인 Development EC2에 Role 연결

1. EC2 → Instances
2. `terraform-iac-essential-dev` 선택
3. Actions → Security → Modify IAM role
4. IAM role에서 `TerraformLabRole` 선택
5. Update IAM role
6. Instance Summary의 IAM Role 항목에서 연결 확인

Role이 목록에 바로 나타나지 않으면 IAM Role 생성 완료를 확인하고 잠시 후 새로고침합니다.

```text
Ubuntu Development EC2
→ TerraformLabRole Instance Profile
→ Temporary Credential
→ AWS API
```

### 1-4. VS Code Remote-SSH 연결

Private Key는 안전하게 보관하고 Git이나 공유 Folder에 넣지 않습니다.

macOS/Linux:

```bash
chmod 400 ~/.ssh/tfkey.pem
ssh -i ~/.ssh/tfkey.pem ubuntu@<Development-EC2-Public-IP>
```

Windows에서는 `%USERPROFILE%\.ssh\tfkey.pem`을 사용하고 VS Code에서 해당 절대 경로를 선택합니다.

VS Code에서:

1. Command Palette (`F1` 또는 `Ctrl/Cmd+Shift+P`)
2. `Remote-SSH: Add New SSH Host`
3. 다음 형식 입력

```text
ssh -i ~/.ssh/tfkey.pem ubuntu@<Development-EC2-Public-IP>
```

Windows에서는 `~/.ssh/tfkey.pem` 대신 `%USERPROFILE%\.ssh\tfkey.pem`의 절대 경로를 입력합니다.

4. SSH Configuration File 선택
5. `Remote-SSH: Connect to Host`
6. 처음 접속 시 Host Fingerprint 확인 후 Linux 선택

SSH Config 예:

```sshconfig
Host terraform-lab
  HostName <Development-EC2-Public-IP>
  User ubuntu
  IdentityFile ~/.ssh/tfkey.pem
```

VS Code 좌측 하단에 `SSH: terraform-lab`이 표시되면 성공입니다.

Troubleshooting:

- Timeout: Development EC2가 Running인지, Public IP와 Security Group SSH Source가 현재 `My IP`인지 확인
- `Permission denied (publickey)`: User가 `ubuntu`인지, 선택한 Key가 Instance의 Key Pair와 일치하는지 확인
- Private Key Permission 오류: Key를 본인만 읽을 수 있는 `.ssh` 위치에 두고 권한 확인

### 1-5. Repository Clone과 환경 자동화

Remote-SSH로 연결한 VS Code에서 Terminal → New Terminal을 엽니다. 이 Terminal은 Local PC가 아니라 Ubuntu Development EC2에서 실행됩니다.

Git이 없다면 먼저 설치합니다.

```bash
sudo apt-get update
sudo apt-get install -y git
```

Public Repository를 Clone합니다.

```bash
cd /home/ubuntu
git clone https://github.com/seungsuk-training/terraform-iac-essential.git
cd terraform-iac-essential
```

Public Repository이므로 GitHub Login, PAT 또는 SSH Key가 필요하지 않습니다.

환경 설정 Script를 실행합니다.

```bash
bash scripts/setup-dev-environment.sh
```

Script는 Ubuntu 24.04에서 다음을 수행합니다.

- Git과 기본 설치 도구 확인
- HashiCorp 공식 APT Repository 구성
- Terraform 설치
- AWS 공식 Installer로 AWS CLI v2 설치
- Version 출력

반복 실행해도 기존 Repository와 설치를 재사용하도록 구성했습니다.

VS Code에서 `File → Open Folder`를 선택하고 다음 Remote Directory를 엽니다.

```text
/home/ubuntu/terraform-iac-essential
```

Remote 환경에도 HashiCorp Terraform Extension 설치를 권장합니다.

### 1-6. Development Environment Checkpoint

VS Code Remote Terminal에서:

```bash
git --version
terraform version
aws --version
aws sts get-caller-identity
```

성공 조건:

- Git/Terraform/AWS CLI Version 출력
- Account가 자신의 실습 AWS Account
- ARN에 `assumed-role/TerraformLabRole` 포함

```text
Terraform
   ↓
AWS Provider
   ↓
EC2 IAM Role Temporary Credential
   ↓
AWS API
```

EC2 Metadata Service가 Temporary Credential을 제공하므로 `aws configure`가 필요하지 않습니다. Access Key를 직접 저장하지 않아도 AWS CLI와 Terraform AWS Provider가 같은 Role Credential을 자동으로 사용합니다.

Role이 바로 보이지 않으면 1~2분 후 다시 실행하고 EC2 → Actions → Security → Modify IAM role에서 `TerraformLabRole` 연결을 확인합니다.

## Lab 2. Terraform Basics와 Network

전체 Source를 직접 입력하지 않습니다.

```text
Architecture 설명
→ VS Code에서 관련 .tf 파일 확인
→ 중요한 Resource/Reference 설명
→ terraform plan
→ Human Review
→ terraform apply
→ AWS Console 확인
```

Terraform Working Directory로 이동합니다.

```bash
cd /home/ubuntu/terraform-iac-essential/terraform
terraform init
terraform fmt
terraform validate
```

- `init`: AWS Provider를 내려받고 Working Directory 초기화
- `fmt`: Terraform 표준 형식으로 HCL 정렬
- `validate`: Syntax와 Resource Reference의 정적 오류 검사
- `plan`: 실제 Infrastructure 변경을 계산하여 사람이 검토
- `apply`: 검토한 Plan을 AWS에 적용

```text
Write / Read
    ↓
terraform fmt
    ↓
terraform validate
    ↓
terraform plan
    ↓
Human Review
    ↓
terraform apply
    ↓
Verify
```

코드에서 다음 Reference를 확인합니다.

```hcl
vpc_id = aws_vpc.main.id
```

Terraform은 Resource Reference를 통해 VPC가 먼저 필요하다는 Implicit Dependency를 이해합니다.

### 2-1. Network Bootstrap

Golden Image Builder를 실습 VPC의 Public Subnet에 배치하기 위해 최초 한 번만 Network를 생성합니다.

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

`-target`은 일반 배포 방식이 아니라 Golden AMI 제작을 위한 일회성 Bootstrap입니다. 이후에는 전체 `terraform plan/apply`를 사용합니다.

AWS Console의 VPC → Your VPCs/Subnets/Route tables에서 확인합니다.

- VPC: `10.0.0.0/16`
- Public/Private Subnet 각 2개
- Public Route: `0.0.0.0/0 → Internet Gateway`
- Private Subnet: Default Route 없음

## Lab 3. Golden AMI

Golden Image Builder EC2는 Terraform으로 만들지 않습니다.

```text
AWS Console
→ Public Subnet C
→ Golden Image Builder EC2
→ userdata/image-builder.sh
→ Web Server 확인
→ AMI 생성
→ Golden AMI ID
→ terraform.tfvars 수정
```

EC2 → Instances → Launch instances:

- Name: `terraform-iac-essential-image-builder`
- AMI: Amazon Linux 2023, x86_64
- Instance type: `t3.micro` 또는 교육용 소형 Type
- Network: `terraform-iac-essential-lab-vpc`
- Subnet: Public Subnet C (`10.0.2.0/24`)
- Auto-assign Public IP: Enable
- 새 Security Group: HTTP 80 허용
- Advanced details → User data: `userdata/image-builder.sh` 내용 붙여넣기

Public IPv4 주소를 Browser에서 열어 다음 값이 표시되는지 확인합니다.

- Instance ID: 현재 Golden Image Builder EC2의 ID
- Availability Zone: 현재 Instance가 실행 중인 AZ

이후 Golden AMI로 만든 Web EC2를 ALB를 통해 여러 번 새로고침하면 응답한 Instance ID와 Availability Zone이 바뀌는 것을 확인할 수 있습니다. 이를 통해 ALB가 Multi-AZ의 여러 Instance로 요청을 분산하는 모습을 실습할 수 있습니다.

다운로드한 예제 앱에는 RDS 연결 화면도 포함되어 있지만, 이번 4시간 과정에서는 DB를 생성하거나 연결하지 않습니다. 이후 RDS 실습으로 확장할 때 활용할 수 있습니다.

User Data는 AL2023의 기본 IMDSv2 요구사항에 맞춰 원본 앱의 Metadata 조회 파일을 교체합니다. `unzip`과 `curl` 설치, PHP-FPM 시작도 Script에 포함되어 있으므로 `userdata/image-builder.sh` 전체를 그대로 붙여넣습니다.

Actions → Image and templates → Create image:

- Image name: `terraform-iac-essential-golden-<YYYYMMDD-HHMM>`
- Tags: `Project=terraform-iac-essential`, `Environment=lab`, `Purpose=GoldenImage`, `BuiltBy=Manual`

AMI 상태가 `Available`이 되면 VS Code에서 `terraform/terraform.tfvars`를 수정합니다.

```hcl
golden_ami_id = "ami-xxxxxxxxxxxxxxxxx"
```

Access Key나 Secret Key를 Terraform 파일에 넣지 않습니다.

> Golden Image Builder의 User Data 실행 또는 AMI 생성 대기시간에는 Network Terraform Code와 Resource Reference를 설명하여 대기시간을 활용합니다.

## Lab 4. Private Web Infrastructure와 ALB

Source에서 다음 관계를 확인합니다.

```text
Internet
   ↓
Application Load Balancer — Public Subnet A/C
   ↓
Target Group
   ↓
Web Auto Scaling Group — Private Subnet A/C
```

ALB는 Public Entry Point, Load Distribution, Health Check와 Multi-AZ High Availability를 제공합니다. Web EC2는 Public IP 없이 Private Subnet에 배치되고 ALB Security Group에서 오는 HTTP만 허용합니다.

확인할 파일:

- `security_groups.tf`: ALB SG → Web SG
- `asg.tf`: Golden AMI Launch Template, Public IP 없음, Private Subnet A/C, desired/min 2, max 4
- `load_balancer.tf`: Public Subnet A/C, Internet-facing ALB, HTTP Listener, `/` Health Check
- `outputs.tf`: ALB DNS와 URL

```bash
cd /home/ubuntu/terraform-iac-essential/terraform
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Plan은 형식적인 단계가 아닙니다. 생성, 변경, 교체와 삭제가 요구사항에 맞는지 사람이 확인한 뒤 Apply합니다.

AWS Console에서:

- EC2 Instances: Web EC2 두 대, Public IPv4 없음
- Auto Scaling Groups: Desired 2
- Target Groups: 두 Target이 Healthy
- Load Balancers: Public Subnet 두 개와 HTTP Listener

```bash
terraform output
terraform output -raw alb_url
```

URL을 Browser에서 열어 Web Page가 표시되면 Infrastructure Lab 성공입니다.

## Lab 5. Kiro CLI Instructor Demo

Kiro CLI는 교육생 필수 설치 도구가 아닙니다. 다양한 Local OS와 4시간 제한을 고려하여 강사의 검증된 환경에서 과정 마지막 공식 Module로 진행합니다.

강사는 [`ai/prompts.md`](ai/prompts.md)의 Scenario를 사용합니다.

```text
현재 Architecture 분석
→ Resource Dependency 설명
→ 개선점 제안
→ Subnet map(object) + for_each Refactoring
→ git diff
→ terraform fmt
→ terraform validate
→ terraform plan
→ Human Verification
```

AI가 생성한 Infrastructure Code를 바로 Apply하지 않습니다.

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

> AI가 Terraform과 Architecture를 대신 이해해 주는 것이 아닙니다. Terraform과 Architecture를 이해한 사람이 AI를 활용하면 코드 생성, 분석, Refactoring 및 검증을 더 빠르게 수행할 수 있습니다.

> AI가 생성하거나 수정한 Infrastructure Code를 바로 적용하지 않고 `terraform validate`와 `terraform plan` 결과를 사람이 검토합니다.

## Lab 6. Cleanup — 비용 방지 필수

### 6-1. Terraform Cleanup

Ubuntu Development EC2의 VS Code Terminal에서:

```bash
cd /home/ubuntu/terraform-iac-essential/terraform
terraform plan -destroy
terraform destroy
```

AWS Console에서 확인합니다.

- Auto Scaling Group과 Web EC2
- Launch Template
- ALB와 Target Group
- Terraform Security Groups
- VPC, Subnet, Route Table과 Internet Gateway

### 6-2. Manual Cleanup

다음은 Terraform State 밖에서 만들었으므로 `terraform destroy`가 삭제하지 않습니다.

- Golden Image Builder EC2 Terminate
- Golden AMI Deregister
- Golden AMI의 EBS Snapshot Delete
- Image Builder용 수동 Security Group Delete
- Ubuntu Development EC2 Terminate
- Development EC2 Security Group Delete
- Development EC2 Key Pair Delete
- `TerraformLabRole`과 Instance Profile Delete

권장 순서:

1. Terraform Destroy 완료
2. Image Builder EC2/AMI/Snapshot/Security Group 삭제
3. Development EC2에서 필요한 파일이 없는지 확인
4. Development EC2 Terminate
5. Development Security Group과 Key Pair 삭제
6. IAM Role과 Instance Profile 삭제

AWS Console에서 IAM → Roles → `TerraformLabRole`을 선택하여 삭제합니다. Development EC2를 먼저 Terminate하고 Instance Profile 연결이 해제된 뒤 진행합니다.

AMI Deregister만으로 EBS Snapshot은 삭제되지 않습니다. 개인 AWS Account에 비용 발생 Resource가 남지 않았는지 EC2와 VPC Console에서 최종 확인합니다.

## Optional Q&A — 1시간

필수 4시간 과정 이후 희망자만 참여합니다.

질문에 따라 다룰 수 있는 주제:

- NAT Gateway와 VPC Endpoint
- RDS
- State와 Remote Backend
- Module
- `count`, `for_each`, `map(object)`
- Naming과 Tagging
- Kiro CLI
- Terraform 실무 운영

이 주제들은 필수 Hands-on 범위에 추가하지 않습니다.

## 4시간 진행 Tip

가장 큰 시간 병목:

- Key Pair와 Remote-SSH 최초 연결
- IAM Role/Instance Profile 전파
- Ubuntu Tool 설치와 AWS Provider 다운로드
- Golden Image Builder User Data
- AMI 생성 대기
- Target Group Health 전환
- Cleanup

교육 전 Role 생성 및 Remote-SSH를 사전 안내하고, 강사는 동일한 Ubuntu 24.04 Script를 리허설합니다. AMI 대기시간에는 Network Code를 설명하고 강사용 예비 Golden AMI를 준비합니다.
