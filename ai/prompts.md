# Kiro CLI 필수 AI-assisted IaC Lab

이 Lab은 완성된 Terraform Architecture를 교육생 각자의 Local PC에서 Kiro CLI로 분석하고, AI의 개선안을 사람이 검토하는 필수 실습입니다.

> AI는 Terraform과 Architecture를 대신 이해해 주는 도구가 아닙니다. Terraform과 Architecture를 이해한 사람이 AI를 활용하면 코드 생성, 분석, Refactoring 및 검증을 더 빠르게 수행할 수 있습니다.

## 1. Kiro CLI 설치 확인

공식 문서: https://kiro.dev/docs/cli/

- macOS/Linux:

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

- Windows 11: 공식 Kiro CLI 문서에서 Windows를 선택하여 PowerShell 설치 절차를 실행합니다.
- Windows 10: Kiro CLI의 현재 Native 지원 대상이 아니므로 WSL2 Ubuntu 안에서 Linux 설치 명령을 실행합니다.

새 Terminal에서 확인합니다.

```bash
kiro-cli --version
```

명령을 찾지 못하면 Terminal을 다시 열고 Installer가 안내한 경로가 PATH에 포함됐는지 확인합니다. macOS/Linux의 일반적인 사용자 실행 경로는 `$HOME/.local/bin`입니다.

## 2. Kiro 로그인

```bash
kiro-cli login
kiro-cli whoami
```

Browser에서 Builder ID, GitHub, Google 또는 교육에서 지정한 조직 계정으로 인증합니다. Kiro 로그인은 AWS CLI의 `tf-user` Credential과 별개입니다. Password, Device Code, Token을 Terraform 파일이나 Git에 기록하지 않습니다.

## 3. Repository Root에서 시작

Kiro CLI는 시작한 Directory의 파일을 Project Context로 사용합니다. Terraform Working Directory가 아니라 Repository Root에서 시작합니다.

```bash
cd <terraform-iac-essential 경로>
pwd
git status
kiro-cli
```

Windows PowerShell 예:

```powershell
cd C:\Users\<사용자명>\terraform-iac-essential
Get-Location
git status
kiro-cli
```

첫 요청으로 Project를 제대로 읽는지 확인합니다.

```text
현재 프로젝트의 Directory 구조와 각 Terraform 파일의 역할을 요약해 주세요.
파일을 수정하거나 terraform apply, terraform destroy 또는 AWS Resource를
변경하는 명령은 실행하지 마세요.
```

예상 결과: `terraform/`, `userdata/`, `ai/`와 VPC, Security Group, ASG, ALB 파일의 역할을 요약합니다.

## 4. Prompt 1 — 변경하지 말고 분석

다음 Prompt를 붙여넣습니다.

```text
현재 Terraform 프로젝트를 분석해 주세요.

다음 관점에서 개선할 부분을 찾아주세요.

- 반복되는 코드
- Variable
- Naming
- Tagging
- Security
- Availability
- Maintainability

코드를 바로 변경하지 말고,
현재 Architecture와 Terraform 코드의 장점 및 개선 가능한 부분을 먼저 설명해 주세요.

특히 다음 관계가 코드에서 올바른지 확인해 주세요.

- ALB는 두 Public Subnet에 배치
- Auto Scaling Group은 두 Private Subnet에 배치
- Web Instance에는 Public IP가 없음
- Web Security Group의 HTTP Source는 ALB Security Group
- Launch Template은 golden_ami_id Variable 사용
- Auto Scaling Group은 Target Group과 연결
- NAT Gateway와 RDS는 의도적으로 제외

terraform apply, terraform destroy 또는 AWS Resource를 변경하는 명령은
실행하지 마세요.
```

사람이 확인할 내용:

- AI가 현재 Architecture를 정확히 이해했는가?
- 보안상 실제 문제와 교육 목적의 단순화를 구분했는가?
- 명시적으로 반복된 네 Subnet을 향후 개선 후보로 발견했는가?
- 기본 Essential Lab에 고급 문법을 무조건 적용하라고 제안하지는 않는가?

## 5. Prompt 2 — 반복 Resource 리팩터링 설계

기본 코드를 바로 수정하지 않고 설계 차이를 먼저 비교합니다.

```text
명시적으로 반복 작성된 Public/Private Subnet Resource를 대상으로
향후 사용할 수 있는 Refactoring 방향을 설명해 주세요.

Repeated Resource
→ map(object)
→ for_each

현재 명시적 Resource 방식과 for_each 방식의 장단점을
Terraform 초심자 교육과 유지보수 관점에서 비교해 주세요.

아직 파일을 수정하지 말고 예상 Resource Address 변화와
기존 Terraform State에 미치는 영향도 설명해 주세요.
terraform apply와 terraform destroy는 실행하지 마세요.
```

