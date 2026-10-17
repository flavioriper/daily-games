# The source of docs/brainstorm/firefly-stages.html, the staged Firefly's
# stages 1-15 as data (S: each stage's text, goal, buff, Medium numbers and
# twists; WAVES/FULLW: each wave's seats and paths; DIFF: the scaling).
# Run from the repo root: python3 docs/brainstorm/firefly-stages.py
import re
SPEC = 'docs/brainstorm/firefly-spec.html'; OUT = 'docs/brainstorm/firefly-stages.html'
css = re.search(r'<style>.*?</style>', open(SPEC).read(), re.S).group(0)

FULL = [
 "<b>Top, centre:</b> 4 ladybirds to the middle of rows 2–3, and from the mirrored loop 4 gnats to the middle of rows 4–5.",
 "<b>Left side, low:</b> the 4 moths to row 1, each followed by a ladybird to the two ends of the ladybird rows' centre.",
 "<b>Right side, low:</b> 8 ladybirds to the outer seats of rows 2–3.",
 "<b>Top, right:</b> 8 gnats to the right half of rows 4–5.",
 "<b>Top, left:</b> 8 gnats to the left half of rows 4–5.",
]
FULL_CAST = "The full swarm of 40: 4 moths (row 1), 16 ladybirds (rows 2–3), 20 gnats (rows 4–5)."

