# Terraform IaC Essential Hands-on

4시간 동안 Terraform 코드가 Custom VPC, Multi-AZ Private Web Tier, Application Load Balancer로 연결되는 전체 흐름을 경험하는 초심자용 실습입니다.

## Lab Overview

```text
Internet → Internet Gateway
              ↓
Public Subnet A/C: Application Load Balancer
              ↓
          Target Group
              ↓
Private Subnet A/C: Auto Scaling Web EC2 (Golden AMI)
```

Region은 `ap-northeast-2`, VPC는 `10.0.0.0/16`입니다. Public Subnet은 `10.0.0.0/24`, `10.0.2.0/24`, Private Subnet은 `10.0.1.0/24`, `10.0.3.0/24`입니다.

이번 실습에서는 Web Server에 필요한 Software와 Application이 포함된 Golden AMI를 사용하므로 Private Web Instance의 Internet Outbound가 필요하지 않습니다. 따라서 NAT Gateway를 구성하지 않습니다. 실제 환경에서는 NAT Gateway나 VPC Endpoint를 검토해야 합니다. RDS, Bastion, Module, Remote Backend와 CI/CD도 4시간 범위에서 제외합니다.

> 모든 단계의 기본 흐름은 Read → Modify → `fmt` → `validate` → `plan` → Apply → AWS Console/Browser Verify입니다.

## Prerequisites

AWS IAM 실습 계정과 GitHub 저장소 URL이 필요합니다. 별도 Access Key나 `aws configure`는 사용하지 않습니다. CloudShell에서 시작합니다.

```bash
git clone <repository-url>
cd terraform-iac-essential
terraform version
aws sts get-caller-identity
git --version
```

예상 결과: Terraform/Git 버전과 현재 실습용 AWS Account, IAM ARN이 출력됩니다.

## Lab 1. AWS CloudShell 실습 환경 확인 (15분)

```bash
cd terraform
terraform fmt -recursive
terraform init
terraform validate
```

`Terraform has been successfully initialized!`, `Success! The configuration is valid.`를 확인합니다. `terraform init`이 만든 `.terraform/`은 Git에서 제외되며 `.terraform.lock.hcl`은 Provider 버전을 재현하기 위해 Git으로 관리합니다.

코드를 읽어 다음 참조를 찾습니다.

```hcl
vpc_id = aws_vpc.main.id
```

이 참조 때문에 Terraform은 VPC를 먼저 만들고 그 ID를 Subnet, Security Group, Target Group에 전달합니다.

## Lab 2. Golden AMI 생성 (50분)

Image Builder EC2는 Terraform이 아닌 EC2 Console에서 만듭니다. 먼저 이 Instance를 배치할 실습 VPC와 Public Subnet C를 생성합니다.

### 2-1. Network bootstrap

전체 Configuration은 Golden AMI ID를 요구하므로, 이 단계에서만 예외적으로 Network 리소스를 대상으로 지정합니다.

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

`-target`은 일반 배포 방식이 아니라 Golden AMI 제작을 위한 일회성 bootstrap입니다. 이후에는 반드시 전체 `terraform plan/apply`를 사용합니다.

Console의 VPC → Your VPCs/Subnets/Route tables에서 VPC, Subnet 4개, Public Route `0.0.0.0/0 → igw-...`를 확인합니다. Private Subnet에는 Default Route가 없어야 합니다.

### 2-2. Image Builder EC2

EC2 → Instances → Launch instances에서 다음을 선택합니다.

- Name: `terraform-iac-essential-image-builder`
- AMI: Amazon Linux 2023, x86_64
- Type: `t3.micro`
- Network: `terraform-iac-essential-lab-vpc`
- Subnet: Public Subnet C (`10.0.2.0/24`)
- Auto-assign public IP: Enable
- Security Group: 새 SG에서 HTTP 80을 자신의 접속 범위(실습에서는 필요 시 `0.0.0.0/0`)에 허용
- Advanced details → User data: `userdata/image-builder.sh` 전체 내용 붙여넣기

Instance가 Running이 된 뒤 Public IPv4 주소를 Browser에서 열어 `Terraform IaC Essential`을 확인합니다. 보이지 않으면 Status checks, Public IP, SG 80, User Data 로그(`/var/log/cloud-init-output.log`)를 확인합니다.

### 2-3. AMI 생성

EC2 → Instances에서 Image Builder 선택 → Actions → Image and templates → Create image:

- Image name: `terraform-iac-essential-golden-<YYYYMMDD-HHMM>`
- Tag: `Project=terraform-iac-essential`, `Environment=lab`, `Purpose=GoldenImage`, `BuiltBy=Manual`

EC2 → AMIs에서 상태가 `Available`이 될 때까지 기다린 후 AMI ID를 복사합니다. `terraform/terraform.tfvars`에서 교육생이 반드시 수정할 값은 이것입니다.

