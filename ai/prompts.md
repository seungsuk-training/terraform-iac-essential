# Kiro CLI를 활용한 AI-assisted IaC Lab

이 Lab은 AWS CloudShell에서 Kiro CLI를 설치하고 현재 Terraform 프로젝트를 분석하는 과정입니다. AI에게 처음부터 코드 변경을 맡기지 않고 분석 → 작은 변경안 → Terraform 검증 → 사람의 승인 순서로 진행합니다.

## 1. CloudShell과 프로젝트 확인

AWS Console 상단의 CloudShell 아이콘을 선택한 후 저장소로 이동합니다.

```bash
cd ~/terraform-iac-essential
pwd
git status
terraform version
```

예상 결과:

- 현재 경로가 `terraform-iac-essential`
- Git 작업 트리 상태가 출력됨
- Terraform CLI 버전이 출력됨

Kiro CLI는 현재 디렉터리의 파일을 프로젝트 Context로 사용하므로 반드시 저장소 루트에서 시작합니다.

## 2. Kiro CLI 설치

Kiro 공식 Linux 설치 스크립트를 실행합니다.

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

설치가 끝나면 현재 Shell이 새 PATH 설정을 읽도록 다시 시작하거나 다음 명령을 실행합니다.

```bash
source ~/.bashrc
```

버전을 확인합니다.

```bash
kiro-cli --version
```

버전이 출력되면 설치 성공입니다.

### `kiro-cli: command not found`가 표시되는 경우

먼저 설치 메시지에 출력된 설치 경로를 확인합니다. 새 CloudShell Terminal을 열어 다시 실행하거나 다음과 같이 일반적인 사용자 실행 경로를 PATH에 추가합니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
kiro-cli --version
```

CloudShell을 다시 열어도 적용되게 하려면 한 번만 다음을 실행합니다.

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

설치 스크립트가 다른 경로를 안내했다면 출력된 경로를 우선 사용합니다.

## 3. Kiro CLI 로그인

CloudShell은 원격 Terminal이므로 Device Flow를 명시적으로 사용합니다.

```bash
kiro-cli login --use-device-flow
```

1. Terminal에 표시된 URL을 새 Browser Tab에서 엽니다.
2. Terminal에 표시된 일회용 Code를 입력합니다.
3. Builder ID, GitHub, Google 또는 교육에서 지정한 조직 계정으로 인증합니다.
4. 인증 완료 후 CloudShell로 돌아옵니다.

로그인 사용자를 확인합니다.

```bash
kiro-cli whoami
```

사용자 또는 인증 정보가 출력되면 로그인 성공입니다. 인증 시간이 만료되면 `kiro-cli login --use-device-flow`를 다시 실행합니다.

> AWS Console의 실습용 IAM 로그인과 Kiro 로그인이 항상 같은 Identity인 것은 아닙니다. 강사가 안내한 Kiro 인증 방식을 사용하세요. Password, Device Code, Token을 README, Terraform 파일 또는 Git에 저장하지 않습니다.

## 4. Terraform 프로젝트에서 Kiro CLI 시작

저장소 루트인지 다시 확인하고 Kiro CLI를 시작합니다.

```bash
cd ~/terraform-iac-essential
kiro-cli
```

Interactive Prompt가 나타나면 먼저 다음처럼 읽기 전용 요청으로 동작을 확인합니다.

```text
현재 디렉터리의 파일 구조를 요약해 주세요.
파일을 수정하거나 terraform apply를 실행하지 마세요.
```

예상 결과: `README.md`, `terraform/`, `userdata/`, `ai/`와 주요 Terraform 파일의 역할을 요약합니다.

종료가 필요하면 Kiro CLI의 종료 명령 안내를 따르거나 `Ctrl+C`를 사용합니다.

## 5. Prompt 1 — 분석만 요청

아래 Prompt를 Kiro CLI에 붙여넣습니다.

```text
현재 Terraform 프로젝트를 분석해 주세요.

다음 관점에서 개선할 부분을 찾아주세요.
- 반복되는 코드
- 변수화
- Naming
- Tagging
- Security
- Availability
- Maintainability

코드를 바로 변경하지 말고, 현재 구조의 장점과 개선 가능한 부분을 먼저 설명해 주세요.
특히 명시적으로 반복된 Subnet Resource가 향후 map(object)와 for_each로
리팩터링될 수 있는지도 설명해 주세요.

