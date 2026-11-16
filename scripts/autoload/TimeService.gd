extends Node
## 시간 판정을 한곳에 모은 서비스.
## 기기 시간(조작 가능)과 단조 시간(부팅 후 경과, 조작 불가)을 함께 제공한다.
## 오프라인 수련 계산(M10)과 일일 초기화에서 사용한다.


## 기기 시간 (유닉스 초)
func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


## 단조 시간 (엔진 시작 후 경과 밀리초)
## 주의: 앱 재시작 시 0부터 다시 시작한다. 재부팅 판별은 M10에서 별도 처리한다.
func now_monotonic_ms() -> int:
	return Time.get_ticks_msec()