```hcl
golden_ami_id = "ami-실제_ID"
```

선택 수정값은 충돌 방지를 위한 `project_name`입니다. `aws_region`과 `instance_type`은 제공값을 유지합니다.

## Lab 3. Terraform Network 이해 및 확인 (30분)

`vpc.tf`를 읽고 명시적으로 작성된 네 Subnet과 Public Route를 확인합니다. `count`와 `for_each`를 일부러 사용하지 않아 각 Resource와 Reference가 보입니다.

```bash
terraform fmt -recursive
terraform validate
terraform plan
```

예상 결과: 이미 만든 Network는 변경 없음이며, ALB/SG/Launch Template/ASG가 추가될 계획입니다. Plan에서 Private Subnet의 `map_public_ip_on_launch = false`와 NAT Gateway가 없음을 확인합니다.

## Lab 4. Private Web Infrastructure 구축 (40분)

`security_groups.tf`와 `asg.tf`를 읽습니다.

- ALB SG: Internet에서 HTTP 80
- Web SG: Source가 `aws_security_group.alb.id`인 HTTP 80만 허용
- Launch Template: `var.golden_ami_id`, Public IP 없음
- ASG: Private Subnet A/C, desired/min 2, max 4

전체 Plan을 사람이 검토한 뒤 적용합니다.

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

예상 결과: ASG가 Golden AMI 기반 EC2 두 대를 두 Private Subnet에 배치합니다. EC2 → Instances에서 Public IPv4가 비어 있는지, EC2 → Auto Scaling Groups에서 Desired 2인지 확인합니다.

## Lab 5. Application Load Balancer 확인 (30분)

`load_balancer.tf`에서 Public Subnet A/C, Internet-facing ALB, HTTP 80 Listener, `/` Health Check를 확인합니다. ASG의 `target_group_arns` 참조가 Instance를 Target Group에 등록합니다.

Console에서 EC2 → Load Balancers → Listeners, Target Groups → Targets를 확인합니다. 두 Target이 `Healthy`가 된 후:

```bash
terraform output
terraform output -raw alb_url
```

출력 URL을 Browser에서 열어 Web Page가 표시되면 최종 성공입니다. Unhealthy이면 Web SG Source, AMI의 httpd, Health Check path/port를 확인합니다.

## Lab 6. AI-assisted IaC (25분)

CloudShell의 Kiro CLI에서 [`ai/prompts.md`](ai/prompts.md)의 Prompt를 순서대로 사용합니다. 첫 Prompt는 분석만 요청하며, 반복된 Subnet이 향후 `map(object) + for_each` 후보임을 찾습니다. 기본 실습 코드에는 해당 고급 문법을 적용하지 않습니다.

```text
AI Suggestion → Code Change → terraform fmt → terraform validate
→ terraform plan → Human Review → terraform apply
```

AI 변경을 곧바로 Apply하지 않습니다. AI는 Terraform과 Architecture를 대신 이해하는 도구가 아니라 이해한 사람이 더 빠르게 개선하도록 돕는 도구입니다.

## Lab 7. Resource Cleanup (20분)

AMI와 Image Builder는 Terraform State 밖의 수동 리소스입니다. 먼저 Terraform 관리 리소스를 삭제합니다.

```bash
terraform plan -destroy
terraform destroy
```

`Destroy complete!`를 확인하고 Console에서 ALB, Target Group, ASG/Instance, Launch Template, SG, VPC가 삭제됐는지 확인합니다. 그다음 수동 리소스를 삭제합니다.

1. EC2 → Instances: Image Builder terminate
2. EC2 → AMIs: Golden AMI deregister
3. EC2 → Snapshots: 해당 AMI의 EBS Snapshot delete
4. Image Builder용 수동 Security Group이 남았다면 delete

AMI deregister만으로 Snapshot은 삭제되지 않아 비용이 남을 수 있습니다.

## Success Checklist

- ALB는 두 Public Subnet, ASG는 두 Private Subnet 사용
- Web EC2에 Public IP 없음
- Web SG HTTP Source는 ALB SG
- Target 두 개가 Healthy
- Browser에서 ALB URL 접속 성공
- Cleanup 후 수동 AMI/Snapshot까지 삭제

## 4시간 진행 팁

AMI 생성 대기와 Target Health 확인이 가장 큰 시간 위험입니다. 강사는 사전 검증한 Amazon Linux 2023과 User Data를 사용하고, AMI 생성이 지연될 경우에만 동일 Account/Region의 예비 Golden AMI ID를 제공합니다. Optional Q&A 1시간은 장애 분석, `for_each` 리팩터링 토론, 실환경 NAT/VPC Endpoint 선택에 활용합니다.