S = [
 dict(n=1, name="First light", kind="play", cast=(1,0,0),
  new="The swarm, the slide and holding to fire. Only gnats, and they never shoot.",
  swarm="20 gnats, rows 4–5. No ladybirds, no moths.",
  waves=["<b>Top, left loop:</b> 10 gnats to the left half of rows 4–5.",
         "<b>Top, right loop (mirrored):</b> 10 gnats to the right half."],
  dives="Once all 20 are seated, gnats peel off one at a time from the edges and dive at you. No seeds: a gnat only costs a firefly by flying into you.",
  goal=("Catch gnats in flight, before they take their seat", (4,5,6,8)), buff="Quicker gun",
  m=(2.6,1,0,1.00), entry_from=None,
  e="Gnats fly in slower and dive one at a time, far apart.",
  h="A seed a dive appears for the first time here.",
  i="Gnats take 2 shots and dive in pairs, side by side."),
 dict(n=2, name="Ladybirds", kind="play", cast=(1,1,0),
  new="Ladybirds, which take more shots than a gnat, and seeds: divers now drop one aimed at where you are.",
  swarm="32 bugs: 12 ladybirds (rows 2–3, the moths' partner seats left empty) and 20 gnats.",
  waves=["<b>Top, centre:</b> 4 ladybirds and 4 gnats, as in the full swarm.",
         "<b>Right side, low:</b> 8 ladybirds to the outer seats of rows 2–3.",
         "<b>Top, right:</b> 8 gnats.",
         "<b>Top, left:</b> 8 gnats."],
  dives="Up to 2 bugs dive at once, ladybirds more often than gnats. Each diver drops 1 seed on its way down.",
  goal=("Catch bugs in flight", (6,8,10,12)), buff="Double fire",
  m=(2.4,2,1,1.03), entry_from=None,
  e="Ladybirds take one shot, like gnats.",
  h="",
  i="A ladybird's seeds come two at a time, side by side."),
 dict(n=3, name="Flyby", kind="flyby", cast=(1,1,1),
  new="The first bonus stage. Forty bugs fly through and never fire. Every bug takes one shot on every difficulty.",
  swarm="40 passers: 5 waves of 8, each wave mixing two kinds.",
  waves=["<b>Top loop, both sides:</b> gnats and ladybirds, 4 from each side.",
         "<b>Low from the left:</b> ladybirds and moths.",
         "<b>Low from the right:</b> gnats only.",
         "<b>Dropping loop from the top, both sides:</b> moths and ladybirds.",
         "<b>Top loop, right side:</b> ladybirds and gnats."],
  dives="No dives, no seeds. Each bug is worth 100.",
  goal=("Catch all forty", None), buff="10,000 bonus (a flyby pays points, not a buff)",
  fb=(3.4,1.00),
  e="You start as a pair, two shots at once.",
  h="",
  i="Waves 2 s apart, so two are often on screen, and a bug that flies into you costs a firefly."),
 dict(n=4, name="Moths", kind="play", cast=(1,1,1),
  new="Moths: the four bosses in row 1. They take the most shots, blush at half health and are worth 400 diving. They dive alone here, with no escorts and no beam yet.",
  swarm=FULL_CAST, waves=FULL,
  dives="Up to 2 divers at once. A moth dives about one time in four. Each diver drops 1 seed.",
  goal=("Shoot moths while they dive", (1,2,2,3)), buff="Piercing spark",
  m=(2.2,2,1,1.06), entry_from=None,
  e="", h="",
  i="A moth that dives and misses loops straight back down for a second pass instead of going home."),
 dict(n=5, name="Escorts", kind="play", cast=(1,1,1),
  new="A moth dives with up to two ladybirds from the seats below it. Shoot both escorts first and the moth is worth 800, then 1,600.",
  swarm=FULL_CAST, waves=FULL,
  dives="Up to 3 divers at once (an escorted moth counts as three). 1 seed each.",
  goal=("Shoot a moth after both its escorts (1,600)", (1,1,1,2)), buff="Score ×1.5",
  m=(2.0,3,1,1.09), entry_from=None,
  e="A moth takes one escort, not two.", h="",
  i="A moth always takes two escorts, and the escorts drop seeds too."),
 dict(n=6, name="Hot entrances", kind="play", cast=(1,1,1),
  new="Bugs fire while they fly in, so the entrance is no longer safe time. The waves also come in closer together (2.6 s apart, from 2.9).",
  swarm=FULL_CAST, waves=FULL,
  dives="Up to 3 divers at once, up to 2 seeds each.",
  goal=("Break a wave: shoot every bug of one wave before any of it sits", (1,1,1,2)), buff="Silk shield",
  m=(1.7,3,2,1.15), entry_from=6,
  e="Entrance fire stays off on Easy.", h="",
  i="Every entering bug fires once."),
 dict(n=7, name="Flyby, crossing", kind="flyby", cast=(1,1,1),
  new="The second flyby. Each wave comes from both sides at once and the two streams cross in the middle.",
  swarm="40 passers: 5 waves of 8, 4 from each side.",
  waves=["<b>Low, both sides:</b> gnats, crossing.",
         "<b>Top loop, both sides:</b> ladybirds.",
         "<b>Dropping loop, both sides:</b> moths and gnats.",
         "<b>Low, both sides:</b> ladybirds and moths.",
         "<b>Top loop, both sides:</b> one of each kind, alternating."],
  dives="No dives, no seeds. 100 each.",
  goal=("Catch all forty", None), buff="10,000 bonus",
  fb=(2.8,1.10),
  e="You start as a pair.", h="",
  i="The crossing streams fly at ×1.3, and a bug that flies into you costs a firefly."),
 dict(n=8, name="The silk beam", kind="play", cast=(1,1,1),
  new="A moth may dive alone, stop above you and open its silk beam. A firefly caught is carried up and hangs under the moth. Shoot that moth while it dives and the firefly comes back beside yours as a pair.",
  swarm=FULL_CAST, waves=FULL,
  dives="Up to 3 divers at once, up to 2 seeds each. About half of a lone moth's dives are beam runs.",
  goal=("Win a firefly back from a moth", (1,1,1,1)), buff="Quicker gun",
  m=(1.8,3,2,1.15), entry_from=6,
  e="The beam opens slower (1.2 s, from 0.8 s), so you have time to slide out.", h="",
  i="The beam stays open 1 s longer and catches from 25% wider."),
 dict(n=9, name="Held", kind="play", cast=(1,1,1),
  new="The stage starts with one of your fireflies already hanging under a moth. It doesn't cost you a life. Shoot that moth in a dive and the firefly joins you as a pair. Shoot it in its seat and the firefly turns rogue (500 seated, 1,000 diving).",
  swarm=FULL_CAST + " The second moth from the left carries the captive.",
  waves=FULL,
  dives="Up to 3 divers at once, up to 2 seeds each. The moth with the captive dives early, within its first 10 s seated.",
  goal=("Bring the held firefly home", (1,1,1,1)), buff="Silk shield",
  m=(1.8,3,2,1.15), entry_from=6,
  e="The captive's moth dives slower.", h="",
  i="The captive's moth dives only once. If it gets home, the captive turns rogue."),
 dict(n=10, name="Busy night", kind="play", cast=(1,1,1),
  new="Dives start once two thirds of the swarm is seated, not the whole swarm. The last two gnat waves fly in together, one from each top side.",
  swarm=FULL_CAST,
  waves=FULL[:3] + ["<b>Top, both sides at once:</b> 16 gnats, right and left halves together."],
  dives="Up to 5 divers at once, up to 2 seeds each.",
  goal=("Reach a chain", (8,12,12,20)), buff="Quicker gun",
  m=(1.5,5,2,1.20), entry_from=6,
  e="", h="",
  i="Dives don't wait for the swarm to sit at all."),
 dict(n=11, name="Flyby, the long way", kind="flyby", cast=(1,1,1),
  new="The third flyby. The loops are wider and the waves alternate sides, so you cross the field for every wave.",
  swarm="40 passers: 5 waves of 8.",
  waves=["<b>Top loop, left:</b> gnats.",
         "<b>Dropping loop, right:</b> ladybirds.",
         "<b>Top loop, right:</b> moths and gnats.",
         "<b>Dropping loop, left:</b> ladybirds and moths.",
         "<b>Low, both sides:</b> one of each kind."],
  dives="No dives, no seeds. 100 each.",
  goal=("Catch all forty", None), buff="10,000 bonus",
  fb=(2.4,1.20),
  e="You start as a pair.", h="",
  i="Half the passers take 2 shots, and a bug that flies into you costs a firefly."),
 dict(n=12, name="Seed rain", kind="play", cast=(1,1,1),
  new="Divers drop up to 3 seeds each, and a ladybird drops its seeds in a fan of three.",
  swarm=FULL_CAST, waves=FULL,
  dives="Up to 3 divers at once, up to 2 seeds each.",
  goal=("Go untouched for a stretch once the swarm is seated (seconds)", (20,30,30,45)), buff="Slow seeds",
  m=(2.2,3,2,1.18), entry_from=6,
  e="No fans: ladybirds drop single seeds.", h="",
  i="Seeds are aimed where you are going, not where you are."),
 dict(n=13, name="Moths first", kind="play", cast=(1,1,1),
  new="The moths come in on the first wave, and they beam more often (three dives in four alone). A beam drifts slowly toward you while it is open.",
  swarm=FULL_CAST,
  waves=["<b>Left side, low:</b> the 4 moths, each followed by a ladybird.",
         "<b>Top, centre:</b> 4 ladybirds and 4 gnats.",
         "<b>Right side, low:</b> 8 ladybirds.",
         "<b>Top, right:</b> 8 gnats.",
         "<b>Top, left:</b> 8 gnats."],
  dives="Up to 4 divers at once, up to 2 seeds each.",
  goal=("Shoot moths while their beam is open", (1,2,2,3)), buff="Piercing spark",
  m=(1.5,4,2,1.25), entry_from=6,
  e="The beam doesn't drift.", h="",
  i="Two moths can beam at the same time."),
 dict(n=14, name="No rest", kind="play", cast=(1,1,1),
  new="The order is reversed, gnats first and moths last, and dives start as soon as the first wave is seated. Bugs flying home to their seat drop seeds too.",
  swarm=FULL_CAST,
  waves=["<b>Top, left:</b> 8 gnats.",
         "<b>Top, right:</b> 8 gnats.",
         "<b>Right side, low:</b> 8 ladybirds.",
         "<b>Top, centre:</b> 4 ladybirds and 4 gnats.",
         "<b>Left side, low:</b> the 4 moths with their ladybirds."],
  dives="Up to 5 divers at once, up to 2 seeds each.",
  goal=("Catch bugs in flight", (10,15,15,20)), buff="Double fire",
  m=(1.6,5,2,1.22), entry_from=6,
  e="Bugs flying home don't fire.", h="",
  i="No pause after the stage banner. The first wave dives as it arrives."),
 dict(n=15, name="Full moon", kind="play", cast=(1,1,1),
  new="The block's finale. Everything so far at once: escorts, beams, entrance fire, seed fans. The waves come in pairs, two at a time from opposite sides.",
  swarm=FULL_CAST,
  waves=["<b>Top centre + left side together:</b> 4 ladybirds and 4 gnats, then the 4 moths with their ladybirds.",
         "<b>Right side + top right together:</b> 8 ladybirds and 8 gnats.",
         "<b>Top, left:</b> 8 gnats."],
  dives="Up to 4 divers at once, up to 2 seeds each. Clearing it opens stage 16 and the first new element.",
  goal=("Break waves", (1,2,2,3)), buff="Score ×2",
  m=(1.9,4,2,1.15), entry_from=6,
  e="Waves come one at a time.", h="",
  i="The swarm's breathing is wider, so seated bugs are harder to line up, and moths take 7 shots."),
]

