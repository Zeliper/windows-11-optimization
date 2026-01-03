# Windows 11 최적화 스크립트 문서

이 폴더는 Windows 11 25H2 최적화 스크립트 프로젝트의 문서를 포함합니다.

## 문서 목차

### 1. [SCRIPTS_OVERVIEW.md](./SCRIPTS_OVERVIEW.md)
전체 스크립트 개요 - 각 스크립트의 번호, 이름, 용도, 그룹 정보를 제공합니다.

### 2. [OPTIMIZATION_CATEGORIES.md](./OPTIMIZATION_CATEGORIES.md)
최적화 카테고리별 기능 정리 - 각 최적화 카테고리에 해당하는 스크립트와 주요 기능을 매핑합니다.

## 프로젝트 개요

Windows 11 25H2 최적화 스크립트 프로젝트는 Windows 11 시스템을 다양한 용도(일반 PC, 게임 PC, 서버 등)에 맞게 최적화하는 PowerShell 스크립트 모음입니다.

### 주요 특징

- **원클릭 실행**: 000.orchestrate.ps1을 통한 대화형 메뉴
- **모듈식 설계**: 각 기능별로 독립적인 스크립트
- **프리셋 지원**: 기본, 게임, 서버, 웹서버 프리셋 제공
- **병렬 실행**: 리소스 충돌을 피하면서 최대한 병렬로 실행
- **재부팅 관리**: 재부팅 필요 항목 자동 관리

### 실행 방법

```powershell
# GitHub에서 직접 실행
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/000.orchestrate.ps1 | iex

# 또는 개별 스크립트 실행
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/001.disable_update.ps1 | iex
```

## 문서 업데이트

이 문서는 프로젝트 변경사항에 따라 업데이트됩니다. 최신 정보는 각 스크립트 파일을 참조하세요.

## 라이선스 및 주의사항

- 이 스크립트는 시스템 설정을 변경합니다. 실행 전 백업을 권장합니다.
- 일부 스크립트는 보안 기능을 비활성화할 수 있습니다 (예: 게임 최적화).
- 프로덕션 환경에서 사용 전 테스트 환경에서 충분히 검증하세요.
