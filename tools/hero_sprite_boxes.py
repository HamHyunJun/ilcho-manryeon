"""최종 캐릭터 시안(1213×1297)에서 각 캐릭터의 큰 일러스트와 전투 포즈를 자를 영역."""
# (이름id, 큰일러스트 box, 전투포즈 box)  box=(x0,y0,x1,y1)
COLX=[(10,248),(254,488),(494,728),(734,968),(974,1210)]
TOP_BIG=(160,445); TOP_POSE=(585,765)
BOT_BIG=(775,1017); BOT_POSE=(1140,1297)
IDS=["cheongpung","maehwa","sorim","eumyang","hyeolma","banghwang","mudang","nahan","cheongang","amyeong"]
def boxes():
    out=[]
    for r,(big,pose) in enumerate([(TOP_BIG,TOP_POSE),(BOT_BIG,BOT_POSE)]):
        for c,(x0,x1) in enumerate(COLX):
            out.append((IDS[r*5+c],(x0,big[0],x1,big[1]),(x0,pose[0],x1,pose[1])))
    return out