DIFF = [
 ("Easy",   4, (1,1,2), 0.85, 1.4,  -1, -1, 0.0),
 ("Medium", 3, (1,2,3), 1.00, 1.0,   0,  0, 0.25),
 ("Hard",   3, (1,2,4), 1.06, 0.8,   1,  1, 0.4),
 ("Insane", 2, (2,3,5), 1.25, 0.75,  1,  1, 0.5),
]
SEED_SPEED = {"Easy":125,"Medium":150,"Hard":170,"Insane":195}


W_, H_ = 240.0, 372.0
PATHS = {
 'TOP':  [(0.56,-0.06),(0.53,0.12),(0.42,0.33),(0.24,0.52),(0.17,0.66),(0.26,0.77),(0.40,0.71),(0.44,0.57),(0.38,0.45)],
 'SIDE': [(-0.08,0.90),(0.12,0.83),(0.32,0.70),(0.45,0.53),(0.43,0.38),(0.31,0.31),(0.20,0.39),(0.24,0.51),(0.34,0.49)],
 'FLY_A':[(0.45,-0.06),(0.46,0.28),(0.30,0.52),(0.14,0.50),(0.18,0.30),(0.38,0.34),(0.62,0.54),(0.86,0.60),(1.12,0.50)],
 'FLY_B':[(-0.08,0.80),(0.28,0.66),(0.50,0.42),(0.36,0.20),(0.20,0.28),(0.34,0.50),(0.70,0.52),(0.90,0.30),(1.12,0.12)],
 'FLY_C':[(0.22,-0.06),(0.30,0.24),(0.50,0.44),(0.70,0.26),(0.60,0.10),(0.48,0.24),(0.50,0.60),(0.40,0.86),(0.30,1.12)],
}
def curve(name, mirror, steps=10):
    pts=[(((1-x) if mirror else x)*W_, y*H_) for x,y in PATHS[name]]
    out=[]; n=len(pts)
    for i in range(n-1):
        p0=pts[max(i-1,0)]; p1=pts[i]; p2=pts[i+1]; p3=pts[min(i+2,n-1)]
        for k in range(steps):
            u=k/steps; u2=u*u; u3=u2*u
            out.append(tuple(0.5*((2*p1[j])+(-p0[j]+p2[j])*u+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*u2+(-p0[j]+3*p1[j]-3*p2[j]+p3[j])*u3) for j in (0,1)))
    out.append(pts[-1]); return out
