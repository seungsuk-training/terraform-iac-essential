# Kiro CLI Instructor Demo Scenario

4시간 과정 마지막 공식 Module에서 강사가 사용할 Demo Script입니다. 교육생은 Kiro CLI를 설치하지 않고 자신의 완성된 Terraform Project와 강사 화면의 분석 결과를 비교합니다.

> AI가 Terraform과 Architecture를 대신 이해해 주는 것이 아닙니다. Terraform과 Architecture를 이해한 사람이 AI를 활용하면 코드 생성, 분석, Refactoring 및 검증을 더 빠르게 수행할 수 있습니다.

> AI가 생성하거나 수정한 Infrastructure Code를 바로 적용하지 않고 `terraform validate`와 `terraform plan` 결과를 사람이 검토합니다.

## 강사 사전 준비

- Kiro CLI 설치와 로그인
- Demo용 Repository와 AWS Credential 확인
- `terraform init`, `terraform validate` 성공 확인
- 교육생 Infrastructure와 분리된 Demo Working Copy 사용
- 각 Prompt와 예상 Plan 사전 리허설

Repository Root에서 시작합니다.

```bash
cd <강사 Demo용 terraform-iac-essential 경로>
git status
kiro-cli
```

먼저 안전 제약을 전달합니다.

```text
이 세션은 Terraform 교육 Demo입니다.

내가 명시적으로 요청하기 전에는 파일을 수정하지 마세요.
terraform apply, terraform destroy 또는 AWS Resource를 변경하는 명령은
실행하지 마세요.

분석과 변경 제안을 먼저 설명하고,
Infrastructure 변경 여부는 사람이 terraform plan으로 검증합니다.
```

## Demo 1 — Architecture와 Dependency 이해

```text
현재 Terraform 프로젝트를 분석해 주세요.

현재 구성된 AWS Architecture와 주요 Terraform Resource의 역할을 설명하고,
Resource 간 Dependency가 어떻게 연결되는지도 설명해 주세요.

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

강사 설명 포인트:

- `vpc_id = aws_vpc.main.id`와 Implicit Dependency
- ALB SG → Web SG Traffic Flow
- ALB Public Subnet과 ASG Private Subnet의 역할 차이
- Golden AMI로 Runtime Internet 의존성을 제거한 이유
- Target Group Health Check와 Multi-AZ High Availability
- ALB DNS Output이 최종 Verification으로 연결되는 과정

## Demo 2 — 개선점 찾기

```text
현재 Terraform 프로젝트를 다음 관점에서 검토해 주세요.

- 반복되는 코드
- Variable
- Naming
- Tagging
- Security
- Availability
- Maintainability

코드를 바로 변경하지 말고 현재 구조의 장점과 개선 가능한 부분을
먼저 설명해 주세요.

특히 명시적으로 반복된 Public/Private Subnet Resource가
향후 map(object)와 for_each를 이용한 Refactoring 대상인지 검토해 주세요.

Architecture를 변경하는 제안과
Terraform 코드 구조만 개선하는 제안을 구분해 주세요.
```

강사 설명 포인트:

```text
명시적 Subnet Resource
→ Resource와 Reference가 눈에 보임
→ 초심자 Dependency 학습에 유리

map(object) + for_each
→ 반복 감소와 확장성 향상
→ Resource Address와 State 변화 검토 필요
```

AI의 제안이 항상 현재 4시간 교육 목적에 적합한 것은 아니라는 점을 설명합니다.

## Demo 3 — Subnet Refactoring Preview

실제 교육생 Infrastructure State와 분리된 강사 Demo Working Copy에서 수행합니다.

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
- 변경 파일과 Resource Address 변화를 먼저 설명
- terraform apply와 terraform destroy는 실행하지 않음

코드를 변경한 뒤 변경 내용을 요약해 주세요.
```

AI 변경 직후 사람이 확인합니다.

```bash
git diff
```

검토 사항:

- CIDR과 Availability Zone 보존
- Public/Private Subnet의 Public IP 설정 보존
- Route Table Association, ALB, ASG Reference 변경
- 기존 Naming과 Tag 의미 보존
- 요청하지 않은 Resource 추가/삭제 여부

## Demo 4 — Terraform 검증과 Human Verification

```bash
cd terraform
terraform fmt
terraform validate
terraform plan
```

- `fmt`: AI가 변경한 HCL을 표준 형식으로 정리
- `validate`: Syntax와 Resource Reference의 정적 오류 확인
- `plan`: 현재 State와 변경 Configuration의 실제 차이 확인

Resource Address가 바뀌면 Architecture가 같아도 Plan에 Destroy/Create가 나타날 수 있습니다. State Migration 또는 `moved` Block 검토가 필요한 이유를 설명합니다.

Plan에 의도하지 않은 삭제나 교체가 보이면 Apply하지 않습니다. Demo 목적은 AI 변경을 배포하는 것이 아니라 Plan에서 위험을 발견하고 사람이 판단하는 과정을 보여주는 것입니다.

```text
Human
  ↓
Architecture / Requirement
  ↓
AI Assistance
  ↓
Terraform Code
  ↓
terraform fmt / validate
  ↓
terraform plan
  ↓
Human Verification
  ↓
Apply 또는 변경 보류
```

## 마무리 질문

1. AI가 현재 Architecture를 정확히 설명했는가?
2. 반복 Subnet은 왜 Essential Source에서 명시적으로 작성했는가?
3. `for_each` Refactoring의 장점과 State 위험은 무엇인가?
4. `validate` 성공만으로 Apply해도 되는가?
5. Plan에서 Destroy/Replace가 보이면 무엇을 확인해야 하는가?
6. AI가 임의로 실행하지 못하도록 제한한 명령은 무엇인가?

> AI Suggestion은 검증 전의 가설입니다. Infrastructure 변경의 최종 책임과 Apply 결정은 사람에게 있습니다.