terraform apply, terraform destroy 또는 AWS Resource를 변경하는 명령은 실행하지 마세요.
```

확인할 내용:

- VPC와 네 Subnet이 명시적으로 작성된 교육적 이유
- Public ALB와 Private ASG 배치
- ALB Security Group만 Web Security Group에 접근 가능
- 반복된 Subnet Resource가 향후 리팩터링 후보인지
- NAT Gateway가 없는 Architecture Decision

## 6. Prompt 2 — 작은 변경 후보

첫 분석 결과 중 하나만 선택합니다. 다음 예시는 공통 Tag의 일관성을 검토하지만 아직 파일을 변경하지 않습니다.

```text
앞서 제안한 개선점 중 공통 Tag 일관성 하나만 선택해 주세요.

초심자가 이해할 수 있는 작은 변경안, 변경 대상 파일,
예상 terraform plan 결과를 먼저 설명해 주세요.
내 승인을 받기 전에는 파일을 수정하지 마세요.

count, for_each, module, dynamic block은 사용하지 마세요.
terraform apply와 terraform destroy는 실행하지 마세요.
```

Kiro의 설명을 사람이 검토한 후 변경이 적절할 때만 명시적으로 수정을 승인합니다.

```text
제안한 변경만 적용해 주세요.
그 외 Resource, Variable, Naming은 변경하지 마세요.
terraform apply와 terraform destroy는 실행하지 마세요.
```

변경 직후 Git Diff를 직접 확인합니다.

```bash
git diff
```

예상하지 않은 파일이나 Resource 변경이 있으면 Apply하지 말고 원인을 먼저 확인합니다.

## 7. Prompt 3 — 변경 후 검토

```text
변경된 Terraform 코드를 검토해 주세요.

다음을 확인해 주세요.
- Resource Reference 오류
- Security Group 연결
- ALB의 Public Subnet 배치
- ASG의 Private Subnet 배치
- Launch Template의 Golden AMI 연결
- ASG와 Target Group 연결
- terraform destroy 시 Dependency 문제

오류 가능성과 확인 방법을 설명하되,
terraform apply와 terraform destroy는 실행하지 마세요.
```

## 8. Terraform 명령으로 검증

Kiro의 설명만 믿지 않고 CloudShell에서 직접 검증합니다.

```bash
cd ~/terraform-iac-essential/terraform
terraform fmt -recursive
terraform validate
terraform plan
```

검증 순서는 항상 다음과 같습니다.

```text
AI Suggestion
→ Code Change
→ git diff
→ terraform fmt
→ terraform validate
→ terraform plan
→ Human Review
→ terraform apply
```

Plan에서 의도하지 않은 삭제나 교체가 보이면 Apply하지 않습니다. 본 AI Lab 시간에는 강사가 별도로 안내하지 않는 한 분석과 Plan 검토까지만 수행합니다.

## 9. Troubleshooting

### 설치 다운로드 실패

```bash
curl -I https://cli.kiro.dev/install
```

CloudShell의 Internet 연결과 조직의 Proxy/Firewall 정책을 확인합니다. Proxy 환경에서는 담당자가 제공한 `HTTPS_PROXY` 설정을 사용합니다.

### 로그인 Browser가 자동으로 열리지 않음

CloudShell에서는 정상적인 상황입니다. 다음 명령을 사용하고 출력된 URL을 직접 Browser에서 엽니다.

```bash
kiro-cli login --use-device-flow
```

### 다른 프로젝트를 분석함

Kiro CLI를 종료한 후 저장소 루트에서 다시 시작합니다.

```bash
cd ~/terraform-iac-essential
pwd
kiro-cli
```

### 인증 상태 초기화

공용 또는 재사용 계정 정책상 로그아웃이 필요할 때만 실행합니다.

```bash
kiro-cli logout
```

> AI는 Terraform과 Architecture를 대신 이해해 주는 것이 아니라, Terraform과 Architecture를 이해한 사람이 더 빠르게 개발하고 개선할 수 있도록 돕는 도구입니다.

## 참고 문서

- Kiro CLI: https://kiro.dev/docs/cli/
- Kiro CLI 명령어: https://kiro.dev/docs/cli/reference/cli-commands/
- Kiro 인증: https://kiro.dev/docs/getting-started/authentication/