def at_frac(c, f):
    L=[0]
    for a,b in zip(c,c[1:]): L.append(L[-1]+((a[0]-b[0])**2+(a[1]-b[1])**2)**.5)
    t=f*L[-1]
    for i in range(len(c)-1):
        if L[i+1]>=t:
            r=(t-L[i])/max(L[i+1]-L[i],1e-6); return (c[i][0]+(c[i+1][0]-c[i][0])*r, c[i][1]+(c[i+1][1]-c[i][1])*r)
    return c[-1]
def seat(col,row): return (120+(col-4.5)*20, 46+row*17)
SYM={'G':('gnat',16),'L':('lady',17),'M':('moth',22)}
def use(k,x,y,op=1.0):
    s,z=SYM[k]; return f'<use href="#{s}" x="{x-z/2:.1f}" y="{y-z/2:.1f}" width="{z}" height="{z}" opacity="{op}"/>'
def pline(c, cls='path'):
    d=' '.join(f'{x:.1f},{y:.1f}' for x,y in c); return f'<polyline class="{cls}" points="{d}" marker-end="url(#arr)"/>'
def field(inner, label):
    return (f'<svg viewBox="-6 -14 252 392" role="img" aria-label="{label}"><rect x="-6" y="-14" width="252" height="392" rx="10" fill="#1d2147"/>'
            f'<rect x="-6" y="330" width="252" height="48" fill="#1f3a3a"/>{inner}'
            f'<circle cx="120" cy="352" r="9" fill="#ffe27a" opacity=".35"/>{use_ff()}</svg>')
def use_ff(): return '<use href="#ff" x="111" y="341" width="18" height="18"/>'
def wave_svg(before, wv, captive=None):
    out=[]
    for k,c,r in before: x,y=seat(c,r); out.append(use(k,x,y,.4))
    for p,m in wv['paths']: out.append(pline(curve(p,m)))
    for k,c,r in wv['seats']: x,y=seat(c,r); out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="9" fill="#ffe27a" opacity=".16"/>'+use(k,x,y))
    if captive:
        x,y=seat(*captive); out.append(f'<line x1="{x}" y1="{y+4}" x2="{x}" y2="{y+12}" stroke="#fff" stroke-width=".8"/><use href="#cap" x="{x-6}" y="{y+10}" width="12" height="12"/>')
    return field(''.join(out), 'wave')
def fly_svg(wv):
    out=[]; n=len(wv['paths']); per=8//n; kinds=wv['kinds']; idx=0
    for p,m in wv['paths']:
        c=curve(p,m); out.append(pline(c))
        for i in range(per):
            x,y=at_frac(c, 0.12+0.075*i); out.append(use(kinds[idx%len(kinds)],x,y)); idx+=1
    return field(''.join(out), 'flyby wave')
