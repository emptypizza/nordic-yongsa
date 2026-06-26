일반 몬스터 스프라이트(generate2dsprite 파이프라인 산출물).
- goblin/, slime/, skeleton/, bat/ : 각 2x2 idle 빌보드 시트 sheet-transparent.png
- Enemy.gd가 일반 몬스터 생성 시 이 중 하나를 랜덤으로 골라 빌보드로 렌더.
- image_gen(higgsfield) 크레딧 0이라 raw는 절차적 placeholder(make_goblin_raw.py / make_creatures.py).
  실제 AI 아트가 나오면 같은 이름의 sheet-transparent.png만 교체하면 됨(Enemy.gd 무수정).