핵심 학습 포인트:

```text
명시적 Resource
→ 각 Resource와 Reference를 쉽게 읽음

map(object) + for_each
→ 반복 감소와 확장성 향상
→ Resource Address와 State 변화 이해 필요
```

이번 4시간 Essential Source 자체는 `for_each` 기반으로 전면 변경하지 않습니다.

## 6. Prompt 3 — 작은 개선 하나 선택

분석 결과에서 Architecture를 바꾸지 않는 작은 개선 하나만 선택합니다.

```text
앞서 제안한 개선 후보 중 Architecture와 Resource Address를 변경하지 않는
작은 개선 하나만 선택해 주세요.

다음을 먼저 설명해 주세요.

1. 선택한 이유
2. 변경할 파일과 정확한 범위
3. 예상 terraform plan 결과
4. 보안 또는 가용성에 미치는 영향

내 승인을 받기 전에는 파일을 수정하지 마세요.
count, for_each, module, dynamic block은 사용하지 마세요.
terraform apply와 terraform destroy는 실행하지 마세요.
```

설명이 적절할 때만 제한된 변경을 승인합니다.

```text
제안한 변경 하나만 적용해 주세요.
그 외 Resource, Variable, Naming과 Architecture는 변경하지 마세요.
terraform apply와 terraform destroy는 실행하지 마세요.
```

## 7. Human Review

Kiro가 변경한 내용을 직접 확인합니다.

```bash
git diff
```

Windows PowerShell에서도 동일합니다.

확인 사항:

- 요청하지 않은 파일이 바뀌지 않았는가?
- Resource 삭제 또는 이름 변경이 없는가?
- Access Key, Secret Key, Account ID가 포함되지 않았는가?
- `golden_ami_id`가 다른 교육생의 값으로 바뀌지 않았는가?
- 기본 Architecture가 유지되는가?

예상하지 않은 변경이 있으면 Apply하지 말고 Kiro에게 변경 이유와 원복 범위를 먼저 설명하도록 요청합니다.

## 8. Prompt 4 — 변경 후 검토

```text
변경된 Terraform 코드를 다시 검토해 주세요.

다음을 확인해 주세요.

- Resource Reference 오류
- ALB Security Group과 Web Security Group 연결
- ALB의 Public Subnet 배치
- ASG의 Private Subnet 배치
- Web Instance Public IP 비활성화
- Launch Template의 Golden AMI 연결
- ASG와 Target Group 연결
- terraform destroy 시 Dependency 문제

오류 가능성과 사람이 확인할 방법을 설명하되,
terraform apply와 terraform destroy는 실행하지 마세요.
```

## 9. Terraform CLI로 검증

AI의 설명만 믿지 않고 Local Terminal에서 직접 검증합니다.

```bash
cd terraform
terraform fmt
terraform validate
terraform plan
```

Plan에서 다음을 검토합니다.

- 의도하지 않은 Destroy 또는 Replace가 없는가?
- 변경 Resource와 Attribute가 요청한 범위인가?
- 예상 비용과 보안 영향은 적절한가?
- Plan을 설명할 수 있는가?

강사가 승인한 경우에만 Apply합니다.

```bash
terraform apply
```

전체 Workflow:

```text
Human
  ↓
Architecture / Requirement
  ↓
AI Analysis
  ↓
Human Review
  ↓
Limited Code Change
  ↓
git diff
  ↓
terraform fmt
  ↓
terraform validate
  ↓
terraform plan
  ↓
Human Verification
  ↓
terraform apply
```

## 10. Troubleshooting

### Kiro가 다른 Project를 분석함

Kiro CLI를 종료하고 Repository Root에서 다시 시작합니다.

```bash
cd <terraform-iac-essential 경로>
kiro-cli
```

### Kiro가 바로 파일을 수정하려고 함

다음 제약을 다시 전달합니다.

```text
지금은 분석 단계입니다.
파일을 수정하거나 terraform apply/destroy를 실행하지 마세요.
변경안과 예상 Plan만 설명해 주세요.
```

### Login Browser가 열리지 않음

```bash
kiro-cli login --use-device-flow
```

출력된 URL과 일회용 Code를 Browser에서 사용합니다.

### 인증 상태 확인 또는 종료

```bash
kiro-cli whoami
kiro-cli logout
```

교육생 개인 PC라면 과정 후 반드시 Logout할 필요는 없습니다. 공용 PC에서는 Logout하고 Credential이 남지 않았는지 확인합니다.