def G(c,r): return ('G',c,r)
def L(c,r): return ('L',c,r)
def M(c,r): return ('M',c,r)
def wv(paths, seats): return {'paths':paths,'seats':seats}
F,T=False,True
FW1=wv([('TOP',F),('TOP',T)],[L(4,1),L(5,1),L(4,2),L(5,2),G(4,3),G(5,3),G(4,4),G(5,4)])
FW2=wv([('SIDE',F)],[M(3,0),L(3,1),M(4,0),L(6,1),M(5,0),L(3,2),M(6,0),L(6,2)])
FW3=wv([('SIDE',T)],[L(c,r) for r in (1,2) for c in (7,8,1,2)])
FW4=wv([('TOP',T)],[G(c,r) for r in (3,4) for c in (6,7,8,9)])
FW5=wv([('TOP',F)],[G(c,r) for r in (3,4) for c in (0,1,2,3)])
FULLW=[FW1,FW2,FW3,FW4,FW5]
def both(a,b): return wv(a['paths']+b['paths'], a['seats']+b['seats'])
def fy(paths,kinds): return {'paths':paths,'kinds':kinds}
WAVES={
 1:[wv([('TOP',F)],[G(c,r) for r in (3,4) for c in range(5)]), wv([('TOP',T)],[G(c,r) for r in (3,4) for c in range(5,10)])],
 2:[FW1,FW3,FW4,FW5],
 3:[fy([('FLY_A',F),('FLY_A',T)],'GL'),fy([('FLY_B',F)],'LM'),fy([('FLY_B',T)],'G'),fy([('FLY_C',F),('FLY_C',T)],'ML'),fy([('FLY_A',T)],'LG')],
 7:[fy([('FLY_B',F),('FLY_B',T)],'G'),fy([('FLY_A',F),('FLY_A',T)],'L'),fy([('FLY_C',F),('FLY_C',T)],'MG'),fy([('FLY_B',F),('FLY_B',T)],'LM'),fy([('FLY_A',F),('FLY_A',T)],'GLM')],
 10:FULLW[:3]+[both(FW4,FW5)],
 11:[fy([('FLY_A',F)],'G'),fy([('FLY_C',T)],'L'),fy([('FLY_A',T)],'MG'),fy([('FLY_C',F)],'LM'),fy([('FLY_B',F),('FLY_B',T)],'GLM')],
 13:[FW2,FW1,FW3,FW4,FW5],
 14:[FW5,FW4,FW3,FW1,FW2],
 15:[both(FW1,FW2),both(FW3,FW4),FW5],
}
def waves_html(st):
    texts=st['waves']; data=WAVES.get(st['n'], FULLW)
    cards=[]; before=[]
    for i,(t,d) in enumerate(zip(texts,data)):
        if 'kinds' in d: img=fly_svg(d)
        else:
            cap=(4,0) if (st['n']==9 and any(s==('M',4,0) for s in d['seats'])) else None
            img=wave_svg(before,d,cap); before=before+d['seats']
        cards.append(f'<figure class="wave">{img}<figcaption><span class="wn">Wave {i+1}</span> {t}</figcaption></figure>')
    assert len(texts)==len(data), st['n']
    return '<div class="wavegrid">'+''.join(cards)+'</div>'

def esc(s): return s

def shots(cast, sh, insane_extra=None):
    out=[]
    for have,v in zip(cast,sh):
        out.append(str(v) if have else "—")
    return " / ".join(out)

def entry(st, d, frac):
    if d=="Easy": return "never"
    if d=="Insane": return "1 in 2" if st['n']>=2 else "never"
    if st.get('entry_from') and st['n']>=st['entry_from']:
        return "1 in 4" if d=="Medium" else "2 in 5"
    return "never"

def play_table(st):
    gap,div,seeds,spd = st['m']
    rows=[]
    for name,ff,sh,sm,gm,dd,sd,_ in DIFF:
        also = {"Easy":st['e'],"Medium":"","Hard":st['h'],"Insane":st['i']}[name]
        if st['n']==15 and name=="Insane": sh=(2,3,7)
        g = st['goal'][1]; goal = str(g[["Easy","Medium","Hard","Insane"].index(name)])
        rows.append(f"<tr><td><b>{name}</b></td><td class='n'>{ff}</td><td class='n'>{shots(st['cast'],sh)}</td>"
            f"<td class='n'>×{spd*sm:.2f}</td><td class='n'>{gap*gm:.1f} s</td><td class='n'>{max(1,div+dd)}</td>"
            f"<td class='n'>{min(4,max(0,seeds+sd))}</td><td class='n'>{SEED_SPEED[name]}</td><td>{entry(st,name,0)}</td>"
            f"<td class='n'>{goal}</td><td>{also}</td></tr>")
    return ("<div class='tbl'><table><thead><tr><th>Difficulty</th><th class='n'>Fireflies</th><th class='n'>Shots g / l / m</th>"
            "<th class='n'>Swarm speed</th><th class='n'>A dive every</th><th class='n'>Divers at once</th><th class='n'>Seeds a dive</th>"
            "<th class='n'>Seed speed</th><th>Entrance fire</th><th class='n'>Goal</th><th>Also</th></tr></thead><tbody>"
            + "".join(rows) + "</tbody></table></div>")

def fly_table(st):
    gap,spd = st['fb']
    mul = {"Easy":(1.2,0.8),"Medium":(1,1),"Hard":(0.85,1.15),"Insane":(0.6,1.3)}
    rows=[]
    for name,ff,*_ in DIFF:
        g,s = mul[name]
        also = {"Easy":st['e'],"Medium":"","Hard":"","Insane":st['i']}[name]
        if name=="Insane" and st['n']==3: g_txt="2.0 s"
        else: g_txt=f"{gap*g:.1f} s"
        rows.append(f"<tr><td><b>{name}</b></td><td class='n'>{ff}</td><td class='n'>{g_txt}</td><td class='n'>×{spd*s:.2f}</td><td>{also}</td></tr>")
    return ("<div class='tbl'><table><thead><tr><th>Difficulty</th><th class='n'>Fireflies</th><th class='n'>Waves apart</th>"
            "<th class='n'>Flight speed</th><th>Also</th></tr></thead><tbody>" + "".join(rows) + "</tbody></table></div>")

