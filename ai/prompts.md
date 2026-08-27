# AI-assisted IaC with Kiro CLI

이 문서는 교육생이 Ubuntu Development EC2에서 직접 사용하는 Copy & Paste용 Prompt Guide입니다. 기본 Hands-on은 Step 1과 Step 2까지이며 약 15~20분을 목표로 합니다. Step 3은 시간이 충분할 때만 진행합니다.

> AI Output은 검증 전의 가설입니다. AI가 Terraform과 Architecture를 대신 이해해 주는 것이 아니며, Infrastructure 변경의 최종 판단은 사람에게 있습니다.

## 시작하기

Repository Root에서 Kiro CLI를 실행합니다.

```bash
cd /home/ubuntu/terraform-iac-essential
kiro-cli
```

먼저 다음 안전 제약을 Copy & Paste합니다.

```text
이 세션은 Terraform 교육 Hands-on입니다.

내가 명시적으로 요청하기 전에는 파일을 수정하지 마세요.
terraform apply, terraform destroy 또는 AWS Resource를 변경하는 명령은
실행하지 마세요.

분석과 변경 제안을 먼저 설명하고,
Infrastructure 변경 여부는 사람이 terraform plan으로 검증합니다.
NAT Gateway, RDS, Module, Remote Backend와 CI/CD는 추가하지 마세요.
```

## Step 1. Terraform Architecture 분석

다음 Prompt를 Copy & Paste합니다.

```text
현재 Terraform 프로젝트를 분석해 주세요.

현재 구축된 AWS Architecture를 설명하고,
주요 Terraform Resource의 역할과 Resource 간 Dependency를 설명해 주세요.

다음 흐름을 중심으로 설명해 주세요.

VPC
→ Public / Private Subnet
→ Security Group
→ Golden AMI
→ Launch Template
→ Auto Scaling Group
→ Target Group
→ Application Load Balancer

특히 다음 항목을 확인해 주세요.

- ALB는 두 Public Subnet에 배치
- Auto Scaling Group은 두 Private Subnet에 배치
- Web Instance에는 Public IP가 없음
- Web Security Group의 HTTP Source는 ALB Security Group
- Launch Template은 golden_ami_id Variable 사용
- Auto Scaling Group은 Target Group과 연결
- NAT Gateway와 RDS는 의도적으로 제외

아직 코드는 변경하지 마세요.
```

AI의 설명을 방금 직접 구축한 Architecture와 비교합니다. 다음 관계가 빠지거나 틀리지 않았는지 확인합니다.

- `vpc_id = aws_vpc.main.id`와 같은 Resource Reference 및 Implicit Dependency
- ALB Security Group에서 Web Security Group으로의 Traffic Flow
- Public ALB와 Private Web Instance의 역할 차이
- Golden AMI와 Launch Template의 관계
- Target Group Health Check와 Multi-AZ High Availability

## Step 2. 개선점 분석

다음 Prompt도 코드 변경 없이 분석만 요청합니다.

```text
현재 Terraform 프로젝트를 다음 관점에서 검토해 주세요.

- 반복되는 코드
- Variable
- Naming
- Tagging
- Security
- Availability
- Maintainability

코드를 바로 변경하지 말고,
현재 구조의 장점과 개선 가능한 부분을 먼저 설명해 주세요.

특히 명시적으로 반복된 Public/Private Subnet Resource가
향후 map(object)와 for_each를 이용한 Refactoring 대상인지 검토해 주세요.

Architecture를 변경하는 제안과
Terraform 코드 구조만 개선하는 제안을 구분해 주세요.
```

AI의 제안을 정답으로 간주하지 않습니다. 이번 Essential 과정에서는 학습을 위해 Subnet을 명시적으로 작성했다는 점과 다음 발전 흐름을 비교합니다.

```text
명시적 Resource 작성
→ 반복 발견
→ count
→ count의 한계
→ object / map(object)
→ for_each
```

여기까지 직접 수행하면 기본 Kiro Hands-on은 성공입니다.

## Step 3. 선택적 Refactoring

시간이 충분하고 README의 “선택적 심화” 준비 절차를 완료한 경우에만 실행합니다.

```text
현재 Public/Private Subnet Resource의 반복을 줄이기 위해
map(object)와 for_each를 이용하는 구조로 리팩터링해 주세요.

요구사항:

- 기존 AWS Architecture, CIDR, AZ와 Tag 동작은 변경하지 않음
- Public Subnet 두 개와 Private Subnet 두 개 유지
- Public Route Table Association 유지
- ALB는 Public Subnet A/C 유지
- ASG는 Private Subnet A/C 유지
- NAT Gateway와 RDS를 추가하지 않음
- 기존 Terraform 파일만 수정하고 새 파일은 만들지 않음
- 변경 파일과 Resource Address 변화를 먼저 설명
- terraform apply와 terraform destroy는 실행하지 않음

코드를 변경한 뒤 변경 내용을 요약해 주세요.
```

Kiro가 수정한 뒤 사람이 먼저 확인합니다.

```bash
git diff -- terraform
git status --short
```

검토 항목:

- CIDR과 Availability Zone 보존
- Public/Private Subnet의 Public IP 설정 보존
- Route Table Association, ALB, ASG Reference 보존
- 기존 Naming과 Tag 의미 보존
- 요청하지 않은 Resource 추가 또는 삭제 여부

## Step 4. Terraform 검증

AI가 실제 코드를 수정한 경우에만 실행합니다.

```bash
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

- `fmt`: HCL을 표준 형식으로 정리
- `validate`: Syntax와 Resource Reference의 정적 오류 확인
- `plan`: State와 변경 Configuration의 실제 차이 확인

`validate` 성공은 Apply 승인이라는 뜻이 아닙니다. Resource Address가 바뀌면 Architecture가 같아도 Plan에 Destroy/Create가 나타날 수 있습니다. Destroy, Replace 또는 예상하지 않은 변경이 보이면 적용하지 않습니다.

이번 4시간 과정에서는 AI Refactoring 결과를 `terraform apply`하지 않습니다. README의 “Cleanup 전 Source 복원” 절차로 원래 Source를 복원한 뒤 기존 Infrastructure를 정리합니다.

## Key Takeaway

```text
AI Suggestion
      ↓
Code Change
      ↓
terraform fmt
      ↓
terraform validate
      ↓
terraform plan
      ↓
Human Verification
      ↓
Apply 또는 변경 보류
```

스스로 확인합니다.

1. AI가 현재 Architecture와 Dependency를 정확히 설명했는가?
2. AI의 개선안이 4시간 Essential 과정의 요구사항에 적합한가?
3. `for_each` 전환이 Resource Address와 State에 어떤 영향을 주는가?
4. Plan에서 Destroy 또는 Replace가 보이면 무엇을 해야 하는가?
5. AI가 실행하지 못하도록 제한한 명령은 무엇인가?
