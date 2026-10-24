from itertools import product, permutations, combinations
from math import comb, factorial, gcd, isqrt, pi, sqrt
from fractions import Fraction as F

results = []
def check(name, got, want):
    ok = got == want
    results.append((ok, name, got, want))

# ---------- Unit 1 ----------
nums3 = range(100, 1000)
check("1-1 ex1 distinct 3-digit", sum(len(set(str(n))) == 3 for n in nums3), 648)
check("1-1 ex2 distinct even 3-digit", sum(len(set(str(n))) == 3 and n % 2 == 0 for n in nums3), 328)
check("1-1 ex3 PIN", sum(1 for p in product(range(10), repeat=4) if p[0] != 0 and p[3] % 2 == 0), 4500)
check("1-2 ex1 has 7", sum('7' in str(n) for n in nums3), 252)
check("1-2 ex2 >=2 heads", sum(sum(c) >= 2 for c in product([0,1], repeat=5)), 26)
check("1-2 ex3 contains 5 in 1..100", sum('5' in str(n) for n in range(1,101)), 19)
check("1-2 coins3 at least one H", sum(sum(c) >= 1 for c in product([0,1], repeat=3)), 7)
check("1-3 intuition", 18+15-7, 26)
check("1-3 ex1", sum(n%2==0 or n%3==0 for n in range(1,101)), 67)
check("1-3 ex2", sum(bool(n%2 and n%3 and n%5) for n in range(1,1001)) , 266)
check("1-3 pitfall mult of 6 to 100", 100//6, 16)
check("1-4 LEVEL", len(set(permutations("LEVEL"))), 30)
check("1-4 MISSISSIPPI", factorial(11)//(factorial(4)**2*factorial(2)), 34650)
check("1-4 10-gon diagonals", 10*7//2, 35)
def pairings(n):
    if n == 0: return 1
    return (n-1)*pairings(n-2)
check("1-4 pairings 4", pairings(4), 3)
check("1-4 pairings 6", pairings(6), 15)
def no_hh(n):
    return sum(all(not(s[i] and s[i+1]) for i in range(n-1)) for s in product([0,1], repeat=n))
check("1-5 no HH n=1..3", [no_hh(n) for n in (1,2,3)], [2,3,5])
def domino(n):
    a, b = 1, 1  # f(0)=1, f(1)=1
    for _ in range(n-1): a, b = b, a+b
    return b
check("1-5 domino 2x8", domino(8), 34)
check("1-5 circle regions n=1..6", [1 + comb(n,2) + comb(n,4) for n in range(1,7)], [1,2,4,8,16,31])

# ---------- Unit 2 ----------
check("2-1 ex1 officers", 10*9*8, 720)
check("2-1 ex1 committee", comb(10,3), 120)
check("2-1 ex2", comb(9,4)-comb(5,4), 121)
check("2-1 ex3 triangles", comb(8,3), 56)
check("2-1 ex3 intersections", comb(8,4), 70)
people = ['B']*4 + ['G']*3
cnt = 0
for perm in permutations(range(7)):
    girls = [i for i, p in enumerate(perm) if p >= 4]
    if all(girls[i+1]-girls[i] > 1 for i in range(len(girls)-1)):
        cnt += 1
check("2-1 ex4 girls not adjacent", cnt, 1440)
check("2-1 pitfall both ways", (comb(10,3)*3, 10*comb(9,2)), (360,360))
check("2-2 intuition", sum(1 for a,b,c in product(range(6), repeat=3) if a+b+c==5), 21)
check("2-2 ex1 positive", sum(1 for x,y,z in product(range(1,11), repeat=3) if x+y+z==10), 36)
check("2-2 ex1 nonneg", sum(1 for x,y,z in product(range(11), repeat=3) if x+y+z==10), 66)
check("2-2 ex2", sum(1 for t in product(range(2,13), repeat=4) if sum(t)==12), 35)
check("2-2 ex3 cap 5", sum(1 for x,y,z in product(range(6), repeat=3) if x+y+z==10), 21)
def paths(m, n, avoid=None, through=None):
    import functools
    @functools.lru_cache(None)
    def f(x, y):
        if avoid and (x,y)==avoid: return 0
        if x==0 and y==0: return 1
        s = 0
        if x>0: s += f(x-1,y)
        if y>0: s += f(x,y-1)
        return s
    return f(m,n)
check("2-3 ex1", paths(4,3), 35)
check("2-3 ex2", paths(2,1)*comb(4,2), 18)
check("2-3 ex3", paths(4,3,avoid=(2,1)), 17)
dice2 = list(product(range(1,7), repeat=2))
primes = {2,3,5,7,11}
check("2-4 ex1", F(sum(a+b in primes for a,b in dice2), 36), F(5,12))
balls = ['R','R','R','B','B']
check("2-4 ex2", F(sum(balls[i]=='R' and balls[j]=='R' for i,j in combinations(range(5),2)), comb(5,2)), F(3,10))
check("2-4 ex3", F(sum(a>b for a,b in dice2),36), F(5,12))
check("2-4 sum 7", F(sum(a+b==7 for a,b in dice2),36), F(1,6))
# alternating coin game: p = sum over k of (1/4)^k * 1/2
check("2-4 ex5", sum(F(1,4)**k * F(1,2) for k in range(200)) - F(2,3) < F(1,10**50), True)
check("2-5 ex1", F(sum(a+b for a,b in dice2),36), F(7))
check("2-5 ex2", F(6,6)-2, F(-1))
hats = list(permutations(range(5)))
check("2-5 ex3", F(sum(sum(p[i]==i for i in range(5)) for p in hats), len(hats)), F(1))

# ---------- Unit 3 ----------
def isprime(n):
    return n >= 2 and all(n % d for d in range(2, isqrt(n)+1))
check("3-1 primes<=100 count", sum(isprime(n) for n in range(101)), 25)
check("3-1 2026", (2*1013, isprime(1013)), (2026, True))
check("3-1 2027 prime", isprime(2027), True)
check("3-1 ex2 square k", next(k for k in range(1,1000) if isqrt(360*k)**2 == 360*k), 10)
def iscube(n):
    r = round(n ** (1/3))
    return any((r+d)**3 == n for d in (-1,0,1))
check("3-1 ex2 cube k", next(k for k in range(1,1000) if iscube(360*k)), 75)
check("3-1 ex3", [(a,1000//a) for a in range(1,1001) if 1000%a==0 and '0' not in str(a) and '0' not in str(1000//a) and a <= 1000//a], [(8,125)])
check("3-1 factors", (7*11*13, 3*37, 11*101, 3*7*13*37), (1001,111,1111,10101))
for n, f in [(51,(3,17)),(57,(3,19)),(87,(3,29)),(91,(7,13)),(119,(7,17)),(133,(7,19)),(143,(11,13)),(161,(7,23)),(187,(11,17)),(221,(13,17))]:
    check(f"3-1 composite {n}", f[0]*f[1], n)
divs = lambda n: [d for d in range(1,n+1) if n%d==0]
check("3-2 12 divisors", divs(12), [1,2,3,4,6,12])
check("3-2 ex1 count", len(divs(360)), 24)
check("3-2 ex1 sum", sum(divs(360)), 1170)
check("3-2 ex1 even", sum(d%2==0 for d in divs(360)), 18)
check("3-2 ex1 odd", sum(d%2==1 for d in divs(360)), 6)
check("3-2 ex2", sum(len(divs(n))%2==1 for n in range(1,101)), 10)
check("3-2 ex3", [n for n in range(1,101) if len(divs(n))==3], [4,9,25,49])
check("3-2 ex4", next(n for n in range(1,1000) if len(divs(n))==6), 12)
check("3-3 intuition", (gcd(12,18), 12*18//gcd(12,18)), (6,36))
pairs = [(a,b) for a in range(1,181) for b in range(a+1,181) if gcd(a,b)==6 and a*b//gcd(a,b)==180]
check("3-3 ex2", len(pairs), 4)
check("3-3 ex3", (gcd(391,299), 391==17*23, 299==13*23), (23,True,True))
def vp(n, p):
    c = 0
    m = factorial(n)
    while m % p == 0: m//=p; c+=1
    return c
check("3-4 10! zeros", len(str(factorial(10))) - len(str(factorial(10)).rstrip('0')), 2)
check("3-4 ex1 100! zeros", len(str(factorial(100))) - len(str(factorial(100)).rstrip('0')), 24)
check("3-4 ex2 v2(30!)", vp(30,2), 26)

# ---------- Unit 4 ----------
check("4-1 intuition day", 100 % 7, 2)
check("4-1 ex1", (123456*789) % 9, 0)
check("4-1 ex2", pow(2,100,7), 2)
check("4-1 ex3 CRT", next(n for n in range(1,100) if n%3==2 and n%5==3), 8)
check("4-1 ex3 next", [n for n in range(1,100) if n%3==2 and n%5==3][1], 23)
check("4-1 ex4", pow(99,5,100), 99)
check("4-2 ex1", pow(7,2026,10), 9)
check("4-2 ex2", (pow(3,2027,10)+pow(7,2027,10)) % 10, 0)
check("4-2 ex3", sum(factorial(k) for k in range(1,101)) % 10, 3)
check("4-2 ex4", pow(7,2026,100), 49)
check("4-2 pitfall 2^100", pow(2,100,10), 6)
check("4-2 cycles", {b: [pow(b,k,10) for k in range(1,5)] for b in (2,3,7,8)}, {2:[2,4,8,6],3:[3,9,7,1],7:[7,9,3,1],8:[8,4,2,6]})
check("4-3 ex1", sorted(n for n in range(7000,8000) if str(n)[2]=='2' and n%36==0), [7020,7128,7524,7920])
check("4-3 ex2", 918082 % 11, 0)
check("4-3 ex3", all(int(str(n)*2) % 1001 == 0 for n in range(100,1000)), True)
check("4-4 ex1 impossible", any(sum(s*k for s,k in zip(signs, range(1,11)))==0 for signs in product([1,-1], repeat=10)), False)
check("4-5 1011_2", int('1011',2), 11)
check("4-5 ex1", bin(2026)[2:], '11111101010')
check("4-5 ex2", all(1*b*b+2*b+1 == (b+1)**2 for b in range(3,50)), True)

# ---------- Unit 5 ----------
def shoelace(pts):
    s = 0
    for i in range(len(pts)):
        x1,y1 = pts[i]; x2,y2 = pts[(i+1)%len(pts)]
        s += x1*y2 - x2*y1
    return F(abs(s),2)
check("5-1 ex2 rhombus", (F(10*24,2), sqrt(5**2+12**2)), (F(120), 13.0))
check("5-1 3-4-5 altitude", F(3*4,5), F(12,5))
check("5-2 ex1", shoelace([(1,0),(6,3),(2,4)]), F(17,2))
check("5-4 ex1 interior", sum(1 for x in range(5) for y in range(4) if x>0 and y>0 and 3*x+4*y<12), 3)
check("5-4 ex2 tilted square", shoelace([(0,0),(3,1),(2,4),(-1,3)]), F(10))
# 5-2 ex3: overlap of square side 10 with vertex at center of another, random rotations
import random
def overlap_area(theta, N=400):
    # Monte Carlo-free: integrate by grid on region of square A [−5,5]^2 (centered at origin),
    # square B has vertex at origin, sides along angles theta and theta+90, side 10.
    import math
    c, s = math.cos(theta), math.sin(theta)
    cnt = 0
    h = 10/N
    for i in range(N):
        for j in range(N):
            x = -5 + (i+0.5)*h; y = -5 + (j+0.5)*h
            u = x*c + y*s; v = -x*s + y*c
            if 0 <= u <= 10 and 0 <= v <= 10: cnt += 1
    return cnt*h*h
check("5-2 ex3 overlap ~25", all(abs(overlap_area(t)-25) < 0.3 for t in (0.0, 0.3, 0.7, 1.2)), True)

# ---------- Unit 6 ----------
check("6-1 ex2", sqrt(3**2+4**2+12**2), 13.0)
check("6-1 ex3", (sqrt(25**2-7**2), sqrt(25**2-20**2), sqrt(25**2-20**2)-7), (24.0, 15.0, 8.0))
for t in [(3,4,5),(5,12,13),(8,15,17),(7,24,25),(20,21,29),(9,40,41)]:
    check(f"6-1 triple {t}", t[0]**2+t[1]**2, t[2]**2)
check("6-2 ex3", (F(9,5)+F(16,5), F(9,5)*F(16,5), F(12,5)**2), (F(5), F(144,25), F(144,25)))
check("6-3 polygons", [F(180*(n-2), n) for n in (5,6,8,10,12)], [108,120,135,144,150])
check("6-3 ex3 clock", abs(30*3 - F(11,2)*30), 75)
check("6-4 ex1", (sqrt(25-9), F(6+12,2)*4), (4.0, 36))

# ---------- Unit 7 ----------
check("7-1 ex1", (F(60,360)*36, F(60,360)*12), (6, 2))
check("7-1 ex3", (F(3*4,2) / F(3+4+5,2), F(3+4-5,2)), (1,1))
check("7-2 ex1", 6*4**2, 96)
check("7-2 ex3 ratio", F(4,3)/F(2), F(2,3))
n = 4
cube = list(product(range(n), repeat=3))
painted = [sum((c==0 or c==n-1) for c in p) for p in cube]
check("7-3 ex1", [painted.count(k) for k in (3,2,1,0)], [8,24,24,8])
check("7-3 ex2 visible", sum(1 for p in product(range(3), repeat=3) if 0 in p), 19)
check("7-4 ex1", sqrt(1+4), sqrt(5))

# ---------- Unit 8 ----------
check("8-1 ex1", (2025//5, 2025//5+2), (405, 407))
check("8-1 ex2", [a for a in range(1,100) if 3*a+12 == 2*(a+12)], [12])
check("8-1 ex3", [(c,p) for c in range(21) for p in range(21) if c+p==20 and 2*c+4*p==56], [(12,8)])
check("8-1 ex4", [(x,y,z) for x in range(20) for y in range(20) for z in range(20) if x+y==10 and y+z==14 and z+x==12], [(4,6,8)])
check("8-2 ex1", (F(2,3)==F(8,12), F(4,5)==F(12,15)), (True,True))
check("8-2 ex3", F(20, 200+50), F(8,100))
check("8-2 consec discount", 1 - F(8,10)*F(9,10), F(28,100))
check("8-2 up down", F(12,10)*F(8,10), F(96,100))
check("8-3 ex1", F(240, 2+3), 48)
check("8-3 ex3", 1/(F(1,4)-F(1,6)), 12)
check("8-4 ex1", 87*5 - 85*4, 95)
best = 0
for t in product(range(1,51), repeat=4):
    pass
# brute force 8-4 ex2 efficiently: sorted 5 positive ints sum 50, median 9, unique mode 8
from collections import Counter
mx = 0
for a in range(1,10):
    for b in range(a,10):
        for d in range(9,51):
            e = 50 - a - b - 9 - d
            if e < d: continue
            L = [a,b,9,d,e]
            c = Counter(L)
            top = max(c.values())
            modes = [k for k,v in c.items() if v==top]
            if modes == [8] and top >= 2:
                mx = max(mx, e)
check("8-4 ex2", mx, 15)
check("8-4 ex3", F(200+31, 11), 21)
check("8-4 baseline mean", F(90+85+95+88,4), F(179,2))
seq = list(range(7,98,5))
check("8-5 ex1", (len(seq), sum(seq)), (19, 988))
check("8-5 ex2", sum(range(1,100,2)), 2500)
check("8-5 1..100", sum(range(1,101)), 5050)
check("8-6 backsolve", 36 + 36//3, 48)

# ---------- Unit 9 ----------
check("9-1 ex1", [x for x in range(100) if (x+3)*2-5 == 25], [12])
def apples(x):
    x = x - (x//2 + 1)
    x = x - (x//2 + 1)
    return x
check("9-1 ex2", [x for x in range(2,100,2) if apples(x)==1 and (x - (x//2+1)) % 2 == 0], [10])
# stone game: losing positions (for player to move) are multiples of 4
import functools
@functools.lru_cache(None)
def win(n):
    return any(not win(n-k) for k in (1,2,3) if k <= n)
check("9-1 ex3 losing positions", [n for n in range(1,22) if not win(n)], [4,8,12,16,20])
check("9-1 ex3 first move", [k for k in (1,2,3) if not win(21-k)], [1])
# 9-2 ex1: parity of final number
import random
def final(nums):
    nums = nums[:]
    while len(nums) > 1:
        a = nums.pop(random.randrange(len(nums))); b = nums.pop(random.randrange(len(nums)))
        nums.append(abs(a-b))
    return nums[0]
check("9-2 ex1 always odd", all(final(list(range(1,11))) % 2 == 1 for _ in range(2000)), True)
check("9-3 ex1", 2*3+1, 7)
check("9-3 ex2", 7+2, 9)
check("9-4 ex1", 100 - (1+2+3+4), 90)
check("9-4 ex2", (sum(range(1,14)), sum(range(1,15)), sum(range(1,13))+22), (91,105,100))
# knights and knaves: A says "both of us are knaves"
sol = [(A,B) for A in (True,False) for B in (True,False) if A == ((not A) and (not B))]
check("9-5 knights", sol, [(False, True)])

# ---------- Appendix ----------
check("app squares", [n*n for n in range(16,26)], [256,289,324,361,400,441,484,529,576,625])
check("app 1/7", str(F(1,7)), "1/7")
check("app combos", [comb(9,2), comb(7,3), comb(9,3)], [36,35,84])

bad = [r for r in results if not r[0]]
print(f"{len(results)} checks, {len(bad)} failed")
for ok, name, got, want in bad:
    print("FAIL", name, "got", got, "want", want)