def goal_line(st):
    txt, g = st['goal']
    if g is None: return f"<b>Goal:</b> {txt}. <b>Reward:</b> {st['buff']}."
    return f"<b>Goal:</b> {txt}: {g[0]} / {g[1]} / {g[2]} / {g[3]} (Easy / Medium / Hard / Insane). <b>Buff for the rest of the stage:</b> {st['buff']}."

arts=[]
for st in S:
    tag = {"play":"","flyby":"<span class='pill fly'>flyby</span>"}[st['kind']]
    if st['n']==15: tag="<span class='pill fin'>finale</span>"
    waves="".join(f"<li>{w}</li>" for w in st['waves'])
    tbl = fly_table(st) if st['kind']=="flyby" else play_table(st)
    arts.append(f"""
<article class="stage" id="s{st['n']}">
  <header><span class="num">{st['n']}</span><h2>{st['name']}</h2>{tag}</header>
  <p class="new"><b>New:</b> {st['new']}</p>
  <div class="grid2">
    <div class="box"><b>The swarm</b><p>{st['swarm']}</p></div>
    <div class="box"><b>Dives</b><p>{st['dives']}</p></div>
  </div>
  <h3>Wave order</h3>
  {waves_html(st)}
  <p class="goal">{goal_line(st)}</p>
  {tbl}
</article>""")

toc = "".join(f"<li><a href='#s{s['n']}'>{s['n']} · {s['name']}</a></li>" for s in S)

extra_css = """
.pill{font:700 .7rem/1 var(--body);letter-spacing:.08em;text-transform:uppercase;padding:.35rem .55rem;border-radius:99px;background:var(--glow-soft);color:var(--ink);white-space:nowrap}
.pill.fly{background:var(--lilac);color:#fff}
.pill.fin{background:var(--rose);color:#fff}
.pill.prop{background:transparent;border:1px solid var(--lilac);color:var(--lilac)}
article.stage{padding-block:2rem 0;border-top:1px solid var(--line);margin-top:2rem}
article.stage header{display:flex;align-items:center;gap:.8rem;flex-wrap:wrap}
article.stage h2{margin:0}
.num{font:600 1.3rem/2.6rem var(--display);width:2.6rem;height:2.6rem;text-align:center;border-radius:50%;background:var(--sky);color:#fff6c9;flex:none}
.new{font-size:1.02rem}
.goal{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:.7rem .9rem;max-width:none}
ol.waves li{margin:.3rem 0}
.tbl td:last-child{min-width:14rem}
.wavegrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:.8rem;margin:.6rem 0 1rem}
figure.wave{margin:0;min-width:0}
figure.wave svg{display:block;width:100%;height:auto;max-width:100%}
figure.wave figcaption{font-size:.84rem;line-height:1.4;margin-top:.4rem;color:var(--ink)}
.wn{display:block;font:700 .7rem/1.4 var(--body);letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
.path{fill:none;stroke:#c9c3ee;stroke-width:1.6;stroke-dasharray:4 3;opacity:.85}
.legend{display:flex;flex-wrap:wrap;gap:.5rem 1.2rem;font-size:.88rem;align-items:center}
.legend span{display:inline-flex;align-items:center;gap:.4rem}
.legend svg{width:22px;height:22px;background:#1d2147;border-radius:5px;padding:2px}
.legend svg[viewBox="0 0 30 10"]{width:36px;height:14px}
"""

page = f"""<title>Firefly Stages 1–15</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600&family=Nunito:ital,wght@0,400;0,600;0,700;0,800;1,400&family=JetBrains+Mono:wght@400;600&display=swap">
{css.replace('</style>', extra_css + '</style>')}

<header class="hero">
  <div class="wrap" style="padding-bottom:2rem">
    <div class="eyebrow">Firefly · staged · proposal 2026-10-17</div>
    <h1>Stages 1–15</h1>
    <p>The first block of the staged Firefly. Each stage is cleared on its own, can be replayed for a better score, and has four difficulties. There's no shop: every stage starts with the same gun, and a skilled player earns a buff for that stage by meeting its goal. These fifteen stages bring in the cast you already know, one thing at a time. Stage 16 brings the first new element.</p>
    <div class="meta"><span class="chip">Decided: stages, no upgrades, 4 difficulties, goals give buffs</span><span class="chip warn">Every number here is proposed and untested</span></div>
  </div>
</header>

<nav class="toc" aria-label="Stages"><div class="wrap"><ol>{toc}<li><a href="#rules">Shared rules</a></li><li><a href="#calls">Calls</a></li></ol></div></nav>

<main class="wrap">
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
<marker id="arr" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10z" fill="#c9c3ee"/></marker>
<symbol id="gnat" viewBox="-10 -10 20 20"><ellipse cx="-6" cy="-3" rx="5" ry="3" fill="#ebf2ff" fill-opacity=".6"/><ellipse cx="6" cy="-3" rx="5" ry="3" fill="#ebf2ff" fill-opacity=".6"/><ellipse cx="0" cy="0" rx="4.5" ry="6" fill="#f4c94f"/><rect x="-4.5" y="-1" width="9" height="1.8" fill="#7a5a3a"/><rect x="-4" y="2.2" width="8" height="1.6" fill="#7a5a3a"/></symbol>
<symbol id="lady" viewBox="-10 -10 20 20"><circle cx="0" cy="-6" r="3" fill="#3b3028"/><circle cx="0" cy="1" r="7" fill="#e2645c"/><line x1="0" y1="-6" x2="0" y2="8" stroke="#bf4a44" stroke-width="1.2"/><circle cx="-3.4" cy="0" r="1.4" fill="#3b3028"/><circle cx="3.4" cy="3" r="1.4" fill="#3b3028"/><circle cx="-2.6" cy="4.4" r="1.1" fill="#3b3028"/></symbol>
<symbol id="moth" viewBox="-14 -12 28 24"><path d="M0 -2 C-6 -12 -14 -10 -13 -2 C-12 4 -5 4 0 2Z" fill="#9aa6e6"/><path d="M0 -2 C6 -12 14 -10 13 -2 C12 4 5 4 0 2Z" fill="#9aa6e6"/><path d="M0 1 C-4 4 -9 9 -6 10 C-3 10 -1 6 0 4Z" fill="#7d8fd9"/><path d="M0 1 C4 4 9 9 6 10 C3 10 1 6 0 4Z" fill="#7d8fd9"/><ellipse cx="0" cy="1" rx="2.6" ry="6" fill="#f6ecd9"/></symbol>
<symbol id="ff" viewBox="-12 -12 24 24"><ellipse cx="-6" cy="-1" rx="6" ry="3" fill="#ebf2ff" fill-opacity=".55"/><ellipse cx="6" cy="-1" rx="6" ry="3" fill="#ebf2ff" fill-opacity=".55"/><ellipse cx="0" cy="-2" rx="3.6" ry="5" fill="#56618a"/><circle cx="0" cy="-6" r="2.6" fill="#ef8a62"/><circle cx="0" cy="5" r="4" fill="#ffe27a"/></symbol>
<symbol id="cap" viewBox="-12 -12 24 24"><circle r="9" fill="#fff" fill-opacity=".85"/><ellipse cx="0" cy="-1" rx="3.6" ry="5" fill="#56618a"/><path d="M-9 -3 L9 3 M-9 3 L9 -3" stroke="#fff" stroke-width="1.5"/></symbol>
</defs></svg>

<section id="rules">
  <div class="eyebrow">Applies to every stage</div>
  <h2>Shared rules</h2>
  <div class="grid2">
    <div class="box"><b>The gun</b><p>The same on every stage: 1 damage, 3 volleys a second, 1 shot a volley. No energy, no shop. Only a buff changes it, and only until the stage ends.</p></div>
    <div class="box"><b>Clearing</b><p>Shoot down the whole swarm to clear the stage. Losing your last firefly fails the attempt, and you retry the stage from its start.</p></div>
    <div class="box"><b>Difficulties</b><p>Easy, Medium, Hard and Insane on every stage, each with its own best score. <span class="pill prop">proposed</span> All four are open on a stage you've reached, and clearing any of them opens the next stage.</p></div>
    <div class="box"><b>Score</b><p>Points as today (gnat 50/100, ladybird 80/160, moth 150/400 and up, rogue 500/1,000, flyby 100 each). Replays are for a higher best. Extra fireflies from points are gone, since a stage is short.</p></div>
    <div class="box"><b>The goal</b><p>One per stage, shown on the stage banner and as a small counter at the top of the field (for example 3 / 5). It's met once per attempt, and the buff starts at once.</p></div>
    <div class="box"><b>How bugs are seated</b><p>Ten columns. Row 1 has the 4 moths (middle columns), rows 2–3 the 16 ladybirds (columns 2–9), rows 4–5 the 20 gnats (all ten). Each wave flies a looping path in, then each bug flies to its own seat.</p></div>
  </div>
  <h3>Reading the wave pictures</h3>
  <p>Each wave is drawn on the field (240 × 372). This wave's bugs glow in the seats they fly to, bugs seated by earlier waves are faded, and the dashed line is the path the wave flies in on. On a flyby, the line is the path the bugs fly through and off the field.</p>
  <div class="legend"><span><svg viewBox="0 0 20 20"><use href="#gnat" width="20" height="20"/></svg>Gnat</span><span><svg viewBox="0 0 20 20"><use href="#lady" width="20" height="20"/></svg>Ladybird</span><span><svg viewBox="0 0 20 20"><use href="#moth" width="20" height="20"/></svg>Moth</span><span><svg viewBox="0 0 20 20"><use href="#cap" width="20" height="20"/></svg>Held firefly</span><span><svg viewBox="0 0 20 20" style="opacity:.3"><use href="#lady" width="20" height="20"/></svg>Seated by an earlier wave</span><span><svg viewBox="0 0 30 10"><polyline points="2,5 24,5" stroke="#c9c3ee" stroke-width="1.6" stroke-dasharray="3 2" fill="none" marker-end="url(#arr)"/></svg>Entrance path</span></div>
  <h3>The buffs</h3>
  <div class="tbl"><table><thead><tr><th>Buff</th><th>What it does until the stage ends</th></tr></thead><tbody>
    <tr><td><b>Quicker gun</b></td><td>4.5 volleys a second, up from 3.</td></tr>
    <tr><td><b>Double fire</b></td><td>A twin flies in beside you: two shots a volley, and a hit costs the twin instead of a life.</td></tr>
    <tr><td><b>Piercing spark</b></td><td>Each shot goes through the first bug it hits and can hit one more.</td></tr>
    <tr><td><b>Silk shield</b></td><td>Absorbs the next hit (a seed or a bug).</td></tr>
    <tr><td><b>Slow seeds</b></td><td>Every seed falls at half speed.</td></tr>
    <tr><td><b>Score ×1.5 / ×2</b></td><td>Every kill after the goal pays more.</td></tr>
  </tbody></table></div>
  <h3>How the difficulties scale</h3>
  <p>Each stage has its Medium numbers. The others scale from them the same way on every stage, and each stage adds its own twist on Easy and Insane (the “Also” column).</p>
  <div class="tbl"><table><thead><tr><th></th><th class="n">Easy</th><th class="n">Medium</th><th class="n">Hard</th><th class="n">Insane</th></tr></thead><tbody>
    <tr><td>Fireflies</td><td class="n">4</td><td class="n">3</td><td class="n">3</td><td class="n">2</td></tr>
    <tr><td>Shots: gnat / ladybird / moth</td><td class="n">1 / 1 / 2</td><td class="n">1 / 2 / 3</td><td class="n">1 / 2 / 4</td><td class="n">2 / 3 / 5</td></tr>
    <tr><td>Swarm speed</td><td class="n">×0.85</td><td class="n">stage's</td><td class="n">×1.06</td><td class="n">×1.25</td></tr>
    <tr><td>Time between dives</td><td class="n">×1.4</td><td class="n">stage's</td><td class="n">×0.8</td><td class="n">×0.75</td></tr>
    <tr><td>Divers at once</td><td class="n">−1 (at least 1)</td><td class="n">stage's</td><td class="n">+1</td><td class="n">+1</td></tr>
    <tr><td>Seeds a dive</td><td class="n">−1</td><td class="n">stage's</td><td class="n">+1</td><td class="n">+1 (at most 4)</td></tr>
    <tr><td>Seed speed</td><td class="n">125</td><td class="n">150</td><td class="n">170</td><td class="n">195</td></tr>
    <tr><td>Bugs that fire while flying in</td><td class="n">never</td><td class="n">1 in 4 from stage 6</td><td class="n">2 in 5 from stage 6</td><td class="n">1 in 2 from stage 2</td></tr>
  </tbody></table></div>
  <p>Seed speed is in field units a second (the field is 240 wide and 372 tall). Today's stage 1 is close to Medium.</p>
</section>

{''.join(arts)}

<section id="calls">
  <div class="eyebrow">For you to decide</div>
  <h2>Calls this page is for</h2>
  <ul>
    <li><b>Unlocks.</b> Does clearing Easy open the next stage? Or does the next stage need Medium, so Easy is only practice?</li>
    <li><b>Flybys in stages.</b> Three in this block (3, 7, 11), keeping today's rhythm. They can't be failed except on Insane, so they're breathers. Fewer?</li>
    <li><b>Extra fireflies from points.</b> Dropped here. A stage is a minute or two, so the 20,000 mark would rarely be reached.</li>
    <li><b>Boosters and Second chance.</b> Spare firefly and Twin start still fit a stage attempt. Second chance would restart the stage with one firefly on the wave you reached. Keep them?</li>
    <li><b>Stage 9's held firefly.</b> It starts the stage with something to win back. Is that clear enough without a tutorial page?</li>
    <li><b>The buffs.</b> Are six enough for the block, and does any feel wrong for its stage?</li>
    <li><b>What goes on the stage map.</b> Four badges per stage (one per difficulty cleared) and the best score.</li>
    <li><b>Stage 16's new element.</b> A wasp that dives straight and fast was the first idea. Not designed here.</li>
  </ul>
  <p>Next, once you've judged this: a bot pass per stage and difficulty to set the numbers, then the spec, then Godot.</p>
</section>

</main>
"""
open(OUT,'w').write(page)
print(len(page))
