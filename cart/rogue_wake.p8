pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- src/00_constants.lua
-- rogue wake constants

states={
 title="title",
 world="world",
 port="port",
 battle="battle",
 boarding="boarding",
 prize="prize",
 event="event",
 summary="summary"
}

factions={
 {id="crown",name="crown",col=8},
 {id="republic",name="republic",col=12},
 {id="empire",name="empire",col=14},
 {id="league",name="league",col=11},
 {id="pirates",name="pirates",col=2}
}

region_defs={
 trade={id="trade",name="trade sea",col=12},
 storm={id="storm",name="storm passage",col=13},
 frontier={id="frontier",name="frontier coast",col=3}
}

ammo_order={"round","chain","grape","heavy"}

ammo_defs={
 round={id="round",name="round shot",col=7},
 chain={id="chain",name="chain shot",col=6},
 grape={id="grape",name="grape shot",col=8},
 ["heavy"]={id="heavy",name="heavy shot",col=9}
}

ammo_reload={round=1,chain=1.1,grape=.85,["heavy"]=1.2}

-- ammo cap scales with broadside so bigger hulls carry more volleys.
-- ratios: 3 heavy, 4 chain, 5 grape volleys (brig at 12/16/20).
function ammo_caps(hull_id)
 local sd=ship_defs[hull_id]
 local bs=sd and sd.broadside or 3
 return {chain=bs*4,grape=bs*5,["heavy"]=bs*3}
end

function ammo_clamp_to_caps(p)
 if not p.ammo_stock then return end
 local caps=ammo_caps(p.hull)
 for k,v in pairs(caps) do
  if (p.ammo_stock[k] or 0)>v then p.ammo_stock[k]=v end
 end
end

crew_modes={
 {id="sailing",name="sailing",col=12},
 {id="gunnery",name="gunnery",col=8},
 {id="damage",name="repair",col=11},
 {id="boarding",name="boarding",col=9}
}

sail_modes={
 {id="reefed",name="reefed",spd=.55,turn=1.20,gun=1.10},
 {id="battle",name="battle",spd=.75,turn=1.00,gun=1.00},
 {id="full",name="full",spd=1.00,turn=.85,gun=.90}
}

port_services={"harbor","shipyard","market","tavern","admiralty","smugglers"}

-- sprite ids
spr_ids={
 round=0,chain=1,grape=2,heavy=3,
 hull=4,sail=5,morale=6,fire=7,
 gold=8,crate=9,anchor=10,skull=11
}

-- sfx ids (music owns 0-55; gameplay sfx live in 56-62)
sfx_ids={
 cannon=56,hit=57,menu=58,gold=59,
 victory=60,defeat=61,clash=62
}

ui_cols={
 bg=1,
 ink=7,
 dim=5,
 good=11,
 bad=8,
 gold=10,
 sea=1,
 panel=0,
 wind=12
}

-- arena is 1024x1024 world pixels
-- screen shows a 128x128 window (camera follows player)
-- so arena = 8x what you see on screen
battle_consts={
 arena_l=0,
 arena_t=0,
 arena_r=1023,
 arena_b=1023,
 board_dist=18,
 fire_range_min=12,
 notice_t=90
}

-- cargo types: id, name, base price, color, legal flag
cargo_defs={
 {id="staples",name="staples",base=8,col=15,legal=true},
 {id="luxury",name="luxury",base=22,col=10,legal=true},
 {id="arms",name="arms",base=18,col=8,legal=true},
 {id="powder",name="powder",base=15,col=9,legal=true},
 {id="medicine",name="medicine",base=20,col=11,legal=true},
 {id="contraband",name="contraband",base=28,col=2,legal=false},
 {id="treasure",name="treasure",base=40,col=10,legal=true}
}

-- port price multipliers by specialty
-- ports buy high what they need, sell low what they produce
cargo_port_mods={
 market={staples=.7,luxury=1.4},
 cargo={staples=.6,arms=.8,powder=.8},
 shipyard={arms=1.3,powder=1.2},
 smuggling={contraband=1.5,arms=1.1},
 contraband={contraband=1.6,luxury=1.3},
 guns={powder=.7,arms=.7},
 repairs={staples=1.2,medicine=1.3},
 boarding={arms=1.2,medicine=.8},
 rigging={staples=.8,powder=1.1},
 storms={medicine=1.4,staples=1.1},
 privateer={arms=1.1,powder=1.1},
 escort={medicine=1.2},
 bounties={arms=1.3},
 convoys={luxury=1.2,staples=.7},
 rumors={luxury=1.1,contraband=1.2}
}

goal_defs={
 {id="treasure",name="treasure fleet",desc="capture a galleon prize"},
 {id="crown",name="pirate crown",desc="defeat the act 3 rival"},
 {id="marque",name="letter of marque",desc="earn 10 rep with any faction"},
 {id="legend",name="legend run",desc="reach 15 renown in act 3"}
}

-- src/01_util.lua
-- utility helpers

function clamp(v,a,b)
 if v<a then return a end
 if v>b then return b end
 return v
end

function sgn0(v)
 if v>0 then return 1 end
 if v<0 then return -1 end
 return 0
end

function wrap1(a)
 while a<0 do
  a+=1
 end
 while a>=1 do
  a-=1
 end
 return a
end

function adiff(a,b)
 local d=abs(a-b)
 if d>.5 then d=1-d end
 return d
end

function dist(x1,y1,x2,y2)
 -- scale before squaring to avoid pico-8's 16.16 fixed-point overflow.
 -- with dx²+dy² both factored in, overflow hits once either delta passes
 -- ~127 (both=127 → sum=32258). over a 1024 arena this produced
 -- wrap-around garbage and apparent "teleporting". /16 scale keeps the
 -- squared sum under 8192 even at a full-arena diagonal.
 local dx=(x2-x1)*.0625
 local dy=(y2-y1)*.0625
 return sqrt(dx*dx+dy*dy)*16
end

function rnd_item(t)
 if not t or #t<1 then return nil end
 return t[1+flr(rnd(#t))]
end

function shallow_copy(t)
 local n={}
 if not t then return n end
 for k,v in pairs(t) do
  n[k]=v
 end
 return n
end

function deep_copy(t)
 if type(t)~="table" then return t end
 local n={}
 for k,v in pairs(t) do
  n[k]=deep_copy(v)
 end
 return n
end

function merge_mod(dst,src)
 if not src then return dst end
 for k,v in pairs(src) do
  if type(v)=="number" then
   dst[k]=(dst[k] or 0)+v
  else
   dst[k]=v
  end
 end
 return dst
end

function printc(str,y,col)
 local x=64-(#str*2)
 print(str,x,y,col)
end

function shadow(str,x,y,col,shade)
 print(str,x+1,y+1,shade or 1)
 print(str,x,y,col or 7)
end

function panel(x,y,w,h,fill,stroke)
 rectfill(x,y,x+w,y+h,fill or 0)
 rect(x,y,x+w,y+h,stroke or 5)
end

function bar(x,y,w,val,maxv,col,bg)
 rectfill(x,y,x+w,y+3,bg or 5)
 local f=0
 if maxv and maxv>0 then
  f=clamp(val/maxv,0,1)
 end
 rectfill(x,y,x+flr(w*f),y+3,col or 11)
 rect(x,y,x+w,y+3,1)
end

-- three-zone bar: dark bg (lost), gray fill up to cap (repairable),
-- colored fill up to val (current). used for hp with repairable ceiling.
function bar3(x,y,w,val,cap,maxv,col)
 rectfill(x,y,x+w,y+3,1)
 if maxv and maxv>0 then
  local cw=flr(w*clamp(cap/maxv,0,1))
  rectfill(x,y,x+cw,y+3,5)
  local vw=flr(w*clamp(val/maxv,0,1))
  rectfill(x,y,x+vw,y+3,col or 8)
 end
 rect(x,y,x+w,y+3,1)
end

function turn_towards(a,target,step)
 local d=target-a
 if d>.5 then d-=1 end
 if d<-.5 then d+=1 end
 if abs(d)<=step then
  return wrap1(target)
 end
 return wrap1(a+sgn0(d)*step)
end

function heading_to(x1,y1,x2,y2)
 return atan2(x2-x1,y2-y1)
end

function side_to_target(ship,target)
 local dx=target.x-ship.x
 local dy=target.y-ship.y
 local fx=cos(ship.a)
 local fy=sin(ship.a)
 local cross=fx*dy-fy*dx
 if cross<0 then
  return "starboard"
 end
 return "port"
end

function can_broadside(ship,target)
 local d=dist(ship.x,ship.y,target.x,target.y)
 if d<ship.range_min or d>ship.range then
  return false
 end
 local a=heading_to(ship.x,ship.y,target.x,target.y)
 local diff=adiff(ship.a,a)
 local lo=ship.arc_lo or .12
 local hi=ship.arc_hi or .38
 return diff>lo and diff<hi
end

-- how many guns bear on target (0 at arc edges, full at broadside)
function guns_in_arc(ship,target)
 local a=heading_to(ship.x,ship.y,target.x,target.y)
 local diff=adiff(ship.a,a)
 local lo=ship.arc_lo or .12
 local hi=ship.arc_hi or .38
 if diff<lo or diff>hi then return 0 end
 -- each gun has its own arc based on hull position
 -- forward guns splay toward bow, rear guns toward stern
 local offset=diff-.25 -- neg=toward bow, pos=toward stern
 local bs=ship.broadside
 local count=0
 for i=1,bs do
  local f=i/(bs+1)
  local splay=(.5-f)*.12 -- rear guns splay aft, front guns splay fore
  if abs(offset-splay)<.08 then count+=1 end
 end
 return max(1,count)
end

-- word-wrap a string into lines no longer than max_chars.
-- naive: splits on spaces, breaks when next word won't fit.
function wrap_text(s,max_chars)
 local out={}
 local cur=""
 local i=1
 local n=#s
 while i<=n do
  -- find next word
  local j=i
  while j<=n and sub(s,j,j)~=" " do j+=1 end
  local word=sub(s,i,j-1)
  if #cur==0 then
   cur=word
  elseif #cur+1+#word<=max_chars then
   cur=cur.." "..word
  else
   add(out,cur)
   cur=word
  end
  i=j+1
 end
 if #cur>0 then add(out,cur) end
 return out
end

function cycle_idx(i,maxn,dir)
 i+=dir
 if i<1 then i=maxn end
 if i>maxn then i=1 end
 return i
end

function msg(str,col)
 g.notice=str
 g.notice_col=col or 7
 g.notice_t=battle_consts.notice_t
end

function total_crew(c)
 return (c.hands or 0)+(c.marines or 0)
end

-- charge hull-defined upkeep when entering a port's services menu.
-- returns true if mutiny triggered (caller should skip the menu transition).
-- payment ladder: pay if you can; otherwise sell belongings (gold→0,
-- morale -10). if morale was already at the floor (20), the crew won't
-- swallow another humiliation — mutiny, run ends.
-- one charge per port stay: re-entering after backing out doesn't bill again.
function charge_port_upkeep()
 if g.run.upkeep_paid_at==g.run.loc then return false end
 local p=g.run.player
 local up=ship_defs[p.hull] and ship_defs[p.hull].upkeep or 0
 if up<=0 then
  g.run.upkeep_paid_at=g.run.loc
  return false
 end
 if p.gold>=up then
  p.gold-=up
  msg("port upkeep -"..up.."g",6)
  g.run.upkeep_paid_at=g.run.loc
  return false
 end
 if p.morale<=20 then
  if g.run.stats then g.run.stats.cause="mutiny in port" end
  set_state(states.summary,{outcome="mutiny"})
  return true
 end
 p.gold=0
 p.morale=max(20,p.morale-10)
 g.run.upkeep_paid_at=g.run.loc
 msg("sold belongings for upkeep!",8)
 return false
end

-- marines stiffen morale: each marine soaks 2% of incoming morale damage,
-- floored at 50% reduction. discipline holds even when the deck is hot.
function apply_morale_dmg(ship,amt)
 local m=ship.marines or 0
 local factor=max(.5,1-m*.02)
 ship.morale=max(0,ship.morale-amt*factor)
end

-- sum of ports across every act, for lifetime run stats
function total_run_ports()
 local n=0
 for a in all(act_defs) do n+=#a.ports end
 return n
end

-- clamp total crew to the hull's crew_cap. trim hands before marines
-- so specialists stick around through cuts.
function enforce_crew_cap(p)
 if not p or not p.crew or not p.hull then return end
 local cap=ship_defs[p.hull].crew_cap
 local c=p.crew
 local tot=total_crew(c)
 if tot<=cap then return end
 local over=tot-cap
 local roles={"hands","marines"}
 for r in all(roles) do
  if over<=0 then break end
  local cur=c[r] or 0
  local cut=min(cur,over)
  c[r]=cur-cut
  over-=cut
 end
end

function hull_name(id)
 local d=ship_defs[id]
 if d then return d.name end
 return id
end

function perk_name(id)
 local p=perk_by_id(id)
 if p then return p.name end
 return id
end

function upgrade_by_id(id)
 for u in all(upgrade_defs) do
  if u.id==id then return u end
 end
 return nil
end

-- effective hull cap including fitted upgrades
function run_hp_max(p)
 local m=ship_defs[p.hull].hull
 if p.upgrades then
  for id in all(p.upgrades) do
   local u=upgrade_by_id(id)
   if u and u.mod and u.mod.hull then m+=u.mod.hull end
  end
 end
 return max(8,m)
end

-- effective sail cap including fitted upgrades
function run_sail_max(p)
 local m=ship_defs[p.hull].sails
 if p.upgrades then
  for id in all(p.upgrades) do
   local u=upgrade_by_id(id)
   if u and u.mod and u.mod.sails then m+=u.mod.sails end
  end
 end
 return max(8,m)
end

-- officers cost both gold and renown; rarer hands want a captain
-- with a reputation, so the pricier berths demand more renown too
function officer_ren_cost(o)
 if not o then return 0 end
 return (o.cost>=70) and 1 or 0
end

function officer_by_id(id)
 for o in all(officer_defs) do
  if o.id==id then return o end
 end
 return nil
end

function contract_by_id(id)
 for c in all(contract_defs) do
  if c.id==id then return c end
 end
 return nil
end

function perk_by_id(id)
 for p in all(perk_defs) do
  if p.id==id then return p end
 end
 return nil
end

function find_port(ix)
 return g.run.ports[ix]
end

function cur_port()
 return g.run.ports[g.run.loc]
end

function short_money(n)
 return "$"..flr(n)
end

function cargo_by_id(id)
 for c in all(cargo_defs) do
  if c.id==id then return c end
 end
 return nil
end

-- calculate buy/sell price for a cargo at a port
-- produces: port makes this good cheaply (buy low here)
-- demands: port needs this good (sell high here)
function cargo_price(cargo_id,port)
 local cd=cargo_by_id(cargo_id)
 if not cd then return 0 end
 local m=1
 -- only produces/demands move a good off base. every port has exactly
 -- 3 such specials (1 produces + 2 demands) so the market screen shows
 -- 3 non-standard prices and the rest sit at base.
 if port.produces then
  for g in all(port.produces) do
   if g==cargo_id then m=m*.65 end
  end
 end
 if port.demands then
  for g in all(port.demands) do
   if g==cargo_id then m=m*1.75 end
  end
 end
 -- quartermaster knows the docks: cheaper buy (global shift)
 if has_officer("sly_quartermaster") then m=m*.90 end
 if has_upgrade("quartermaster") then m=m*.94 end
 return max(1,flr(cd.base*m))
end

-- sell price includes a spread so buying and selling at the
-- same port always loses money. profit requires a real route.
function cargo_sell_price(cargo_id,port)
 local buy=cargo_price(cargo_id,port)
 local mult=.82
 -- quartermaster trims the spread on your favor (combined cap at .94 so
 -- stacking the officer and upgrade doesn't fully erase the spread)
 if has_officer("sly_quartermaster") then mult=.90 end
 if has_upgrade("quartermaster") then mult=min(.94,mult+.04) end
 return max(1,flr(buy*mult))
end

-- cargo load as fraction 0..1
function cargo_load_pct()
 local cap=cargo_cap()
 if cap<=0 then return 0 end
 return min(1,cargo_count()/cap)
end

-- rough gold value of the current hold (raider bait)
function cargo_gold_value()
 local v=0
 local c=g.run.player.cargo or {}
 for cd in all(cargo_defs) do
  local n=c[cd.id] or 0
  if n>0 then v+=n*(cd.base or 0) end
 end
 return v
end

-- count total cargo units player is carrying
function cargo_count()
 local n=0
 if not g.run or not g.run.player.cargo then return 0 end
 for _,v in pairs(g.run.player.cargo) do
  n+=v
 end
 return n
end

-- max cargo capacity
function cargo_cap()
 local c=ship_defs[g.run.player.hull].cargo or 20
 if has_upgrade("smuggler_holds") then c+=6 end
 return c
end

function has_perk(id)
 if not g.run or not g.run.player then return false end
 for p in all(g.run.player.perks) do
  if p==id then return true end
 end
 return false
end

function has_upgrade(id)
 if not g.run or not g.run.player then return false end
 for u in all(g.run.player.upgrades) do
  if u==id then return true end
 end
 return false
end

-- merchant-heir's silver purse: 15% off big-ticket port fees
function silver_purse_cost(c)
 if has_background("merchant_heir") then return flr(c*.85) end
 return c
end

function has_background(id)
 if not g.run or not g.run.player then return false end
 return g.run.player.background==id
end

function port_hostile(port)
 if not port or not port.owner then return false end
 if port.owner=="pirates" then return false end
 local frep=g.run.factions[port.owner]
 if frep and frep.rep<=-6 then
  -- false_colors upgrade lets you sneak in
  if has_upgrade("false_colors") then return false end
  return true
 end
 return false
end

function faction_standing(fid)
 if not g.run.factions[fid] then return "neutral" end
 local r=g.run.factions[fid].rep
 if r>=8 then return "allied"
 elseif r>=4 then return "friendly"
 elseif r>=-3 then return "neutral"
 elseif r>=-5 then return "wary"
 else return "hostile"
 end
end

function standing_col(fid)
 local s=faction_standing(fid)
 if s=="allied" then return 11
 elseif s=="friendly" then return 11
 elseif s=="neutral" then return 7
 elseif s=="wary" then return 9
 else return 8
 end
end

-- src/02_data_ships.lua
-- hulls and encounter ship profiles

-- 512x512 arena, 128px viewport
-- speeds: ~0.3-0.5 px/frame = slow crawl on screen
-- ranges: 30-55px = quarter to half screen engagement
-- accel: how fast cur_spd ramps toward target each frame (per slow=1).
-- big hulls keep decent top speed but spool up slowly so they feel weighty.
ship_defs={
 cutter={
  id="cutter",name="cutter",
  hull=36,sails=28,crew_cap=18,cargo=20,
  broadside=3,range=35,range_min=10,
  speed=0.6,turn=.0025,accel=.04,
  upkeep=2,size=6,shallow=1
 },
 sloop={
  id="sloop",name="sloop",
  hull=48,sails=36,crew_cap=26,cargo=28,
  broadside=4,range=40,range_min=12,
  speed=0.55,turn=.002,accel=.035,
  upkeep=3,size=7,shallow=1
 },
 brig={
  id="brig",name="brig",
  hull=64,sails=48,crew_cap=38,cargo=40,
  broadside=6,range=45,range_min=14,
  speed=0.48,turn=.0012,accel=.025,
  upkeep=5,size=8,shallow=2
 },
 corvette={
  id="corvette",name="corvette",
  hull=76,sails=56,crew_cap=46,cargo=36,
  broadside=7,range=50,range_min=14,
  speed=0.46,turn=.0013,accel=.02,
  upkeep=6,size=8,shallow=2
 },
 frigate={
  id="frigate",name="frigate",
  hull=96,sails=68,crew_cap=60,cargo=52,
  broadside=9,range=55,range_min=16,
  speed=0.48,turn=.0010,accel=.006,
  upkeep=8,size=9,shallow=3
 },
 galleon={
  id="galleon",name="galleon",
  hull=120,sails=80,crew_cap=78,cargo=72,
  broadside=11,range=48,range_min=14,
  speed=0.50,turn=.0007,accel=.004,
  upkeep=10,size=10,shallow=4
 }
}

encounter_profiles={
 -- "trader" replaces the old auto-fleeing merchant: armed merchants that
 -- give a broadside fight, only running once badly hurt
 {id="merchant",name="trader",hull="brig",ai="trader",gold=38,col=10,lawful=true},
 {id="raider",name="raider",hull="sloop",ai="raider",gold=40,col=8,lawful=false},
 {id="privateer",name="privateer",hull="corvette",ai="duelist",gold=55,col=12,lawful=true},
 {id="hunter",name="hunter",hull="frigate",ai="hunter",gold=80,col=14,lawful=true},
 {id="escort",name="escort",hull="brig",ai="escort",gold=45,col=11,lawful=true},
 -- treasure galleon is the climactic prize: stands and fights, no flee
 {id="treasure",name="galleon",hull="galleon",ai="treasure",gold=120,col=10,lawful=true}
}

function make_ship(hull_id)
 local d=deep_copy(ship_defs[hull_id])
 d.hp=d.hull
 d.hp_max=d.hull
 d.hp_perm=d.hull
 d.sail_hp=d.sails
 d.sail_max=d.sails
 d.sail_perm=d.sails
 d.morale=70
 d.crew=flr(d.crew_cap*.65)
 d.marines=max(2,flr(d.crew*.18))
 d.ammo=1
 d.crew_mode=2
 d.sail_mode=2
 d.shots_l=0
 d.shots_r=0
 d.fire=0
 d.flood=0
 d.panic=0
 d.reload_base=190
 d.brace_cd=0
 d.sub={rig=100,gun_l=100,gun_r=100}
 d.arc_lo=.12
 d.arc_hi=.38
 d.rcl_x=0 d.rcl_y=0
 d.cur_spd=0  -- ramps toward move_speed() via ship.accel each frame
 -- per-gun cooldowns (sparse; 0 or missing = ready)
 d.gcd_l={}
 d.gcd_r={}
 d.gcdm_l={}
 d.gcdm_r={}
 d.x=0
 d.y=0
 d.a=0
 return d
end

function player_ship_from_run()
 local s=make_ship(g.run.player.hull)
 local p=g.run.player
 s.hp=p.hp
 s.hp_max=ship_defs[p.hull].hull
 s.hp_perm=p.hp
 s.sail_hp=p.sail_hp
 s.sail_max=ship_defs[p.hull].sails
 s.morale=p.morale
 s.crew=total_crew(p.crew)
 s.marines=p.crew.marines
 apply_upgrade_mods(s,p.upgrades)
 apply_officer_mods(s,p.officers)
 -- background bonuses
 if p.background=="fort_gunner" then
  s.range=s.range+8
 end
 if p.background=="corsair_orphan" then
  s.marines=s.marines+2
 end
 -- cargo load penalty: heavy holds slow you and hurt turn
 local load=cargo_load_pct()
 if load>0 then
  s.speed=max(.25,s.speed*(1-load*.28))
  s.turn=max(.0002,s.turn*(1-load*.25))
 end
 return s
end

function apply_upgrade_mods(ship,upgrades)
 if not upgrades then return end
 for id in all(upgrades) do
  -- chase guns: extend the forward edge of the firing arc.
  -- broadside coverage (near the beam) is untouched; bow-on shots
  -- that used to miss now bear.
  if id=="chase_guns" then ship.arc_lo=.06 end
  local u=upgrade_by_id(id)
  if u and u.mod then
   if u.mod.speed then ship.speed=max(.4,ship.speed*(1+u.mod.speed)) end
   if u.mod.turn then ship.turn=max(.0001,ship.turn*(1+u.mod.turn)) end
   if u.mod.range then ship.range=max(12,ship.range+u.mod.range) end
   if u.mod.broadside then ship.broadside=max(1,ship.broadside+u.mod.broadside) end
   if u.mod.hull then
    ship.hp_max=max(8,ship.hp_max+u.mod.hull)
    ship.hp=min(ship.hp,ship.hp_max)
   end
   if u.mod.sails then
    ship.sail_max=max(8,ship.sail_max+u.mod.sails)
    ship.sail_hp=min(ship.sail_hp,ship.sail_max)
   end
   if u.mod.morale then ship.morale=min(99,ship.morale+u.mod.morale) end
   if u.mod.marines then ship.marines=max(0,ship.marines+u.mod.marines) end
   if u.mod.reload then ship.reload_mul=(ship.reload_mul or 1)+u.mod.reload end
  end
 end
end

function apply_officer_mods(ship,officers)
 if not officers then return end
 for id in all(officers) do
  local o=officer_by_id(id)
  if o and o.mod then
   if o.mod.speed then ship.speed=max(.4,ship.speed*(1+o.mod.speed)) end
   if o.mod.turn then ship.turn=max(.0001,ship.turn*(1+o.mod.turn)) end
   if o.mod.range then ship.range=max(12,ship.range+o.mod.range) end
   if o.mod.broadside then ship.broadside=max(1,ship.broadside+o.mod.broadside) end
   if o.mod.morale then ship.morale=min(99,ship.morale+o.mod.morale) end
   if o.mod.marines then ship.marines=max(0,ship.marines+o.mod.marines) end
   if o.mod.reload then ship.reload_mul=(ship.reload_mul or 1)+o.mod.reload end
  end
 end
end

function make_enemy_ship(profile_id,region)
 local prof=nil
 for p in all(encounter_profiles) do
  if p.id==profile_id then prof=p break end
 end
 if not prof then prof=encounter_profiles[1] end

 -- early-game softening: act 1, first 5 days, random traders sail
 -- smaller hulls (sloop vs brig) so a starting cutter has a real shot
 local hull=prof.hull
 local early_weak=profile_id=="merchant" and g.run.act==1 and g.run.day<=5
 if early_weak then hull="sloop" end
 local s=make_ship(hull)
 s.profile=prof.id
 s.label=prof.name
 s.col=prof.col
 s.ai=prof.ai
 s.team="enemy"
 s.reload_base=210
 s.a=.5+rnd(.1)-.05
 s.x=94+rnd(8)
 s.y=56+rnd(22)
 s.morale=62+flr(rnd(18))
 -- early-game traders are skittish: lower morale start, so they're
 -- closer to the surrender threshold without artificial pressure
 if early_weak then s.morale=48+flr(rnd(12)) end
 s.crew=max(8,flr(s.crew_cap*(.55+rnd(.25))))
 s.marines=max(1,flr(s.crew*.2))
 if region=="storm" then
  s.morale+=3
 end
 -- merchants are cargo-laden: slower, clumsier, bigger sail profile
 -- player can catch them and damage sails (already scales speed) to slow further
 if prof.ai=="merchant" then
  s.speed=s.speed*.72
  s.turn=s.turn*.78
  s.sail_max=flr(s.sail_max*1.15)
  s.sail_hp=s.sail_max
  s.broadside=max(1,s.broadside-1)
 end
 return s
end

-- src/03_data_upgrades.lua
-- upgrades and perks

upgrade_defs={
 {id="reinforced_ribs",name="reinforced ribs",slot="hull",price=70,
  desc="+hull, -turn",mod={hull=8,turn=-.08}},
 {id="copper_bottom",name="copper bottom",slot="hull",price=100,
  desc="+speed, pricier repairs",mod={speed=.12}},
 {id="shallow_keel",name="shallow keel",slot="hull",price=55,
  desc="+turn",mod={turn=.10}},
 {id="bulkheads",name="bulkheads",slot="hull",price=110,
  desc="heavy armor",mod={hull=14}},
 {id="iron_prow",name="iron prow",slot="hull",price=70,
  desc="brutal rams, bow tanks hits",mod={hull=2}},
 {id="storm_sails",name="storm sails",slot="rig",price=75,
  desc="+turn, +sail, less storm dmg",mod={turn=.12,sails=4}},
 {id="fine_rudder",name="fine rudder",slot="rig",price=70,
  desc="+turn",mod={turn=.18}},
 {id="spare_spars",name="spare spars",slot="rig",price=60,
  desc="+sail hp",mod={sails=7}},
 {id="nimble_rigging",name="nimble rigging",slot="rig",price=70,
  desc="faster sail changes",mod={}},
 {id="long_guns",name="long guns",slot="guns",price=85,
  desc="+range, slower reload",mod={range=7,reload=-.15}},
 {id="carronades",name="carronades",slot="guns",price=80,
  desc="+broadside, -range",mod={range=-6,broadside=2}},
 {id="chase_guns",name="chase guns",slot="guns",price=45,
  desc="wider forward firing arc",mod={}},
 {id="fine_powder",name="fine powder",slot="guns",price=70,
  desc="faster volleys",mod={reload=.10}},
 {id="drilled_crews",name="drilled crews",slot="crew",price=75,
  desc="+morale, faster reload",mod={morale=6,reload=.15}},
 {id="marines",name="marine detachment",slot="crew",price=85,
  desc="+marines, stronger boarding",mod={marines=6,morale=3}},
 {id="surgeon",name="ship surgeon",slot="crew",price=80,
  desc="reduced losses after battle",mod={morale=4}},
 {id="carpenter",name="master carpenter",slot="crew",price=85,
  desc="stronger field repairs",mod={hull=4}},
 {id="quartermaster",name="quartermaster",slot="crew",price=65,
  desc="better economy",mod={morale=3}},
 {id="false_colors",name="false colors",slot="utility",price=60,
  desc="easier approach and smuggling",mod={}},
 {id="smuggler_holds",name="smuggler holds",slot="utility",price=75,
  desc="+6 cargo, buy contraband",mod={}},
 {id="grapnels",name="grapnels",slot="utility",price=65,
  desc="better boarding start",mod={marines=2}},
 {id="prize_charter",name="prize charter",slot="utility",price=70,
  desc="better prize value",mod={}}
}

perk_defs={
 {id="weather_eye",name="weather eye",desc="storms hurt less"},
 {id="cold_shot",name="cold shot",desc="faster ammo swap"},
 {id="sea_wolf",name="sea wolf",desc="morale after victory"},
 {id="lucky_devil",name="lucky devil",desc="bigger loot + salvage"},
 {id="silver_tongue",name="silver tongue",desc="enemies break sooner"},
 {id="ruthless_example",name="ruthless example",desc="fear factor, harsher heat"},
 {id="salvage_instinct",name="salvage instinct",desc="more loot everywhere"},
 {id="veteran_discipline",name="veteran discipline",desc="brace + travel morale"},
 {id="dead_reckoning",name="dead reckoning",desc="travel -1 day per leg"},
 {id="ships_surgeon",name="ship's surgeon",desc="crew losses reduced in battle"},
 {id="iron_keel",name="iron keel",desc="+hull regen during travel"},
 {id="black_market_eye",name="black market eye",desc="better smuggler prices"},
 {id="old_salt",name="old salt",desc="port arrival: +mor, +sup"}
}

-- src/04_data_ports.lua
-- faction and port layout

act_defs={
 { -- act 1: trade sea (easy) - 6 ports
  name="trade sea",region="trade",danger=.38,col=12,
  ports={
   {name="ashdown",x=22,y=30,owner="crown",prosperity=3,unrest=1,
    services={"harbor","shipyard","tavern","admiralty","market"},
    specialties={"shipyard","privateer"},
    produces={"staples"},demands={"powder","luxury"},
    links={2,3,4,6}},
   {name="san castor",x=84,y=24,owner="republic",prosperity=3,unrest=1,
    services={"harbor","market","tavern","admiralty"},
    specialties={"market","escort"},
    produces={"luxury"},demands={"medicine","staples"},
    links={1,5,6}},
   {name="red wharf",x=52,y=78,owner="league",prosperity=2,unrest=2,
    services={"harbor","market","tavern"},
    specialties={"cargo","rumors"},
    produces={"arms"},demands={"luxury","treasure"},
    links={1,4,5,6}},
   {name="hollow cay",x=12,y=70,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","tavern","smugglers"},
    specialties={"smuggling","contraband"},
    produces={"contraband"},demands={"arms","medicine"},
    links={1,3}},
   {name="tern isle",x=108,y=64,owner="republic",prosperity=2,unrest=1,
    services={"harbor","market","tavern"},
    specialties={"repairs","rigging"},
    produces={"medicine"},demands={"powder","arms"},
    links={2,3}},
   {name="quill reach",x=64,y=46,owner="crown",prosperity=2,unrest=1,
    services={"harbor","shipyard","admiralty"},
    specialties={"guns","bounties"},
    produces={"powder"},demands={"staples","medicine"},
    links={1,2,3}}
  }
 },
 { -- act 2: storm passage (medium) - 6 ports
  name="storm passage",region="storm",danger=.42,col=13,
  ports={
   {name="brightwater",x=24,y=26,owner="empire",prosperity=2,unrest=1,
    services={"harbor","shipyard","admiralty","market","tavern"},
    specialties={"guns","convoys"},
    produces={"arms"},demands={"medicine","luxury"},
    links={2,3,4,6}},
   {name="greyhaven",x=92,y=44,owner="league",prosperity=2,unrest=2,
    services={"harbor","shipyard","market","tavern"},
    specialties={"rigging","storms"},
    produces={"luxury"},demands={"powder","staples"},
    links={1,5,6}},
   {name="saint vey",x=48,y=84,owner="crown",prosperity=2,unrest=2,
    services={"harbor","market","tavern","admiralty"},
    specialties={"repairs","bounties"},
    produces={"medicine"},demands={"arms","treasure"},
    links={1,4,5,6}},
   {name="tempest hold",x=14,y=58,owner="empire",prosperity=2,unrest=2,
    services={"harbor","shipyard"},
    specialties={"guns","storms"},
    produces={"powder"},demands={"medicine","staples"},
    links={1,3}},
   {name="iron bend",x=104,y=82,owner="league",prosperity=2,unrest=2,
    services={"harbor","market","tavern"},
    specialties={"boarding","bounties"},
    produces={"staples"},demands={"arms","luxury"},
    links={2,3}},
   {name="kelpie cove",x=66,y=34,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","tavern","smugglers"},
    specialties={"smuggling","contraband"},
    produces={"contraband"},demands={"powder","medicine"},
    links={1,2,3}}
  }
 },
 { -- act 3: frontier coast (hard) - 6 ports
  name="frontier coast",region="frontier",danger=.50,col=9,
  ports={
   {name="dagger cay",x=28,y=38,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","tavern","smugglers","market","shipyard"},
    specialties={"smuggling","boarding"},
    produces={"contraband"},demands={"medicine","luxury"},
    links={2,3,4,6}},
   {name="port mercy",x=96,y=28,owner="republic",prosperity=2,unrest=2,
    services={"harbor","market","tavern","admiralty"},
    specialties={"contraband","rumors"},
    produces={"staples"},demands={"treasure","arms"},
    links={1,5,6}},
   {name="black isle",x=56,y=88,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","tavern","smugglers","shipyard"},
    specialties={"outfit","bounties"},
    produces={"arms"},demands={"staples","contraband"},
    links={1,4,5,6}},
   {name="salt rift",x=40,y=60,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","tavern","smugglers"},
    specialties={"smuggling","contraband"},
    produces={"contraband"},demands={"treasure","arms"},
    links={1,3}},
   {name="far lantern",x=108,y=60,owner="league",prosperity=2,unrest=2,
    services={"harbor","market","tavern"},
    specialties={"rumors","repairs"},
    produces={"treasure"},demands={"medicine","powder"},
    links={2,3}},
   {name="ember isle",x=80,y=76,owner="pirates",prosperity=1,unrest=3,
    services={"harbor","shipyard","smugglers"},
    specialties={"boarding","outfit"},
    produces={"powder"},demands={"staples","contraband"},
    links={1,2,3}}
  }
 }
}

function load_act_ports(act_n)
 local ad=act_defs[act_n]
 local ports={}
 for pd in all(ad.ports) do
  local p=deep_copy(pd)
  p.region=ad.region
  -- per-seed economy: ports whose original produce is a staple commodity
  -- (not contraband/treasure - those are specialty-gated identities) get
  -- a random commodity this run so ashdown isn't "always staples".
  local commodities={"staples","luxury","arms","powder","medicine"}
  local cur=p.produces and p.produces[1]
  if cur~="contraband" and cur~="treasure" then
   p.produces={commodities[1+flr(rnd(#commodities))]}
  end
  -- shuffle initial demands from any cargo type except what we produce.
  -- inline (rather than calling market_shift_port) because g.run still
  -- references the previous run here; next_shift is left nil and seeded
  -- lazily by update_market_shifts once the run starts ticking.
  local dem_avail={}
  for cd in all(cargo_defs) do
   if cd.id~=p.produces[1] then add(dem_avail,cd.id) end
  end
  p.demands={}
  for i=1,2 do
   if #dem_avail>0 then
    local ix=1+flr(rnd(#dem_avail))
    add(p.demands,dem_avail[ix])
    del(dem_avail,dem_avail[ix])
   end
  end
  p.next_shift=nil
  p.offer_upgrade=random_port_upgrade(p)
  p.offer_officer=random_port_officer(p)
  p.offer_contract=random_port_contract(p)
  p.rumor=rnd_item(rumor_pool)
  init_port_stock(p)
  add(ports,p)
 end
 return ports
end

-- initial market stock: produced goods plentiful, others scarce.
-- contraband only exists at ports with smugglers (and stays scarce there).
function init_port_stock(p)
 if not port_has(p,"market") and not port_has(p,"smugglers") then
  p.stock=nil return
 end
 local prosp=p.prosperity or 2
 p.stock={}
 p.stock_max={}
 for cd in all(cargo_defs) do
  local max_s=0
  local produces_this=false
  if p.produces then
   for g in all(p.produces) do
    if g==cd.id then produces_this=true break end
   end
  end
  if cd.id=="contraband" then
   if port_has(p,"smugglers") then
    max_s=produces_this and (4+prosp) or (1+flr(prosp/2))
   end
  elseif cd.id=="treasure" then
   max_s=produces_this and (2+flr(prosp/2)) or 0
  else
   if port_has(p,"market") then
    max_s=produces_this and (8+prosp*2) or (2+prosp)
   elseif port_has(p,"smugglers") and cd.id=="arms" then
    max_s=2+flr(prosp/2)
   end
  end
  if max_s>0 then
   p.stock[cd.id]=max_s
   p.stock_max[cd.id]=max_s
  end
 end
 p.last_stock_day=1
end

-- refresh stock based on days since last visit (called on port entry)
-- market drift: each port's two demanded goods rotate on its own
-- 15-30 day cycle. produces stays fixed so port identity (pirate
-- cove, arms foundry, etc) doesn't dissolve. invariant: always
-- exactly 1 produces + 2 demands = 3 "special" priced goods.
function market_shift_port(p)
 if not p.demands then return end
 local avail={}
 for cd in all(cargo_defs) do
  local skip=false
  if p.produces then
   for g in all(p.produces) do
    if g==cd.id then skip=true break end
   end
  end
  if not skip then add(avail,cd.id) end
 end
 local new_dem={}
 for i=1,2 do
  if #avail>0 then
   local ix=1+flr(rnd(#avail))
   add(new_dem,avail[ix])
   del(avail,avail[ix])
  end
 end
 p.demands=new_dem
 p.next_shift=(g.run.day or 1)+15+flr(rnd(16))
end

function update_market_shifts()
 if not g.run or not g.run.ports then return end
 for p in all(g.run.ports) do
  if not p.next_shift then p.next_shift=(g.run.day or 1)+15+flr(rnd(16)) end
  if (g.run.day or 1)>=p.next_shift then
   market_shift_port(p)
  end
 end
end

function refresh_port_stock(p)
 if not p.stock then return end
 local now=g.run.day or 1
 local days=max(0,now-(p.last_stock_day or now))
 if days<=0 then return end
 local prosp=p.prosperity or 2
 for id,mx in pairs(p.stock_max) do
  local cur=p.stock[id] or 0
  if cur<mx then
   -- produced goods restock faster; prosperity accelerates all goods
   local rate=.25+prosp*.05
   local produces_this=false
   if p.produces then
    for g in all(p.produces) do
     if g==id then produces_this=true break end
    end
   end
   if produces_this then rate*=2 end
   p.stock[id]=min(mx,cur+flr(days*rate))
  end
 end
 p.last_stock_day=now
end

function cur_act()
 return act_defs[g.run.act or 1]
end

-- npc ships on the world map
function npc_profile_pool(region)
 if region=="trade" then return {"merchant","merchant","merchant","escort","privateer"} end
 if region=="storm" then return {"merchant","escort","privateer","privateer","hunter"} end
 if region=="frontier" then return {"merchant","raider","raider","privateer","hunter"} end
 return {"merchant","escort","privateer"}
end

-- pick a port linked to `from`, optionally avoiding `exclude`
function pick_linked_port(from,exclude)
 local p=g.run.ports[from]
 if not p or not p.links or #p.links==0 then return from end
 local opts={}
 for li in all(p.links) do
  if li~=exclude and li~=from then add(opts,li) end
 end
 if #opts==0 then return p.links[1+flr(rnd(#p.links))] end
 return opts[1+flr(rnd(#opts))]
end

function spawn_npc_at(region,is_rival,rival_ref,profile)
 local np=#g.run.ports
 if np<2 then return end
 -- pick home, then destination from home's shipping lanes so the npc
 -- actually travels along a visible route
 local a=1+flr(rnd(np))
 local b=pick_linked_port(a)
 local prof=profile
 if not prof then
  local pool=npc_profile_pool(region)
  prof=pool[1+flr(rnd(#pool))]
 end
 local n={
  profile=prof,
  region=region,
  home=a,dest=b,
  t=rnd(1),
  rival=is_rival or false,
  rival_ref=rival_ref
 }
 add(g.run.npcs,n)
 update_npc_positions()
 return n
end

-- treasure finale beat 2: drop the galleon into the world once the
-- escort is down, or once the grace timer has elapsed. guarded mode
-- means the escort was never broken, so the galleon fights harder.
function maybe_spawn_treasure_galleon()
 if g.run.treasure_taken then return end
 if g.run.treasure_galleon_spawned then return end
 local tc=g.run.treasure_clue
 if not (tc and tc.act==g.run.act) then return end
 local grace=g.run.treasure_grace or 0
 if (not g.run.treasure_escort_down) and g.run.day<grace then return end
 local ad=act_defs[g.run.act]
 if not ad then return end
 local n=spawn_npc_at(ad.region,false,nil,"treasure")
 if n then
  n.treasure_prize=true
  if not g.run.treasure_escort_down then
   n.treasure_guarded=true
  end
 end
 g.run.treasure_galleon_spawned=true
 if g.run.goal=="treasure" then
  msg(g.run.treasure_escort_down and "galleon sighted" or "guarded galleon!",10)
 end
end

function spawn_act_npcs()
 g.run.npcs={}
 local ad=cur_act()
 -- act 1: guaranteed easy merchant target near the player's starting port
 -- so the first fight teaches interception cleanly
 if g.run.act==1 then
  local np=#g.run.ports
  if np>=2 then
   local home=g.run.loc or 1
   local dest=home
   for _=1,6 do
    dest=1+flr(rnd(np))
    if dest~=home then break end
   end
   local n={
    profile="merchant",region=ad.region,
    home=home,dest=dest,t=.12,
    rival=false,tutorial=true
   }
   add(g.run.npcs,n)
   update_npc_positions()
  end
 end
 -- 4 routine traffic ships
 for i=1,6 do spawn_npc_at(ad.region,false) end
 -- add the act rival as a visible target
 for r in all(g.run.rivals or {}) do
  if r.region==ad.region and not r.defeated then
   spawn_npc_at(ad.region,true,r,r.profile)
   break
  end
 end
 -- treasure finale: spawn the royal escort first. the galleon only
 -- appears once the escort is down, or once the grace timer elapses
 -- (in which case the galleon arrives "guarded" - a tougher fight).
 if g.run.treasure_clue and g.run.treasure_clue.act==g.run.act then
  if not g.run.treasure_escort_down then
   local e=spawn_npc_at(ad.region,false,nil,"hunter")
   if e then e.treasure_escort=true end
   g.run.treasure_grace=g.run.day+12
   if g.run.goal=="treasure" then
    msg("break escort first",10)
   end
  else
   maybe_spawn_treasure_galleon()
  end
  g.run.treasure_clue.spawned=true
 end
 spawn_weather()
end

function update_npc_positions()
 for n in all(g.run.npcs or {}) do
  local a=g.run.ports[n.home]
  local b=g.run.ports[n.dest]
  if a and b then
   n.x=a.x+(b.x-a.x)*n.t
   n.y=a.y+(b.y-a.y)*n.t
  end
 end
end

function tick_npcs(days)
 for n in all(g.run.npcs or {}) do
  n.t=n.t+days*.09
  if n.t>=1 then
   local prev=n.home
   n.home=n.dest
   -- next leg follows a shipping lane from the new home, preferring
   -- not to immediately double back
   n.dest=pick_linked_port(n.home,prev)
   n.t=0
  end
 end
 -- occasional respawn of defeated traffic (not rival)
 if #g.run.npcs<7 and rnd(1)<.5 then
  spawn_npc_at(cur_act().region,false)
 end
 -- heavy cargo attracts raiders, but cap the pool so routes don't clutter
 local load=cargo_load_pct()
 if load>.5 and rnd(1)<load*.35 and #g.run.npcs<8 then
  local raiders=0
  for n in all(g.run.npcs) do
   if n.profile=="raider" then raiders+=1 end
  end
  if raiders<3 then
   spawn_npc_at(cur_act().region,false,nil,"raider")
  end
 end
 update_npc_positions()
end

function npc_col(n)
 if n.treasure_prize then return 9 end
 if n.treasure_escort then return 12 end
 if n.bounty_target then return 9 end
 if n.rival then return 8 end
 if n.profile=="merchant" then return 10 end
 if n.profile=="raider" then return 8 end
 if n.profile=="hunter" then return 14 end
 if n.profile=="privateer" then return 12 end
 return 11
end

-- selection helpers
function sel_total()
 return #g.run.ports + #(g.run.npcs or {})
end
function sel_is_port()
 return g.world.sel<=#g.run.ports
end
function sel_npc()
 if sel_is_port() then return nil end
 return g.run.npcs[g.world.sel-#g.run.ports]
end
function sel_port()
 if sel_is_port() then return g.run.ports[g.world.sel] end
 return nil
end

function target_pos(ix)
 if ix<=#g.run.ports then
  local p=g.run.ports[ix]
  if p then return p.x,p.y end
  return 0,0
 end
 local n=g.run.npcs[ix-#g.run.ports]
 if n then return n.x,n.y end
 return 0,0
end

-- pick the nearest target in the given direction (0=L,1=R,2=U,3=D)
function nav_select(dir)
 local sx,sy=target_pos(g.world.sel)
 local best=nil
 local bestd=99999
 local tot=sel_total()
 for i=1,tot do
  if i~=g.world.sel then
   local tx,ty=target_pos(i)
   local dx=tx-sx
   local dy=ty-sy
   local valid=false
   if dir==0 then
    valid=(dx < -1)
   elseif dir==1 then
    valid=(dx > 1)
   elseif dir==2 then
    valid=(dy < -1)
   elseif dir==3 then
    valid=(dy > 1)
   end
   if valid then
    local adx=abs(dx)
    local ady=abs(dy)
    local score
    if dir<=1 then
     score=adx+ady*2
    else
     score=ady+adx*2
    end
    if score<bestd then
     bestd=score
     best=i
    end
   end
  end
 end
 if best then g.world.sel=best end
end

-- src/05_data_officers.lua
-- officers

officer_defs={
 {
  id="old_gunner",name="old gunner",role="gunner",cost=55,
  desc="faster reload, +4 morale",
  mod={reload=.08,morale=4}
 },
 {
  id="cutthroat_bosun",name="cutthroat bosun",role="boatswain",cost=60,
  desc="+3 marines, boarding start",
  mod={marines=3,morale=1,board_start=1}
 },
 {
  id="sly_quartermaster",name="sly quartermaster",role="quartermaster",cost=50,
  desc="market: cheaper buy, better sell",
  mod={morale=2}
 },
 {
  id="storm_sailing_master",name="storm master",role="sailing",cost=65,
  desc="+8% speed, +10% turn",
  mod={speed=.08,turn=.10}
 },
 {
  id="scarred_marine",name="scarred marine",role="marine",cost=70,
  desc="+6 marines, +3 morale",
  mod={marines=6,morale=3}
 },
 {
  id="ship_surgeon",name="ship surgeon",role="surgeon",cost=60,
  desc="40% chance to save lost hands",
  mod={morale=3}
 },
 {
  id="port_spy",name="port spy",role="spy",cost=65,
  desc="contracts pay +20% and +1 renown",
  mod={}
 },
 {
  id="smuggler_priest",name="smuggler-priest",role="contact",cost=75,
  desc="half contraband heat, fence +5g/unit",
  mod={morale=2}
 }
}

-- src/06_data_events.lua
-- backgrounds, contracts, rumors, text snippets

background_defs={
 {
  id="dock_rat",name="dock rat",hull="cutter",
  gold=70,crew={hands=12,marines=2},
  bonus="cheap port services"
 },
 {
  id="pressed_sailor",name="pressed sailor",hull="sloop",
  gold=55,crew={hands=14,marines=2},
  bonus="morale recovery"
 },
 {
  id="disgraced_officer",name="disgraced officer",hull="brig",
  gold=40,crew={hands=16,marines=3},
  bonus="lawful contacts"
 },
 {
  id="smuggler_runner",name="smuggler runner",hull="cutter",
  gold=80,crew={hands=11,marines=1},
  bonus="contraband edge"
 },
 {
  id="corsair_orphan",name="corsair orphan",hull="sloop",
  gold=50,crew={hands=10,marines=4},
  bonus="boarding veteran"
 },
 {
  id="navy_deserter",name="navy deserter",hull="corvette",
  gold=25,crew={hands=18,marines=3},
  bonus="drilled, hot crown"
 },
 {
  id="fort_gunner",name="fort gunner",hull="sloop",
  gold=60,crew={hands=13,marines=1},
  bonus="keen eye at range"
 },
 {
  id="merchant_heir",name="merchant heir",hull="brig",
  gold=80,crew={hands=11,marines=1},
  bonus="silver purse"
 },
 {
  id="shipwright",name="shipwright",hull="brig",
  gold=45,crew={hands=13,marines=2},
  bonus="free fitting"
 },
 {
  id="navigator",name="navigator",hull="sloop",
  gold=60,crew={hands=12,marines=2},
  bonus="-1 day per leg"
 },
 {
  id="corsair_captain",name="corsair captain",hull="corvette",
  gold=25,crew={hands=14,marines=3},
  bonus="renown head start"
 }
}

-- `short` is used in the world HUD contract line where the full name
-- + longest port name (12) + deadline days would overflow x=4 budget.
-- name pool for bounty hunt targets — picked at contract issue
bounty_names={"black harlock","quinn the wolf","saber crowes","red maud","grim teague","silas vantsel","whip ivers","cain mott"}

contract_defs={
 {id="convoy_hunt",name="convoy hunt",short="convoy",pay=65,danger=2,
  desc="sink two traders",
  kind="battle",battle_target="merchant",days=12,target_count=2},
 {id="escort",name="escort",short="escort",pay=55,danger=2,
  desc="protect a route or merchant",
  kind="arrive",days=10},
 {id="smuggling_run",name="smuggling run",short="smuggle",pay=70,danger=2,
  desc="deliver contraband to target",
  kind="arrive",days=8},
 {id="blockade_break",name="blockade break",short="blockade",pay=75,danger=3,
  desc="run a hostile cordon",
  kind="arrive",days=10},
 {id="bounty_hunt",name="bounty hunt",short="bounty",pay=80,danger=3,
  desc="hunt the named captain",
  kind="battle",battle_target="hunter",days=14},
 {id="rescue",name="rescue",short="rescue",pay=60,danger=2,
  desc="extract prisoners or courier",
  kind="arrive",days=10}
}

rumor_pool={
 "a treasure ship was seen limping east",
 "the admiralty is paying for pirate colors",
 "storm lights were seen over the passage",
 "dagger cay is flush with stolen powder",
 "greyhaven wants escort captains",
 "a hunter frigate is asking about your name",
 "san castor is desperate for medicine",
 "a rival captain bought charts in ashdown"
}

sea_event_pool={
 "a false distress lantern drifts ahead",
 "wreckage lines the swells after last night's storm",
 "powder kegs bob in the surf",
 "crew whisper of mutiny aboard a nearby prize",
 "rain walls march over the passage"
}

-- src/07_gen_world.lua
-- run generation and content offers

function new_run(seed,bg,goal_id)
 srand(seed)
 bg=bg or background_defs[1+flr(rnd(#background_defs))]
 local run={}
 run.seed=seed
 run.day=1
 run.goal=goal_id or "crown"
 run.heat=0
 run.renown=1
 run.loc=1
 run.act=1
 run.last_battle=nil
 run.contract=nil
 run.rumor=rnd_item(rumor_pool)

 run.factions={}
 for f in all(factions) do
  run.factions[f.id]={rep=0,heat=0}
 end

 run.ports=load_act_ports(1)
 run.npcs={}

 run.rivals=seed_rivals()
 run.player=make_player_from_background(bg)
 -- summary stats: accumulate across the run
 run.stats={
  gold_earned=0,
  contracts_done=0,
  ports_visited={},
  biggest_prize=0,
  biggest_prize_name="",
  cause=nil
 }

 -- disgraced officer starts with lawful faction rep
 if bg.id=="disgraced_officer" then
  for fid,f in pairs(run.factions) do
   if fid~="pirates" then f.rep+=4 end
  end
 end

 -- navy deserter starts with heat (bounty on your head) and crown hostility
 if bg.id=="navy_deserter" then
  run.heat=4
  if run.factions["crown"] then
   run.factions["crown"].rep=-6
  end
 end

 -- shipwright starts with one random upgrade pre-fitted. pool is the
 -- cheaper/utility fittings so the head-start is broad, not min-maxed.
 if bg.id=="shipwright" then
  local pool={"carronades","copper_bottom","drilled_crews","fine_powder","shallow_keel","storm_sails","chase_guns"}
  add(run.player.upgrades,pool[1+flr(rnd(#pool))])
 end

 -- corsair captain: already famous (and wanted). trade early peace for
 -- a renown head start; hunters may show up sooner.
 if bg.id=="corsair_captain" then
  run.heat=2
  run.renown=3
 end

 -- treasure goal: auto-seed the clue for the final act so the galleon
 -- is guaranteed to appear in act 3. all wins are act-3-gated — the
 -- galleon is the climactic prize, not an opportunistic early target.
 if run.goal=="treasure" then
  run.treasure_clue={act=#act_defs}
 end

 g.run=run
 spawn_act_npcs()
 return run
end

function make_player_from_background(bg)
 local p={}
 p.name="captain"
 p.background=bg.id
 p.hull=bg.hull
 p.gold=bg.gold
 p.supplies=20
 p.cargo={}
 p.upgrades={}
 p.officers={}
 p.crew=deep_copy(bg.crew)
 -- specialty ammo stockpile (round is always available)
 p.ammo_stock=ammo_caps(p.hull)
 p.hp=ship_defs[p.hull].hull
 p.sail_hp=ship_defs[p.hull].sails
 p.morale=74
 p.perks={}
 p.captures=0
 p.faction_mark=nil
 return p
end

function has_rival_reward(id)
 local rr=g.run and g.run.player and g.run.player.rival_rewards
 return rr and rr[id] or false
end

function has_officer(id)
 local p=g.run and g.run.player
 if not p or not p.officers then return false end
 for oid in all(p.officers) do
  if oid==id then return true end
 end
 return false
end

-- write battle crew losses back to run state. hands take most hits,
-- marines a smaller share (proportional to starting mix) so specialists
-- don't get chewed up by every glancing blow.
function persist_battle_crew_losses()
 if not (g.btl and g.btl.player) then return end
 local pl=g.btl.player
 local start=pl.crew_start or pl.crew
 local lost=max(0,start-pl.crew)
 if lost<=0 then return end
 local p=g.run.player
 local c=p.crew
 local total=(c.hands or 0)+(c.marines or 0)
 if total<=0 then return end
 local take_h=flr(lost*(c.hands or 0)/total+.5)
 local take_m=max(0,lost-take_h)
 c.hands=max(0,(c.hands or 0)-take_h)
 c.marines=max(0,(c.marines or 0)-take_m)
end

-- apply crew loss with ship-surgeon save chance for the player
function crew_loss(ship,amount)
 if ship.team=="player" then
  local save_p=0
  if has_officer("ship_surgeon") then save_p+=.4 end
  if has_upgrade("surgeon") then save_p+=.25 end
  -- ship's surgeon perk: independent ~25% save roll stacking with gear
  if has_perk("ships_surgeon") then save_p+=.25 end
  if save_p>0 then
   local saved=0
   for i=1,amount do
    if rnd(1)<save_p then saved+=1 end
   end
   amount=max(0,amount-saved)
  end
 end
 ship.crew=max(0,ship.crew-amount)
end

-- prize crew required to sail a captured hull back to port
function prize_crew_cost(hull_id)
 local d=ship_defs[hull_id]
 if not d then return 6 end
 return max(4,flr(d.crew_cap*.25))
end

-- dockyard value of a captured hull (gold when sold at shipyard)
function prize_sale_value(hull_id,hp_frac,sail_frac)
 local d=ship_defs[hull_id]
 if not d then return 200 end
 local base=d.hull*4+d.broadside*15+d.sails*2
 if hp_frac and sail_frac then
  local cond=mid(.3,(hp_frac+sail_frac)*.5,1)
  base=flr(base*cond)
 end
 if has_upgrade("prize_charter") then base=flr(base*1.10) end
 return base
end

function grant_rival_reward(rival,p)
 p.rival_rewards=p.rival_rewards or {}
 local rid=rival.reward_id
 if not rid then return end
 p.rival_rewards[rid]=true
 if rid=="navy_charts" then
  -- free long guns fitting; skip if already owned (no stacked copies),
  -- or pay out a windfall if slots are full
  if not has_upgrade("long_guns") and #p.upgrades<4 then
   add(p.upgrades,"long_guns")
  else
   p.gold+=100
  end
 elseif rid=="signal_books" then
  g.run.renown+=2
  p.morale=min(99,p.morale+10)
 elseif rid=="elite_marines" then
  p.crew.marines=(p.crew.marines or 0)+4
  enforce_crew_cap(p)
 end
end

function seed_rivals()
 -- `short` is the display name in budget-constrained HUDs (battle label
 -- at x=88 has a 10-char budget; full names overflow). keep `name` for
 -- world map / log lines that have the room.
 local src={
  {name="seraf vane",short="vane",profile="raider",reward="navy charts",reward_id="navy_charts",region="trade"},
  {name="ysabel moura",short="moura",profile="privateer",reward="signal books",reward_id="signal_books",region="storm"},
  {name="red knife mercer",short="red knife",profile="hunter",reward="elite marines",reward_id="elite_marines",region="frontier"}
 }
 local rivals={}
 for i=1,#src do
  local r=deep_copy(src[i])
  r.heat=1+i
  r.defeated=false
  add(rivals,r)
 end
 return rivals
end

-- weighted pick: items is an array, weight_fn(item) returns a positive number.
-- items with weight 0 are skipped. falls back to uniform if all weights are 0.
function weighted_pick(items,weight_fn)
 local total=0
 local weights={}
 for i=1,#items do
  local w=weight_fn(items[i])
  if w<0 then w=0 end
  weights[i]=w
  total+=w
 end
 if total<=0 then return items[1+flr(rnd(#items))] end
 local r=rnd(total)
 local acc=0
 for i=1,#items do
  acc+=weights[i]
  if r<=acc then return items[i] end
 end
 return items[#items]
end

-- port_has_specialty defined later; forward uses ok in pico-8 (runtime lookup)

function random_port_upgrade(port)
 -- affinity by slot: what kind of outfitter is this port?
 local slot_bias={hull=1,rig=1,guns=1,crew=1,utility=1}
 if port then
  if port_has(port,"shipyard") then slot_bias.hull+=2 slot_bias.rig+=2 end
  if port_has_specialty(port,"guns") then slot_bias.guns+=3 end
  if port_has_specialty(port,"repairs") then slot_bias.hull+=2 slot_bias.rig+=1 end
  if port_has_specialty(port,"rigging") or port_has_specialty(port,"storms") then slot_bias.rig+=2 end
  if port_has_specialty(port,"boarding") then slot_bias.crew+=2 end
  if port_has(port,"smugglers") or port_has_specialty(port,"smuggling")
     or port_has_specialty(port,"contraband") then slot_bias.utility+=3 end
  if port.owner=="pirates" then slot_bias.utility+=1 slot_bias.crew+=1 end
  if port.owner=="crown" or port.owner=="empire" then slot_bias.guns+=1 slot_bias.hull+=1 end
 end
 local candidates={}
 for u in all(upgrade_defs) do
  if not has_upgrade(u.id) then add(candidates,u) end
 end
 if #candidates==0 then
  for u in all(upgrade_defs) do add(candidates,u) end
 end
 local pick=weighted_pick(candidates,function(u) return slot_bias[u.slot] or 1 end)
 return pick.id
end

function random_port_officer(port)
 local role_bias={
  gunner=1,boatswain=1,quartermaster=1,sailing=1,
  marine=1,surgeon=1,spy=1,contact=1
 }
 if port then
  if port_has(port,"admiralty") then role_bias.spy+=3 role_bias.gunner+=1 end
  if port_has(port,"shipyard") or port_has_specialty(port,"guns") then role_bias.gunner+=2 end
  if port_has(port,"market") or port_has_specialty(port,"rumors") then role_bias.quartermaster+=2 end
  if port_has(port,"smugglers") or port_has_specialty(port,"smuggling")
     or port_has_specialty(port,"contraband") then role_bias.contact+=3 role_bias.quartermaster+=1 end
  if port_has_specialty(port,"boarding") or port_has_specialty(port,"privateer") then
   role_bias.boatswain+=2 role_bias.marine+=2
  end
  if port_has_specialty(port,"rigging") or port_has_specialty(port,"storms") then role_bias.sailing+=3 end
  if port_has_specialty(port,"repairs") then role_bias.surgeon+=2 end
  if port.owner=="pirates" then
   role_bias.boatswain+=1 role_bias.marine+=1 role_bias.contact+=1
   role_bias.spy=max(0,role_bias.spy-1)
  end
  if port.owner=="crown" or port.owner=="empire" then
   role_bias.spy+=1 role_bias.gunner+=1
   role_bias.contact=max(0,role_bias.contact-1)
  end
 end
 local candidates={}
 for o in all(officer_defs) do
  if not has_officer(o.id) then add(candidates,o) end
 end
 if #candidates==0 then
  for o in all(officer_defs) do add(candidates,o) end
 end
 local pick=weighted_pick(candidates,function(o) return role_bias[o.role] or 1 end)
 return pick.id
end

function random_port_contract(port)
 local id_bias={
  convoy_hunt=1,escort=1,smuggling_run=1,
  blockade_break=1,bounty_hunt=1,rescue=1
 }
 if port then
  if port_has(port,"admiralty") then
   id_bias.bounty_hunt+=3 id_bias.escort+=2 id_bias.blockade_break+=2
   id_bias.smuggling_run=max(0,id_bias.smuggling_run-1)
  end
  if port_has(port,"market") or port_has_specialty(port,"cargo")
     or port_has_specialty(port,"escort") then id_bias.escort+=2 id_bias.convoy_hunt+=1 end
  if port_has(port,"smugglers") or port_has_specialty(port,"smuggling")
     or port_has_specialty(port,"contraband") then
   id_bias.smuggling_run+=4 id_bias.convoy_hunt+=1
   id_bias.bounty_hunt=max(0,id_bias.bounty_hunt-1)
  end
  if port_has_specialty(port,"bounties") then id_bias.bounty_hunt+=3 end
  if port_has_specialty(port,"convoys") or port_has_specialty(port,"privateer") then
   id_bias.convoy_hunt+=2
  end
  if port_has_specialty(port,"rumors") then id_bias.rescue+=2 end
  if port.owner=="pirates" then
   id_bias.smuggling_run+=2 id_bias.convoy_hunt+=1
   id_bias.escort=max(0,id_bias.escort-1)
   id_bias.bounty_hunt=max(0,id_bias.bounty_hunt-1)
  end
  if port.owner=="crown" or port.owner=="empire" then
   id_bias.escort+=1 id_bias.bounty_hunt+=1 id_bias.blockade_break+=1
   id_bias.smuggling_run=max(0,id_bias.smuggling_run-2)
  end
 end
 local pick=weighted_pick(contract_defs,function(c) return id_bias[c.id] or 1 end)
 return pick.id
end

function refresh_port_offers(port)
 port.offer_upgrade=random_port_upgrade(port)
 port.offer_officer=random_port_officer(port)
 port.offer_contract=random_port_contract(port)
 port.rumor=rnd_item(rumor_pool)
end

function travel_days(a,b)
 local d=dist(a.x,a.y,b.x,b.y)
 local days=max(1,flr(d/18))
 -- dead_reckoning perk and navigator background both trim a day off
 -- each leg; they don't stack beyond a -1 (floor is still 1 day).
 if has_perk("dead_reckoning") or has_background("navigator") then
  days=max(1,days-1)
 end
 return days
end

-- true if from port has a direct shipping link to target
function ports_linked(from_ix,to_ix)
 local p=g.run.ports[from_ix]
 if not p or not p.links then return false end
 for li in all(p.links) do
  if li==to_ix then return true end
 end
 return false
end

function region_danger(region)
 if region=="storm" then return .42 end
 if region=="frontier" then return .50 end
 if region=="trade" then return .38 end
 -- unknown region: fall back to current act's danger
 if g.run and g.run.act then return act_defs[g.run.act].danger end
 return .30
end

function roll_travel_encounter(from_p,to_p)
 local c=region_danger(to_p.region)
 -- early-game softening: first 3 days of act 1, the sea is calmer.
 -- region danger contribution is halved so encounters trigger less often.
 if g.run.act==1 and g.run.day<=3 then c*=.5 end
 c+=g.run.heat*.01
 -- full hold of valuables makes you raider bait
 local cv=cargo_gold_value()
 if cv>0 then c+=min(.20,cv/600) end
 -- contraband specifically attracts hunters
 local cband=(g.run.player.cargo and g.run.player.cargo.contraband) or 0
 if cband>0 then c+=min(.12,cband*.015) end
 -- guarantee combat on the very first travel (act 1, day 1)
 local force=(g.run.day<=1 and g.run.act==1 and not g.run.had_first_battle)
 if not force and rnd(1)>c then return nil end

 -- check for rival encounter first (skip if an undefeated act rival NPC
 -- already lives on the map - that forces intercept, not random pops)
 local has_act_rival_npc=false
 if g.run.npcs and act_defs[g.run.act] then
  local areg=act_defs[g.run.act].region
  for n in all(g.run.npcs) do
   if n.rival and not n.defeated and (n.region==areg or to_p.region==areg) then
    has_act_rival_npc=true break
   end
  end
 end
 if not has_act_rival_npc then
  local rival_enc=check_rival_encounter(to_p.region)
  if rival_enc then return rival_enc end
 end

 -- hunter spawns scale with heat (starts lower, scales softer)
 if g.run.heat>=2 then
  local hunt_chance=.08+(g.run.heat*.02)
  if rnd(1)<hunt_chance then
   local h={kind="hunter",profile="hunter",region=to_p.region,
    heat_buff=min(5,flr(g.run.heat/3))}
   if to_p.region=="storm" then h.kind="storm" end
   return h
  end
 end

 local prof="merchant"
 local act=g.run.act or 1
 if to_p.owner=="pirates" then
  prof=rnd(1)<.55 and "raider" or "merchant"
 elseif to_p.region=="frontier" then
  local roll=rnd(1)
  if roll<.45 then prof="raider"
  elseif roll<.80 then prof="privateer"
  else prof="merchant" end
 elseif act==1 then
  -- act 1: mostly merchants, easier first fights.
  -- privateer grace period: first 5 days, privateer rolls become escorts
  -- so a starting hull doesn't run face-first into a corvette.
  local roll=rnd(1)
  if roll<.72 then prof="merchant"
  elseif roll<.92 then prof="escort"
  else prof=(g.run.day<=5) and "escort" or "privateer" end
 else
  local roll=rnd(1)
  if roll<.45 then
   prof="merchant"
  elseif roll<.75 then
   prof="escort"
  else
   prof="privateer"
  end
 end

 local kind=(to_p.region=="storm") and "storm" or "sea"
 return {kind=kind,profile=prof,region=to_p.region}
end

-- rival encounter check
function check_rival_encounter(region)
 if not g.run.rivals then return nil end
 for r in all(g.run.rivals) do
  if not r.defeated and r.region==region then
   -- chance scales with rival heat and run heat
   local chance=.08+(r.heat*.03)+(g.run.heat*.01)
   if rnd(1)<chance then
    r.heat=min(10,r.heat+1)
    return {
     kind="rival",
     profile=r.profile,
     region=region,
     rival=r
    }
   end
  end
 end
 return nil
end

function maybe_gain_perk()
 if g.run.perk_pick then return end
 if #g.run.player.perks<4 and g.run.renown>=3*(#g.run.player.perks+1) then
  -- offer pick-1-of-3 from perks the player has unlocked and doesn't
  -- already hold
  local avail={}
  for i=1,#perk_defs do
   local p=perk_defs[i]
   if perk_unlocked(i) and not has_perk(p.id) then add(avail,p.id) end
  end
  if #avail==0 then return end
  local opts={}
  for i=1,min(3,#avail) do
   local ix=1+flr(rnd(#avail))
   add(opts,avail[ix])
   del(avail,avail[ix])
  end
  g.run.perk_pick={opts=opts,sel=1}
 end
end

function perk_pick_update()
 local pp=g.run.perk_pick
 if btnp(2) then pp.sel=cycle_idx(pp.sel,#pp.opts,-1) end
 if btnp(3) then pp.sel=cycle_idx(pp.sel,#pp.opts,1) end
 if btnp(5) or btnp(4) then
  local pick=pp.opts[pp.sel]
  add(g.run.player.perks,pick)
  msg("doctrine: "..perk_name(pick),11)
  g.run.perk_pick=nil
 end
end

function perk_pick_draw()
 local pp=g.run.perk_pick
 panel(10,30,107,68,0,7)
 shadow("choose your doctrine",18,34,10,1)
 print("a lesson from the deep",18,42,6)
 for i=1,#pp.opts do
  local pid=pp.opts[i]
  local pdef
  for p in all(perk_defs) do
   if p.id==pid then pdef=p end
  end
  local yy=52+(i-1)*14
  local col=6
  if i==pp.sel then
   col=10
   rectfill(12,yy-1,115,yy+11,1)
   print("\139",13,yy+2,col)
  end
  print(pdef.name,22,yy,col)
  print(pdef.desc,22,yy+6,5)
 end
end

-- contract completion
function check_contract_arrive(port_ix)
 local c=g.run.contract
 if not c or c.done then return end
 -- timeout check
 if g.run.day>c.deadline then
  fail_contract()
  return
 end
 -- arrive-type contracts complete on reaching target
 if c.kind=="arrive" and port_ix==c.target then
  -- smuggle: must arrive carrying contraband; one unit is consumed
  if c.id=="smuggling_run" then
   local cargo=g.run.player.cargo
   local cband=(cargo and cargo.contraband) or 0
   if cband<=0 then
    msg("smuggle: no contraband",8)
    return
   end
   cargo.contraband=cband-1
   if cargo.contraband<=0 then cargo.contraband=nil end
  end
  complete_contract()
 end
end

function check_contract_battle(enemy_profile)
 local c=g.run.contract
 if not c or c.done then return end
 if g.run.day>c.deadline then
  fail_contract()
  return
 end
 -- battle-type contracts complete on defeating right enemy type
 if c.kind=="battle" and enemy_profile==c.battle_target then
  -- bounty: only the named NPC counts; any other hunter is just XP
  if c.id=="bounty_hunt" then
   local npc=g.btl and g.btl.enc and g.btl.enc.npc
   if npc and npc.bounty_target then complete_contract() end
   return
  end
  -- convoy: needs target_count kills to finish
  if c.target_count and c.target_count>1 then
   c.progress=(c.progress or 0)+1
   if c.progress>=c.target_count then
    complete_contract()
   else
    msg("convoy "..c.progress.."/"..c.target_count,11)
   end
   return
  end
  complete_contract()
 end
end

function complete_contract()
 local c=g.run.contract
 if not c then return end
 local pay=c.pay or 50
 -- port spy fences contract intel: better paperwork, better payout
 if has_officer("port_spy") then
  pay=flr(pay*1.2)
  g.run.renown+=1
 end
 g.run.player.gold+=pay
 g.run.renown+=1
 c.done=true
 if g.run.stats then
  g.run.stats.contracts_done+=1
  g.run.stats.gold_earned+=pay
 end
 maybe_gain_perk()
 msg("contract done! +"..pay.."g",10)
 g.run.contract=nil
end

function fail_contract()
 local c=g.run.contract
 if not c then return end
 g.run.player.morale=max(20,g.run.player.morale-5)
 g.run.renown=max(0,g.run.renown-1)
 msg("contract expired!",8)
 g.run.contract=nil
end

-- src/08_game.lua
-- global runtime and dispatch

g={}

function _init()
 load_meta()
 boot_title()
end

function boot_title()
 g.state=states.title
 g.notice=""
 g.notice_t=0
 g.notice_col=7
 g.fx={}
 g.music_cur=nil
 route_music(states.title)
 title_init()
end

function start_new_run(seed,bg,rich,goal_id)
 g.run=new_run(seed,bg,goal_id)
 g.fx={}
 if rich then apply_rich_start() end
 g.state=states.world
 route_music(states.world)
 world_init()
 msg(rich and "rich start!" or ("new run seeded "..seed),11)
end

-- alternate start: extra gold, a bigger hull, a few upgrades, full stockpile
-- per-background rich-start loadouts: each background gets a thematic
-- ship-up + upgrade kit. corsair_captain commands a galleon (flagship
-- fantasy). default falls back to corvette + balanced gear.
rich_loadouts={
 dock_rat        ={hull="sloop",   ups={"smuggler_holds","copper_bottom","drilled_crews"}},
 pressed_sailor  ={hull="brig",    ups={"drilled_crews","marines","spare_spars"}},
 disgraced_officer={hull="corvette",ups={"long_guns","fine_powder","drilled_crews","reinforced_ribs"}},
 smuggler_runner ={hull="sloop",   ups={"smuggler_holds","copper_bottom","fine_rudder","false_colors"}},
 corsair_orphan  ={hull="brig",    ups={"marines","grapnels","carronades","drilled_crews"}},
 navy_deserter   ={hull="frigate", ups={"long_guns","fine_powder","drilled_crews","marines"}},
 fort_gunner     ={hull="brig",    ups={"long_guns","fine_powder","chase_guns","drilled_crews"}},
 merchant_heir   ={hull="corvette",ups={"smuggler_holds","copper_bottom","prize_charter","drilled_crews"}},
 shipwright      ={hull="corvette",ups={"carpenter","reinforced_ribs","spare_spars","copper_bottom"}},
 navigator       ={hull="brig",    ups={"copper_bottom","storm_sails","fine_rudder","nimble_rigging"}},
 corsair_captain ={hull="galleon", ups={"carronades","marines","drilled_crews","reinforced_ribs"}}
}

function apply_rich_start()
 local p=g.run.player
 local lo=rich_loadouts[p.background] or {hull="corvette",ups={"copper_bottom","long_guns","fine_powder","drilled_crews"}}
 p.hull=lo.hull
 p.hp=ship_defs[p.hull].hull
 p.sail_hp=ship_defs[p.hull].sails
 p.gold=350
 p.supplies=30
 p.morale=85
 p.upgrades={}
 for u in all(lo.ups) do
  add(p.upgrades,u)
 end
 p.ammo_stock=ammo_caps(p.hull)
 p.crew.marines=(p.crew.marines or 0)+2
end

test_presets={
 {name="brig (starter)",hull="brig",ups={},enemy="privateer",
  desc="balanced. 6 guns, decent armor."},
 {name="sloop (fast raider)",hull="sloop",ups={"copper_bottom","carronades"},enemy="raider",
  desc="fast + agile. short range guns."},
 {name="corvette (gunship)",hull="corvette",ups={"long_guns","fine_powder"},enemy="hunter",
  desc="long range + firepower. vs hunter."},
 {name="frigate (warship)",hull="frigate",ups={"reinforced_ribs","copper_bottom","marines","drilled_crews"},enemy="escort",
  desc="armored, fast for its size. vs escort."}
}

function start_test_battle()
 g.title.phase="test_select"
 g.title.test_sel=1
end

function launch_test_battle(preset)
 g.run=new_run(flr(rnd(99999)))
 g.fx={}
 g.run.player.hull=preset.hull
 g.run.player.hp=ship_defs[preset.hull].hull
 g.run.player.sail_hp=ship_defs[preset.hull].sails
 g.run.player.gold=200
 g.run.player.morale=80
 g.run.player.upgrades={}
 for u in all(preset.ups) do add(g.run.player.upgrades,u) end
 set_state(states.battle,{profile=preset.enemy,region="trade"})
end

-- music controller: map state+context -> pattern/mask.
-- patterns: 0 title, 3 harbour, 7 caribbean, 11 pirate, 15 event, 17 battle, 23 boarding, 25 prize
-- ch3 reserved for gameplay sfx during battle/boarding (mask=7); other states use mask 15.
-- unauthored patterns return nil so the router stays silent until a cue exists.
-- patterns that actually contain music. router stays silent otherwise.
authored_music={[0]=true,[3]=true,[7]=true,[11]=true,[15]=true,
 [17]=true,[19]=true,[21]=true,[23]=true,[25]=true,[26]=true,[34]=true,[36]=true}
-- battle A/B/C cycle: controller swaps at phrase boundary when stress changes.
battle_music_cycle={[17]=19,[19]=17}  -- normal: A <-> B
battle_stress_cycle={[36]=36}          -- stress: syncopated alt battle loops
function ship_stress(ship)
 if not ship then return 0 end
 local h=ship.hp/max(1,ship.hp_max)
 local m=(ship.morale or 80)/100
 return min(h,m)
end
function want_battle_pattern(cur)
 local b=g.btl
 if not b then return 17 end
 local s=ship_stress(b.player)
 if s<.5 then return 36 end
 -- normal: alternate A(17) and B(19) every ~16 seconds
 b.mus_t=(b.mus_t or 0)+1
 if cur==36 then b.mus_t=0 return 17 end   -- exiting stress, restart A
 if b.mus_t>=960 then               -- ~16s at 60fps
  b.mus_t=0
  return (cur==17) and 19 or 17
 end
 return cur or 17
end
function update_battle_music()
 -- only touch music while in battle state
 if g.state~=states.battle then return end
 local cur=g.music_cur
 local want=want_battle_pattern(cur)
 if want==cur then return end
 -- swap at phrase boundary: only when current pattern is about to end,
 -- or immediately if we're entering stress from normal (ok to cut mid-phrase per GPT Pro).
 local at_end=(stat(54)<0) or (stat(56) and stat(56)>=28)
 local to_stress=(want==36 and cur~=36)
 if at_end or to_stress then
  music(want,0,7)
  g.music_cur=want
 end
end
function port_music_pat(port)
 if not port then return 3 end
 local o,sv=port.owner,port.services or {}
 local has=function(k) for s in all(sv) do if s==k then return true end end return false end
 if o=="pirates" or has("smugglers") then return 11 end
 if has("shipyard") or has("admiralty") then return 3 end
 return 7
end
function music_for_state(id,arg)
 if id==states.title then return 0,15 end
 if id==states.world then return 26,15 end
 if id==states.port then
  local p=g.run and g.run.ports and g.run.ports[g.run.loc]
  return port_music_pat(p),15
 end
 if id==states.event then return 15,15 end
 if id==states.battle then return 17,7 end
 if id==states.boarding then return 23,7 end
 if id==states.prize then return 25,15 end
 if id==states.summary then return 34,15 end
 return nil,15
end
function route_music(id,arg)
 local pat,mask=music_for_state(id,arg)
 if pat and authored_music[pat] then
  if g.music_cur~=pat then
   music(pat,0,mask)
   g.music_cur=pat
  end
 else
  if g.music_cur~=nil then
   music(-1)
   g.music_cur=nil
  end
 end
end

function set_state(id,arg)
 g.state=id
 route_music(id,arg)
 if id==states.title then
  title_init(arg)
 elseif id==states.world then
  world_init(arg)
 elseif id==states.port then
  port_init(arg)
 elseif id==states.battle then
  battle_init(arg)
 elseif id==states.boarding then
  boarding_init(arg)
 elseif id==states.prize then
  prize_init(arg)
 elseif id==states.event then
  event_init(arg)
 elseif id==states.summary then
  summary_init(arg)
 end
end

function resolve_battle_to_run(outcome)
 local p=g.run.player
 if not g.btl then return end

 -- capture from boarding still goes through prize screen
 if outcome=="capture" then
  enter_prize_screen("capture")
  return
 end

 -- auto-repair the repairable pool; permanent damage sticks until port
 local final_hp=g.btl.player.hp_perm or g.btl.player.hp
 p.hp=clamp(flr(final_hp),0,run_hp_max(p))
 p.sail_hp=clamp(flr(g.btl.player.sail_hp),0,run_sail_max(p))
 p.morale=clamp(flr(g.btl.player.morale),20,99)
 persist_battle_crew_losses()

 if outcome=="escape" then
  g.run.heat+=1
  msg("escaped the fight",12)
 elseif outcome=="enemy_escaped" then
  -- target got away; remove them from the map anyway
  if g.btl and g.btl.enc and g.btl.enc.npc then
   del(g.run.npcs,g.btl.enc.npc)
  end
 elseif outcome=="defeat" then
  if g.run.stats and g.btl and g.btl.enemy then
   g.run.stats.cause=g.btl.enemy.label or g.btl.enemy.profile or "the sea"
  end
  set_state(states.summary,{outcome="defeat"})
  return
 end

 if p.gold>g.meta.best_gold then g.meta.best_gold=p.gold end
 if g.run.renown>g.meta.best_renown then g.meta.best_renown=g.run.renown end
 save_meta()

 if g.pending_dest then
  g.run.loc=g.pending_dest
  g.pending_dest=nil
  if g.run.stats then g.run.stats.ports_visited["a"..g.run.act.."_"..g.run.loc]=true end
  check_contract_arrive(g.run.loc)
 end

 set_state(states.world)
end

function start_battle(enc)
 set_state(states.battle,enc)
end

-- carry button-press edges across skipped pacer ticks (see _update60).
-- intercept btnp(i): if this index was pressed during a skipped tick,
-- report it true now and clear the bit so it only fires once.
_native_btnp=btnp
function btnp(i,p)
 if i and g.pace then
  local m=1<<i
  if band(g.pace.carry or 0,m)~=0 then
   g.pace.carry=bxor(g.pace.carry,m)
   return true
  end
 end
 if i==nil then return _native_btnp() end
 return _native_btnp(i,p)
end

function _update60()
 -- 30fps self-pacer: some fake-08 builds tick _update60 at 60hz and some
 -- at 30hz. sample wall-clock seconds (stat 95) to count ticks/sec. once
 -- we see >40 in a second we know the host is fast, so skip every other
 -- call to keep game logic at ~30hz on all platforms.
 g.pace=g.pace or {sec=-1,cnt=0,skip=false,tog=false,carry=0}
 local s=stat(95) or 0
 if s~=g.pace.sec then
  g.pace.sec=s
  g.pace.skip=g.pace.cnt>40
  g.pace.cnt=0
 end
 g.pace.cnt+=1
 if g.pace.skip then
  g.pace.tog=not g.pace.tog
  if not g.pace.tog then
   -- on skipped ticks, capture any button-press edges so the next
   -- non-skipped tick can still see them via our btnp() wrapper.
   for i=0,5 do
    if _native_btnp(i) then
     g.pace.carry=bor(g.pace.carry,1<<i)
    end
   end
   return
  end
 end

 update_fx()
 if g.notice_t>0 then
  g.notice_t-=1
 end

 -- hard gold cap so the top bar never has to render 4+ digits
 if g.run and g.run.player and g.run.player.gold>999 then
  g.run.player.gold=999
 end

 -- doctrine pick overlay blocks all other input
 if g.run and g.run.perk_pick then
  perk_pick_update()
  return
 end

 if g.state==states.title then
  title_update()
 elseif g.state==states.world then
  world_update()
 elseif g.state==states.port then
  port_update()
 elseif g.state==states.battle then
  battle_update()
 elseif g.state==states.boarding then
  boarding_update()
 elseif g.state==states.prize then
  prize_update()
 elseif g.state==states.event then
  event_update()
 elseif g.state==states.summary then
  summary_update()
 end
end

function _draw()
 cls(ui_cols.bg)

 if g.state==states.title then
  title_draw()
 elseif g.state==states.world then
  world_draw()
 elseif g.state==states.port then
  port_draw()
 elseif g.state==states.battle then
  battle_draw()
 elseif g.state==states.boarding then
  boarding_draw()
 elseif g.state==states.prize then
  prize_draw()
 elseif g.state==states.event then
  event_draw()
 elseif g.state==states.summary then
  summary_draw()
 end

 -- fx drawn inside battle_draw with camera; others draw here
 if g.state~=states.battle then
  draw_fx()
 end

 if g.notice_t>0 then
  if g.state==states.battle then
   shadow(g.notice,32,20,g.notice_col,1)
  else
   panel(8,118,111,8,0,5)
   shadow(g.notice,12,120,g.notice_col,1)
  end
 end

 if g.run and g.run.perk_pick then
  perk_pick_draw()
 end
end

-- src/09_state_title.lua
-- title state

function title_init()
 g.title={}
 g.title.seed=flr(rnd(99999))
 g.title.sel=1
 g.title.last_sel=1
 g.title.phase="menu"
 g.title.bg_sel=1
 g.title.menu={
  "set sail",
  "rich start",
  "unlock perks",
  "seed",
  "next goal",
  "fx"
 }
 -- starfield (more stars, three brightness tiers)
 g.title.stars={}
 local n_stars=lowfx() and 24 or 48
 for i=1,n_stars do
  add(g.title.stars,{
   x=flr(rnd(128)),
   y=flr(rnd(48)),
   b=rnd(1)
  })
 end
 -- title swells: mostly-vertical rollers coming in toward the viewer.
 -- each swell stores a position and a slight angle off straight-down.
 g.title.swells={}
 local n_tsw=lowfx() and 3 or 6
 for i=1,n_tsw do
  add(g.title.swells,{
   x=rnd(128),
   y=58+rnd(66),
   vy=.12+rnd(.14),
   vx=(rnd(1)<.5 and -1 or 1)*(.02+rnd(.04)),
   len=18+flr(rnd(22)),
   thick=3+flr(rnd(3)),
   seed=rnd(99)
  })
 end
 g.title.foam={}
 local n_foam=lowfx() and 18 or 36
 for i=1,n_foam do
  add(g.title.foam,{
   x=flr(rnd(128)),
   y=58+flr(rnd(68)),
   vy=.15+rnd(.2),
   vx=(rnd(1)<.5 and -1 or 1)*(.02+rnd(.03)),
   col=rnd(1)<.25 and 6 or 13
  })
 end
 g.title.parrot=nil
end

function title_update()
 update_title_parrot()
 if g.title.phase=="menu" then
  title_update_menu()
 elseif g.title.phase=="background" then
  title_update_bg()
 elseif g.title.phase=="perks" then
  title_update_perks()
 elseif g.title.phase=="test_select" then
  if btnp(2) then g.title.test_sel=cycle_idx(g.title.test_sel,#test_presets,-1) end
  if btnp(3) then g.title.test_sel=cycle_idx(g.title.test_sel,#test_presets,1) end
  if btnp(5) then launch_test_battle(test_presets[g.title.test_sel]) end
  if btnp(4) then g.title.phase="menu" end
 end
end

function title_update_menu()
 local sel_changed=false
 if btnp(2) then
  g.title.sel=cycle_idx(g.title.sel,#g.title.menu,-1)
  sel_changed=true
 end
 if btnp(3) then
  g.title.sel=cycle_idx(g.title.sel,#g.title.menu,1)
  sel_changed=true
 end
 if sel_changed then
  sfx(sfx_ids.menu,3)
 end

 if btnp(5) then
  if g.title.sel==1 then
   g.title.phase="background"
   g.title.rich=false
   sfx(sfx_ids.menu,3)
  elseif g.title.sel==2 then
   -- rich start is a one-time meta unlock. while locked, pressing X
   -- spends tokens to unlock it; on the next press the run begins.
   if g.meta.rich_unlocked then
    g.title.phase="background"
    g.title.rich=true
    sfx(sfx_ids.menu,3)
   else
    local cost=rich_start_cost()
    if (g.meta.tokens or 0)>=cost then
     g.meta.tokens-=cost
     g.meta.rich_unlocked=true
     save_meta()
     msg("rich start unlocked!",11)
    else
     msg("need "..cost.." \135",8)
    end
   end
  elseif g.title.sel==3 then
   g.title.phase="perks"
   g.title.perk_sel=1
   sfx(sfx_ids.menu,3)
  elseif g.title.sel==4 then
   -- reroll seed inline — parrot ruffles its feathers
   g.title.seed=flr(rnd(99999))
   title_parrot_ruffle()
   sfx(sfx_ids.clash,3)
  elseif g.title.sel==5 then
   g.title.goal_ix=cycle_idx(g.title.goal_ix or 1,#goal_defs,1)
   title_parrot_flap()
   sfx(sfx_ids.menu,3)
  elseif g.title.sel==6 then
   g.opts.lowfx=not g.opts.lowfx
   save_meta()
   sfx(sfx_ids.menu,3)
  end
 end
end

function title_update_perks()
 if btnp(2) then g.title.perk_sel=cycle_idx(g.title.perk_sel,#perk_defs,-1) end
 if btnp(3) then g.title.perk_sel=cycle_idx(g.title.perk_sel,#perk_defs,1) end
 if btnp(5) then
  if not perk_unlocked(g.title.perk_sel) then
   local cost=perk_unlock_cost(g.title.perk_sel)
   if (g.meta.tokens or 0)>=cost then
    g.meta.tokens-=cost
    unlock_perk(g.title.perk_sel)
    save_meta()
    msg("unlocked!",11)
   else
    msg("need "..cost.." \135",8)
   end
  end
 end
 if btnp(4) then
  g.title.phase="menu"
 end
end

function title_update_bg()
 if btnp(0) or btnp(2) then g.title.bg_sel=cycle_idx(g.title.bg_sel,#background_defs,-1) end
 if btnp(1) or btnp(3) then g.title.bg_sel=cycle_idx(g.title.bg_sel,#background_defs,1) end

 if btnp(5) then
  if bg_unlocked(g.title.bg_sel) then
   start_new_run(g.title.seed,background_defs[g.title.bg_sel],g.title.rich,goal_defs[g.title.goal_ix or 1].id)
  else
   local cost=bg_unlock_cost(g.title.bg_sel)
   if (g.meta.tokens or 0)>=cost then
    g.meta.tokens-=cost
    unlock_bg(g.title.bg_sel)
    save_meta()
    msg("unlocked!",11)
   else
    msg("need "..cost.." \135",8)
   end
  end
 end

 if btnp(4) then
  g.title.phase="menu"
 end
end

function title_draw()
 local tt=t()

 -- night sky
 rectfill(0,0,127,127,0)

 -- stars (twinkle)
 for s in all(g.title.stars) do
  local flicker=sin(tt*.3+s.b)
  if flicker>-.2 then
   local c=flicker>.65 and 7 or (flicker>.25 and 6 or 5)
   pset(s.x,s.y,c)
  end
 end

 -- large moon partially off-screen: feels bigger and more atmospheric
 -- than a tiny disc floating in the corner. dim halo + twinkling
 -- sparks give it a subtle glow without a hard ring.
 local mcx,mcy=128,6
 circ(mcx,mcy,12,1)
 circfill(mcx,mcy,9,7)
 -- fixed craters
 pset(mcx-5,mcy+1,6)
 pset(mcx-2,mcy+4,6)
 pset(mcx-7,mcy-1,6)
 -- drifting surface shimmer (stays on-screen)
 local shim_a=tt*.12
 pset(mcx-5+flr(cos(shim_a)*2),mcy+flr(sin(shim_a)*2),6)
 -- twinkling sparkles around the moon — they blink on/off at different
 -- phases so the moon appears to glimmer
 local sparks={
  {117,4,0},{120,14,.25},{124,13,.5},
  {115,10,.65},{116,1,.15},{126,12,.8}
 }
 for s in all(sparks) do
  local f=sin(tt*.8+s[3])
  if f>.5 then pset(s[1],s[2],f>.85 and 7 or 6) end
 end

 -- horizon haze band
 line(0,55,127,55,1)

 -- sea base
 rectfill(0,56,127,127,1)

 -- moonlight pillar: thin shimmer on the water directly below the moon
 for i=0,6 do
  local ry=58+i*4
  local rx=100+flr(sin(tt*.4+i*.25)*3)
  local c=i<2 and 7 or (i<4 and 6 or 13)
  line(rx-(4-min(3,i)),ry,rx+(4-min(3,i)),ry,c)
 end

 -- swells: rollers come in from horizon toward the viewer (mostly
 -- vertical with a slight angle). length + thickness scale with
 -- perspective so near waves look heavier than distant ones.
 for s in all(g.title.swells) do
  s.y+=s.vy
  s.x+=s.vx
  if s.y>128 then
   s.y=56+rnd(6)
   s.x=rnd(128)
  end
  if s.x<-s.len then s.x+=128+s.len*2 end
  if s.x>128+s.len then s.x-=128+s.len*2 end
  local persp=(s.y-56)/72
  local len=s.len*(.5+persp*.8)
  local thk=s.thick+flr(persp*2)
  -- angled crest: small rise/fall along x gives a tilted wave front
  for k=-len,len do
   local wx=s.x+k
   local wy=s.y+flr(k*.08+sin(k*.1+s.seed)*.9)
   if wx>=0 and wx<128 and wy>=56 and wy<128 then
    local edge=abs(k)/len
    if edge<.95 then
     local h=flr(k*31+s.y*11+s.seed*7)
     local dens=thk+flr(edge*edge*5)
     if h%dens<1 then
      pset(wx,wy,h%17<3 and 6 or 13)
     end
    end
   end
  end
 end

 -- foam flecks drift with the same direction as swells
 for d in all(g.title.foam) do
  d.y+=d.vy
  d.x+=d.vx
  if d.y>127 then d.y=57 d.x=rnd(128) end
  if d.x<0 then d.x+=128 end
  if d.x>=128 then d.x-=128 end
  if flr(d.x+d.y)%3~=0 then pset(d.x,d.y,d.col) end
 end

 -- foreground + distant land
 for x=0,34 do
  local h=sin(x*.02+.3)*4+2
  if h>0 then line(x,56,x,56-h,0) end
 end
 for x=108,127 do
  local h=sin((x-108)*.05+.8)*2+1
  if h>0 then line(x,57,x,57-h,1) end
 end

 -- single ship in the gap between panels
 local bob=sin(tt*.6)*.7
 local sx,sy=18,76+bob
 draw_ship_primitive(sx,sy,.08,5,7,6)
 draw_wake(sx,sy,.08,.4,13)
 local lant=sin(tt*2)>.3 and 10 or 9
 pset(sx-4,sy,lant)

 -- title at the top, with a faint brighter pulse row
 printc("rogue wake",5,0)
 printc("rogue wake",4,7)
 if sin(tt*.4)>.7 then printc("rogue wake",4,10) end

 -- tagline (kept clear of the moon to the right: moon lives at x>=118)
 local tag="captain's career roguelite"
 local tw=#tag*4
 shadow(tag,64-tw/2,14,6,1)

 if g.title.phase=="menu" then
  draw_title_menu()
 elseif g.title.phase=="background" then
  draw_title_bg()
 elseif g.title.phase=="perks" then
  draw_title_perks()
 elseif g.title.phase=="test_select" then
  draw_test_select()
 end

 -- meta stats: aligned with the upper panel edges (panel starts at x=8,
 -- ends at x=119) so the row reads as part of the same column.
 if g.title.phase=="menu" then
  if g.meta.runs>0 then
   shadow("runs:"..g.meta.runs.." best:"..g.meta.best_gold.."g",10,28,5,0)
  end
  shadow("\135"..(g.meta.tokens or 0),110,28,9,0)
 end
end

function draw_title_menu()
 -- upper panel: menu + parrot
 panel(8,36,111,52,0,5)
 -- rich start shows a token price tag while locked so the gate is
 -- obvious from the menu without entering the row.
 local rich_label="rich start"
 if not g.meta.rich_unlocked then
  rich_label="rich start ["..rich_start_cost().."\135]"
 end
 local labels={
  "set sail",
  rich_label,
  "unlock perks",
  "seed  "..g.title.seed,
  "next goal",
  "fx: "..(lowfx() and "low" or "full")
 }
 for i=1,#labels do
  local col=6
  local y=40+(i-1)*8
  if i==g.title.sel then
   col=10
   print("\139",12,y,10)
  end
  shadow(labels[i],20,y,col,1)
 end
 draw_title_parrot(100,57)

 -- lower panel: context-sensitive. seed and rich-start rows get their
 -- own blurb; every other row falls through to the chosen goal.
 panel(8,92,111,26,0,5)
 if g.title.sel==4 then
  shadow("seed",12,95,9,1)
  shadow("reshuffles shop offers,",12,104,7,1)
  shadow("encounters, and events",12,110,7,1)
 elseif g.title.sel==2 then
  shadow("rich start",12,95,9,1)
  if g.meta.rich_unlocked then
   shadow("hull + 350g + gear",12,104,7,1)
   shadow("unlocked",12,110,11,1)
  else
   shadow("hull + 350g + gear",12,104,7,1)
   shadow("unlock: "..rich_start_cost().."\135  have: "..(g.meta.tokens or 0).."\135",12,110,9,1)
  end
 elseif g.title.sel==6 then
  shadow("fx mode",12,95,9,1)
  if lowfx() then
   shadow("low: fewer waves + foam,",12,104,7,1)
   shadow("no wake. handheld safe.",12,110,6,1)
  else
   shadow("full: all sea fx on.",12,104,7,1)
   shadow("toggle if fps dips.",12,110,6,1)
  end
 else
  local gi=g.title.goal_ix or 1
  shadow("goal: "..goal_defs[gi].name,12,95,9,1)
  local glines=wrap_text(goal_defs[gi].desc,26)
  for i=1,min(#glines,2) do
   shadow(glines[i],12,104+(i-1)*6,7,1)
  end
 end
end

-- parrot mascot (v3 scarlet macaw): 18x26 single-frame sprite with
-- integrated wing coverts — yellow shoulder band + blue primaries
-- are the iconic macaw markers the earlier passes were missing.
-- animation is transform-based (bob, flap hop, ruffle shimmy) so
-- we don't need multi-frame art to sell motion.
_tp_pal={r=8,o=9,y=10,w=7,k=0,s=5,b=12,B=1,n=4}
_tp_ax=9
_tp_ay=13
_tp_ready=false

_tp_rows={
 "..................",
 "........rrr.......",
 ".......rrrrr......",
 "......rrrrrrr.....",
 ".....rrrrwwyyyy...",
 "....rrrwwwwyyyyy..",
 "....rrwwkwwyyyyy..",
 "....rrwwwwwyyyys..",
 "....rrrrwwwwyyss..",
 "....rrrrrrrr.ss...",
 "...rryyyyyyrrrr...",
 "...rrryyyyyrrrr...",
 "...rrrbbbbbrrrr...",
 "...rrbbBBBBBrrr...",
 "...rrbbBBBrrrrr...",
 "....rrrrrrrrrr....",
 "....rrrrrrrrrr....",
 ".....rrrrrrrr.....",
 ".....rrrrrrrr.....",
 "......rrrrrr......",
 "....nn.rrbbBB.....",
 "...nnn.bbBBB......",
 "...nn..bbBB.......",
 ".......bBBB.......",
 ".......bBBB.......",
 "........BB........"
}

function _tp_build_runs(rows)
 local runs={}
 for y=1,#rows do
  local row=rows[y]
  local x=1
  while x<=#row do
   local ch=sub(row,x,x)
   if ch~="." then
    local x2=x
    while x2<#row and sub(row,x2+1,x2+1)==ch do x2+=1 end
    add(runs,{x1=x-1,x2=x2-1,y=y-1,c=_tp_pal[ch]})
    x=x2+1
   else
    x+=1
   end
  end
 end
 return runs
end

function _tp_init()
 if _tp_ready then return end
 _tp_runs=_tp_build_runs(_tp_rows)
 _tp_ready=true
end

function _tp_state()
 if not g.title then g.title={} end
 if not g.title.parrot then g.title.parrot={flap_t=0,ruffle_t=0} end
 if not g.title.parrot.blink_t then g.title.parrot.blink_t=60+flr(rnd(120)) end
 return g.title.parrot
end

function title_parrot_flap()
 local pr=_tp_state()
 pr.flap_t=12
end

function title_parrot_ruffle()
 local pr=_tp_state()
 pr.ruffle_t=20
end

function update_title_parrot()
 local pr=_tp_state()
 if pr.flap_t>0 then pr.flap_t-=1 end
 if pr.ruffle_t>0 then pr.ruffle_t-=1 end
 pr.blink_t-=1
 if pr.blink_t<=-3 then
  pr.blink_t=80+flr(rnd(140))
 end
end

function draw_title_parrot(cx,cy)
 _tp_init()
 local pr=_tp_state()
 -- gentle idle bob (+/-1)
 local bob=flr(sin(t()*.9)+.5)
 local ox=cx-_tp_ax
 local oy=cy-_tp_ay+bob
 -- flap: quick up-hop that eases back down
 if pr.flap_t>0 then
  oy-=flr(pr.flap_t/3)
 end
 -- ruffle: horizontal shimmy
 if pr.ruffle_t>0 then
  ox+=((flr(pr.ruffle_t/2))%2)*2-1
 end
 for r in all(_tp_runs) do
  rectfill(ox+r.x1,oy+r.y,ox+r.x2,oy+r.y,r.c)
 end
 -- eye blink: paint cheek white over the eye pixel
 if pr.blink_t<=0 then
  pset(ox+8,oy+6,_tp_pal.w)
 end
end


function draw_test_select()
 shadow("choose test ship",28,24,7,1)
 panel(10,34,107,74,0,5)
 for i=1,#test_presets do
  local p=test_presets[i]
  local col=6
  if i==g.title.test_sel then
   col=10
   print("\139",14,34+i*10,10)
  end
  shadow(p.name,22,34+i*10,col,1)
 end
 -- details for selected
 local sel=test_presets[g.title.test_sel]
 local hd=ship_defs[sel.hull]
 panel(10,82,107,28,0,5)
 shadow(sel.desc,14,86,7,1)
 shadow("hull:"..hd.hull.." guns:"..hd.broadside.." spd:"..flr(hd.speed*100),14,94,12,1)
 if #sel.ups>0 then
  -- panel inner right is x=117, text starts x=14 -> 25-char budget.
  -- truncate so multi-upgrade presets (frigate has 4) don't overflow.
  local ustr=""
  for u in all(sel.ups) do
   local ud=upgrade_by_id(u)
   if ud then ustr=ustr..ud.name.." " end
  end
  if #ustr>25 then ustr=sub(ustr,1,23).."\148" end
  shadow(ustr,14,102,11,1)
 end
end

function draw_title_perks()
 shadow("perks",52,24,7,1)
 shadow("\135"..(g.meta.tokens or 0),102,24,9,1)

 -- scroll window: 8 visible rows at 9px stride fit inside the 74px
 -- panel. with 13+ perks the list scrolls so the selection stays on
 -- screen. track perk_scroll on g.title and keep it clamped to the
 -- selection so cursor movement auto-scrolls.
 local max_vis=8
 local sel_i=g.title.perk_sel or 1
 local sc=g.title.perk_scroll or 0
 if sel_i<sc+1 then sc=sel_i-1 end
 if sel_i>sc+max_vis then sc=sel_i-max_vis end
 sc=mid(0,sc,max(0,#perk_defs-max_vis))
 g.title.perk_scroll=sc

 panel(8,34,111,74,0,5)
 for vi=1,max_vis do
  local i=vi+sc
  if i>#perk_defs then break end
  local pd=perk_defs[i]
  local y=36+(vi-1)*9
  local unl=perk_unlocked(i)
  local col=unl and 11 or 5
  if i==sel_i then
   col=unl and 10 or 9
   print("\139",10,y,col)
  end
  shadow(pd.name,18,y,col,1)
  if not unl then
   shadow("["..perk_unlock_cost(i).."\135]",96,y,9,1)
  end
 end
 -- scroll indicators only when content extends past the visible window
 if sc>0 then print("\148",114,36,6) end
 if sc+max_vis<#perk_defs then print("\131",114,36+(max_vis-1)*9,6) end

 local sel=perk_defs[sel_i]
 shadow(sel.desc,8,112,6,1)
 shadow("\151 unlock  \142 back",30,120,5,1)
end

function draw_title_bg()
 shadow("choose your past",32,32,7,1)

 local bg=background_defs[g.title.bg_sel]
 local unlocked=bg_unlocked(g.title.bg_sel)

 -- background card: pushed down so it sits below the title + tagline
 panel(10,42,107,56,0,5)

 if g.title.bg_sel>1 then print("\139",14,46,6) end
 if g.title.bg_sel<#background_defs then print("\145",108,46,6) end
 local name_col=unlocked and 10 or 5
 shadow(bg.name,38,46,name_col,1)

 if unlocked then
  -- when rich start is active, swap to the rich-loadout hull/gold so the
  -- card shows what the player actually receives, not the base profile
  local show_hull=bg.hull
  local show_gold=bg.gold
  if g.title.rich and rich_loadouts[bg.id] then
   show_hull=rich_loadouts[bg.id].hull
   show_gold=350
  end
  shadow("ship: "..show_hull,16,58,7,1)
  shadow(show_gold.."g",102,58,10,1)
  local tc=bg.crew
  shadow("crew: "..tc.hands.."h "..tc.marines.."m",16,66,7,1)
  shadow("edge: "..bg.bonus,16,76,11,1)
  local hd=ship_defs[show_hull]
  shadow("hull:"..hd.hull.." sail:"..hd.sails.." spd:"..hd.speed,16,86,6,1)
  shadow("\151 embark  \142 back",30,104,5,1)
 else
  local cost=bg_unlock_cost(g.title.bg_sel)
  shadow("locked",48,62,8,1)
  shadow("cost: "..cost.." \135",44,74,9,1)
  shadow("earn tokens from runs",14,86,5,1)
  shadow("\151 unlock  \142 back",30,104,5,1)
 end
end

-- src/10_state_world.lua
-- world map travel

function world_init()
 g.world={}
 g.world.sel=g.run.loc
 g.world.view_rumor=false
 -- safety: make sure selection is in range
 local tot=sel_total()
 if g.world.sel<1 or g.world.sel>tot then g.world.sel=g.run.loc end
 update_npc_positions()

 -- check for run victory conditions
 check_run_victory()
end

function check_run_victory()
 -- each goal has its own win trigger. "crown" is resolved in
 -- resolve_battle_to_run when the act 3 rival falls.
 local goal=g.run.goal
 -- all wins are act-3-gated. treasure is implicit (galleon only spawns
 -- in the final act); crown triggers when the act-3 rival falls.
 -- legend/marque additionally require progress made *in* act 3 — you
 -- can't show up already at 15 renown / 10 rep and win on entry.
 if goal=="legend" and g.run.act>=#act_defs and g.run.renown>=15 then
  local base=g.run.act3_renown_base or 0
  if g.run.renown>base then
   set_state(states.summary,{outcome="legend"})
   return
  end
 end
 if goal=="marque" and g.run.act>=#act_defs then
  for fid,f in pairs(g.run.factions) do
   if f.rep>=10 then
    local base=(g.run.act3_rep_base and g.run.act3_rep_base[fid]) or 0
    if f.rep>base then
     set_state(states.summary,{outcome="marque",faction=fid})
     return
    end
   end
  end
 end
 if goal=="treasure" and g.run.treasure_taken then
  set_state(states.summary,{outcome="treasure"})
  return
 end
end

function world_update()
 if g.run.act_card_t then
  local e=t()-g.run.act_card_t
  if e<2.6 then
   if e>1.2 and (btnp(4) or btnp(5)) then g.run.act_card_t=nil end
   return
  end
  g.run.act_card_t=nil
 end
 -- left/right cycles through reachable ports by x position;
 -- up/down cycles through interceptable npcs by y position. only
 -- the current port and ports directly linked to it count as
 -- reachable, and npcs are interceptable only if their current leg
 -- lies on a route segment adjacent to this port.
 local near={[g.run.loc]=true}
 local cp=cur_port()
 if cp and cp.links then
  for li in all(cp.links) do near[li]=true end
 end

 if btnp(0) or btnp(1) then
  local dir=btnp(0) and -1 or 1
  local order={}
  for i=1,#g.run.ports do
   if near[i] then add(order,i) end
  end
  for i=1,#order do
   for j=i+1,#order do
    local xi=target_pos(order[i])
    local xj=target_pos(order[j])
    if xj<xi then
     local tmp=order[i] order[i]=order[j] order[j]=tmp
    end
   end
  end
  if #order>0 then
   local cur_i=0
   if sel_is_port() then
    for i=1,#order do
     if order[i]==g.world.sel then cur_i=i break end
    end
   end
   if cur_i==0 then
    for i=1,#order do
     if order[i]==g.run.loc then cur_i=i break end
    end
    if cur_i==0 then cur_i=1 end
    g.world.sel=order[cur_i]
   else
    g.world.sel=order[cycle_idx(cur_i,#order,dir)]
   end
  end
 elseif btnp(2) or btnp(3) then
  local dir=btnp(2) and -1 or 1
  local order={}
  for i=1,#(g.run.npcs or {}) do
   local n=g.run.npcs[i]
   if n and near[n.home] and near[n.dest] then
    add(order,#g.run.ports+i)
   end
  end
  for i=1,#order do
   for j=i+1,#order do
    local _,yi=target_pos(order[i])
    local _,yj=target_pos(order[j])
    if yj<yi then
     local tmp=order[i] order[i]=order[j] order[j]=tmp
    end
   end
  end
  if #order>0 then
   local cur_i=0
   if not sel_is_port() then
    for i=1,#order do
     if order[i]==g.world.sel then cur_i=i break end
    end
   end
   if cur_i==0 then
    g.world.sel=order[dir>0 and 1 or #order]
   else
    g.world.sel=order[cycle_idx(cur_i,#order,dir)]
   end
  end
 end

 if btnp(5) or btnp(4) then
  if sel_is_port() then
   if g.world.sel==g.run.loc then
    local pp=cur_port()
    if port_hostile(pp) then
     msg(pp.name.." turns you away!",8)
    else
     -- upkeep is charged on actual port entry, not just landing.
     -- mutiny here aborts the menu transition (summary already set).
     if charge_port_upkeep() then return end
     set_state(states.port,pp)
    end
   else
    sail_to_port(g.world.sel)
   end
  else
   intercept_npc(sel_npc())
  end
 end
end

function sail_to_port(ix)
 local from_p=cur_port()
 local to_p=find_port(ix)
 if not to_p then return end

 -- you can only sail to ports directly connected to your current one
 if not ports_linked(g.run.loc,ix) then
  msg("no direct route",8)
  return
 end

 local days=travel_days(from_p,to_p)
 days+=apply_travel_weather(from_p,to_p)
 g.run.day+=days
 g.pending_dest=ix

 -- heat decay: 1 point per 3 days traveled. short hops don't shake patrols.
 if g.run.heat>0 and days>=3 then
  local decay=flr(days/3)
  g.run.heat=max(0,g.run.heat-decay)
 end

 -- passive repair during travel
 local rr=.5
 if has_upgrade("carpenter") then rr=1 end
 -- iron_keel perk adds a flat +1/day to hull regen on top of the base
 -- (sails get half of that to stay consistent with the base ratio)
 local iron=has_perk("iron_keel") and 1 or 0
 local p=g.run.player
 local mh=run_hp_max(p)
 local ms=run_sail_max(p)
 p.hp=min(mh,p.hp+flr(days*rr)+flr(days*iron))
 p.sail_hp=min(ms,p.sail_hp+flr(days*rr*.7)+flr(days*iron*.5))

 -- veteran discipline: crew unwinds on the passage
 if has_perk("veteran_discipline") then
  p.morale=min(99,p.morale+min(2,days))
 end

 -- consume supplies (heavier cargo = more mouths/effort).
 -- marines eat heavier than hands — bigger rations, kit upkeep — at 1.5x.
 local c=g.run.player.crew
 local crew_weight=(c.hands or 0)+(c.marines or 0)*1.5
 local load=cargo_load_pct()
 local sup_cost=max(2,flr(days*crew_weight/11 *(1+load*.5)))
 g.run.player.supplies-=sup_cost

 -- carrying contraband adds heat over time (patrols notice)
 if g.run.player.cargo and (g.run.player.cargo.contraband or 0)>0 then
  -- smuggler-priest keeps patrols looking the other way
  if not has_officer("smuggler_priest") or rnd(1)<.5 then
   g.run.heat=min(10,g.run.heat+1)
   msg("contraband draws eyes: +1 heat",2)
  end
 end
 if g.run.player.supplies<0 then
  g.run.player.morale=max(20,g.run.player.morale-8)
  g.run.player.crew.hands=max(1,g.run.player.crew.hands-1)
  g.run.player.supplies=0
  msg("crew starving!",8)
 elseif g.run.player.supplies<5 then
  g.run.player.morale=max(20,g.run.player.morale-2)
  msg("supplies running low",9)
 end

 -- tick npc traffic while you travel
 tick_npcs(days)
 update_market_shifts()
 maybe_spawn_treasure_galleon()

 -- brotherhood strike payout when the day arrives
 if g.run.pending_brotherhood and g.run.day>=g.run.pending_brotherhood.day then
  g.run.player.gold+=g.run.pending_brotherhood.gold
  msg("brotherhood share +"..g.run.pending_brotherhood.gold.."g",10)
  g.run.pending_brotherhood=nil
 end

 -- roll a travel encounter: rivals, hunters, sea raiders.
 local enc=roll_travel_encounter(from_p,to_p)
 if enc then
  g.run.had_first_battle=true
  start_battle(enc)
  return
 end

 -- customs cutter: lawful patrol on a lawful lane. priority over general events.
 local patroller=roll_customs_cutter(from_p,to_p)
 if patroller then
  set_state(states.event,{event=customs_cutter_def,dest=ix,patroller=patroller})
  return
 end

 -- check for sea event (non-combat)
 if rnd(1)<.55 then
  local ev=roll_sea_event()
  set_state(states.event,{event=ev,dest=ix})
  return
 end

 g.run.loc=ix
 g.pending_dest=nil
 if g.run.stats then g.run.stats.ports_visited["a"..g.run.act.."_"..ix]=true end
 check_contract_arrive(ix)
end

-- intercept an npc ship on the world map
function intercept_npc(n)
 -- consume a day or two to catch them
 local days=1+flr(rnd(2))
 g.run.day+=days
 tick_npcs(days)
 local enc={
  kind="sea",profile=n.profile,region=n.region,
  npc=n
 }
 if n.rival and n.rival_ref then
  enc.kind="rival"
  enc.rival=n.rival_ref
 end
 msg("intercept course!",8)
 start_battle(enc)
end

function draw_world_routes()
 for i=1,#g.run.ports do
  local p=g.run.ports[i]
  for li in all(p.links) do
   if li>i then
    local q=g.run.ports[li]
    local dx=q.x-p.x
    local dy=q.y-p.y
    local d=sqrt(dx*dx+dy*dy)
    local steps=flr(d/3)
    -- highlight lanes out of the player's current port
    local hot=(i==g.run.loc or li==g.run.loc)
    local col=hot and 6 or 13
    for s=0,steps do
     if s%2==0 then
      local f=s/steps
      pset(p.x+dx*f,p.y+dy*f,col)
     end
    end
   end
  end
 end
end

function draw_world_nodes()
 local tt=t()
 for i=1,#g.run.ports do
  local p=g.run.ports[i]
  local col=region_defs[p.region].col
  if p.owner=="pirates" then col=2 end

  -- island shape
  circfill(p.x,p.y,3,col)
  pset(p.x-1,p.y-2,col)
  pset(p.x+2,p.y-1,col)

  -- contract target marker
  if g.run.contract and g.run.contract.target==i then
   if sin(tt*1.2)>.0 then
    circ(p.x,p.y,6,10)
   end
  end

  -- port dot (red X if hostile)
  if port_hostile(p) then
   line(p.x-1,p.y-1,p.x+1,p.y+1,8)
   line(p.x+1,p.y-1,p.x-1,p.y+1,8)
  else
   circfill(p.x,p.y,1,15)
  end

  -- port name label (always visible)
  print(p.name,p.x-#p.name*2,p.y+5,6)

  -- current location: bright pulsing ring + "you" marker
  if i==g.run.loc then
   local pulse=sin(tt*.5)*.5+.5
   local pr=5+flr(pulse*2)
   circ(p.x,p.y,pr,11)
  end

  -- selection box (gold) for port
  if sel_is_port() and i==g.world.sel and i~=g.run.loc then
   local sz=6+flr(sin(tt*.8)*.5)
   rect(p.x-sz,p.y-sz,p.x+sz,p.y+sz,10)
  end
 end

 -- draw npc ships (tiny ship sprites aligned to heading)
 for k,n in ipairs(g.run.npcs or {}) do
  local col=npc_col(n)
  -- compute heading from home->dest
  local a=g.run.ports[n.home]
  local b=g.run.ports[n.dest]
  local hx,hy=1,0
  if a and b then
   local dx=b.x-a.x
   local dy=b.y-a.y
   local len=sqrt(dx*dx+dy*dy)
   if len>.1 then hx=dx/len hy=dy/len end
  end
  -- perpendicular for mast/sail
  local px=-hy
  local py=hx
  local x=n.x
  local y=n.y
  -- wake trail behind
  pset(x-hx*3,y-hy*3,13)
  pset(x-hx*2,y-hy*2,6)
  -- hull: 3 px along heading
  pset(x-hx,y-hy,col)
  pset(x,y,col)
  pset(x+hx,y+hy,col)
  -- sail: 1 px perpendicular (light)
  pset(x+px,y+py,7)
  -- bow: slight highlight ahead
  pset(x+hx*2,y+hy*2,col)
  if n.rival then
   local pr=3+flr(sin(tt*1.2)*.5+.5)
   circ(n.x,n.y,pr,8)
   -- rival flag: red pixel above
   pset(x-px,y-py,8)
  end
  -- selection
  if not sel_is_port() and sel_npc()==n then
   local sz=5+flr(sin(tt*.8)*.5)
   rect(n.x-sz,n.y-sz,n.x+sz,n.y+sz,10)
  end
 end

 -- travel / intercept line from current location to target
 local from=cur_port()
 local tx,ty
 if sel_is_port() then
  if g.world.sel~=g.run.loc then
   local to=find_port(g.world.sel)
   tx,ty=to.x,to.y
  end
 else
  local n=sel_npc()
  if n then tx,ty=n.x,n.y end
 end
 if tx then
  local tt2=t()
  for i=0,20 do
   local f=i/20
   local blink=(i+flr(tt2*4))%3
   if blink>0 then
    pset(from.x+(tx-from.x)*f,from.y+(ty-from.y)*f,10)
   end
  end
 end
end

function draw_map_sea()
 rectfill(0,0,127,127,1)
 -- subtle scattered foam + swell streaks in the middle band so the map
 -- reads as ocean rather than a blank field. drawn before routes/nodes
 -- so everything else layers on top cleanly.
 local tt=t()
 for i=0,48 do
  local h=i*23+flr(tt*.4)
  local x=(h*7)%128
  local y=20+((h*13)%76)
  local phase=(tt*.3+i*.13)%1
  if phase>.7 then
   pset(x,y,phase>.9 and 6 or 13)
  end
 end
 -- three slow rolling swell streaks
 for i=0,2 do
  local sy=28+i*22
  local dx=flr((tt*(5+i*2))%140)-6
  for k=0,10 do
   local wx=dx+k
   local wy=sy+flr(sin(k*.3+tt*.5+i)*.8)
   if wx>=0 and wx<128 then pset(wx,wy,13) end
  end
 end
end

-- weather zones on the world map (between ports)
weather_defs={
 storm={col=5,col2=6,name="storm",desc="-hull/sail on cross"},
 fog={col=13,col2=6,name="fog bank",desc="may lose target sight"},
 doldrums={col=3,col2=11,name="doldrums",desc="+travel days"}
}

function spawn_weather()
 g.run.weather={}
 -- doldrums removed: visually it reads as a flat blue bar and its only
 -- effect was +travel days, which didn't pull its weight
 local kinds={"storm","fog"}
 for i=1,2+flr(rnd(2)) do
  local k=kinds[1+flr(rnd(#kinds))]
  add(g.run.weather,{
   kind=k,
   x=18+flr(rnd(92)),
   y=26+flr(rnd(58)),
   r=4+flr(rnd(3)),
   t0=rnd(1)
  })
 end
end

function point_in_weather(x,y,w)
 local dx=x-w.x
 local dy=y-w.y
 return dx*dx+dy*dy<=w.r*w.r
end

function line_crosses_weather(ax,ay,bx,by,w)
 for i=0,10 do
  local f=i/10
  if point_in_weather(ax+(bx-ax)*f,ay+(by-ay)*f,w) then return true end
 end
 return false
end

function apply_travel_weather(from_p,to_p)
 if not g.run.weather then return 0 end
 local extra_days=0
 for w in all(g.run.weather) do
  if line_crosses_weather(from_p.x,from_p.y,to_p.x,to_p.y,w) then
   if w.kind=="storm" then
    local p=g.run.player
    local dmg=4+flr(rnd(4))
    if has_perk("weather_eye") then dmg=max(1,flr(dmg*.5)) end
    if has_upgrade("storm_sails") then dmg=max(1,dmg-2) end
    p.hp=max(1,p.hp-dmg)
    p.sail_hp=max(1,p.sail_hp-flr(dmg*.7))
    msg("storm! -"..dmg.." hull",8)
   elseif w.kind=="doldrums" then
    local d=2
    if has_officer("storm_sailing_master") then d=1 end
    extra_days+=d
    msg("stuck in doldrums +"..d.."d",9)
   elseif w.kind=="fog" then
    -- lose track of traffic: non-rival npcs jump to random positions
    for n in all(g.run.npcs) do
     if not n.rival then n.t=rnd(1) end
    end
    update_npc_positions()
    msg("lost sight in the fog",13)
   end
  end
 end
 return extra_days
end

function draw_weather()
 if not g.run.weather then return end
 local tt=t()
 local lf=lowfx()
 for w in all(g.run.weather) do
  local r=w.r
  if w.kind=="storm" then
   -- dark sea shadow cast beneath the cloud
   if not lf then
    for dx=-r-1,r+1 do
     for dy=0,r do
      local sd=sqrt(dx*dx+dy*dy*1.6)
      if sd<r+1 and (dx+dy+flr(tt*2))%3==0 then
       pset(w.x+dx,w.y+dy+1,0)
      end
     end
    end
   end
   -- layered cloud body
   local churn=sin(tt*.4+w.t0*6)*.6
   circfill(w.x-1,w.y-1,r,5)
   circfill(w.x+2+churn,w.y-2,r-1,5)
   circfill(w.x-2,w.y+churn*.5,r-2,1)
   -- inner highlights (lighter grey)
   pset(w.x-1+flr(sin(tt*.5)*1),w.y-2,6)
   pset(w.x+1,w.y-1+flr(cos(tt*.4)*.8),6)
   -- wispy cloud tufts on top, each slow-drifting
   if not lf then
    for i=0,4 do
     local ph=tt*.25+i*1.1+w.t0*3
     local wx=w.x-r+i*(r/2)+sin(ph)*1.2
     local wy=w.y-r-1+cos(ph*.7)*.6
     pset(wx,wy,6)
     pset(wx+1,wy,6)
     pset(wx,wy+1,5)
    end
    -- rain: multiple angled streaks with varied phase
    for i=0,5 do
     local rx=w.x-r+i*(r*2/5)+flr(sin(tt+i)*.5)
     local rp=(tt*6+i*1.7+w.t0*10)%(r+3)
     local ry=w.y-1+flr(rp)
     if ry<w.y+r+1 then
      pset(rx,ry,12)
      if rp<r then pset(rx,ry+1,1) end
     end
    end
   end
   -- lightning: slow cycle, multi-frame flash
   local phase=(tt*.18+w.t0)%1
   if phase<.05 then
    -- quick overbright flash
    local bright=phase<.025
    local zx=w.x+flr(sin(tt*7+w.t0*5)*2)
    local col=bright and 7 or 10
    line(zx,w.y-r,zx-1,w.y-r/2,col)
    line(zx-1,w.y-r/2,zx+1,w.y,col)
    line(zx+1,w.y,zx,w.y+r-1,col)
    if bright then
     -- halo flash
     circ(zx,w.y,r-1,7)
     pset(zx,w.y+r,10)
    end
   end
  elseif w.kind=="fog" then
   -- soft low-contrast fog - multiple long wisps at different speeds
   local b_lo,b_hi=-2,2
   if lf then b_lo,b_hi=-1,1 end
   for band=b_lo,b_hi do
    local by=w.y+band
    local drift1=sin(tt*.2+band*.9+w.t0*4)*3
    local drift2=cos(tt*.13+band*.6+w.t0*6)*2
    for dx=-r-2,r+2 do
     local x=w.x+dx
     local edge=abs(dx)/(r+2)
     local n1=sin(dx*.4+tt*.3+band*1.1+drift1)
     local n2=sin(dx*.9+tt*.5+band*.7+drift2*.5)
     local n=(n1+n2)*.5
     if n>edge-.35 then
      local c
      if n>edge+.25 then c=7
      elseif n>edge then c=6
      else c=13 end
      pset(x,by,c)
     end
    end
   end
   -- a few drifting denser wisps
   for i=0,2 do
    local wx=w.x-r+((tt*2+i*r*.8)%(r*2+2))
    pset(wx,w.y-1+flr(sin(tt*.4+i)*.6),7)
    pset(wx+1,w.y+flr(cos(tt*.3+i)*.5),6)
   end
  elseif w.kind=="doldrums" then
   -- wider flat glassy zone
   local h=1
   for dy=-h,h do
    line(w.x-r,w.y+dy,w.x+r,w.y+dy,12)
   end
   -- horizontal mirror bands (calm reflections)
   for i=-r,r,2 do
    local gx=w.x+i+flr(sin(tt*.2+i*.3)*.5)
    pset(gx,w.y-1,13)
    pset(gx+1,w.y+1,6)
   end
   -- slow moving sun glint
   local glint=flr((tt*2)%(r*2+1))-r
   pset(w.x+glint,w.y,7)
   pset(w.x+glint-1,w.y,10)
   pset(w.x+glint+1,w.y,10)
   -- a faint thermal wobble edge
   for i=0,3 do
    local sx=w.x-r+i*(r/2)
    pset(sx,w.y-h-1+flr(sin(tt*.5+i)*.5),13)
   end
  end
 end
end

function world_draw()
 draw_map_sea()
 draw_weather()
 draw_world_routes()
 draw_world_nodes()

 local pcur=cur_port()
 local psel=sel_is_port() and find_port(g.world.sel) or nil
 local nsel=sel_npc()
 local at_port=(sel_is_port() and g.world.sel==g.run.loc)

 -- top bar: act chip, day, gold (g), cargo %, heat (h), renown (r).
 -- gold is hard-capped at 999 on display + ingestion; cargo uses the
 -- same brown tier as the vitals row, red when the hold is full.
 local ad=cur_act()
 panel(0,0,127,8,0,5)
 local pl=g.run.player
 local lp=cargo_load_pct()
 local cgc=lp>.75 and 8 or 4
 shadow("a"..g.run.act,4,2,ad.col,0)
 shadow(g.run.day.."d",14,2,7,0)
 shadow("g "..min(999,pl.gold),30,2,10,0)
 shadow("cgo "..flr(lp*100).."%",54,2,cgc,0)
 shadow("h "..g.run.heat,86,2,8,0)
 shadow("r "..g.run.renown,102,2,11,0)

 -- bottom panel: selected port + controls
 panel(0,100,127,27,0,5)

 if at_port then
  shadow(pcur.name,4,103,12,1)
  shadow(port_svc_tags(pcur),4,111,6,1)
 elseif nsel then
  -- lbl + "intercept " prefix must fit under the tag at x=96:
  -- budget = (96-4)/4 - 10 prefix chars = ~12 chars of lbl.
  local lbl=nsel.rival and (nsel.rival_ref.short or nsel.rival_ref.name) or nsel.profile
  if nsel.treasure_prize then lbl="treasure" end
  if nsel.treasure_escort then lbl="royal escort" end
  if nsel.bounty_target then lbl=nsel.bounty_name or "bounty" end
  shadow("intercept "..lbl,4,103,8,1)
  shadow(nsel.region.." ship",4,111,npc_col(nsel),1)
  -- right-side tag: rival/prize beats faction standing
  local tag,tcol
  if nsel.rival then tag="rival" tcol=8
  elseif nsel.treasure_prize then tag="prize" tcol=10
  elseif nsel.treasure_escort then tag="guard" tcol=12
  elseif nsel.bounty_target then tag="bounty" tcol=9
  else
   local hp=nsel.home and g.run.ports[nsel.home]
   local fid=hp and hp.owner
   if fid=="pirates" then tag="pirate" tcol=8
   elseif fid then
    local st=faction_standing(fid)
    tag=st
    tcol=(st=="hostile" and 8) or (st=="friendly" and 11) or 6
   else tag="target" tcol=7 end
  end
  shadow(tag,96,111,tcol,1)
 elseif psel then
  local linked=ports_linked(g.run.loc,g.world.sel)
  -- line 1: port name (blue), facilities (grey), days (right)
  -- unlinked ports are dimmed so it's obvious they can't be sailed to
  local name_col=linked and 12 or 5
  shadow(psel.name,4,103,name_col,1)
  shadow(port_svc_tags(psel),54,103,linked and 6 or 5,1)
  local days=travel_days(pcur,psel)
  shadow(days.."d",116,103,linked and 7 or 5,1)
  -- line 2: produce (green) + demand (pink), using short 3-char names
  -- so they never overflow even on 4-item ports
  if port_has(psel,"market") then
   local short={staples="sta",powder="pow",arms="arm",luxury="lux",
    medicine="med",treasure="tre",contraband="cbd"}
   local px=4
   if psel.produces then
    for p in all(psel.produces) do
     local s="-"..(short[p] or p)
     shadow(s,px,111,11,1)
     px+=#s*4+2
    end
   end
   px+=4
   if psel.demands then
    for d in all(psel.demands) do
     local s="+"..(short[d] or d)
     shadow(s,px,111,14,1)
     px+=#s*4+2
    end
   end
  else
   -- no market here: just show a small hint instead
   shadow("no market",4,111,5,1)
  end
  -- right-side route badge so the rule is clear
  if not linked then
   shadow("no route",80,111,8,1)
  end
 end

 -- contract reminder (or standing objective if no active contract)
 if g.run.contract then
  local c=g.run.contract
  local tgt=find_port(c.target)
  local dl=c.deadline-g.run.day
  local dcol=dl>3 and 12 or 8
  -- budget at x=4: 31 chars. worst case with short: 8+12+4 ~= 29.
  local line="job:"..(c.short or c.name).."\145"..tgt.name.." "..dl.."d"
  if c.target_count and c.target_count>1 then
   line=line.." "..(c.progress or 0).."/"..c.target_count
  end
  shadow(line,4,93,dcol,0)
 else
  local obj="hunt "..(cur_act().region).." rival"
  for r in all(g.run.rivals or {}) do
   if r.region==cur_act().region and not r.defeated then obj="hunt "..r.name break end
  end
  shadow(obj,4,93,8,0)
 end

 -- ship vitals row (hp/sail bars + supplies/crew/cargo)
 local pl=g.run.player
 local mh=ship_defs[pl.hull].hull
 local ms=ship_defs[pl.hull].sails
 bar(4,117,58,pl.hp,mh,8,5)
 bar(66,117,58,pl.sail_hp,ms,12,5)
 local lp=cargo_load_pct()
 local lc=(lp>.75) and 8 or (lp>.4 and 10 or 11)
 -- vitals row: morale (green), supplies, crew — cargo + gold moved up
 -- to the top bar. spacing tightened since cargo no longer shares.
 shadow("mor "..pl.morale,4,121,11,1)
 shadow("sup "..pl.supplies,32,121,7,1)
 shadow("crw "..total_crew(pl.crew),60,121,7,1)
 if g.run.prize_in_tow then
  shadow("\130"..g.run.prize_in_tow.hull,92,121,10,1)
 end

 if g.run.act_card_t then draw_act_card() end
end

function draw_act_card()
 local e=t()-g.run.act_card_t
 local ad=act_defs[g.run.act]
 -- fade in (0..0.5s), hold (0.5..2.1s), fade out (2.1..2.6s)
 local a
 if e<.5 then a=e/.5
 elseif e<2.1 then a=1
 else a=max(0,1-(e-2.1)/.5)
 end
 -- darken the world behind the card (two-stage dither then solid)
 if a>=.25 and a<.7 then
  fillp(0b1010010110100101)
  rectfill(0,0,127,127,0x10)
  fillp()
 elseif a>=.7 then
  rectfill(0,0,127,127,0)
 end
 -- card slides in from above, settles by t=0.5
 local cy=28+flr((1-min(1,e/.5))*-40)
 local col=ad.col
 -- outer card (sized to contain the prompt so nothing spills below)
 rectfill(10,cy,117,cy+56,1)
 rect(10,cy,117,cy+56,col)
 rect(12,cy+2,115,cy+54,col)
 -- act number
 local s1="act "..g.run.act
 printc(s1,cy+6,7)
 -- divider
 line(28,cy+15,99,cy+15,col)
 -- act name (big-ish via double-print shadow)
 local nm=ad.name
 local nx=64-(#nm*4)/2
 print(nm,nx+1,cy+21,0)
 print(nm,nx,cy+20,col)
 -- objective hint, split onto 2 lines so nothing spills past the box.
 -- non-final acts always point at the next rival. the final act picks
 -- a line keyed to the title-chosen goal so legend/treasure/marque
 -- runs don't see a misleading "final foe" prompt.
 local obj1,obj2="a new rival rules","these waters"
 if g.run.act>=#act_defs then
  local goal=g.run.goal
  if goal=="treasure" then obj1,obj2="seek the","treasure fleet"
  elseif goal=="legend" then obj1,obj2="reach 15 renown","to win"
  elseif goal=="marque" then obj1,obj2="earn 10 rep","for marque"
  else obj1,obj2="the final foe","awaits"
  end
 end
 printc(obj1,cy+28,6)
 printc(obj2,cy+36,6)
 -- prompt after hold starts
 if e>1.2 and (flr(e*2)%2==0) then
  printc("\142/\151 to sail on",cy+47,5)
 end
end

-- src/11_state_port.lua
-- port menus

function port_init(port)
 g.port={}
 g.port.ref=port or cur_port()
 -- re-roll offers the player already owns so every port visit shows something new
 if g.port.ref.offer_upgrade and has_upgrade(g.port.ref.offer_upgrade) then
  g.port.ref.offer_upgrade=random_port_upgrade(g.port.ref)
 end
 if g.port.ref.offer_officer and has_officer(g.port.ref.offer_officer) then
  g.port.ref.offer_officer=random_port_officer(g.port.ref)
 end
 -- pressed sailors find shore leave more restorative than peers
 if has_background("pressed_sailor") and g.run.player.morale<99 then
  g.run.player.morale=min(99,g.run.player.morale+1)
 end
 -- old_salt perk: every port stop pays out +1 morale and +1 supplies.
 -- kept small so it stacks gently with other morale sources.
 if has_perk("old_salt") then
  local pl=g.run.player
  pl.morale=min(99,pl.morale+1)
  pl.supplies=min(99,pl.supplies+1)
 end
 -- restock the market based on how long we've been gone
 refresh_port_stock(g.port.ref)
 g.port.sel=1
 g.port.mode="main"
 g.port.items=build_port_menu(g.port.ref)
 g.port.mkt_sel=1
 g.port.mkt_mode="buy"
 g.port.tav_sel=1
 g.port.scroll=0
end

function port_has(port,svc)
 if not port or not port.services then return false end
 for s in all(port.services) do
  if s==svc then return true end
 end
 return false
end

function build_shipyard_menu(port)
 local items={}
 add(items,{id="repair_hull",name="repair hull",price=hull_repair_cost()})
 local ou=upgrade_by_id(port.offer_upgrade)
 if ou then
  add(items,{id="buy_upgrade",name="fit "..ou.name,price=silver_purse_cost(ou.price)})
 end
 -- strip: one row per currently-fitted upgrade, refunds 40% of price
 for upid in all(g.run.player.upgrades or {}) do
  local u=upgrade_by_id(upid)
  if u then
   local refund=max(1,flr(u.price*.4))
   add(items,{id="strip_upgrade",name="strip "..u.name.." +"..refund.."g",up_id=upid,refund=refund})
  end
 end
 local pw=port_has_specialty(port,"guns") and 18 or 24
 add(items,{id="powder",name="refill ammo",price=pw})
 if g.run.prize_in_tow then
  local pz=g.run.prize_in_tow
  local pd=ship_defs[pz.hull]
  local hf=pd and pz.hp/pd.hull or 1
  local sf=pd and pd.sails>0 and pz.sail_hp/pd.sails or 1
  add(items,{id="prize_sell",name="sell "..pz.hull.." +"..prize_sale_value(pz.hull,hf,sf).."g"})
  add(items,{id="prize_swap",name="take helm of "..pz.hull})
 end
 add(items,{id="yard_back",name="leave yard"})
 return items
end

function port_has_specialty(port,tag)
 if not port or not port.specialties then return false end
 for s in all(port.specialties) do
  if s==tag then return true end
 end
 return false
end

-- short service tag line for the world-map hint
function port_svc_tags(port)
 if not port or not port.services then return "" end
 local tags={
  shipyard="yd",market="mkt",tavern="tav",
  admiralty="adm",smugglers="smg"
 }
 local out=""
 for s in all(port.services) do
  if tags[s] then out=out..tags[s].." " end
 end
 return out
end

function build_port_menu(port)
 local items={}
 -- captain's log: always available, no cost, no time. win-condition
 -- reference since the world HUD has no room for a goal reminder.
 add(items,{id="log",name="captain's log"})
 -- harbor: always available — basic resupply, sail patching, departure
 add(items,{id="resupply",name="resupply",price=8})
 add(items,{id="repair_sails",name="patch sails",price=sail_repair_cost()})
 -- shipyard: heavy hull work, fittings, powder, and prize claim
 if port_has(port,"shipyard") then
  -- shipyard is now its own submenu so repairs, fittings, strip, powder,
  -- and prize handling live together in one place
  add(items,{id="shipyard",name="visit shipyard"})
 elseif port_has(port,"market") then
  local pw=port_has_specialty(port,"guns") and 22 or 30
  add(items,{id="powder",name="refill ammo",price=pw})
 end
 -- specialty-unlocked services
 if port_has_specialty(port,"rumors") then
  add(items,{id="buy_rumor",name="buy rumor",price=20})
 end
 if port_has_specialty(port,"boarding") then
  add(items,{id="marine_drill",name="marine drill",price=30})
 end
 -- market: cargo trading
 if port_has(port,"market") then
  add(items,{id="market",name="market"})
 end
 -- tavern: morale, rumors, all crew/marine hires, officer hire/dismiss
 if port_has(port,"tavern") then
  add(items,{id="tavern",name="tavern"})
  local oref=officer_by_id(port.offer_officer)
  add(items,{id="hire_officer",name="hire "..oref.name,price=silver_purse_cost(oref.cost),ren_cost=officer_ren_cost(oref)})
 end
 -- admiralty: contracts
 if port_has(port,"admiralty") then
  add(items,{id="take_contract",name=contract_by_id(port.offer_contract).name})
 end
 -- smugglers: fence contraband for reduced heat
 if port_has(port,"smugglers") then
  add(items,{id="fence",name="fence goods"})
 end
 add(items,{id="leave",name="set sail"})
 if g.run.renown>=7 or (g.run.act or 1)>=2 then
  add(items,{id="retire",name="retire ashore"})
 end
 return items
end

function hull_repair_cost()
 local maxh=run_hp_max(g.run.player)
 local cost=max(0,(maxh-g.run.player.hp)*2)
 if has_background("dock_rat") then cost=flr(cost*.7) end
 if g.port and port_has_specialty(g.port.ref,"repairs") then cost=flr(cost*.7) end
 -- copper bottom is fast but expensive to maintain
 if has_upgrade("copper_bottom") then cost=flr(cost*1.15) end
 return cost
end

function sail_repair_cost()
 local maxs=run_sail_max(g.run.player)
 local cost=max(0,(maxs-g.run.player.sail_hp))
 if has_background("dock_rat") then cost=flr(cost*.7) end
 if g.port and port_has_specialty(g.port.ref,"repairs") then cost=flr(cost*.7) end
 if has_upgrade("copper_bottom") then cost=flr(cost*1.15) end
 return cost
end

function port_update()
 if g.port.mode=="main" then
  port_update_main()
 elseif g.port.mode=="market" then
  port_update_market()
 elseif g.port.mode=="tavern" then
  port_update_tavern()
 elseif g.port.mode=="shipyard" then
  port_update_shipyard()
 elseif g.port.mode=="log" then
  port_update_log()
 end
end

function port_update_log()
 if btnp(4) or btnp(5) then
  g.port.mode="main"
 end
end

function port_update_shipyard()
 local items=g.port.yard_items
 if btnp(2) then g.port.yard_sel=cycle_idx(g.port.yard_sel,#items,-1) end
 if btnp(3) then g.port.yard_sel=cycle_idx(g.port.yard_sel,#items,1) end
 -- keep selection visible in scroll window
 local max_vis=6
 g.port.yard_scroll=g.port.yard_scroll or 0
 if g.port.yard_sel-g.port.yard_scroll>max_vis then
  g.port.yard_scroll=g.port.yard_sel-max_vis
 end
 if g.port.yard_sel<=g.port.yard_scroll then
  g.port.yard_scroll=g.port.yard_sel-1
 end
 if btnp(5) then
  do_port_action(items[g.port.yard_sel])
  -- refresh in case an upgrade was bought/stripped
  g.port.yard_items=build_shipyard_menu(g.port.ref)
  if g.port.yard_sel>#g.port.yard_items then g.port.yard_sel=#g.port.yard_items end
  if g.port.yard_scroll>max(0,#g.port.yard_items-max_vis) then
   g.port.yard_scroll=max(0,#g.port.yard_items-max_vis)
  end
 end
 if btnp(4) then g.port.mode="main" end
end

function port_update_main()
 if btnp(2) then
  g.port.sel=cycle_idx(g.port.sel,#g.port.items,-1)
 end
 if btnp(3) then
  g.port.sel=cycle_idx(g.port.sel,#g.port.items,1)
 end
 -- keep selection visible in scroll window
 local max_vis=7
 if g.port.sel-g.port.scroll>max_vis then
  g.port.scroll=g.port.sel-max_vis
 end
 if g.port.sel<=g.port.scroll then
  g.port.scroll=g.port.sel-1
 end

 if btnp(5) then
  do_port_action(g.port.items[g.port.sel])
  g.port.items=build_port_menu(g.port.ref)
 end

 if btnp(4) then
  set_state(states.world)
 end
end

function port_update_market()
 if btnp(2) then g.port.mkt_sel=cycle_idx(g.port.mkt_sel,#cargo_defs,-1) end
 if btnp(3) then g.port.mkt_sel=cycle_idx(g.port.mkt_sel,#cargo_defs,1) end
 if btnp(0) then g.port.mkt_mode="buy" end
 if btnp(1) then g.port.mkt_mode="sell" end

 if btnp(5) then
  local cd=cargo_defs[g.port.mkt_sel]
  if g.port.mkt_mode=="buy" then
   do_market_buy(cd)
  else
   do_market_sell(cd)
  end
 end

 if btnp(4) then
  g.port.mode="main"
 end
end

function build_tavern_menu()
 local items={
  {id="tav_rounds",name="buy rounds  $5"},
  {id="tav_rumor",name="hear a rumor"},
  {id="tav_press",name="press-gang  $8"},
  {id="tav_recruit",name="recruit crew $12"}
 }
 -- marine recruitment only at ports with admiralty (lawful muster)
 -- or boarding specialty (privateer crews looking for colors).
 local port=g.port and g.port.ref
 if port and (port_has(port,"admiralty") or port_has_specialty(port,"boarding")) then
  add(items,{id="tav_marines",name="recruit marines $20"})
 end
 for oid in all(g.run.player.officers or {}) do
  local o=officer_by_id(oid)
  if o then
   add(items,{id="dismiss_officer",name="fire "..o.name,off_id=oid})
  end
 end
 return items
end

function port_update_tavern()
 local items=g.port.tav_items or build_tavern_menu()
 g.port.tav_items=items
 if btnp(2) then g.port.tav_sel=cycle_idx(g.port.tav_sel,#items,-1) end
 if btnp(3) then g.port.tav_sel=cycle_idx(g.port.tav_sel,#items,1) end
 local max_vis=3
 g.port.tav_scroll=g.port.tav_scroll or 0
 if g.port.tav_sel-g.port.tav_scroll>max_vis then
  g.port.tav_scroll=g.port.tav_sel-max_vis
 end
 if g.port.tav_sel<=g.port.tav_scroll then
  g.port.tav_scroll=g.port.tav_sel-1
 end
 if btnp(5) then
  do_tavern_action(items[g.port.tav_sel])
  g.port.tav_items=build_tavern_menu()
  if g.port.tav_sel>#g.port.tav_items then g.port.tav_sel=#g.port.tav_items end
  if g.port.tav_scroll>max(0,#g.port.tav_items-max_vis) then
   g.port.tav_scroll=max(0,#g.port.tav_items-max_vis)
  end
 end
 if btnp(4) then
  g.port.mode="main"
 end
end

function do_market_buy(cd)
 local p=g.run.player
 local price=cargo_price(cd.id,g.port.ref)
 if not cd.legal and not has_upgrade("smuggler_holds") and not has_background("smuggler_runner") then
  msg("need smuggler holds",8)
  return
 end
 -- stock gate: port has finite supply that refreshes over time
 local port=g.port.ref
 local stk=port.stock and port.stock[cd.id]
 if port.stock and (not stk or stk<=0) then
  msg("none in stock",8) return
 end
 if p.gold<price then msg("not enough gold",8) return end
 if cargo_count()>=cargo_cap() then msg("hold full",8) return end
 p.gold-=price
 p.cargo[cd.id]=(p.cargo[cd.id] or 0)+1
 if port.stock then port.stock[cd.id]=stk-1 end
 msg("bought "..cd.name.." -"..price.."g",11)
end

function do_market_sell(cd)
 local p=g.run.player
 if not p.cargo[cd.id] or p.cargo[cd.id]<1 then
  msg("none to sell",6)
  return
 end
 -- contraband can't be dumped at lawful markets; use a fence at
 -- smuggler/pirate ports instead
 if not cd.legal then
  local port=g.port.ref
  local shady=port_has(port,"smugglers") or port.owner=="pirates"
  if not shady then
   msg("no buyer here - use fence",8)
   return
  end
 end
 local sell=cargo_sell_price(cd.id,g.port.ref)
 -- black_market_eye: +20% on contraband sales at smuggler ports (the
 -- only place contraband can be legally moved through the market path)
 if has_perk("black_market_eye") and not cd.legal and port_has(g.port.ref,"smugglers") then
  sell=flr(sell*1.2)
 end
 p.gold+=sell
 if g.run.stats then g.run.stats.gold_earned+=sell end
 p.cargo[cd.id]-=1
 if p.cargo[cd.id]<=0 then p.cargo[cd.id]=nil end
 msg("sold "..cd.name.." +"..sell.."g",10)
end

function do_tavern_action(item)
 if not item then return end
 local p=g.run.player
 if item.id=="tav_rounds" then
  if p.gold<5 then msg("not enough gold",8) return end
  p.gold-=5
  local boost=6
  if has_background("pressed_sailor") then boost=9 end
  p.morale=min(99,p.morale+boost)
  msg("morale +"..boost,11)
 elseif item.id=="tav_rumor" then
  g.port.ref.rumor=generate_actionable_rumor()
 elseif item.id=="tav_press" then
  if p.gold<8 then msg("not enough gold",8) return end
  p.gold-=8
  p.crew.hands=p.crew.hands+2
  enforce_crew_cap(p)
  msg("+2 hands",11)
 elseif item.id=="tav_recruit" then
  if p.gold<12 then msg("need 12g",8) return end
  p.gold-=12
  add_basic_crew()
  p.morale=min(99,p.morale+2)
  msg("crew recruited",11)
 elseif item.id=="tav_marines" then
  if p.gold<20 then msg("not enough gold",8) return end
  p.gold-=20
  p.crew.marines=(p.crew.marines or 0)+2
  enforce_crew_cap(p)
  msg("+2 marines",11)
 elseif item.id=="dismiss_officer" then
  local o=officer_by_id(item.off_id)
  del(p.officers,item.off_id)
  msg("dismissed "..(o and o.name or item.off_id),9)
 end
end

function generate_actionable_rumor()
 local rumors={}
 if g.run.rivals then
  for r in all(g.run.rivals) do
   if not r.defeated then
    add(rumors,r.name.." seen in "..r.region)
   end
  end
 end
 for i=1,#g.run.ports do
  local pp=g.run.ports[i]
  if pp.offer_contract then
   add(rumors,pp.name..": "..contract_by_id(pp.offer_contract).name)
  end
 end
 add(rumors,"luxury sells high in storms")
 add(rumors,"arms cheap at frontier coves")
 add(rumors,rnd_item(rumor_pool))
 return rnd_item(rumors)
end

function add_basic_crew()
 local p=g.run.player
 local c=p.crew
 c.hands=c.hands+3
 c.marines=c.marines+1
 enforce_crew_cap(p)
end

function do_port_action(item)
 if not item then return end
 local p=g.run.player

 if item.id=="repair_hull" then
  local cost=hull_repair_cost()
  if cost<1 then msg("hull sound",12) return end
  if p.gold<cost then msg("need "..cost.."g",8) return end
  p.gold-=cost
  p.hp=run_hp_max(p)
  msg("hull restored",11)
  return
 end

 if item.id=="repair_sails" then
  local cost=sail_repair_cost()
  if cost<1 then msg("sails sound",12) return end
  if p.gold<cost then msg("need "..cost.."g",8) return end
  p.gold-=cost
  p.sail_hp=run_sail_max(p)
  msg("sails mended",11)
  return
 end

 if item.id=="resupply" then
  if p.supplies>=28 then msg("holds full",12) return end
  if p.gold<8 then msg("need 8g",8) return end
  p.gold-=8
  p.supplies=min(30,p.supplies+8)
  msg("+8 supplies",11)
  return
 end


 if item.id=="buy_rumor" then
  if p.gold<20 then msg("need 20g",8) return end
  p.gold-=20
  -- first priority: grant a treasure clue if none active.
  -- galleon always spawns in the final act (win is act-3-gated).
  if not g.run.treasure_clue then
   g.run.treasure_clue={act=#act_defs}
   msg("treasure whispered (act "..g.run.treasure_clue.act..")",10)
   return
  end
  -- else reveal an undefeated rival's region
  local live={}
  for r in all(g.run.rivals or {}) do
   if not r.defeated then add(live,r) end
  end
  if #live>0 then
   local r=live[1+flr(rnd(#live))]
   msg((r.short or r.name).." in "..r.region,12)
  else
   p.gold+=20
   msg("no rumors worth coin",6)
  end
  return
 end

 if item.id=="marine_drill" then
  if p.gold<30 then msg("need 30g",8) return end
  p.gold-=30
  p.crew.marines=(p.crew.marines or 0)+2
  enforce_crew_cap(p)
  p.morale=min(99,p.morale+1)
  msg("+2 marines drilled",11)
  return
 end

 if item.id=="market" then
  g.port.mode="market"
  g.port.mkt_sel=1
  g.port.mkt_mode="buy"
  return
 end

 if item.id=="tavern" then
  g.port.mode="tavern"
  g.port.tav_items=build_tavern_menu()
  g.port.tav_sel=1
  g.port.tav_scroll=0
  return
 end

 if item.id=="log" then
  g.port.mode="log"
  return
 end

 if item.id=="shipyard" then
  g.port.mode="shipyard"
  g.port.yard_items=build_shipyard_menu(g.port.ref)
  g.port.yard_sel=1
  g.port.yard_scroll=0
  return
 end

 if item.id=="yard_back" then
  g.port.mode="main"
  return
 end

 if item.id=="hire_officer" then
  local o=officer_by_id(g.port.ref.offer_officer)
  local rcost=officer_ren_cost(o)
  local cost=silver_purse_cost(o.cost)
  if #p.officers>=3 then msg("slots full",8) return end
  if p.gold<cost then msg("need "..cost.."g",8) return end
  if g.run.renown<rcost then msg("need "..rcost.." renown",8) return end
  p.gold-=cost
  g.run.renown-=rcost
  add(p.officers,o.id)
  msg("hired "..o.name,10)
  g.port.ref.offer_officer=random_port_officer(g.port.ref)
  return
 end

 if item.id=="buy_upgrade" then
  local u=upgrade_by_id(g.port.ref.offer_upgrade)
  local cost=silver_purse_cost(u.price)
  if p.gold<cost then msg("need "..cost.."g",8) return end
  if #p.upgrades>=4 then msg("slots full",8) return end
  p.gold-=cost
  add(p.upgrades,u.id)
  if u.mod and u.mod.hull then
   p.hp=min(ship_defs[p.hull].hull+u.mod.hull,p.hp+u.mod.hull)
  end
  if u.mod and u.mod.sails then
   p.sail_hp=min(ship_defs[p.hull].sails+u.mod.sails,p.sail_hp+u.mod.sails)
  end
  msg("fitted "..u.name,10)
  g.port.ref.offer_upgrade=random_port_upgrade(g.port.ref)
  g.port.items=build_port_menu(g.port.ref)
  return
 end

 if item.id=="strip_upgrade" then
  del(p.upgrades,item.up_id)
  p.gold+=item.refund
  if g.run.stats then g.run.stats.gold_earned+=item.refund end
  -- stripping can shrink max hull/sail — clamp current values down
  p.hp=min(p.hp,run_hp_max(p))
  p.sail_hp=min(p.sail_hp,run_sail_max(p))
  msg("stripped fittings +"..item.refund.."g",9)
  g.port.items=build_port_menu(g.port.ref)
  return
 end

 if item.id=="take_contract" then
  if g.run.contract then msg("already contracted",8) return end
  local c=contract_by_id(g.port.ref.offer_contract)
  g.run.contract=deep_copy(c)
  g.run.contract.origin=g.port.ref.name
  local tgt=g.run.loc
  for _=1,10 do
   tgt=1+flr(rnd(#g.run.ports))
   if tgt~=g.run.loc then break end
  end
  g.run.contract.target=tgt
  g.run.contract.deadline=g.run.day+(c.days or 10)
  g.run.contract.done=false
  -- per-type setup: convoy tracks progress, bounty spawns a named NPC
  if c.id=="convoy_hunt" then
   g.run.contract.progress=0
  elseif c.id=="bounty_hunt" then
   local bn=bounty_names[1+flr(rnd(#bounty_names))]
   g.run.contract.bounty_name=bn
   local n=spawn_npc_at(cur_act().region,false,nil,"hunter")
   if n then n.bounty_target=true n.bounty_name=bn end
   msg("bounty: "..bn,9)
  end
  msg(c.name.." \145 "..find_port(tgt).name,11)
  g.port.ref.offer_contract=random_port_contract(g.port.ref)
  return
 end

 if item.id=="prize_sell" then
  local pz=g.run.prize_in_tow
  if not pz then return end
  local pd=ship_defs[pz.hull]
  local hf=pd and pz.hp/pd.hull or 1
  local sf=pd and pd.sails>0 and pz.sail_hp/pd.sails or 1
  local gold=prize_sale_value(pz.hull,hf,sf)
  p.gold+=gold
  p.crew.hands=p.crew.hands+pz.crew_held
  enforce_crew_cap(p)
  if g.run.stats then
   g.run.stats.gold_earned+=gold
   if gold>g.run.stats.biggest_prize then
    g.run.stats.biggest_prize=gold
    g.run.stats.biggest_prize_name=pz.hull
   end
  end
  g.run.prize_in_tow=nil
  msg("sold "..pz.hull.." +"..gold.."g, crew back",10)
  return
 end

 if item.id=="prize_swap" then
  local pz=g.run.prize_in_tow
  if not pz then return end
  p.hull=pz.hull
  p.hp=pz.hp
  p.sail_hp=pz.sail_hp
  p.crew.hands=p.crew.hands+pz.crew_held
  enforce_crew_cap(p)
  ammo_clamp_to_caps(p)
  g.run.prize_in_tow=nil
  msg("you take the "..pz.hull,10)
  return
 end

 if item.id=="powder" then
  local cost=item.price
  if p.gold<cost then msg("need "..cost.."g",8) return end
  p.ammo_stock=p.ammo_stock or {}
  local stk=p.ammo_stock
  -- full top-up to this hull's caps (scales with broadside)
  local caps=ammo_caps(p.hull)
  local any=false
  for k,v in pairs(caps) do
   if (stk[k] or 0)<v then stk[k]=v any=true end
  end
  if not any then msg("holds full",12) return end
  p.gold-=cost
  msg("ammo restocked",11)
  return
 end

 if item.id=="fence" then
  -- sell all contraband at a flat rate and shed heat per unit
  local held=(p.cargo and p.cargo.contraband) or 0
  if held<=0 then msg("no contraband",6) return end
  local rate=22
  if has_officer("smuggler_priest") then rate=27 end
  -- black_market_eye: +20% fence rate, and one extra heat shed per fence
  local extra_heat=0
  if has_perk("black_market_eye") then
   rate=flr(rate*1.2)
   extra_heat=1
  end
  local pay=held*rate
  p.gold+=pay
  if g.run.stats then g.run.stats.gold_earned+=pay end
  p.cargo.contraband=nil
  g.run.heat=max(0,g.run.heat-min(4,held+extra_heat))
  msg("fenced "..held.." for "..pay.."g",10)
  return
 end

 if item.id=="leave" then
  set_state(states.world)
  return
 end

 if item.id=="retire" then
  set_state(states.summary,{outcome="retire"})
  return
 end
end

-- === DRAWING ===

function draw_port_scene(p)
 local tt=t()

 -- 1) night sky backdrop (fills the chrome strip)
 rectfill(0,0,127,33,0)

 -- 2) stars, drawn BEHIND everything so they only show between buildings
 for i=0,5 do
  local sx=(i*23+7)%128
  local sy=(i*11+3)%14
  if sin(tt*.25+i)>.1 then pset(sx,sy,6) end
 end

 -- 3) distant cloud band: very slow drift so it reads as atmosphere,
 -- not motion
 for i=0,3 do
  local cx=(flr(tt*.8+i*40))%140-12
  pset(cx,6+i%2,5)
  pset(cx+1,6+i%2,5)
  pset(cx+2,6+i%2,5)
  pset(cx+3,6+i%2,5)
 end

 -- 4) water band with shimmer
 rectfill(0,30,127,40,1)
 for yy=31,39 do
  if sin(yy*.08+tt*.5)>.6 then
   line(0,yy,127,yy,13)
  end
 end

 -- 5) skyline: layered silhouette buildings (painted OVER the sky)
 -- warehouse with slanted roof
 rectfill(6,22,28,30,5)
 line(6,22,17,17,5)
 line(17,17,28,22,5)
 -- lit windows
 for wx=10,24,4 do
  pset(wx,25,sin(tt*.3+wx)>0 and 10 or 4)
 end

 -- inn (tall, 2 stories with chimney smoke)
 rectfill(32,14,48,30,5)
 -- shingled top highlight
 line(32,14,48,14,6)
 -- windows
 for wy=18,26,4 do
  for wx=34,46,4 do
   pset(wx,wy,sin(tt*.4+wx+wy)>-.2 and 10 or 4)
  end
 end
 -- chimney + drifting smoke
 rectfill(44,10,46,14,5)
 for i=0,3 do
  local st=(tt*.3+i*.22)%1
  local smx=46+flr(sin(tt*.5+i)*2)+flr(st*3)
  local smy=10-flr(st*8)
  local sc=st<.4 and 6 or (st<.75 and 13 or 1)
  if st<.9 then pset(smx,smy,sc) end
 end

 -- church/tower building (main flag pole sits here)
 rectfill(52,16,64,30,5)
 line(52,16,58,11,5)
 line(58,11,64,16,5)
 -- rose window
 pset(58,20,10)

 -- customs house (wide, low)
 rectfill(68,22,92,30,5)
 rectfill(70,20,90,22,5)
 for wx=72,88,4 do
  pset(wx,26,sin(tt*.2+wx)>.3 and 9 or 4)
 end

 -- dockside cottages filling the far right (replaces the lighthouse)
 rectfill(106,24,114,30,5)
 line(106,24,110,21,5)
 line(110,21,114,24,5)
 pset(110,26,sin(tt*.3+10)>0 and 10 or 4)
 rectfill(118,26,124,30,5)

 -- 6) dock line
 rectfill(0,30,127,32,4)

 -- 7) FLAG on the church tower — tall pole, visibly waving cloth
 local fcol=7
 for f in all(factions) do
  if f.id==p.owner then fcol=f.col break end
 end
 local px=58
 local pt=4 -- pole top
 line(px,pt,px,11,5) -- the pole
 pset(px,pt-1,10) -- gold finial
 -- flag cloth: 4 rows, each waving with a different phase
 for fy=0,3 do
  local fl=3+flr(sin(tt*1.4+fy*.5)*2.5)
  local fx1=px+1
  local fx2=px+1+fl
  if fx2>fx1 then line(fx1,pt+fy,fx2,pt+fy,fcol) end
 end
 -- flag fringe darker for depth
 pset(px+1,pt+3,sget(0,0)==0 and fcol or fcol) -- reserved

 -- 8) drifting gulls across the sky (over buildings, under text)
 for i=0,2 do
  local gt=(tt*.18+i*.37)%1
  local gx=flr(gt*140)-6
  local gy=6+i*2+flr(sin(tt*.7+i)*1)
  if gx>=0 and gx<=127 then
   pset(gx,gy,6)
   pset(gx+1,gy-1,6)
   pset(gx+2,gy,6)
  end
 end

 -- 9) docked ship silhouette bobbing at the pier
 local dsx=98+flr(sin(tt*.25)*.5)
 local dsy=29+flr(sin(tt*.4)*.3)
 -- hull
 line(dsx-4,dsy,dsx+4,dsy,5)
 pset(dsx-3,dsy-1,5)
 pset(dsx+3,dsy-1,5)
 -- mast + sails
 line(dsx,dsy-7,dsx,dsy,5)
 line(dsx,dsy-6,dsx+3,dsy-5,7)
 line(dsx,dsy-4,dsx-2,dsy-3,7)
 -- port name
 shadow(p.name,4,3,10,0)
 shadow(p.owner,4,11,7,0)
 if p.specialties then
  -- only surface specialties that carry a live mechanical effect.
  -- outfit/bounties/convoys/escort/privateer/cargo/market/shipyard
  -- are dormant or redundant with the services tag line.
  local visible={guns=1,repairs=1,rumors=1,boarding=1,
   smuggling=1,contraband=1,storms=1,rigging=1}
  local s=""
  for sp in all(p.specialties) do
   if visible[sp] then
    if #s>0 then s=s.." " end
    s=s..sp
   end
  end
  if #s>0 then shadow(s,4,19,12,0) end
 end
end

function port_draw()
 local p=g.port.ref
 rectfill(0,0,127,127,0)
 draw_port_scene(p)

 if g.port.mode=="main" then
  draw_port_main(p)
 elseif g.port.mode=="market" then
  draw_port_market(p)
 elseif g.port.mode=="tavern" then
  draw_port_tavern(p)
 elseif g.port.mode=="shipyard" then
  draw_port_shipyard(p)
 elseif g.port.mode=="log" then
  draw_port_log(p)
 end
end

function draw_port_log(p)
 -- header: panel + title
 panel(2,34,123,8,0,5)
 print("captain's log",6,36,10)
 print("a"..(g.run.act or 1).." d"..g.run.day,86,36,7)

 -- body panel
 local y=46
 panel(2,y-2,123,72,0,5)

 -- goal block: name + win condition text + live progress
 local gid=g.run.goal or "crown"
 local gdef=nil
 for gd in all(goal_defs) do
  if gd.id==gid then gdef=gd break end
 end
 local gname=(gdef and gdef.name) or gid
 local gdesc=(gdef and gdef.desc) or ""

 print("goal",6,y,9)
 print(gname,30,y,12)
 y+=8

 local dl=wrap_text(gdesc,28)
 for i=1,min(#dl,2) do
  print(dl[i],6,y,6)
  y+=6
 end
 y+=2

 -- progress line keyed to goal
 local prog,pcol="progress: ?",7
 if gid=="crown" then
  local tot,beat=0,0
  for r in all(g.run.rivals or {}) do
   tot+=1
   if r.defeated then beat+=1 end
  end
  prog="rivals "..beat.."/"..tot
  pcol=(beat>=tot) and 11 or 7
 elseif gid=="legend" then
  local in_act3=(g.run.act or 1)>=#act_defs
  local base=g.run.act3_renown_base or 0
  local r=g.run.renown or 0
  local armed=in_act3 and r>=15 and r>base
  prog="renown "..r.."/15"
  if not in_act3 then prog=prog.." (act 3)"
  elseif r>=15 and not armed then prog=prog.." earn in act 3"
  end
  pcol=armed and 11 or 7
 elseif gid=="marque" then
  local best,bfid=0,nil
  for fid,f in pairs(g.run.factions or {}) do
   if f.rep>best then best=f.rep bfid=fid end
  end
  local in_act3=(g.run.act or 1)>=#act_defs
  local base=(g.run.act3_rep_base and bfid and g.run.act3_rep_base[bfid]) or 0
  local armed=in_act3 and best>=10 and best>base
  local need_a3=in_act3 and best>=10 and not armed
  prog="best rep "..max(0,best).."/10"
  if bfid and not need_a3 then prog=prog.." ("..bfid..")" end
  if not in_act3 then prog=prog.." (act 3)"
  elseif need_a3 then prog=prog.." earn in act 3"
  end
  pcol=armed and 11 or 7
 elseif gid=="treasure" then
  -- progress text must fit the body panel: ~115px budget from x=6.
  -- longest string below ("break the royal escort") = 23ch = 92px.
  if g.run.treasure_taken then
   prog="galleon taken!" pcol=11
  elseif g.run.treasure_clue then
   local ca=g.run.treasure_clue.act
   if ca==g.run.act then
    if g.run.treasure_galleon_spawned then
     prog=g.run.treasure_escort_down and "galleon sighted - strike" or "galleon sighted - guarded"
     pcol=10
    elseif g.run.treasure_escort_down then
     prog="galleon inbound" pcol=10
    else
     prog="break the royal escort" pcol=9
    end
   else prog="galleon due in a"..ca pcol=9 end
  else
   prog="no clue yet - try taverns" pcol=8
  end
 end
 print(prog,6,y,pcol)
 y+=10

 -- current act / region name
 local ad=act_defs[g.run.act or 1]
 print("region",6,y,9)
 print((ad and ad.name) or "?",38,y,(ad and ad.col) or 7)
 y+=8

 -- faction rep: iterate the canonical factions table for stable order,
 -- wrap to a second row so five entries don't spill off the 128px panel.
 -- layout: 3 per row * 30px stride, starting at x=22; max rep label is
 -- ~7 chars ("emp -10") which fits inside each 30px cell.
 print("rep",6,y,9)
 local col=0
 local rx=22
 for fd in all(factions) do
  local f=g.run.factions[fd.id]
  if f then
   local rcol=(f.rep>=5 and 11) or (f.rep<=-5 and 8) or 6
   print(sub(fd.id,1,3).." "..f.rep,rx,y,rcol)
   rx+=30
   col+=1
   if col>=3 then
    col=0
    rx=22
    y+=6
   end
  end
 end

 -- status + close prompt
 draw_port_status()
end

function draw_port_shipyard(p)
 -- header: yard name + fitted slots indicator
 panel(2,34,123,8,0,5)
 print("shipyard",6,36,12)
 local slots=#(g.run.player.upgrades or {})
 print("slots "..slots.."/4",60,36,slots>=4 and 8 or 7)
 print(g.run.player.gold.."g",100,36,10)

 -- scrollable menu: 6 rows at a time so the panel stops just above the
 -- status bar (at y=96). 7 rows would clip the last row behind status.
 local items=g.port.yard_items or {}
 local max_vis=6
 local menu_y=46
 local item_h=8
 local sc=g.port.yard_scroll or 0
 panel(2,menu_y-2,123,max_vis*item_h+4,0,5)
 for vi=1,max_vis do
  local i=vi+sc
  if i>#items then break end
  local it=items[i]
  local yy=menu_y+(vi-1)*item_h
  local col=6
  if i==g.port.yard_sel then
   col=10
   rectfill(4,yy-1,123,yy+5,1)
   print("\139",4,yy,10)
  end
  print(it.name,10,yy,col)
  if it.price and it.price>0 then
   print("$"..it.price,100,yy,10)
  end
 end
 if sc>0 then print("\148",120,menu_y-2,6) end
 if sc+max_vis<#items then print("\131",120,menu_y+max_vis*item_h-2,6) end

 -- status + controls
 draw_port_status()
end

function draw_port_main(p)
 -- scrollable menu: show 7 items at a time
 local max_vis=7
 local menu_y=36
 local item_h=7
 local sc=g.port.scroll

 panel(2,menu_y-2,123,max_vis*item_h+4,0,5)

 for vi=1,max_vis do
  local i=vi+sc
  if i>#g.port.items then break end
  local it=g.port.items[i]
  local yy=menu_y+(vi-1)*item_h
  local col=6
  if i==g.port.sel then
   col=10
   rectfill(4,yy-1,123,yy+5,1)
   print("\139",4,yy,10)
  end
  print(it.name,10,yy,col)
  -- gold cost + optional renown cost, placed right-aligned and distinct
  if it.price and it.price>0 then
   local pstr="$"..it.price
   local rx=it.ren_cost and 100 or 100
   print(pstr,rx,yy,10)
  end
  if it.ren_cost and it.ren_cost>0 then
   -- small orange tag after the price so the two costs don't collide
   local base_x=115
   if it.price and it.price>=100 then base_x=117 end
   print(it.ren_cost.."r",base_x,yy,9)
  end
 end

 -- scroll indicators
 if sc>0 then print("\148",120,menu_y-2,6) end
 if sc+max_vis<#g.port.items then print("\131",120,menu_y+max_vis*item_h-2,6) end

 -- status bar at bottom
 draw_port_status()

end

function draw_port_market(p)
 -- top bar: buy/sell toggle (buy=green, sell=orange, match value colors)
 panel(2,34,123,8,0,5)
 local buy_active=g.port.mkt_mode=="buy"
 local sell_active=g.port.mkt_mode=="sell"
 print("< buy",6,36,buy_active and 11 or 5)
 print("sell >",36,36,sell_active and 9 or 5)
 print(g.run.player.gold.."g",60,36,10)
 print(cargo_count().."/"..cargo_cap(),98,36,7)

 -- panel h=50 keeps row 7 (treasure, y=88..93) inside the border.
 -- previously h=48 meant the last row clipped the bottom edge.
 panel(2,44,123,50,0,5)
 -- column header: one quiet legend line so the numbers below are clear
 print("item",6,46,5)
 print("buy",56,46,11)
 print("sell",72,46,9)
 print("stk",94,46,6)
 print("own",108,46,7)

 for i=1,#cargo_defs do
  local cd=cargo_defs[i]
  local buy=cargo_price(cd.id,p)
  local sell=cargo_sell_price(cd.id,p)
  local bsign=""
  if p.produces then
   for gd in all(p.produces) do
    if gd==cd.id then bsign="-" break end
   end
  end
  if bsign=="" and p.demands then
   for gd in all(p.demands) do
    if gd==cd.id then bsign="+" break end
   end
  end
  local ssign=bsign
  local held=g.run.player.cargo[cd.id] or 0
  local yy=52+(i-1)*6
  local col=6
  if i==g.port.mkt_sel then
   col=cd.col
   rectfill(4,yy-1,123,yy+4,1)
   print("\139",4,yy,col)
  end
  print(cd.name,10,yy,col)
  print(bsign..buy,52,yy,11)
  print(ssign..sell,70,yy,9)
  -- port stock: dim when empty
  local stk=p.stock and p.stock[cd.id]
  if p.stock and stk~=nil then
   print(stk,94,yy,stk<=0 and 5 or (stk<3 and 9 or 11))
  end
  if held>0 then
   print(held,108,yy,7)
  end
  if not cd.legal then
   print("!",120,yy,8)
  end
 end

end

function draw_port_tavern(p)
 panel(2,34,123,8,0,5)
 print("tavern",50,36,10)
 print("g "..g.run.player.gold,96,36,10)

 -- actions panel: 3 rows visible. shrunk from 4 to give the rumor
 -- panel below room to grow + breathe (label-to-text gap requested).
 panel(2,44,123,24,0,5)
 local items=g.port.tav_items or {}
 local max_vis=3
 local scroll=g.port.tav_scroll or 0
 for i=1,max_vis do
  local ix=scroll+i
  local item=items[ix]
  if item then
   local yy=47+(i-1)*7
   local col=6
   if ix==g.port.tav_sel then
    col=10
    rectfill(4,yy-1,114,yy+5,1)
    print("\139",4,yy,10)
   end
   print(item.name,10,yy,col)
  end
 end
 -- scroll indicators when list exceeds visible rows (same glyphs as shipyard)
 if scroll>0 then print("\148",118,45,6) end
 if scroll+max_vis<#items then print("\131",118,62,6) end

 -- rumor panel: label + 2 wrapped lines, with a clear visual gap between
 -- the "rumor:" header and the message body. panel y=70-94 (interior 72-92).
 panel(2,70,123,24,0,5)
 print("rumor:",4,72,6)
 local rlines=wrap_text(p.rumor or "",28)
 for i=1,min(#rlines,2) do
  print(rlines[i],4,80+(i-1)*7,7)
 end
end

function draw_port_status()
 panel(2,96,123,20,0,5)
 -- 5-column equidistant vitals sized for the 3-digit worst case.
 -- layout (each char ~4px wide):
 --   gold  : "999g"     16 px   x=  4..19
 --   cgo   : "cgo100%"  28 px   x= 22..49
 --   sup   : "sup100"   24 px   x= 52..75
 --   crw   : "crw100"   24 px   x= 78..101
 --   mor   : "mor100"   24 px   x=104..127
 -- gaps between fields = 3 px visible, equidistant. no overlap even
 -- when all values hit 3 digits. label and value are concatenated
 -- (no internal space) so there's guaranteed room for a full hold %.
 local pl=g.run.player
 local lp=cargo_load_pct()
 local cgc=lp>.75 and 8 or 4
 print(pl.gold.."g",4,99,10)
 print("cgo",22,99,6)
 print(flr(lp*100).."%",34,99,cgc)
 print("sup",52,99,6)
 print(pl.supplies,64,99,7)
 print("crw",78,99,6)
 print(total_crew(pl.crew),90,99,7)
 print("mor",104,99,6)
 print(pl.morale,116,99,11)

 -- bottom row: hull/sail bars (bar color alone conveys which is which)
 bar(4,108,54,pl.hp,ship_defs[pl.hull].hull,8,5)
 bar(64,108,54,pl.sail_hp,ship_defs[pl.hull].sails,12,5)
end

-- src/12_state_battle.lua
-- naval combat

function battle_init(enc)
 local region=enc.region or cur_port().region
 local pl=player_ship_from_run()
 local en=make_enemy_ship(enc.profile or "merchant",region)

 pl.team="player"
 pl.x=480
 pl.y=512
 pl.a=0
 pl.crew_start=pl.crew
 pl.sail_perm=pl.sail_hp

 en.x=560
 en.y=512+rnd(16)-8
 en.a=.5

 -- rival buff
 if enc.rival then
  -- battle HUD label at x=88 has a 10-char budget. use the short name
  -- ("vane"/"moura"/"red knife") without the "capt." prefix to fit.
  en.label=enc.rival.short or enc.rival.name
  en.col=9
  en.hp=flr(en.hp*1.3)
  en.hp_max=en.hp
  en.hp_perm=en.hp
  en.morale=min(99,en.morale+15)
  en.crew=flr(en.crew*1.2)
  en.marines=flr(en.marines*1.3)
  en.broadside=en.broadside+1
 end

 -- treasure finale escort: a named, buffed frigate that guards the
 -- galleon. must be broken to get a clean shot at the prize.
 -- battle HUD label budget at x=88 is 10 chars.
 if enc.npc and enc.npc.treasure_escort then
  en.label="escort"
  en.col=12
  en.hp=flr(en.hp*1.2)
  en.hp_max=en.hp
  en.hp_perm=en.hp
  en.morale=min(99,en.morale+10)
  en.broadside=en.broadside+1
 end

 -- guarded galleon: escort never broken, so the galleon fights like
 -- it still has support. smaller buff than a rival; meant to punish
 -- skipping the escort without making the finale unwinnable.
 if enc.npc and enc.npc.treasure_guarded then
  en.label="guarded"
  en.col=12
  en.hp=flr(en.hp*1.25)
  en.hp_max=en.hp
  en.hp_perm=en.hp
  en.morale=min(99,en.morale+12)
  en.marines=flr(en.marines*1.25)
  en.broadside=en.broadside+1
 end

 -- heat buff
 if enc.heat_buff and enc.heat_buff>0 then
  local hb=enc.heat_buff
  en.hp=flr(en.hp*(1+hb*.08))
  en.hp_max=en.hp
  en.hp_perm=en.hp
  en.morale=min(99,en.morale+hb*3)
  en.broadside=en.broadside+flr(hb/2)
  -- label budget at x=88 is 10 chars (40px to screen edge).
  if hb>=3 then en.label="vet hunter" end
  if hb>=5 then en.label="elite hntr" en.col=14 end
 end

 -- faction: intercepts track the target's home port owner directly;
 -- random encounters fall back to the region's dominant port owner
 local enc_faction=nil
 if enc.npc and enc.npc.home then
  local hp=g.run.ports[enc.npc.home]
  if hp then enc_faction=hp.owner end
 end
 if not enc_faction then
  for p in all(g.run.ports) do
   if p.region==region and p.owner~="pirates" then
    enc_faction=p.owner break
   end
  end
 end
 if enc.profile=="raider" then enc_faction="pirates" end

 local loot=(enc.profile=="merchant" and 35) or (enc.profile=="hunter" and 65) or 45
 if enc.rival then loot=80 end

 local wind=flr(rnd(8))/8

 -- drifting foam/whitecap dots (scaled for 1024x1024 arena)
 local dots={}
 local n_dots=lowfx() and 80 or 240
 for i=1,n_dots do
  add(dots,{
   x=flr(rnd(1012))+6,
   y=flr(rnd(1012))+6,
   col=rnd_item({7,7,13,13,6,6}),
   dx=cos(wind)*.005+rnd(.003)-.0015,
   dy=sin(wind)*.005+rnd(.003)-.0015
  })
 end

 -- swells (varied length, thickness, angle)
 local swells={}
 local n_swells=lowfx() and 3 or 7
 for i=1,n_swells do
  add(swells,{
   pos=rnd(512),
   spd=.1+rnd(.12),
   ang=wrap1(wind+.5+rnd(.14)-.07),
   len=25+flr(rnd(65)),
   thick=4+flr(rnd(5))
  })
 end

 g.btl={
  enc=enc,region=region,
  wind=wind,
  player=pl,enemy=en,
  slow=1,loot=loot,
  result=nil,hit_flash=0,
  enc_faction=enc_faction,
  cam_x=0,cam_y=0,cam_init=true,
  projectiles={},
  dots=dots,swells=swells,
  sea_t=0,shake=0,
  ammo_hits={round=0,chain=0,grape=0,heavy=0}
 }
 update_battle_camera(g.btl)
 msg("engaged "..en.label,8)
end

-- camera: smooth lerp, frames both ships
function update_battle_camera(b)
 local bc=battle_consts
 local pl=b.player
 local en=b.enemy
 local d=dist(pl.x,pl.y,en.x,en.y)
 -- weight enemy more when close. when the enemy is far off-screen, drop
 -- its weight to 0 so the lerp stops fighting the player hard-clamp
 -- (that fight looked like camera jitter + red-dot snapping).
 local w
 if d>200 then w=0
 else w=clamp(1-d/180,0.12,0.4) end
 local tx=pl.x*(1-w)+en.x*w-64
 local ty=pl.y*(1-w)+en.y*w-64
 tx=clamp(tx,bc.arena_l,bc.arena_r-127)
 ty=clamp(ty,bc.arena_t,bc.arena_b-127)
 if b.cam_init then
  b.cam_x=tx
  b.cam_y=ty
  b.cam_init=false
 else
  b.cam_x+=(tx-b.cam_x)*0.1
  b.cam_y+=(ty-b.cam_y)*0.1
 end
 -- hard clamp: player must stay on screen
 b.cam_x=min(b.cam_x,pl.x-14)
 b.cam_x=max(b.cam_x,pl.x-113)
 b.cam_y=min(b.cam_y,pl.y-14)
 b.cam_y=max(b.cam_y,pl.y-113)
 b.cam_x=clamp(b.cam_x,bc.arena_l,bc.arena_r-127)
 b.cam_y=clamp(b.cam_y,bc.arena_t,bc.arena_b-127)
end

function battle_update()
 local b=g.btl
 local pl=b.player
 local en=b.enemy

 b.slow=(btn(4) or btn(5)) and .35 or 1
 if b.hitstop and b.hitstop>0 then b.hitstop-=1 b.slow=.2 end
 b.tick=(b.tick or 0)+1
 if b.hit_flash>0 then b.hit_flash-=1 end

 -- music stress controller: pick A/B/C at phrase boundaries
 update_battle_music()

 -- fire particles on burning ships
 if pl.fire and pl.fire>0 and rnd(1)<.1 then spawn_fire(pl.x,pl.y,1) end
 if en.fire and en.fire>0 and rnd(1)<.1 then spawn_fire(en.x,en.y,1) end
 -- damage smoke/fire (scales with damage)
 local pl_pct=pl.hp/pl.hp_max
 local en_pct=en.hp/en.hp_max
 if pl_pct<.75 and rnd(1)<.03 then spawn_smoke(pl.x+rnd(4)-2,pl.y+rnd(4)-2,1,5) end
 if pl_pct<.5 and rnd(1)<.06 then spawn_fire(pl.x+rnd(4)-2,pl.y+rnd(4)-2,1) end
 if pl_pct<.25 and rnd(1)<.1 then spawn_fire(pl.x+rnd(3)-1.5,pl.y+rnd(3)-1.5,1) end
 if en_pct<.75 and rnd(1)<.03 then spawn_smoke(en.x+rnd(4)-2,en.y+rnd(4)-2,1,5) end
 if en_pct<.5 and rnd(1)<.06 then spawn_fire(en.x+rnd(4)-2,en.y+rnd(4)-2,1) end
 if en_pct<.25 and rnd(1)<.1 then spawn_fire(en.x+rnd(3)-1.5,en.y+rnd(3)-1.5,1) end

 -- input
 local z=btn(4)
 local x=btn(5)
 if z and x then
  -- Z+X chord: brace (fires once when second button arrives)
  if btnp(4) or btnp(5) then battle_brace(pl) end
 elseif z then
  -- Z + directions: crew mode quick-select. down = boarding:
  -- in range it launches the duel, out of range it preps crew
  -- (boarding mode bonus at the cost of another mode)
  if btnp(0) then try_crew_change(pl,1) end
  if btnp(2) then try_crew_change(pl,2) end
  if btnp(1) then try_crew_change(pl,3) end
  if btnp(3) then
   local bd=dist(pl.x,pl.y,en.x,en.y)
   if bd<=battle_consts.board_dist then
    try_boarding()
   else
    try_crew_change(pl,4)
   end
  end
 elseif x then
  -- X + any direction cycles ammo. turning is allowed but sail mode
  -- is skipped so up/down don't double-fire with the ammo cycle.
  local turn=pl.turn*sail_modes[pl.sail_mode].turn*b.slow
  if pl.crew_mode==1 then turn*=1.12 end
  if pl.crew_mode==3 then turn*=.65 end
  if pl.sub then turn*=max(.2,pl.sub.rig/100) end
  if btn(0) then pl.a=wrap1(pl.a+turn) end
  if btn(1) then pl.a=wrap1(pl.a-turn) end
  local old_ammo=pl.ammo
  if btnp(2) then pl.ammo=1 end
  if btnp(3) then pl.ammo=2 end
  if btnp(0) then pl.ammo=3 end
  if btnp(1) then pl.ammo=4 end
  if pl.ammo~=old_ammo then ammo_swap_reload(pl) end
 else
  handle_player_helm(pl,b.slow)
 end
 -- per-gun auto-fire
 local ammo_id=ammo_order[pl.ammo]
 update_auto_fire(pl,en,ammo_id)

 update_reload(pl,b.slow)
 update_reload(en,b.slow)
 update_ship_motion(pl,b.wind,b.slow)
 update_enemy_ai(en,pl,b.wind,b.slow)
 update_ship_motion(en,b.wind,b.slow)
 check_ship_collision(b)
 apply_status_tick(pl,b.slow)
 apply_status_tick(en,b.slow)
 update_projectiles(b)
 -- sea state + gradual wind shift
 b.sea_t=(b.sea_t or 0)+.016
 -- wind drifts slowly (random walk with momentum)
 b.wind_vel=(b.wind_vel or 0)+(rnd(.0004)-.0002)
 b.wind_vel=clamp(b.wind_vel,-.0002,.0002)
 b.wind=wrap1(b.wind+b.wind_vel)
 for s in all(b.swells) do
  s.pos+=s.spd
  if s.pos>512 then s.pos-=512 end
 end
 for d in all(b.dots) do
  d.x+=d.dx d.y+=d.dy
 end
 update_battle_camera(b)

 -- check surrender
 if check_surrender(en) then
  enter_prize_screen("surrender") return
 end
 if en.hp<=0 or en.crew<=0 then
  enter_prize_screen("victory") return
 end
 if pl.hp<=0 or pl.crew<=0 then
  resolve_battle_to_run("defeat") return
 end
 -- merchants and badly-hurt traders can escape: either by reaching the
 -- arena edge or by opening enough water that pursuit fails. treasure
 -- never escapes — it's the climactic prize.
 local can_escape=en.ai=="merchant"
  or (en.ai=="trader" and en.hp/max(1,en.hp_max)<.35)
 if can_escape and not en.rival_ref then
  local bc=battle_consts
  local near_edge=
   en.x-bc.arena_l<24 or bc.arena_r-en.x<24 or
   en.y-bc.arena_t<24 or bc.arena_b-en.y<24
  local d=dist(pl.x,pl.y,en.x,en.y)
  local far=d>en.range*1.4
  -- distance-based escape: well past visual range (screen is ~128wide,
  -- 180 means they're long gone). slow chasers can never catch fleeing
  -- merchants in the open arena, so the chase ends decisively.
  local far_away=d>180
  if (near_edge and far) or far_away then
   en.escape_t=(en.escape_t or 0)+1
   if en.escape_t>90 then
    msg(en.label.." slipped away!",6)
    resolve_battle_to_run("enemy_escaped") return
   end
  else
   en.escape_t=0
  end
 end
 -- player disengages either by sailing off the arena edge OR by
 -- opening enough water that the enemy loses contact. either way
 -- the same "flee" meter fills over ~1.5s.
 do
  local bc=battle_consts
  local near_l=pl.x<bc.arena_l+24
  local near_r=pl.x>bc.arena_r-24
  local near_t=pl.y<bc.arena_t+24
  local near_b=pl.y>bc.arena_b-24
  local at_edge=near_l or near_r or near_t or near_b
  local cx,cy=cos(pl.a),sin(pl.a)
  local pointing_out=
   (near_l and cx<-.3) or (near_r and cx>.3) or
   (near_t and cy<-.3) or (near_b and cy>.3)
  local edge_escape=at_edge and pointing_out
  -- pursuit break: far from the enemy means they've fallen behind.
  -- if you're faster, the gap keeps growing and the fight dissolves.
  local d=dist(pl.x,pl.y,en.x,en.y)
  local outrun=d>260 and not en.surrendered
  b.edge_escape=edge_escape or outrun
  if b.edge_escape then
   b.escape_t=(b.escape_t or 0)+b.slow
   if b.escape_t>=90 then
    if outrun and not edge_escape then msg("lost contact",12) end
    resolve_battle_to_run("escape") return
   end
  else
   b.escape_t=max(0,(b.escape_t or 0)-2)
  end
 end
 -- enemy boarding attempt: instead of flipping to the boarding state,
 -- start a telegraphed wind-up so the player sees grapples thrown and
 -- can break contact, volley, or push through
 if b.board_wind then
  local w=b.board_wind
  w.t+=b.slow
  local bd2=dist(pl.x,pl.y,en.x,en.y)
  -- cancel conditions: gap opened, enemy broken, player boarded another way
  if bd2>battle_consts.board_dist*2 or en.hp<=0 or en.surrendered then
   b.board_wind=nil
   msg("shook the grapples!",12)
  elseif w.t>=w.max then
   b.board_wind=nil
   set_state(states.boarding,{side="enemy"})
  end
 elseif en.ai~="merchant" then
  local bd2=dist(pl.x,pl.y,en.x,en.y)
  -- raiders can throw from a touch further out; everyone else has to be
  -- right alongside
  local bd_max=battle_consts.board_dist*(en.ai=="raider" and 1.15 or .9)
  if bd2<bd_max and can_board(en,pl) then
   local bch=.012
   if en.ai=="raider" then bch=.018 end
   if rnd(1)<bch*b.slow then
    -- telegraph: long enough to maneuver away or silence the attacker
    local wind=180
    if en.ai=="raider" then wind=135 end
    b.board_wind={t=0,max=wind}
    sfx(sfx_ids.clash or sfx_ids.hit,3)
    msg("grapples!",8)
   end
  end
 end
end

-- sail mode change is crew work — block rapid cycling with a cooldown.
-- sailing stance shaves it, nimble_rigging upgrade shaves it further.
-- sail changes are queued: pressing starts unfurling/reefing; the new
-- mode only takes effect once sail_cd ticks to 0 (see apply_status_tick).
-- this replaces the old "instant change + lockout" model.
function try_sail_change(ship,new_mode)
 -- pressing a new mode mid-cooldown re-targets and resets the timer,
 -- so the player isn't locked into a wrong call for the full cd window
 local cur=ship.sail_pending or ship.sail_mode
 if cur==new_mode then return false end
 local cd=80
 if ship.crew_mode==1 then cd=flr(cd*.7) end
 if ship.team=="player" and has_upgrade("nimble_rigging") then cd=flr(cd*.55) end
 ship.sail_pending=new_mode
 ship.sail_cd=cd
 return true
end

-- crew-mode changes are queued the same way: marines and hands
-- need a moment to shift stations before the new mode's effects apply.
function try_crew_change(ship,new_mode)
 local cur=ship.crew_pending or ship.crew_mode
 if cur==new_mode then return false end
 local cd=120
 if ship.team=="player" and has_officer("cutthroat_bosun") then cd=flr(cd*.6) end
 ship.crew_pending=new_mode
 ship.crew_cd=cd
 return true
end

function handle_player_helm(pl,slow)
 local turn=pl.turn*sail_modes[pl.sail_mode].turn*slow
 if pl.crew_mode==1 then turn*=1.12 end
 if pl.crew_mode==3 then turn*=.65 end
 if pl.sub then turn*=max(.2,pl.sub.rig/100) end
 if btn(0) then pl.a=wrap1(pl.a+turn) end
 if btn(1) then pl.a=wrap1(pl.a-turn) end
 if btnp(2) then
  try_sail_change(pl,min(#sail_modes,pl.sail_mode+1))
 end
 if btnp(3) then
  try_sail_change(pl,max(1,pl.sail_mode-1))
 end
end

-- swapping ammo forces both broadsides to reload fresh rounds of the new
-- type. "cold shot" perk shortens the swap penalty. guns already mid-reload
-- keep the longer of their current cooldown or the swap cd.
function ammo_swap_reload(ship)
 -- top-up, not reset: already-loading guns keep progress, empties get a
 -- partial swap penalty. cold_shot shortens the swap cost further.
 local mul=1.0
 if ship.team=="player" and has_perk("cold_shot") then mul=.7 end
 local swap_cd=flr((ship.reload_base or 190)*mul*.45)
 local bs=ship.broadside or 1
 for i=1,bs do
  if (ship.gcd_l[i] or 0)<swap_cd then
   ship.gcd_l[i]=swap_cd
   ship.gcdm_l[i]=max(ship.gcdm_l[i] or 0,swap_cd)
  end
  if (ship.gcd_r[i] or 0)<swap_cd then
   ship.gcd_r[i]=swap_cd
   ship.gcdm_r[i]=max(ship.gcdm_r[i] or 0,swap_cd)
  end
 end
 sfx(sfx_ids.menu,3)
end

-- crew efficiency: below 50% of crew_cap, guns/sails/repairs slow down
-- proportionally. floor at 40% so a skeleton crew can still limp on.
-- gives grape shot real weight — crew kills directly degrade the ship.
function crew_eff(ship)
 local cap=ship.crew_cap or 1
 return clamp((ship.crew or 0)/(cap*.5),.4,1)
end

function update_reload(ship,slow)
 local rate=1*slow
 if ship.reload_mul then rate*=ship.reload_mul end
 if ship.crew_mode==1 then rate*=.90 end
 if ship.crew_mode==2 then rate*=1.20 end
 if ship.crew_mode==3 then rate*=.45 end
 if ship.crew_mode==4 then rate*=.85 end
 if ship.team=="player" and has_background("navy_deserter") then rate*=1.15 end
 rate*=crew_eff(ship)
 for i,v in pairs(ship.gcd_l) do
  if v>0 then ship.gcd_l[i]=max(0,v-rate) end
 end
 for i,v in pairs(ship.gcd_r) do
  if v>0 then ship.gcd_r[i]=max(0,v-rate) end
 end
end

function wind_factor(a,wind)
 local d=adiff(a,wind)
 -- beam reach (~90deg off wind) is best
 if d<.06 then return .2 end    -- in irons
 if d<.12 then return .55 end   -- close-hauled
 if d<.20 then return .85 end   -- close reach
 if d<.30 then return 1.0 end   -- beam reach
 if d<.40 then return .88 end   -- broad reach
 return .65                      -- running
end

function move_speed(ship,wind)
 local sail=sail_modes[ship.sail_mode]
 local m=sail.spd
 if ship.crew_mode==1 then m*=1.12 end
 if ship.crew_mode==3 then m*=.7 end
 if ship.crew_mode==4 then m*=.95 end
 m*=crew_eff(ship)
 -- bare masts still drift on wind so you're never truly frozen
 local hull_mul
 if ship.sail_hp<=0 then
  hull_mul=.15
 else
  hull_mul=clamp(ship.sail_hp/ship.sail_max,.25,1)
 end
 local rig_mul=ship.sub and max(.3,ship.sub.rig/100) or 1
 -- subtle swell interaction: with waves = tiny boost, against = tiny drag
 local swell_mul=1
 if g.btl and g.btl.swells then
  for s in all(g.btl.swells) do
   -- check if crest is near ship
   local mdx,mdy=cos(s.ang),sin(s.ang)
   local proj=(ship.x-512)*mdx+(ship.y-512)*mdy
   local dd=proj-s.pos
   while dd>256 do dd-=512 end
   while dd<-256 do dd+=512 end
   if abs(dd)<6 then
    local align=adiff(ship.a,s.ang)
    if align<.15 then swell_mul+=.03     -- sailing with wave
    elseif align>.35 then swell_mul-=.02 end -- sailing against
   end
  end
 end
 return ship.speed*m*hull_mul*rig_mul*swell_mul*wind_factor(ship.a,wind)
end

function update_ship_motion(ship,wind,slow)
 -- target is what move_speed wants right now (wind/sails/crew/etc).
 -- cur_spd ramps toward target via accel — big hulls feel weighty
 -- because they take seconds to spool up to a new target speed.
 local target=move_speed(ship,wind)
 ship.cur_spd=ship.cur_spd or 0
 local accel=(ship.accel or .025)*slow
 local diff=target-ship.cur_spd
 -- cold-start penalty: building from a near-stop is much harder than
 -- nudging from cruising. sails haven't bellied, hull hasn't broken
 -- inertia. once at half-target, full accel kicks in.
 if diff>0 and target>0 and ship.cur_spd<target*.5 then
  accel*=.4
 end
 if abs(diff)<=accel then
  ship.cur_spd=target
 elseif diff>0 then
  ship.cur_spd+=accel
 else
  -- decel a bit faster than accel so brake feels responsive
  ship.cur_spd-=accel*1.5
 end
 local spd=ship.cur_spd*slow
 ship.spd_cache=spd
 local bc=battle_consts
 ship.x=clamp(ship.x+cos(ship.a)*spd,bc.arena_l+4,bc.arena_r-4)
 ship.y=clamp(ship.y+sin(ship.a)*spd,bc.arena_t+4,bc.arena_b-4)
end

function check_ship_collision(b)
 local pl,en=b.player,b.enemy
 local d=dist(pl.x,pl.y,en.x,en.y)
 local r=pl.size+en.size
 if d>=r then return end
 -- push apart
 local mx=(pl.x+en.x)/2
 local my=(pl.y+en.y)/2
 local nx,ny
 if d<.5 then
  nx,ny=cos(pl.a),sin(pl.a)
 else
  nx=(pl.x-en.x)/d
  ny=(pl.y-en.y)/d
 end
 local push=(r-d)/2+.5
 local bc=battle_consts
 pl.x=clamp(pl.x+nx*push,bc.arena_l+4,bc.arena_r-4)
 pl.y=clamp(pl.y+ny*push,bc.arena_t+4,bc.arena_b-4)
 en.x=clamp(en.x-nx*push,bc.arena_l+4,bc.arena_r-4)
 en.y=clamp(en.y-ny*push,bc.arena_t+4,bc.arena_b-4)
 -- cooldown check
 if (pl.ram_cd or 0)>0 then return end
 -- closing speed: a fast charge against a stopped target still counts,
 -- so the attacker's solo speed gates ram damage, not the sum.
 local spd_pl=pl.spd_cache or 0
 local spd_en=en.spd_cache or 0
 local rel=max(spd_pl,spd_en)+min(spd_pl,spd_en)*.5
 -- bow angle
 local bow_pl=adiff(pl.a,heading_to(pl.x,pl.y,en.x,en.y))
 local bow_en=adiff(en.a,heading_to(en.x,en.y,pl.x,pl.y))
 local dmg_pl,dmg_en,cd
 if rel>.18 and min(bow_pl,bow_en)<.12 then
  -- ram: bow hit
  local raw=flr(rel*12)+2
  local attacker,victim,dmg_atk,dmg_vic
  if bow_pl<bow_en then
   attacker,victim=pl,en
   dmg_vic=raw+flr(pl.size/3)
   dmg_atk=flr(raw*.3)
  else
   attacker,victim=en,pl
   dmg_vic=raw+flr(en.size/3)
   dmg_atk=flr(raw*.3)
  end
  -- brace is defense-only: bracing victim takes -50%, attacker self -40%
  if victim.brace_t and victim.brace_t>0 then
   dmg_vic=flr(dmg_vic*.5)
  end
  if attacker.brace_t and attacker.brace_t>0 then
   dmg_atk=flr(dmg_atk*.6)
  end
  -- iron prow: brutal rams on the attack, bow tanks hits on defense
  if attacker.team=="player" and has_upgrade("iron_prow") then
   dmg_vic=flr(dmg_vic*1.5)
   dmg_atk=flr(dmg_atk*.5)
  elseif victim.team=="player" and has_upgrade("iron_prow") then
   dmg_atk=flr(dmg_atk*.5)
  end
  if attacker==pl then dmg_en=dmg_vic dmg_pl=dmg_atk
  else dmg_pl=dmg_vic dmg_en=dmg_atk end
  victim.morale=max(0,victim.morale-(2+flr(raw/4)))
  cd=50
  b.shake=max(b.shake or 0,6)
  b.hitstop=3
  spawn_debris(mx,my,10)
  spawn_flash(mx,my,0)
  spawn_flash(mx,my,.25)
  spawn_flash(mx,my,.5)
  spawn_flash(mx,my,.75)
  sfx(sfx_ids.clash,3)
 else
  -- side grind
  dmg_pl=1 dmg_en=1 cd=90
  b.shake=max(b.shake or 0,1)
  spawn_debris(mx,my,2)
 end
 pl.hp=max(0,pl.hp-dmg_pl)
 en.hp=max(0,en.hp-dmg_en)
 pl.ram_cd=cd en.ram_cd=cd
end

function apply_status_tick(ship,slow)
 if ship.ram_cd and ship.ram_cd>0 then ship.ram_cd-=1 end
 if ship.brace_cd and ship.brace_cd>0 then ship.brace_cd-=1 end
 if ship.brace_t and ship.brace_t>0 then ship.brace_t=max(0,ship.brace_t-1) end
 if ship.sail_cd and ship.sail_cd>0 then
  ship.sail_cd=max(0,ship.sail_cd-slow)
  if ship.sail_cd==0 and ship.sail_pending then
   ship.sail_mode=ship.sail_pending
   ship.sail_pending=nil
  end
 end
 if ship.crew_cd and ship.crew_cd>0 then
  ship.crew_cd=max(0,ship.crew_cd-slow)
  if ship.crew_cd==0 and ship.crew_pending then
   ship.crew_mode=ship.crew_pending
   ship.crew_pending=nil
  end
 end
 -- fire/flood are timers (frames remaining); hits re-ignite them.
 -- part of the tick grinds hp_perm so field repair can't fully erase it.
 if ship.fire and ship.fire>0 then
  ship.hp=max(0,ship.hp-.012*slow)
  ship.hp_perm=max(0,(ship.hp_perm or ship.hp_max)-.004*slow)
  ship.fire=max(0,ship.fire-slow)
 end
 if ship.flood and ship.flood>0 then
  ship.hp=max(0,ship.hp-.018*slow)
  ship.hp_perm=max(0,(ship.hp_perm or ship.hp_max)-.006*slow)
  ship.flood=max(0,ship.flood-slow)
 end
 -- carpenter officer/upgrade speeds field repair; crew efficiency also
 -- scales (skeleton crews patch slowly). shared by passive + active repair.
 local field=(ship.team=="player" and has_upgrade("carpenter")) and 1.5 or 1
 field*=crew_eff(ship)
 -- passive subsystem repair (any crew mode): crew works on rigging and
 -- gun crews between fires, but only brings them back to 60%. dedicated
 -- repair mode lifts the cap to 100% and speeds the work.
 if ship.sub then
  local in_repair=(ship.crew_mode==3)
  local cap=in_repair and 100 or 60
  local rate=in_repair and .08 or .02
  if rnd(1)<rate*field*slow then
   local s=ship.sub
   local k=nil
   if s.rig<cap then k="rig" end
   if s.gun_l<cap and (not k or s.gun_l<s[k]) then k="gun_l" end
   if s.gun_r<cap and (not k or s.gun_r<s[k]) then k="gun_r" end
   if k then s[k]=min(cap,s[k]+1) end
  end
 end
 -- repair mode: status timers decay, sails/hull patch —
 -- but active fire/flood block hull regen so pressure states really pressure
 if ship.crew_mode==3 then
  local on_fire=(ship.fire and ship.fire>0) or (ship.flood and ship.flood>0)
  if ship.fire and ship.fire>0 then ship.fire=max(0,ship.fire-1*slow) end
  if ship.flood and ship.flood>0 then ship.flood=max(0,ship.flood-1*slow) end
  -- repair mode can push sails past their perm ceiling (emergency
  -- patchwork beyond the permanent damage) — capped at sail_max
  local sail_cap=min(ship.sail_max,(ship.sail_perm or ship.sail_max)+flr(ship.sail_max*.25))
  if ship.sail_hp<sail_cap then
   local rate=ship.sail_hp<=0 and .35 or .14
   if rnd(1)<rate*field*slow then
    ship.sail_hp=min(sail_cap,ship.sail_hp+1)
   end
  end
  -- plug hull leaks: only while no active fire or flood, and only up
  -- to the current repairable ceiling (which fire/flood already ground down)
  if not on_fire then
   local hp_cap=ship.hp_perm or (ship.hp_max*.85)
   if ship.hp<hp_cap and rnd(1)<.05*field*slow then
    ship.hp=min(hp_cap,ship.hp+1)
   end
  end
 end
 if ship.panic and ship.panic>0 then ship.panic=max(0,ship.panic-.2*slow) end
 -- recoil decay
 if ship.rcl_x then ship.rcl_x*=.8 ship.rcl_y*=.8 end
end

function battle_brace(ship)
 if ship.brace_cd and ship.brace_cd>0 then
  if ship.team=="player" then msg("brace cooling",6) end
  return
 end
 local boost=2
 if ship.team=="player" and has_perk("veteran_discipline") then boost=4 end
 ship.morale=min(99,ship.morale+boost)
 -- bracing locks down: crew crouches, gun ports close briefly,
 -- so damage is reduced and no volleys fire until brace lifts
 ship.brace_t=110
 ship.brace_cd=210
end

-- auto-fire: each gun fires independently when it bears and is reloaded
function update_auto_fire(ship,target,ammo_id)
 if not can_broadside(ship,target) then return end
 -- bracing closes the gun ports: no volleys while locked down
 if ship.brace_t and ship.brace_t>0 then return end
 -- chain shot flies heavier, so it carries a shorter effective range
 if ammo_id=="chain" then
  local dd=dist(ship.x,ship.y,target.x,target.y)
  if dd>ship.range*.82 then return end
 end
 local side=side_to_target(ship,target)
 local cd_arr=side=="port" and ship.gcd_l or ship.gcd_r
 local cdm_arr=side=="port" and ship.gcdm_l or ship.gcdm_r
 local gk=side=="port" and "gun_l" or "gun_r"
 local gpct=ship.sub and ship.sub[gk]/100 or 1
 -- which guns currently bear? (same splay math as guns_in_arc)
 local a=heading_to(ship.x,ship.y,target.x,target.y)
 local diff=adiff(ship.a,a)
 local lo=ship.arc_lo or .12
 local hi=ship.arc_hi or .38
 if diff<lo or diff>hi then return end
 local offset=diff-.25
 local bs=ship.broadside
 -- subsystem damage can silence some guns: scale bears count by gpct
 local avail=flr(bs*gpct+.5)
 local guns={}
 local bears={}
 for i=1,bs do
  local f=i/(bs+1)
  local splay=(.5-f)*.12
  if abs(offset-splay)<.08 then
   add(bears,i)
  end
 end
 while #bears>avail do
  deli(bears,#bears)
 end
 for b in all(bears) do
  if (cd_arr[b] or 0)<=0 then add(guns,b) end
 end
 if #guns==0 then return end
 -- ammo stockpile: players must have rounds of the specialty ammo
 -- type; if short, extra guns fire round shot instead of holding fire
 local primary={}
 local secondary={}
 if ship.team=="player" and ammo_id~="round" then
  local stock=(g.run.player.ammo_stock and g.run.player.ammo_stock[ammo_id]) or 0
  local n_spec=min(#guns,stock)
  for k=1,n_spec do add(primary,guns[k]) end
  for k=n_spec+1,#guns do add(secondary,guns[k]) end
  if n_spec>0 then
   g.run.player.ammo_stock[ammo_id]=stock-n_spec
  end
 else
  for k=1,#guns do add(primary,guns[k]) end
 end
 sfx(ship.team=="player" and sfx_ids.cannon or sfx_ids.hit,3)
 if #primary>0 then spawn_volley(ship,target,ammo_id,primary) end
 if #secondary>0 then spawn_volley(ship,target,"round",secondary) end
 local fa=side=="port" and wrap1(ship.a-.25) or wrap1(ship.a+.25)
 spawn_gun_smoke(ship.x,ship.y,fa,3+flr(#guns/2))
 spawn_flash(ship.x,ship.y,fa)
 g.btl.hit_flash=ship.team=="player" and 6 or 4
 g.btl.hit_flash_team=ship.team
 local nmul=#guns/max(1,bs)
 g.btl.shake=max(g.btl.shake,.5+nmul)
 local rx=side=="port" and -sin(ship.a) or sin(ship.a)
 local ry=side=="port" and cos(ship.a) or -cos(ship.a)
 ship.rcl_x=rx*1.5*nmul ship.rcl_y=ry*1.5*nmul
 -- per-gun reload with correct per-gun ammo type (damaged batteries lose
 -- gun count via 'avail', no extra cooldown inflation)
 local cd_primary=flr(ship.reload_base*(ammo_reload[ammo_id] or 1))
 local cd_round=flr(ship.reload_base*(ammo_reload["round"] or 1))
 for b in all(primary) do
  cd_arr[b]=cd_primary
  cdm_arr[b]=cd_primary
 end
 for b in all(secondary) do
  cd_arr[b]=cd_round
  cdm_arr[b]=cd_round
 end
end

function enemy_pick_ammo(en,pl)
 local ammo="round"
 local ed=dist(en.x,en.y,pl.x,pl.y)
 local pl_rig=pl.sub and pl.sub.rig or 100
 if en.ai=="merchant" then
  ammo="round"
 elseif en.ai=="hunter" then
  if pl_rig>50 and ed<45 then ammo="chain"
  elseif ed<20 then ammo="grape"
  elseif ed<30 then ammo="heavy" end
 elseif en.ai=="duelist" then
  if pl_rig>50 and ed<40 then ammo="chain"
  elseif ed<22 then ammo="heavy" end
 elseif en.ai=="raider" then
  if ed<20 then ammo="grape" end
 elseif en.ai=="escort" then
  if pl.sail_hp>pl.sail_max*.7 and ed<40 then ammo="chain" end
 end
 if ammo=="chain" and pl.sail_hp<pl.sail_max*.3 then ammo="round" end
 return ammo
end

function enemy_fire()
 local ammo=enemy_pick_ammo(g.btl.enemy,g.btl.player)
 ship_fire(g.btl.enemy,g.btl.player,ammo,false)
end

function calc_hit_q(src,tgt)
 local q=.65
 local d=dist(src.x,src.y,tgt.x,tgt.y)
 local rf=d/max(1,src.range)
 if rf<.4 then q+=.15
 elseif rf>.9 then q-=.25
 elseif rf>.7 then q-=.15 end
 q*=sail_modes[src.sail_mode].gun
 if src.crew_mode==2 then q+=.12 end
 local sa=heading_to(src.x,src.y,tgt.x,tgt.y)
 local rake=adiff(sa,tgt.a)
 if rake<.1 then q+=.10 end
 local ts=tgt.spd_cache or 0
 q-=ts*.08
 -- swell penalty: broadside to swell reduces accuracy slightly
 if g.btl and g.btl.swells then
  for s in all(g.btl.swells) do
   local sd=adiff(src.a,s.ang)
   if sd>.18 and sd<.32 then q-=.018 end
  end
 end
 return clamp(q,.1,.92)
end

function resolve_hit(p)
 local b=g.btl
 local tgt=p.tgt
 if not tgt or tgt.hp<=0 then
  spawn_splash(p.x,p.y,3)
  return
 end
 -- proximity check: shots are fired at a leaded position. if the target
 -- accelerated/turned and outran the predicted impact, the ball lands
 -- in empty water (visible splash, no damage). hull-radius + a bit of
 -- slop = max distance for a hit to register.
 local proxd=dist(p.x,p.y,tgt.x,tgt.y)
 local hit_radius=(tgt.size or 7)+3
 if proxd>hit_radius then
  spawn_splash(p.x,p.y,4)
  return
 end
 -- hit/miss roll
 if rnd(1)>p.q then
  spawn_splash(p.x,p.y,4)
  return
 end
 -- hit! distance damage scaling (closer = harder impact)
 local rd=dist(p.src.x,p.src.y,tgt.x,tgt.y)
 local rng=max(1,p.src.range or 40)
 local range_mul=clamp(1.3-rd/rng*.6,.6,1.4)
 if p.ammo=="grape" then range_mul=clamp(1.8-rd/rng*1.5,.3,1.8) end
 -- heavy shot: flatter curve so it stays viable at range
 if p.ammo=="heavy" then range_mul=clamp(1.2-rd/rng*.3,.9,1.2) end
 -- brace reduction
 local mul=range_mul
 if tgt.brace_t and tgt.brace_t>0 then mul*=.7 end
 -- raking: stern vs bow vs broadside
 local sa=heading_to(p.src.x,p.src.y,tgt.x,tgt.y)
 local rake=adiff(sa,tgt.a)
 local rk=1
 local stern=rake<.1
 local bow=rake>.4
 if stern then rk=2.5      -- devastating stern rake
 elseif rake<.2 then rk=1.2
 elseif bow then rk=1.4 end -- bow rake
 -- which side of target faces shooter
 local tdx=p.src.x-tgt.x
 local tdy=p.src.y-tgt.y
 local tfx,tfy=cos(tgt.a),sin(tgt.a)
 local tcross=tfx*tdy-tfy*tdx
 local hit_side=tcross<0 and "gun_r" or "gun_l"
 -- concentrated fire bonus: rapid hits deal more damage
 local tick=g.btl.tick or 0
 if tgt.last_hit_t and (tick-tgt.last_hit_t)<12 then
  tgt.hit_streak=min(5,(tgt.hit_streak or 0)+1)
 else
  tgt.hit_streak=0
 end
 tgt.last_hit_t=tick
 mul*=(1+tgt.hit_streak*.05)
 -- record player hits for post-battle reward math
 if p.src.team=="player" and tgt.team=="enemy" and b.ammo_hits then
  b.ammo_hits[p.ammo]=(b.ammo_hits[p.ammo] or 0)+1
 end
 -- apply by ammo
 local ammo=p.ammo
 local fc=.06 -- flood chance
 if stern then fc=.12 end
 -- heavy shot is explosive — doubles flood chance and bumps fire too
 if ammo=="heavy" then fc*=2 end
 if ammo=="round" then
  local dmg=flr((2+rnd(1.5))*rk*mul)
  tgt.hp=max(0,tgt.hp-dmg)
  tgt.hp_perm=max(0,(tgt.hp_perm or tgt.hp_max)-flr(dmg*.55))
  apply_morale_dmg(tgt,.4)
  if rnd(1)<fc then tgt.flood=max(tgt.flood or 0,720) end
  -- subsystem: battery on hit side (broadside), or random battery (stern)
  if stern then
   local bk=rnd(1)<.5 and "gun_l" or "gun_r"
   tgt.sub[bk]=max(0,tgt.sub[bk]-(4+flr(rnd(4))))
   apply_morale_dmg(tgt,2)
  elseif bow then
   tgt.sub.rig=max(0,tgt.sub.rig-(3+flr(rnd(3))))
  elseif not stern then
   tgt.sub[hit_side]=max(0,tgt.sub[hit_side]-(3+flr(rnd(3))))
  end
 elseif ammo=="chain" then
  -- chain rips canvas: exposure scales, but rake power is capped so a
  -- single stern-rake on full sail can't one-pass delete mobility
  local sm=tgt.sail_mode or 2
  local sail_expose=({.85,1,1.15})[sm]
  local chain_rk=min(rk,1.2)
  local sdmg=flr((4.5+rnd(2.5))*chain_rk*mul*sail_expose)
  tgt.sail_hp=max(0,tgt.sail_hp-sdmg)
  tgt.sail_perm=max(0,(tgt.sail_perm or tgt.sail_max)-flr(sdmg*.65))
  apply_morale_dmg(tgt,.5)
  tgt.sub.rig=max(0,tgt.sub.rig-flr((3+flr(rnd(4)))*sail_expose))
 elseif ammo=="grape" then
  -- grape is primarily a morale/crew weapon. broadside hits catch the
  -- most crew topside; stern/bow hits find fewer bodies.
  local gd=dist(p.src.x,p.src.y,tgt.x,tgt.y)
  local close=gd<22
  local morale_dmg,crew_chance
  if stern then
   morale_dmg=close and 1.5 or .7
   crew_chance=close and .3 or 0
  elseif bow then
   morale_dmg=close and 2.0 or 1.0
   crew_chance=close and .4 or .1
  else
   -- broadside: crew is lined up at the guns and rail
   morale_dmg=close and 5 or 3
   crew_chance=close and .9 or .5
  end
  apply_morale_dmg(tgt,morale_dmg)
  if rnd(1)<crew_chance then crew_loss(tgt,1) end
  -- grape: no subsystem damage
 elseif ammo=="heavy" then
  local dmg=flr((3+rnd(2))*rk*mul)
  tgt.hp=max(0,tgt.hp-dmg)
  tgt.hp_perm=max(0,(tgt.hp_perm or tgt.hp_max)-flr(dmg*.55))
  local sdmg=flr(1*mul)
  tgt.sail_hp=max(0,tgt.sail_hp-sdmg)
  tgt.sail_perm=max(0,(tgt.sail_perm or tgt.sail_max)-sdmg)
  apply_morale_dmg(tgt,.6)
  if rnd(1)<fc then tgt.flood=max(tgt.flood or 0,720) end
  if stern then
   local bk=rnd(1)<.5 and "gun_l" or "gun_r"
   tgt.sub[bk]=max(0,tgt.sub[bk]-(4+flr(rnd(4))))
   apply_morale_dmg(tgt,2)
  elseif bow then
   tgt.sub.rig=max(0,tgt.sub.rig-(3+flr(rnd(3))))
  else
   tgt.sub[hit_side]=max(0,tgt.sub[hit_side]-(3+flr(rnd(3))))
  end
 end
 -- fire ignition: heavy ~3x more likely than round/chain
 local fire_chance=ammo=="heavy" and .12 or .04
 if ammo~="grape" and rnd(1)<fire_chance then tgt.fire=max(tgt.fire or 0,540) end
 if tgt.morale<15 and rnd(1)<.12 then crew_loss(tgt,1) end
 -- vfx (debris at target position, not projectile)
 local hx,hy=tgt.x+rnd(4)-2,tgt.y+rnd(4)-2
 if stern then
  spawn_debris(hx,hy,5)
  b.shake=max(b.shake or 0,3.5)
 elseif ammo=="round" or ammo=="heavy" then
  spawn_debris(hx,hy,3)
  b.shake=max(b.shake or 0,2)
 elseif ammo=="chain" then
  spawn_debris(hx,hy,2)
  b.shake=max(b.shake or 0,1.5)
 else
  spawn_debris(hx,hy,1)
  b.shake=max(b.shake or 0,1)
 end
end

function update_enemy_stance(en,pl)
 if en.stance_cd and en.stance_cd>0 then
  en.stance_cd-=1 return
 end
 local d=dist(en.x,en.y,pl.x,pl.y)
 -- crew mode decision (priority order). routed through try_crew_change
 -- so enemies obey the same 2s queue as the player.
 local want_cm
 if en.fire>0 or en.flood>0 then
  want_cm=3
 elseif en.sub and (en.sub.rig<30 or en.sub.gun_l<30 or en.sub.gun_r<30) and en.fire==0 and en.flood==0 then
  want_cm=3
 elseif d<battle_consts.board_dist+5 and en.ai~="merchant" and en.ai~="trader" and en.ai~="treasure" and en.ai~="escort" then
  want_cm=4
 elseif (d>en.range*1.5 and en.ai~="merchant") or en.ai=="merchant" then
  want_cm=1
 else
  want_cm=2
 end
 local cm_queued=try_crew_change(en,want_cm)
 -- sail mode decision (respects the same cooldown players face)
 local want_sail
 if en.ai=="merchant" then
  want_sail=3
 elseif d>en.range then
  want_sail=3
 elseif d<25 then
  want_sail=1
 else
  want_sail=2
 end
 local sm_queued=try_sail_change(en,want_sail)
 -- spawn intent labels when a change is queued so the player can read
 -- the enemy's plan before it commits. targets are pending, not active.
 if cm_queued then
  local labels={"sailing","gunnery","repairs!","boarding!"}
  local cols={6,2,13,2}
  spawn_label(en.x,en.y-8,labels[en.crew_pending],cols[en.crew_pending])
  en.stance_cd=90
 end
 if sm_queued then
  local sl={"reefing","battle","full sail"}
  spawn_label(en.x,en.y-12,sl[en.sail_pending],6)
  en.stance_cd=90
 end
end

function update_enemy_ai(en,pl,wind,slow)
 update_enemy_stance(en,pl)
 local d=dist(en.x,en.y,pl.x,pl.y)
 local aim=heading_to(en.x,en.y,pl.x,pl.y)
 -- broadside side preference: if port battery is crippled (<50%) and
 -- starboard is healthier, flip the angle offset so starboard guns bear
 local side_sign=1
 if en.sub then
  local gl=en.sub.gun_l or 100
  local gr=en.sub.gun_r or 100
  if gl<50 and gr>gl then side_sign=-1
  elseif gr<50 and gl>gr then side_sign=1 end
 end
 -- traders are armed merchants: defend with a broadside until badly hurt,
 -- then break and run like the old merchant AI
 local trader_fleeing=en.ai=="trader" and en.hp/max(1,en.hp_max)<.35
 -- close distance first, then use broadside pattern
 local off=0
 local fleeing=en.ai=="merchant" or trader_fleeing
 if d>en.range*1.3 and not fleeing then
  off=.06
 else
  if fleeing then off=.5
  elseif en.ai=="raider" then off=.22
  elseif en.ai=="duelist" then off=.24
  elseif en.ai=="hunter" then
   off=(d>35) and .16 or .26
  elseif en.ai=="escort" then off=.20
  elseif en.ai=="trader" then off=.22
  elseif en.ai=="treasure" then
   -- defensive duelist: bring the bigger battery to bear at all ranges
   off=(d>35) and .20 or .26
  end
 end
 -- 180° flee isn't a broadside approach — don't flip its sign
 if not fleeing then off*=side_sign end
 aim=wrap1(aim+off)
 -- merchants/fleeing traders hugging a wall: run parallel along it
 if en.ai=="merchant" or trader_fleeing then
  local bc=battle_consts
  local near_l=en.x-bc.arena_l<40
  local near_r=bc.arena_r-en.x<40
  local near_t=en.y-bc.arena_t<40
  local near_b=bc.arena_b-en.y<40
  if near_l or near_r or near_t or near_b then
   local vx,vy=0,0
   if near_l or near_r then
    -- run vertically, away from player's y
    vy=(en.y>=pl.y) and 1 or -1
    vx=near_l and .15 or -.15
   elseif near_t or near_b then
    vx=(en.x>=pl.x) and 1 or -1
    vy=near_t and .15 or -.15
   end
   aim=atan2(vx,vy)
  end
 end
 local et=en.turn*sail_modes[en.sail_mode].turn*slow
 if en.crew_mode==1 then et*=1.12 end
 if en.crew_mode==3 then et*=.65 end
 if en.sub then et*=max(.2,en.sub.rig/100) end
 en.a=turn_towards(en.a,aim,et)
 local ammo=enemy_pick_ammo(en,pl)
 update_auto_fire(en,pl,ammo)
end

-- boarding gate: both sides need a weakened defender and a boarder
-- with comparable morale + a real boarding party. keeps healthy ships
-- from being stormed and stops a broken captain from forcing the issue.
function can_board(atk,def)
 local hp_pct=def.hp/max(1,def.hp_max)
 local sail_pct=def.sail_hp/max(1,def.sail_max)
 local d_weak=hp_pct<.6 or sail_pct<.4 or def.morale<50 or def.crew<3
 local a_strong=atk.morale>=def.morale-5
 local a_has_men=atk.crew>=3
 -- marine-heavy fits actually matter for the gate (not just the meter fight)
 local a_marines=(atk.marines or 0)>=max(2,flr((def.marines or 0)*.75))
 return d_weak and a_strong and a_has_men and a_marines
end

function try_boarding()
 local pl,en=g.btl.player,g.btl.enemy
 local d=dist(pl.x,pl.y,en.x,en.y)
 if d>battle_consts.board_dist then msg("too far",6) return end
 if not can_board(pl,en) then
  -- narrow the diagnostic so players know what to fix
  local hp_pct=en.hp/max(1,en.hp_max)
  local sail_pct=en.sail_hp/max(1,en.sail_max)
  local d_weak=hp_pct<.6 or sail_pct<.4 or en.morale<50 or en.crew<3
  if not d_weak then msg("soften her first",6)
  elseif pl.morale<en.morale-5 then msg("crew too shaken",6)
  elseif pl.crew<3 then msg("too few hands",6)
  elseif (pl.marines or 0)<max(2,flr((en.marines or 0)*.75)) then msg("too few marines",6)
  else msg("they'd repel you",6) end
  return
 end
 set_state(states.boarding,{side="player"})
end

function enter_prize_screen(outcome)
 set_state(states.prize,{outcome=outcome})
end

function check_surrender(en)
 if en.surrendered then return false end
 local hp_pct=en.hp/en.hp_max
 local thresh=.35
 if en.ai=="merchant" then thresh=.55
 elseif en.ai=="escort" then thresh=.40
 elseif en.ai=="raider" then thresh=.30
 elseif en.ai=="duelist" then thresh=.25
 elseif en.ai=="hunter" then thresh=.24 end
 if has_perk("silver_tongue") then thresh+=.10 end
 if has_perk("ruthless_example") then thresh+=.08 end
 if has_rival_reward("signal_books") then thresh+=.10 end
 -- accumulating pressure meter: hull loss, crew collapse, morale rout,
 -- rigging down, or both batteries crippled all count as "broken"
 local rig=(en.sub and en.sub.rig) or 100
 local gl=(en.sub and en.sub.gun_l) or 100
 local gr=(en.sub and en.sub.gun_r) or 100
 local broken=hp_pct<thresh or en.crew<5 or en.morale<20
  or rig<20 or (gl<25 and gr<25)
 en.surr_p=en.surr_p or 0
 if broken then
  local gain=.008
  if hp_pct<thresh*.5 then gain=.014 end
  if en.morale<10 or en.crew<3 then gain=.020 end
  en.surr_p+=gain
 else
  en.surr_p=max(0,en.surr_p-.004)
 end
 -- boarding stance: intimidation pressure when close
 local pl=g.btl and g.btl.player
 if pl and pl.crew_mode==4 and broken then
  local d=dist(pl.x,pl.y,en.x,en.y)
  if d<40 then en.surr_p+=.006 end
 end
 if en.surr_p>=1 then
  en.surrendered=true return true
 end
 return false
end

-- projectiles
-- guns: array of gun indices (1..broadside) that are actually firing
function spawn_volley(src,tgt,ammo_id,guns)
 local b=g.btl
 local q=calc_hit_q(src,tgt)
 -- lead target: aim where they'll be when shots arrive
 -- dist() is overflow-safe for the full 1024 arena; inline sqrt wasn't
 local rawdist=max(1,dist(src.x,src.y,tgt.x,tgt.y))
 local tspd=tgt.spd_cache or 0
 local flight=rawdist/1.1
 local lead_x=cos(tgt.a)*tspd*flight
 local lead_y=sin(tgt.a)*tspd*flight
 local sz=src.size or 7
 local bs=src.broadside or 1
 local n=#guns
 for k=1,n do
  local i=guns[k]
  -- gun port position: evenly spaced along middle 70% of hull
  local f=i/(bs+1)-.1
  local gx=cos(src.a)*sz*f
  local gy=sin(src.a)*sz*f
  local spread=(k-n/2-.5)*1.5
  local tx=tgt.x+lead_x+rnd(5)-2.5+spread
  local ty=tgt.y+lead_y+rnd(5)-2.5
  local sx=src.x+gx
  local sy=src.y+gy
  local dx=tx-sx
  local dy=ty-sy
  local d=max(1,dist(sx,sy,tx,ty))
  local spd=1.1
  if ammo_id=="grape" then spd=1.5 end
  if ammo_id=="chain" then spd=0.9 end
  if ammo_id=="heavy" then spd=1.3 end
  add(b.projectiles,{
   x=sx,y=sy,
   dx=dx/d*spd,dy=dy/d*spd,
   dist_left=d,ammo=ammo_id,
   hit=false,col=ammo_defs[ammo_id].col,
   src=src,tgt=tgt,
   q=q+rnd(.1)-.05
  })
 end
end

function update_projectiles(b)
 for p in all(b.projectiles) do
  p.x+=p.dx p.y+=p.dy
  p.dy+=0.003
  p.dist_left-=sqrt(p.dx*p.dx+p.dy*p.dy)
  if p.dist_left<=0 and not p.hit then
   p.hit=true
   resolve_hit(p)
  end
  if p.dist_left<-20 then del(b.projectiles,p) end
 end
end

-- === DRAWING ===

function battle_draw()
 local b=g.btl
 local pl=b.player
 local en=b.enemy

 -- camera with screen shake
 local shk_x,shk_y=0,0
 if b.shake>0 then
  shk_x=rnd(b.shake*2)-b.shake
  shk_y=rnd(b.shake*2)-b.shake
  b.shake*=0.82
  if b.shake<0.3 then b.shake=0 end
 end
 camera(b.cam_x+shk_x,b.cam_y+shk_y)

 -- ocean
 local vx=b.cam_x+shk_x
 local vy=b.cam_y+shk_y
 rectfill(vx-1,vy-1,vx+129,vy+129,1)

 -- swell wave crests (finite length, tapered edges, varied thickness)
 local st=b.sea_t or 0
 local scx,scy=vx+64,vy+64
 for s in all(b.swells) do
  local mdx,mdy=cos(s.ang),sin(s.ang)
  local cdx,cdy=cos(s.ang+.25),sin(s.ang+.25)
  -- find nearest crest to screen center
  local sp=(scx-512)*mdx+(scy-512)*mdy
  local diff=s.pos-sp
  while diff>256 do diff-=512 end
  while diff<-256 do diff+=512 end
  local ox=scx+mdx*diff
  local oy=scy+mdy*diff
  -- trace along crest (finite length, varied width)
  local rows=s.thick<6 and 1 or 0
  for row=-rows,rows do
   for t=-s.len,s.len do
    local bulge=sin(t*.005+s.thick*.1)*6+sin(t*.013)*3
    local wx=ox+cdx*t+mdx*(bulge+row)
    local wy=oy+cdy*t+mdy*(bulge+row)
    if wx>vx and wx<vx+128 and wy>vy and wy<vy+128 then
     local edge=abs(t)/s.len
     local dens=s.thick+abs(row)*4+flr(edge*edge*10)
     local h=(t*31+flr(s.pos*11)+row*13)
     if h%dens<1 then
      local c=h%19<3 and 6 or 13
      pset(wx,wy,c)
     end
    end
   end
  end
 end

 -- drifting foam/whitecap dots
 for d in all(b.dots) do
  if d.x>vx-2 and d.x<vx+130 and
     d.y>vy-2 and d.y<vy+130 then
   pset(d.x,d.y,d.col)
  end
 end

 -- arena edge markers (when near edge)
 local bc=battle_consts
 if b.cam_x<30 then
  for yy=b.cam_y,b.cam_y+127,6 do pset(bc.arena_l+2,yy,5) end
 end
 if b.cam_x+127>bc.arena_r-30 then
  for yy=b.cam_y,b.cam_y+127,6 do pset(bc.arena_r-2,yy,5) end
 end
 if b.cam_y<30 then
  for xx=b.cam_x,b.cam_x+127,6 do pset(xx,bc.arena_t+2,5) end
 end
 if b.cam_y+127>bc.arena_b-30 then
  for xx=b.cam_x,b.cam_x+127,6 do pset(xx,bc.arena_b-2,5) end
 end

 -- broadside arcs (subtle dots)
 if not btn(4) and not btn(5) then
  draw_broadside_arc(pl,5)
 end

 -- wake trails
 draw_wake(pl.x,pl.y,pl.a,pl.spd_cache or 0,13)
 draw_wake(en.x,en.y,en.a,en.spd_cache or 0,13)

 -- projectiles with trails
 for p in all(b.projectiles) do
  if not p.hit then
   local tl=3.5
   line(p.x,p.y,p.x-p.dx*tl,p.y-p.dy*tl,5)
   if p.ammo=="grape" then
    circfill(p.x,p.y,0,p.col)
    pset(p.x,p.y,7)
   else
    circfill(p.x,p.y,1,p.col)
    pset(p.x,p.y,10)
   end
  end
 end

 -- ships (with recoil + wave bob)
 local prx,pry=pl.rcl_x or 0,pl.rcl_y or 0
 local erx,ery=en.rcl_x or 0,en.rcl_y or 0
 -- wave bob: tiny offset when crest passes under ship
 for s in all(b.swells) do
  local mdx,mdy=cos(s.ang),sin(s.ang)
  local pp=(pl.x-512)*mdx+(pl.y-512)*mdy
  local pd=pp-s.pos
  while pd>256 do pd-=512 end
  while pd<-256 do pd+=512 end
  if abs(pd)<4 then
   local bob=(1-abs(pd)/4)*.8
   pry-=bob
  end
  local ep=(en.x-512)*mdx+(en.y-512)*mdy
  local ed=ep-s.pos
  while ed>256 do ed-=512 end
  while ed<-256 do ed+=512 end
  if abs(ed)<4 then
   local bob=(1-abs(ed)/4)*.8
   ery-=bob
  end
 end
 draw_ship_primitive(pl.x+prx,pl.y+pry,pl.a,4,pl.size,7,pl.sub)
 draw_ship_damage(pl.x+prx,pl.y+pry,pl.a,pl.size,pl.hp,pl.hp_max)
 draw_ship_primitive(en.x+erx,en.y+ery,en.a,en.col or 8,en.size,7,en.sub)
 draw_ship_damage(en.x+erx,en.y+ery,en.a,en.size,en.hp,en.hp_max)
 -- brace outline pulse: tells the player the defensive stance is live
 if pl.brace_t and pl.brace_t>0 and sin(t()*6)>0 then
  circ(pl.x+prx,pl.y+pry,pl.size+2,12)
 end
 if en.brace_t and en.brace_t>0 and sin(t()*6)>0 then
  circ(en.x+erx,en.y+ery,en.size+2,12)
 end

 -- muzzle highlight on the ship that just fired
 if b.hit_flash>0 and b.hit_flash%2==0 then
  local fs=b.hit_flash_team=="enemy" and en or pl
  circ(fs.x,fs.y,fs.size+3,8)
 end

 -- boarding line: only while the gate is actually open. keeps the
 -- indicator honest instead of teasing you at every close pass.
 local bd=dist(pl.x,pl.y,en.x,en.y)
 if bd<=bc.board_dist and can_board(pl,en) and not en.surrendered then
  line(pl.x,pl.y,en.x,en.y,11)
 end
 -- grapple wind-up: enemy is throwing ropes across. show lines pulling
 -- taut and a pair of hook dots travelling toward the player
 if b.board_wind then
  local w=b.board_wind
  local f=w.t/w.max
  -- three jittering rope strands, one color heavier as time runs out
  local col=f<.5 and 9 or (f<.8 and 8 or 2)
  for i=-1,1 do
   local ox=sin(t()*3+i)*1.2
   local oy=cos(t()*3+i*.7)*1.2
   line(en.x+ox,en.y+oy,pl.x-ox,pl.y-oy,col)
  end
  -- grapple hooks flying in — move from enemy to player
  local hx=en.x+(pl.x-en.x)*f
  local hy=en.y+(pl.y-en.y)*f
  circfill(hx,hy,1,col)
  circfill(hx+2,hy+1,1,col)
 end

 -- fx (world space)
 draw_fx()

 -- === HUD: reset camera, transparent text overlay ===
 camera(0,0)

 -- top: ship names + stacked bars (hp / sail / morale)
 shadow(pl.label or hull_name(g.run.player.hull),3,2,11,1)
 bar3(3,9,36,pl.hp,pl.hp_perm or pl.hp,pl.hp_max,8)
 bar(3,13,36,pl.sail_hp,pl.sail_max,12,1)
 bar(3,17,36,pl.morale,100,11,1)
 -- subsystem pips: katakana ki (mast w/ crossbeams) = rig, </> = guns
 if pl.sub then
  local function sc(v)
   if v>=85 then return 11 end
   if v>=60 then return 10 end
   if v>=30 then return 9 end
   return 8
  end
  shadow("\210",3,22,sc(pl.sub.rig),1)
  shadow("<",15,22,sc(pl.sub.gun_l),1)
  shadow(">",27,22,sc(pl.sub.gun_r),1)
 end

 shadow(en.label or "enemy",88,2,8,1)
 bar3(88,9,36,en.hp,en.hp_perm or en.hp,en.hp_max,8)
 bar(88,13,36,en.sail_hp,en.sail_max,12,1)
 bar(88,17,36,en.morale,100,11,1)
 -- enemy subsystem pips (mirror of player's r/p/s)
 if en.sub then
  local function sc(v)
   if v>=85 then return 11 end
   if v>=60 then return 10 end
   if v>=30 then return 9 end
   return 8
  end
  shadow("\210",88,22,sc(en.sub.rig),1)
  shadow("<",100,22,sc(en.sub.gun_l),1)
  shadow(">",112,22,sc(en.sub.gun_r),1)
 end
 -- tactical callouts (blink to draw the eye). stacked under enemy HUD.
 local blink=flr(t()*3)%2==0
 local cy=28
 local function callout(txt,col)
  if blink then shadow(txt,88,cy,col,1) end
  cy+=6
 end
 local hp_pct=en.hp/max(1,en.hp_max)
 local d=dist(pl.x,pl.y,en.x,en.y)
 if en.sub then
  if en.sub.rig<30 then callout("rigging!",13) end
  if en.sub.gun_l<30 and en.sub.gun_r<30 then callout("guns out!",5) end
 end
 if en.fire and en.fire>0 then callout("afire",8) end
 if en.flood and en.flood>0 then callout("flooding",12) end
 if not en.surrendered and d<bc.board_dist+24 and can_board(pl,en) then
  callout("board \131",11)
 end
 if en.surr_p and en.surr_p>.4 and not en.surrendered then
  callout("wavering",10)
 end
 if en.surrendered then callout("surrender!",11) end

 -- flee meter: shows when you're at an arena edge pointing outward.
 -- hold the heading for ~1.5s to disengage.
 if b.edge_escape or (b.escape_t or 0)>0 then
  local et=b.escape_t or 0
  local fw=flr(32*min(1,et/90))
  local fcol=b.edge_escape and 12 or 5
  rectfill(48,2,80,6,0)
  rect(48,2,80,6,fcol)
  if fw>0 then rectfill(48,2,48+fw,6,fcol) end
  shadow("flee",54,8,fcol,1)
 end

 -- grapple wind-up banner: show a countdown so the player can react
 if b.board_wind then
  local w=b.board_wind
  local f=w.t/w.max
  local gw=flr(46*f)
  local col=f<.5 and 9 or (f<.8 and 8 or 2)
  rectfill(40,36,88,48,0)
  rect(40,36,88,48,col)
  if gw>0 then rectfill(40,36,40+gw,48,col) end
  local label="grapples!"
  if flr(t()*4)%2==0 then shadow(label,46,38,col,1) end
  shadow("break contact",42,44,6,1)
 end

 -- bottom: controls overlay
 local ammo_id=ammo_order[pl.ammo]
 local ammo_label=ammo_id
 if ammo_id~="round" then
  local stk=(g.run.player.ammo_stock and g.run.player.ammo_stock[ammo_id]) or 0
  ammo_label=ammo_id..":"..stk
 end
 shadow(ammo_label,3,118,ammo_defs[ammo_id].col,1)
 -- while a sail change is queued, show the target mode in gray so the
 -- player sees their intent immediately. it commits when cd hits 0.
 local sail_pending=pl.sail_pending and pl.sail_cd and pl.sail_cd>0
 local sail_show=sail_pending and pl.sail_pending or pl.sail_mode
 local sail_col=sail_pending and 5 or 12
 shadow(sail_modes[sail_show].name,38,118,sail_col,1)
 -- crew mode uses the same queued pattern (pending shown grayed).
 local crew_pending=pl.crew_pending and pl.crew_cd and pl.crew_cd>0
 local crew_show=crew_pending and pl.crew_pending or pl.crew_mode
 local crew_col=crew_pending and 5 or crew_modes[crew_show].col
 shadow(crew_modes[crew_show].name,72,118,crew_col,1)
 if pl.brace_t and pl.brace_t>0 then
  shadow("brace",104,118,9,1)
 end

 -- per-gun reload indicators (port row then starboard row)
 -- each gun is independent: dark=spent, amber=loading, green=loaded
 local bs=max(1,pl.broadside or 1)
 local row_w=bs*3+(bs-1)
 local function draw_gun_row(x0,cd_arr,cdm_arr)
  for i=1,bs do
   local bx=x0+(i-1)*4
   local cd=cd_arr[i] or 0
   local cdm=cdm_arr[i] or 1
   local col=11
   if cd>0 then
    local prog=1-cd/max(1,cdm)
    col=prog>.5 and 10 or 9
   end
   rectfill(bx,108,bx+2,111,col)
  end
 end
 draw_gun_row(2,pl.gcd_l,pl.gcdm_l)
 draw_gun_row(2+row_w+4,pl.gcd_r,pl.gcdm_r)
 local sep_x=2+row_w+1
 line(sep_x,108,sep_x,111,5)

 -- status (moved off the gun-pip row to the sub-pip row to the right)
 if pl.fire and pl.fire>0 then shadow("fire",40,22,8,1) end
 if pl.flood and pl.flood>0 then shadow("flood",60,22,12,1) end

 -- wind indicator
 draw_wind_arrow(116,110,wrap1(b.wind+.5))

 -- enemy direction indicator (offscreen)
 local esx=en.x-b.cam_x
 local esy=en.y-b.cam_y
 if esx<-2 or esx>129 or esy<-2 or esy>129 then
  local ix=clamp(flr(esx),5,122)
  local iy=clamp(flr(esy),18,108)
  circfill(ix,iy,2,8)
  pset(ix,iy,7)
  local ed=flr(dist(pl.x,pl.y,en.x,en.y))
  print(ed,ix-4,iy+4,8)
 end
end

-- src/13_state_boarding.lua
-- boarding duel with visible tactics

function boarding_init(arg)
 local pl=g.btl.player
 local en=g.btl.enemy
 local side=(arg and arg.side) or "player"

 g.board={
  side=side,sel=1,
  cmds={"volley","rush","brace","rally","cut free"},
  cmd_cols={8,9,11,12,6},
  cmd_desc={"fire into their crew","charge the decks","hold and absorb","inspire your men","retreat (costly)"},
  round=1,max_rounds=7,
  meter=0,
  info_pl="",info_en="",info_net=0,
  en_act="",flash=0,sfx_t=0,sfx_cmd="",
  done=nil,done_t=0,
  -- pl_start_crew/en_start_crew used as bar baseline for visual depletion
  pl_start_crew=max(1,pl.crew),
  en_start_crew=max(1,en.crew),
  bonuses={}
 }

 if has_background("corsair_orphan") and side=="player" then
  g.board.meter=1
  add(g.board.bonuses,"corsair +1")
 end
 if g.btl.player.crew_mode==4 and side=="player" then
  g.board.meter+=1
  add(g.board.bonuses,"boarding prep +1")
 end
 if has_upgrade("grapnels") and side=="player" then
  g.board.meter+=1
  add(g.board.bonuses,"grapnels +1")
 end
 if has_officer("cutthroat_bosun") and side=="player" then
  g.board.meter+=1
  add(g.board.bonuses,"bosun +1")
 end
 if has_rival_reward("elite_marines") and side=="player" then
  g.board.meter+=1
  add(g.board.bonuses,"elite marines +1")
 end
 if side=="enemy" then
  g.board.meter=-1
  add(g.board.bonuses,"you were boarded -1")
 end
 if #g.board.bonuses==0 then
  g.board.info_pl="grapples bite!"
 else
  g.board.info_pl="opening: "..g.board.bonuses[1]
 end
 -- pre-pick enemy intent so player can read it before committing
 g.board.en_intent=pick_board_enemy_action(en,g.board.meter)
end

function pick_board_enemy_action(en,meter)
 if en.morale<30 then return "rallies" end
 if meter<-1 then return "holds" end
 if rnd(1)<.55 then return "charges" end
 return "holds"
end

function boarding_update()
 local b=g.board
 -- outcome banner playing: tick down, then resolve
 if b.done then
  b.done_t-=1
  if b.done_t<=0 or btnp(5) then
   if b.done=="capture" then
    resolve_battle_to_run("capture") return
   elseif b.done=="defeat" then
    resolve_battle_to_run("defeat") return
   end
  end
  return
 end
 if btnp(2) then b.sel=cycle_idx(b.sel,#b.cmds,-1) end
 if btnp(3) then b.sel=cycle_idx(b.sel,#b.cmds,1) end
 if btnp(5) then resolve_board_round(b.cmds[b.sel]) end
 -- no free exit: to retreat, pick "cut free" (costly)
 if b.flash>0 then b.flash-=1 end
 if b.sfx_t>0 then b.sfx_t-=1 end
end

function resolve_board_round(cmd)
 local pl=g.btl.player
 local en=g.btl.enemy
 local b=g.board

 if cmd=="cut free" then
  -- costly retreat: axing grappling lines under fire bleeds crew and
  -- rips canvas. you live to fight on, but wounded.
  local lost=2+flr(rnd(3))
  crew_loss(pl,lost)
  pl.morale=max(0,pl.morale-6)
  pl.sail_hp=max(0,pl.sail_hp-flr(pl.sail_max*.15))
  msg("cut the grapples! -"..lost.." crew",9)
  g.state=states.battle return
 end

 -- enemy action was telegraphed at round start
 local ea=b.en_intent or pick_board_enemy_action(en,b.meter)

 -- player shift (marines now scale shifts harder — they're the
 -- difference between a brawl and a one-sided beating)
 local shift=0
 if cmd=="volley" then
  shift=1+flr(pl.marines/3)
  local kills=1+flr(rnd(3))
  if ea=="charges" then kills+=1 shift+=1 end
  en.crew=max(0,en.crew-kills)
  b.info_pl="volley +"..shift.." ("..kills.." killed)"
 elseif cmd=="rush" then
  shift=2+flr(pl.marines/4)
  crew_loss(pl,1)
  if ea=="holds" then shift=max(0,shift-1) end
  b.info_pl="rush +"..shift.." (1 lost)"
 elseif cmd=="brace" then
  shift=0
  pl.morale=min(99,pl.morale+3)
  b.info_pl="brace (+3 morale)"
 elseif cmd=="rally" then
  shift=1
  pl.morale=min(99,pl.morale+4)
  b.info_pl="rally +"..shift.." (+4 morale)"
 end

 -- enemy push
 local ep=1+flr(en.marines/4)+flr(rnd(2))
 if b.side=="enemy" then ep+=1 end
 if cmd=="brace" then ep=max(0,ep-2) end
 if ea=="charges" then
  ep+=1
  b.info_en="foe charges! -"..ep
 elseif ea=="holds" then
  b.info_en="foe holds -"..ep
 elseif ea=="rallies" then
  ep=max(0,ep-1)
  en.morale=min(99,en.morale+5)
  b.info_en="foe rallies -"..ep
 end

 local net=shift-ep
 b.meter+=net
 b.round+=1
 b.flash=14
 b.info_net=net
 b.en_act=ea
 b.sfx_cmd=cmd
 b.sfx_t=20
 sfx(sfx_ids.clash,3)

 -- threshold widened from 5 to 7 so evenly-matched boardings don't
 -- resolve in 2 rounds. typical net shift is ±3, so this gives ~4-5
 -- rounds of back-and-forth before a decision.
 if b.meter>=7 then
  b.done="capture" b.done_t=120 b.flash=30 return
 end
 if b.meter<=-7 then
  -- decisive defeat: your ship is taken. run ends.
  crew_loss(pl,2+flr(rnd(2)))
  pl.morale=max(0,pl.morale-8)
  b.done="defeat" b.done_t=150 b.flash=30
  if g.run.stats then g.run.stats.cause=(en.label or "boarders") end
  return
 end
 if b.round>b.max_rounds then
  if b.meter>0 then
   b.done="capture" b.done_t=120 b.flash=30
  else
   crew_loss(pl,2+flr(rnd(2)))
   pl.morale=max(0,pl.morale-8)
   b.done="defeat" b.done_t=150 b.flash=30
   if g.run.stats then g.run.stats.cause=(en.label or "boarders") end
  end
  return
 end
 -- telegraph next round's enemy intent
 b.en_intent=pick_board_enemy_action(en,b.meter)
end

function boarding_draw()
 local pl=g.btl.player
 local en=g.btl.enemy
 local b=g.board
 local tt=t()

 -- background: dark sky + sea band
 rectfill(0,0,127,127,0)
 rectfill(0,40,127,68,1)
 for yy=42,66,3 do
  if sin(yy*.05+tt*.3)>.4 then
   pset(flr(sin(yy*.07+tt*.2)*20)+64,yy,13)
  end
 end

 -- === HEADER: round + crew bars for both sides ===
 shadow("boarding",4,2,10,0)
 shadow("round "..b.round.."/"..b.max_rounds,86,2,12,0)

 -- crew bars
 local pcw=min(48,flr(48*pl.crew/b.pl_start_crew))
 local ecw=min(48,flr(48*en.crew/b.en_start_crew))
 print("you",4,10,11)
 rectfill(20,10,68,14,1)
 if pcw>0 then rectfill(20,10,20+pcw,14,11) end
 print(pl.crew,70,10,7)
 print("\136"..pl.marines,82,10,9)
 print("foe",4,18,8)
 rectfill(20,18,68,22,1)
 if ecw>0 then rectfill(20,18,20+ecw,22,8) end
 print(en.crew,70,18,7)
 print("\136"..en.marines,82,18,9)

 -- bonuses applied at start (only on round 1)
 if b.round==1 and #b.bonuses>0 then
  local bx=4
  for s in all(b.bonuses) do
   shadow(s,bx,28,12,0)
   bx+=#s*4+8
  end
 end

 -- === SHIPS (visual tug-of-war): close-up, hulls nearly touching ===
 local meter_shake=(b.flash>0) and (rnd(2)-1) or 0
 local pl_x=50+b.meter+meter_shake
 local en_x=78-b.meter-meter_shake
 draw_ship_primitive(pl_x,52,.12,4,7,7)
 draw_ship_primitive(en_x,52,.62,en.col or 8,7,7)

 -- damage fire
 if pl.hp<pl.hp_max*.5 then
  pset(pl_x+rnd(6)-3,48+rnd(4),rnd(1)>.5 and 8 or 9)
 end
 if en.hp<en.hp_max*.5 then
  pset(en_x+rnd(6)-3,48+rnd(4),rnd(1)>.5 and 8 or 9)
 end

 -- grappling ropes
 local sway=sin(tt*2)*.8
 local tens=b.flash>0 and sin(tt*8)*1.5 or 0
 line(pl_x+10,50,en_x-10,54,6)
 line(pl_x+10,56,en_x-10,50,6)
 line(pl_x+10,53+sway+tens,en_x-10,53-sway-tens,4)

 -- enemy intent label above their ship (telegraphed next action)
 if b.en_intent and not b.done then
  local act_col=b.en_intent=="charges" and 8 or (b.en_intent=="rallies" and 12 or 13)
  shadow("\142"..b.en_intent,en_x-12,40,act_col,0)
 end

 -- combat effects
 if b.sfx_t>0 then
  local mid=(pl_x+en_x)/2
  if b.sfx_cmd=="volley" then
   for i=1,3 do
    pset(pl_x+10+rnd(12),50+rnd(6),rnd(1)>.5 and 10 or 5)
   end
  elseif b.sfx_cmd=="rush" then
   for i=1,4 do
    local f=(tt*3+i*.25)%1
    pset(pl_x+10+f*(en_x-pl_x-20),52+rnd(6),11)
   end
  end
  if b.en_act=="charges" then
   for i=1,3 do
    local f=(tt*3+i*.3)%1
    pset(en_x-10-f*(en_x-pl_x-20),52+rnd(6),8)
   end
  end
  if b.sfx_t>8 then
   for i=1,4 do
    pset(mid-15+rnd(30),48+rnd(10),10)
   end
  end
 end

 -- === METER ===
 -- threshold is ±7, so the bar now has 14 cells (i=-7..+6). cells are
 -- 8px wide, spanning x=8..119 with the center divider at x=64.
 local my=72
 rectfill(4,my,123,my+8,0)
 for i=-7,6 do
  local sx=8+flr((i+7)*8)
  if i>=0 and b.meter>i then
   rectfill(sx+1,my+1,sx+7,my+7,11)
  elseif i<0 and b.meter<=i then
   rectfill(sx+1,my+1,sx+7,my+7,8)
  else
   rectfill(sx+1,my+1,sx+7,my+7,5)
  end
 end
 line(64,my-1,64,my+9,7)
 if b.flash>6 and b.round>1 then
  local nc=b.info_net>0 and 11 or (b.info_net<0 and 8 or 6)
  local ns=b.info_net>0 and "+"..b.info_net or ""..b.info_net
  shadow(ns,58,my-6,nc,0)
 end
 -- labels sit outside the bar (bar spans x=8..119) so they read cleanly
 -- regardless of how far the meter has filled.
 print("-7",0,my+1,8)
 print("+7",120,my+1,11)

 -- === ROUND RESULT (moved up into the empty band above the ships) ===
 if b.round>1 then
  shadow(b.info_pl,4,28,11,0)
  shadow(b.info_en,4,34,8,0)
 end

 -- === COMMANDS (expanded panel, readable spacing) ===
 panel(2,84,76,43,0,5)
 for i=1,#b.cmds do
  local col=6
  local y=88+i*5
  if i==b.sel then
   col=b.cmd_cols[i]
   print("\139",4,y,col)
  end
  shadow(b.cmds[i],10,y,col,1)
 end
 -- selected command desc inside the panel, comfortably above bottom
 shadow(b.cmd_desc[b.sel],4,120,5,0)

 -- === STATS (hp/morale for both sides; marines already shown up top) ===
 panel(82,84,43,43,0,5)
 shadow("you",86,87,11,1)
 shadow("hp "..flr(pl.hp),86,94,8,1)
 shadow("mor "..flr(pl.morale),86,101,12,1)
 shadow("foe",86,109,8,1)
 shadow("hp "..flr(en.hp),86,116,8,1)
 shadow("mor "..flr(en.morale),86,122,12,1)

 -- === OUTCOME BANNER (over everything) ===
 if b.done then
  local title=b.done=="capture" and "their colors strike!" or "your ship is taken!"
  local col=b.done=="capture" and 11 or 8
  rectfill(0,52,127,76,0)
  rect(0,52,127,76,col)
  shadow(title,(127-#title*4)\2,58,col,1)
  shadow("\151 continue",42,68,7,1)
 end
end

-- src/14_ui.lua
-- ui and primitive draw helpers

-- draw a ship using only built-in primitives (no trifill)
function draw_ship_primitive(x,y,a,hull_col,size,sail_col,sub)
 sail_col=sail_col or 7
 local ca,sa=cos(a),sin(a)
 local px,py=-sa,ca
 local hw=max(1,flr(size*.35))

 -- hull: overlapping circles (clean, no artifacts)
 circfill(x-ca*size*.7,y-sa*size*.7,max(1,hw-1),hull_col)
 circfill(x-ca*size*.3,y-sa*size*.3,hw,hull_col)
 circfill(x,y,hw,hull_col)
 circfill(x+ca*size*.4,y+sa*size*.4,hw,hull_col)
 circfill(x+ca*size*.7,y+sa*size*.7,max(1,hw-1),hull_col)
 if size>=5 then
  circfill(x+ca*size,y+sa*size,max(1,hw-2),hull_col)
 end
 -- bow tip
 local bx=x+ca*size*1.4
 local by=y+sa*size*1.4
 line(x+ca*size*(size>=5 and 1 or .7),
      y+sa*size*(size>=5 and 1 or .7),
      bx,by,hull_col)
 pset(bx,by,10)

 -- deck line
 line(x+ca*size*.3,y+sa*size*.3,
      x-ca*size*.3,y-sa*size*.3,
      hull_col==7 and 6 or 5)

 -- gun ports (darken if battery damaged)
 if size>=5 then
  local gn=max(2,flr(size/2))
  local lc=sub and sub.gun_l<50 and 5 or 0
  local rc=sub and sub.gun_r<50 and 5 or 0
  for i=1,gn do
   local f=i/(gn+1)-.1
   local gx=x+ca*size*f
   local gy=y+sa*size*f
   pset(gx+px*hw*.7,gy+py*hw*.7,lc)
   pset(gx-px*hw*.7,gy-py*hw*.7,rc)
  end
 end

 -- mast
 pset(x,y,4)

 -- main sail (reduced when rigging damaged)
 local sw=size*.55
 local rig_ok=not sub or sub.rig>=50
 local sn=rig_ok and 3 or 1
 for i=0,sn do
  local f=i/sn
  local along=f*size*.3
  local billow=sw*(1-f*f*.3)
  if not rig_ok then billow*=.6 end
  line(x+ca*along,y+sa*along,
       x+ca*along+px*billow,y+sa*along+py*billow,sail_col)
 end

 -- fore sail (larger ships, skip if rigging wrecked)
 if size>=7 and rig_ok then
  local fx=x+ca*size*.5
  local fy=y+sa*size*.5
  pset(fx,fy,4)
  local fsw=size*.35
  for i=0,2 do
   local f=i/2
   local al=f*size*.15
   local bl=fsw*(1-f*f*.3)
   line(fx+ca*al,fy+sa*al,
        fx+ca*al+px*bl,fy+sa*al+py*bl,sail_col)
  end
 end

 -- mizzen sail (3-mast ships: frigate, galleon)
 if size>=9 and rig_ok then
  local mx=x-ca*size*.4
  local my=y-sa*size*.4
  pset(mx,my,4)
  local msw=size*.3
  for i=0,1 do
   local f=i
   local al=f*size*.12
   local bl=msw*(1-f*.3)
   line(mx-ca*al,my-sa*al,
        mx-ca*al+px*bl,my-sa*al+py*bl,sail_col)
  end
 end

 -- stern flag
 pset(x-ca*size*.9,y-sa*size*.9,hull_col==4 and 15 or hull_col)
end

-- visual damage marks on hull (deterministic, no flicker)
function draw_ship_damage(x,y,a,size,hp,hp_max)
 local pct=hp/hp_max
 if pct>0.75 then return end
 local ca,sa=cos(a),sin(a)
 local px,py=-sa,ca
 local hw=max(1,flr(size*.35))
 local n=pct<0.25 and 6 or (pct<0.5 and 3 or 1)
 for i=1,n do
  local along=sin(i*.37)*size*.4
  local across=cos(i*.73)*hw*.4
  pset(x+ca*along+px*across,y+sa*along+py*across,0)
  if pct<0.4 then
   pset(x+ca*along+px*across+1,y+sa*along+py*across,0)
  end
 end
end

-- filled triangle (no screen clamp — works at any world coords)
function trifill(x0,y0,x1,y1,x2,y2,col)
 if y1<y0 then x0,y0,x1,y1=x1,y1,x0,y0 end
 if y2<y0 then x0,y0,x2,y2=x2,y2,x0,y0 end
 if y2<y1 then x1,y1,x2,y2=x2,y2,x1,y1 end
 if flr(y0)==flr(y2) then return end

 for yy=flr(y0),flr(y2) do
  local xa,xb
  if yy<y1 then
   if y1==y0 then xa=x0 else
    xa=x0+(x2-x0)*(yy-y0)/(y2-y0)
    xb=x0+(x1-x0)*(yy-y0)/(y1-y0)
   end
  else
   xa=x0+(x2-x0)*(yy-y0)/(y2-y0)
   if y2==y1 then xb=x1 else
    xb=x1+(x2-x1)*(yy-y1)/(y2-y1)
   end
  end
  if xa and xb then
   if xa>xb then xa,xb=xb,xa end
   rectfill(xa,yy,xb,yy,col)
  end
 end
end

function draw_wind_arrow(x,y,a)
 circfill(x,y,7,0)
 circ(x,y,7,5)
 -- shaft
 local sx=x-cos(a)*3
 local sy=y-sin(a)*3
 local ex=x+cos(a)*5
 local ey=y+sin(a)*5
 line(sx,sy,ex,ey,12)
 -- arrowhead
 local bx=-cos(a)*2.5
 local by=-sin(a)*2.5
 local ppx=-sin(a)*2
 local ppy=cos(a)*2
 line(ex,ey,ex+bx+ppx,ey+by+ppy,7)
 line(ex,ey,ex+bx-ppx,ey+by-ppy,7)
 pset(ex,ey,7)
end

-- wake: V-shaped trail behind moving ship
function draw_wake(x,y,a,spd,col)
 if spd<.02 then return end
 if lowfx() then return end
 col=col or 13
 local ca,sa=cos(a),sin(a)
 local px,py=-sa,ca
 local n=min(8,3+flr(spd*12))
 for i=1,n do
  local d=i*1.8
  local wx=x-ca*d+rnd(.8)-.4
  local wy=y-sa*d+rnd(.8)-.4
  local sp=i*.6
  pset(wx+px*sp,wy+py*sp,col)
  pset(wx-px*sp,wy-py*sp,col)
  if i<=2 then pset(wx,wy,12) end
 end
end

-- broadside arc indicators
function draw_broadside_arc(ship,col)
 local r=ship.range or 30
 local rmin=ship.range_min or 10
 local lo=ship.arc_lo or .12
 local hi=ship.arc_hi or .38
 -- lo = forward edge (near bow), hi = aft edge (near stern).
 -- small .02 inset so the drawn arc reads slightly inside the real one.
 local pa1=wrap1(ship.a-hi+.02)
 local pa2=wrap1(ship.a-lo-.02)
 local sa1=wrap1(ship.a+lo+.02)
 local sa2=wrap1(ship.a+hi-.02)
 local n=12
 for i=0,n do
  local f=i/n
  local pa=pa1+(pa2-pa1)*f
  local sa=sa1+(sa2-sa1)*f
  -- outer range (dashed, brighter)
  if i%2==0 then
   pset(ship.x+cos(pa)*r,ship.y+sin(pa)*r,13)
   pset(ship.x+cos(sa)*r,ship.y+sin(sa)*r,13)
  end
  -- inner range
  if i%3==0 then
   pset(ship.x+cos(pa)*rmin,ship.y+sin(pa)*rmin,5)
   pset(ship.x+cos(sa)*rmin,ship.y+sin(sa)*rmin,5)
  end
 end
 -- edge lines (wedge boundaries)
 line(ship.x+cos(pa1)*rmin,ship.y+sin(pa1)*rmin,
      ship.x+cos(pa1)*r,ship.y+sin(pa1)*r,5)
 line(ship.x+cos(pa2)*rmin,ship.y+sin(pa2)*rmin,
      ship.x+cos(pa2)*r,ship.y+sin(pa2)*r,5)
 line(ship.x+cos(sa1)*rmin,ship.y+sin(sa1)*rmin,
      ship.x+cos(sa1)*r,ship.y+sin(sa1)*r,5)
 line(ship.x+cos(sa2)*rmin,ship.y+sin(sa2)*rmin,
      ship.x+cos(sa2)*r,ship.y+sin(sa2)*r,5)
end

-- src/15_fx.lua
-- particles and transient visual juice

function spawn_smoke(x,y,n,col)
 for i=1,n do
  add(g.fx,{
   kind="smoke",
   x=x+rnd(6)-3,
   y=y+rnd(6)-3,
   dx=rnd(.6)-.3,
   dy=rnd(.5)-.6,
   t=16+flr(rnd(12)),
   col=col or (5+flr(rnd(2))),
   r=1+flr(rnd(2))
  })
 end
end

-- broadside gun smoke (lingers, drifts with wind)
function spawn_gun_smoke(x,y,side_a,n)
 local wind=g.btl and g.btl.wind or 0
 local wx,wy=cos(wind)*.08,sin(wind)*.08
 for i=1,n do
  local sa=side_a+rnd(.3)-.15
  add(g.fx,{
   kind="smoke",
   x=x+cos(sa)*3+rnd(4)-2,
   y=y+sin(sa)*3+rnd(4)-2,
   dx=cos(sa)*.2+wx+rnd(.1)-.05,
   dy=sin(sa)*.2+wy+rnd(.1)-.05,
   t=28+flr(rnd(20)),
   col=5+flr(rnd(2)),
   r=1+flr(rnd(2))
  })
 end
end

-- cannon muzzle flash (bright, short-lived)
function spawn_flash(x,y,a)
 local fx=x+cos(a)*4
 local fy=y+sin(a)*4
 add(g.fx,{
  kind="flash",
  x=fx,y=fy,
  dx=cos(a)*.3,dy=sin(a)*.3,
  t=6,col=10,r=2
 })
 add(g.fx,{
  kind="flash",
  x=fx+rnd(2)-1,y=fy+rnd(2)-1,
  dx=cos(a)*.2,dy=sin(a)*.2,
  t=4,col=7,r=1
 })
end

-- water splash (blue particles rising then falling)
function spawn_splash(x,y,n)
 n=n or 5
 for i=1,n do
  local ang=rnd(1)
  add(g.fx,{
   kind="splash",
   x=x+rnd(6)-3,
   y=y+rnd(4)-2,
   dx=cos(ang)*.6,
   dy=-(rnd(.9)+.3),
   t=18+flr(rnd(12)),
   col=rnd_item({7,7,12,12,6}),
   r=0
  })
 end
end

-- fire/ember particles (orange-red, drift up)
function spawn_fire(x,y,n)
 n=n or 3
 for i=1,n do
  local c=rnd_item({8,9,10,10})
  add(g.fx,{
   kind="fire",
   x=x+rnd(6)-3,
   y=y+rnd(4)-2,
   dx=rnd(.4)-.2,
   dy=-(rnd(.4)+.1),
   t=14+flr(rnd(10)),
   col=c,
   r=flr(rnd(2))
  })
 end
end

-- debris/splinter particles
function spawn_debris(x,y,n)
 n=n or 5
 for i=1,n do
  local ang=rnd(1)
  local spd=rnd(1.2)+.3
  add(g.fx,{
   kind="debris",
   x=x+rnd(5)-2.5,
   y=y+rnd(5)-2.5,
   dx=cos(ang)*spd,
   dy=sin(ang)*spd-.4,
   t=24+flr(rnd(14)),
   col=rnd_item({4,4,4,4,15,15}),
   r=0
  })
 end
end

function spawn_label(x,y,text,col)
 add(g.fx,{kind="label",x=x,y=y,dx=0,dy=-.12,t=30,text=text,col=col,r=0})
end

function update_fx()
 if not g.fx then g.fx={} end
 for fx in all(g.fx) do
  fx.x+=fx.dx
  fx.y+=fx.dy
  fx.t-=1
  -- gravity for splash and debris
  if fx.kind=="splash" or fx.kind=="debris" then
   fx.dy+=.03
  end
  -- fire drifts and fades
  if fx.kind=="fire" and fx.t<6 then
   fx.col=5
  end
  if fx.t<=0 then
   del(g.fx,fx)
  end
 end
end

function draw_fx()
 if not g.fx then return end
 for fx in all(g.fx) do
  if fx.kind=="smoke" then
   circfill(fx.x,fx.y,fx.r,fx.col)
  elseif fx.kind=="flash" then
   circfill(fx.x,fx.y,fx.r,fx.col)
  elseif fx.kind=="splash" then
   pset(fx.x,fx.y,fx.col)
  elseif fx.kind=="fire" then
   if fx.r>0 then
    circfill(fx.x,fx.y,fx.r,fx.col)
   else
    pset(fx.x,fx.y,fx.col)
   end
  elseif fx.kind=="debris" then
   pset(fx.x,fx.y,fx.col)
  elseif fx.kind=="label" then
   if fx.t>8 then
    print(fx.text,fx.x-#fx.text*2,fx.y,fx.col)
   end
  end
 end
end

-- src/16_persistence.lua
-- tiny persistent meta layer

function load_meta()
 cartdata("rogue_wake_meta")
 local bg=dget(4)
 local pk=dget(5)
 -- first boot: only dock rat + first three perks unlocked
 if bg<=0 then bg=1 end
 if pk<=0 then pk=7 end
 g.meta={
  runs=dget(0) or 0,
  best_gold=dget(1) or 0,
  best_renown=dget(2) or 0,
  tokens=dget(3) or 0,
  bg_unlocks=bg,
  perk_unlocks=pk,
  rich_unlocked=(dget(6) or 0)>0
 }
 g.opts={lowfx=(dget(7) or 0)>0}
end

function save_meta()
 dset(0,g.meta.runs or 0)
 dset(1,g.meta.best_gold or 0)
 dset(2,g.meta.best_renown or 0)
 dset(3,g.meta.tokens or 0)
 dset(4,g.meta.bg_unlocks or 1)
 dset(5,g.meta.perk_unlocks or 7)
 dset(6,g.meta.rich_unlocked and 1 or 0)
 dset(7,(g.opts and g.opts.lowfx) and 1 or 0)
end

function lowfx() return g.opts and g.opts.lowfx end

function rich_start_cost() return 20 end

function bg_unlocked(ix)
 return band(g.meta.bg_unlocks or 1,1<<(ix-1))~=0
end

function perk_unlocked(ix)
 return band(g.meta.perk_unlocks or 7,1<<(ix-1))~=0
end

-- cost scale: backgrounds are bigger playstyle shifts than perks
function bg_unlock_cost(ix) return 8 end
function perk_unlock_cost(ix) return 4 end

function unlock_bg(ix)
 g.meta.bg_unlocks=bor(g.meta.bg_unlocks or 1,1<<(ix-1))
end
function unlock_perk(ix)
 g.meta.perk_unlocks=bor(g.meta.perk_unlocks or 7,1<<(ix-1))
end

-- src/17_state_prize.lua
-- prize choice after battle victory / surrender

function prize_init(arg)
 local en=g.btl.enemy
 local pl=g.btl.player
 local outcome=(arg and arg.outcome) or "victory"

 local base_loot=g.btl.loot or 40
 if outcome=="surrender" then
  base_loot=flr(base_loot*1.2)
 end
 if has_perk("lucky_devil") then
  base_loot=flr(base_loot*1.15)
 end
 if has_perk("salvage_instinct") then
  base_loot=flr(base_loot*1.10)
 end
 if has_upgrade("prize_charter") then
  base_loot=flr(base_loot*1.25)
 end

 -- capture: detach a prize crew (hands + 1 marine) to sail the hull to
 -- the nearest shipyard. disabled if towing a prize, low on hands, or
 -- without at least 2 marines (one for the prize, one to keep aboard).
 local prize_cost=ship_defs[en.id] and prize_crew_cost(en.id) or 99
 local hands=(g.run.player.crew and g.run.player.crew.hands) or 0
 local marines=(g.run.player.crew and g.run.player.crew.marines) or 0
 local can_capture=ship_defs[en.id]~=nil
  and not g.run.prize_in_tow
  and hands>=prize_cost+2
  and marines>=2

 -- determine cargo loot based on enemy profile
 local prize_cargo=nil
 local prize_cargo_qty=0
 local prof=en.profile or ""
 if prof=="merchant" then
  prize_cargo=rnd_item({"staples","luxury","medicine","powder"})
  prize_cargo_qty=2+flr(rnd(3))
 elseif prof=="raider" then
  prize_cargo=rnd_item({"contraband","arms"})
  prize_cargo_qty=1+flr(rnd(2))
 elseif prof=="treasure" then
  prize_cargo="treasure"
  prize_cargo_qty=2+flr(rnd(3))
 elseif prof=="privateer" then
  prize_cargo=rnd_item({"arms","powder"})
  prize_cargo_qty=1+flr(rnd(2))
 end

 -- ammo-type reward shaping:
 -- round/heavy shot holes the hull and crates. grape panics crew
 -- and reveals hidden stashes. chain preserves cargo. boarding wins
 -- (surrender/capture outcomes) keep cargo intact and add a bonus.
 local ah=(g.btl and g.btl.ammo_hits) or {round=0,chain=0,grape=0,heavy=0}
 local cargo_mult=1
 local loot_mult=1
 if prize_cargo_qty>0 then
  local smash=ah.round+ah.heavy*1.4
  cargo_mult=max(.45,1-smash*.07)
 end
 loot_mult=min(1.35,1+ah.grape*.025)
 if outcome=="surrender" or outcome=="capture" then
  cargo_mult=min(1.3,cargo_mult+.25)
  loot_mult=loot_mult*1.05
 end
 prize_cargo_qty=max(0,flr(prize_cargo_qty*cargo_mult+.5))
 base_loot=flr(base_loot*loot_mult)

 g.prize={
  outcome=outcome,
  loot=base_loot,
  enemy_name=en.label or "enemy",
  enemy_hull=en.id or "sloop",
  can_capture=can_capture,
  sel=1,
  items={},
  pl_hp_lost=flr(pl.hp_max-pl.hp),
  pl_crew_lost=max(0,flr((pl.crew_start or pl.crew)-pl.crew)),
  pl_sail_lost=flr(pl.sail_max-pl.sail_hp),
  cargo=prize_cargo,
  cargo_qty=prize_cargo_qty,
  ammo_hits=ah
 }

 -- build choice list
 local loot_desc="loot "..base_loot.."g"
 if prize_cargo then
  loot_desc=loot_desc.." +"..prize_cargo_qty.." "..prize_cargo
 end
 add(g.prize.items,{id="loot",name=loot_desc})
 if can_capture then
  add(g.prize.items,{id="capture",name="capture ("..prize_cost.."h 1m)"})
 end
 add(g.prize.items,{id="release",name="release for renown"})

 -- seed a small ocean matching the battle feel: a few swells + foam dots
 g.prize_swells={}
 local n_psw=lowfx() and 2 or 3
 for i=1,n_psw do
  add(g.prize_swells,{
   cx=flr(rnd(128)),
   cy=40+flr(rnd(70)),
   pos=rnd(1),
   spd=.05+rnd(.08),
   len=30+flr(rnd(30)),
   thick=4+flr(rnd(4))
  })
 end
 g.prize_dots={}
 local n_pd=lowfx() and 30 or 80
 for i=1,n_pd do
  add(g.prize_dots,{
   x=flr(rnd(128)),
   y=flr(rnd(128)),
   col=rnd_item({7,7,13,13,6,6}),
   ph=rnd(1)
  })
 end
end

function prize_update()
 if btnp(2) then g.prize.sel=cycle_idx(g.prize.sel,#g.prize.items,-1) end
 if btnp(3) then g.prize.sel=cycle_idx(g.prize.sel,#g.prize.items,1) end

 if btnp(5) then
  do_prize_choice(g.prize.items[g.prize.sel])
 end
end

function do_prize_choice(item)
 if not item then return end
 local p=g.run.player

 -- write back battle damage to run state first (restore repairable pool)
 local final_hp=g.btl.player.hp_perm or g.btl.player.hp
 p.hp=clamp(flr(final_hp),0,run_hp_max(p))
 p.sail_hp=clamp(flr(g.btl.player.sail_hp),0,run_sail_max(p))
 p.morale=clamp(flr(g.btl.player.morale),20,99)
 persist_battle_crew_losses()

 if item.id=="loot" then
  if g.run.stats then
   g.run.stats.gold_earned+=g.prize.loot
   if g.prize.loot>g.run.stats.biggest_prize then
    g.run.stats.biggest_prize=g.prize.loot
    g.run.stats.biggest_prize_name=g.prize.enemy_name or "a prize"
   end
  end
  p.gold+=g.prize.loot
  -- add cargo loot
  if g.prize.cargo and g.prize.cargo_qty>0 then
   local room=cargo_cap()-cargo_count()
   local qty=min(g.prize.cargo_qty,room)
   if qty>0 then
    p.cargo[g.prize.cargo]=(p.cargo[g.prize.cargo] or 0)+qty
   end
  end
  g.run.heat+=1
  g.run.renown+=1
  if has_perk("ruthless_example") then
   g.run.heat+=1
   g.run.renown+=1
  end
  maybe_gain_perk()
  sfx(sfx_ids.gold,3)
  msg("looted "..g.prize.loot.." gold",10)

 elseif item.id=="capture" then
  -- send a prize crew (hands + 1 marine) to sail her to the nearest
  -- shipyard. player's current hull is unchanged; prize resolves at port.
  local new_hull=g.prize.enemy_hull
  local cost=prize_crew_cost(new_hull)
  p.crew.hands=max(0,p.crew.hands-cost)
  p.crew.marines=max(0,(p.crew.marines or 0)-1)
  -- capture condition: carry forward actual battle damage from the enemy
  local en=g.btl.enemy
  local en_hp=(en and (en.hp_perm or en.hp)) or (ship_defs[new_hull].hull*.6)
  local en_sail=(en and en.sail_hp) or (ship_defs[new_hull].sails*.7)
  en_hp=max(1,flr(en_hp))
  en_sail=max(0,flr(en_sail))
  g.run.prize_in_tow={
   hull=new_hull,
   label=g.prize.enemy_name,
   crew_held=cost,
   hp=en_hp,
   sail_hp=en_sail
  }
  local cap_gold=flr(g.prize.loot*.4)
  p.gold+=cap_gold
  if g.run.stats then g.run.stats.gold_earned+=cap_gold end
  p.captures+=1
  g.run.heat+=2
  g.run.renown+=2
  -- capturing a marked treasure galleon completes the treasure goal
  if g.btl and g.btl.enc and g.btl.enc.npc and g.btl.enc.npc.treasure_prize then
   g.run.treasure_taken=true
  end
  maybe_gain_perk()
  msg("prize crew aboard "..new_hull,10)

 elseif item.id=="release" then
  g.run.renown+=3
  -- releasing lowers heat and improves faction standing
  g.run.heat=max(0,g.run.heat-1)
  p.morale=min(99,p.morale+3)
  maybe_gain_perk()
  msg("released - renown +3",11)
 end

 -- sea wolf perk: morale boost on any win
 if has_perk("sea_wolf") then
  p.morale=min(99,p.morale+4)
 end

 -- check battle-type contract completion
 if g.btl and g.btl.enemy then
  check_contract_battle(g.btl.enemy.profile or "")
 end

 -- faction reputation changes: random (self-defence) encounters with
 -- a neutral/friendly faction don't cost rep - only deliberate attacks
 -- (intercept, rival) or already-hostile skirmishes tick rep down
 if g.btl and g.btl.enc_faction and g.btl.enc_faction~="pirates" then
  local fid=g.btl.enc_faction
  if g.run.factions[fid] then
   local intentional=(g.btl.enc and (g.btl.enc.npc or g.btl.enc.rival)) and true or false
   local already_hostile=faction_standing(fid)=="hostile"
   local rep_counts=intentional or already_hostile
   if item.id=="loot" and rep_counts then
    g.run.factions[fid].rep-=2
   elseif item.id=="capture" and rep_counts then
    g.run.factions[fid].rep-=3
   elseif item.id=="release" then
    g.run.factions[fid].rep+=2
   end
  end
 end
 -- attacking pirates improves all lawful factions slightly
 if g.btl and g.btl.enc_faction=="pirates" then
  for _,f in pairs(g.run.factions) do
   f.rep+=1
  end
 end

 -- remove the intercepted npc from the world (if any)
 if g.btl and g.btl.enc and g.btl.enc.npc then
  if g.btl.enc.npc.treasure_escort then
   g.run.treasure_escort_down=true
  end
  del(g.run.npcs,g.btl.enc.npc)
  maybe_spawn_treasure_galleon()
 end

 -- mark rival as defeated + advance act
 if g.btl and g.btl.enc and g.btl.enc.rival then
  local r=g.btl.enc.rival
  r.defeated=true
  g.run.renown+=3
  p.gold+=40
  if g.run.stats then g.run.stats.gold_earned+=40 end
  grant_rival_reward(r,p)
  maybe_gain_perk()
  -- msg budget at x=12: 26 chars. short name (max 9) + " +" + reward (max 13) = 24.
  msg((r.short or r.name).." +"..r.reward,10)
  -- advance act if this was the current act's rival
  if r.region==act_defs[g.run.act].region then
   if g.run.act>=#act_defs then
    -- final rival defeated. only triggers the crown outcome if that
    -- was the chosen goal; otherwise the run continues until the
    -- chosen goal is met (via check_run_victory). tell the player
    -- what still stands between them and the summary screen.
    if g.run.goal=="crown" then
     set_state(states.summary,{outcome="pirate_crown"})
     return
    elseif g.run.goal=="treasure" then
     msg("final foe down - take a galleon",10)
    elseif g.run.goal=="legend" then
     msg("final foe down - reach 15 renown",10)
    elseif g.run.goal=="marque" then
     msg("final foe down - reach 10 rep",10)
    end
   else
    g.run.act+=1
    -- snapshot baselines when entering act 3 so legend/marque wins
    -- require progress made *in* act 3, not accumulated in acts 1-2.
    if g.run.act==#act_defs then
     g.run.act3_renown_base=g.run.renown
     g.run.act3_rep_base={}
     for fid,f in pairs(g.run.factions) do
      g.run.act3_rep_base[fid]=f.rep or 0
     end
    end
    g.run.ports=load_act_ports(g.run.act)
    g.run.loc=1
    g.pending_dest=nil
    if g.run.contract then
     -- half-pay the voided contract so it doesn't vanish silently
     p.gold+=flr((g.run.contract.pay or 0)*.5)
     msg("contract voided: +half pay",9)
    end
    g.run.contract=nil -- old contract targets don't exist in new act
    spawn_act_npcs()
    if g.run.stats then g.run.stats.ports_visited["a"..g.run.act.."_1"]=true end
    g.run.act_card_t=t()
    sfx(60,3)
   end
  end
 end

 -- update meta
 if p.gold>g.meta.best_gold then g.meta.best_gold=p.gold end
 if g.run.renown>g.meta.best_renown then g.meta.best_renown=g.run.renown end
 save_meta()

 -- return to world
 if g.pending_dest then
  g.run.loc=g.pending_dest
  g.pending_dest=nil
  if g.run.stats then g.run.stats.ports_visited["a"..g.run.act.."_"..g.run.loc]=true end
  check_contract_arrive(g.run.loc)
 end
 set_state(states.world)
end

function prize_draw()
 local pr=g.prize
 local tt=t()

 -- ocean fills the whole frame, matching the battle style.
 -- no sky/horizon chrome — the ship floats in the sea, period.
 rectfill(0,0,127,127,1)

 -- wave crests drifting across (static swells, similar to battle)
 for s in all(g.prize_swells or {}) do
  local off=(s.pos+tt*s.spd*8)%160-16
  for t=-s.len,s.len do
   local wx=s.cx+t
   local wy=s.cy+sin(t*.04+s.pos)*3+off*.0
   local drift=sin(tt*.3+s.pos)*1.5
   wy+=drift
   if wx>=0 and wx<=127 and wy>=0 and wy<=127 then
    local h=(t*31+flr(s.pos*11))
    local dens=s.thick+flr(abs(t)/s.len*8)
    if h%dens<1 then
     pset(wx,wy,h%17<3 and 6 or 13)
    end
   end
  end
 end

 -- drifting foam/whitecap dots (static field seeded once)
 for d in all(g.prize_dots or {}) do
  pset(d.x+sin(tt*.2+d.ph)*.5,d.y,d.col)
 end

 -- enemy ship: real hull, color, damage from battle
 local en=g.btl and g.btl.enemy
 local hull_id=pr.enemy_hull or "sloop"
 local sd=ship_defs[hull_id]
 local ship_size=((sd and sd.size) or 7)+3
 local ship_col=(en and en.col) or 8
 local hp_pct=1
 local sail_pct=1
 if en and en.hp_max then hp_pct=max(0,en.hp/en.hp_max) end
 if en and en.sail_max then sail_pct=max(0,en.sail_hp/en.sail_max) end

 -- listing angle increases with hull damage
 local list=.05+(1-hp_pct)*.12
 local sx,sy=64,54
 sy+=sin(tt*.5)*.7

 -- wake at the waterline (subtle white foam arcs)
 for i=-ship_size,ship_size do
  if rnd(1)<.35 then
   pset(sx+i,sy+ship_size*.5+rnd(2),7)
  end
 end

 -- smoke plume when wounded
 if hp_pct<.6 then
  for i=0,6 do
   local st=(tt*.4+i*.15)%1
   local sy2=sy-6-st*26
   local sx2=sx+sin(tt*.3+i*1.1)*4-st*4
   local c=st<.35 and 5 or (st<.7 and 6 or 13)
   if st<.92 then pset(sx2,sy2,c) end
  end
 end

 -- flames at the waterline for heavy damage
 if hp_pct<.35 then
  for i=0,4 do
   local fx=sx+rnd(ship_size*1.4)-ship_size*.7
   local fy=sy+1+rnd(2)
   pset(fx,fy,rnd(1)>.5 and 9 or 8)
  end
 end

 draw_ship_primitive(sx,sy,list,ship_col,ship_size,
  sail_pct<.4 and 5 or 7,en and en.sub)

 -- hull-breach black pips along the damaged side
 if hp_pct<.7 then
  local n=flr((1-hp_pct)*10)
  for i=1,n do
   local dx=sx-ship_size+i*2
   local dy=sy+flr(rnd(3))
   pset(dx,dy,0)
  end
 end

 -- outcome banner (drawn on top of everything so it reads clearly)
 local title_col=11
 local title_txt="victory!"
 if pr.outcome=="surrender" then
  title_txt="they strike colors!"
  title_col=10
 elseif pr.outcome=="capture" then
  title_txt="prize taken!"
  title_col=11
 end
 -- small shadowed backdrop behind the banner for contrast
 local tw=#title_txt*4
 rectfill(64-tw/2-3,4,64+tw/2+2,12,0)
 printc(title_txt,6,title_col)

 -- ammo breakdown (how your shot choices shaped the prize)
 if pr.ammo_hits then
  local ah=pr.ammo_hits
  local xx=8
  local n_round=ah.round+ah.heavy
  if n_round>0 then
   local t=n_round.."rnd"
   shadow(t,xx,16,10,0)
   xx+=#t*4+4
  end
  if ah.chain>0 then
   local t=ah.chain.."chn"
   shadow(t,xx,16,12,0)
   xx+=#t*4+4
  end
  if ah.grape>0 then
   local t=ah.grape.."grp"
   shadow(t,xx,16,8,0)
  end
 end

 -- damage report + enemy name
 panel(4,72,119,16,0,5)
 shadow(pr.enemy_name,8,75,6,1)
 shadow("-hull "..pr.pl_hp_lost,8,82,8,1)
 shadow("-sail "..pr.pl_sail_lost,48,82,12,1)
 shadow("-crew "..max(0,pr.pl_crew_lost),86,82,7,1)

 -- choices
 panel(8,92,111,34,0,5)
 for i=1,#pr.items do
  local col=6
  local y=94+i*7
  if i==pr.sel then
   col=10
   print("\139",11,y,10)
  end
  shadow(pr.items[i].name,18,y,col,1)
 end
end

-- src/18_state_event.lua
-- sea events during travel (non-combat encounters)

-- event definitions with mechanical effects
event_defs={
 {
  id="storm_front",
  text="a black squall thunders across the bow",
  choices={
   {name="drive through",effect="storm_push"},
   {name="heave to and wait",effect="storm_wait"},
   {name="run for shelter",effect="storm_shelter"}
  }
 },
 {
  id="distress",
  text="a lantern flashes distress in the dusk",
  choices={
   {name="approach with guns run out",effect="distress_armed"},
   {name="approach in good faith",effect="distress_open"},
   {name="keep your course",effect="distress_ignore"}
  }
 },
 {
  id="derelict",
  text="a drifting hulk, silent and swaying",
  choices={
   {name="strip her cargo",effect="derelict_loot"},
   {name="cannibalize for repairs",effect="derelict_repair"},
   {name="press the crew she hides below",effect="derelict_press"}
  }
 },
 {
  id="brotherhood",
  text="a black-sailed brig signals you to parley",
  choices={
   {name="join their strike plan",effect="broth_join"},
   {name="sell her captain intel",effect="broth_sell"},
   {name="decline and report home",effect="broth_decline"}
  }
 },
 {
  id="fever",
  text="sickness moves through the lower deck",
  choices={
   {name="break out the medicine",effect="fever_medicine"},
   {name="isolate the sick",effect="fever_isolate"},
   {name="sweat it out on short rations",effect="fever_rations"}
  }
 },
 {
  id="false_colors",
  text="a ship flies colors that don't match her rigging",
  choices={
   {name="engage at once",effect="fc_engage"},
   {name="demand tribute",effect="fc_tribute"},
   {name="slip away",effect="fc_flee"}
  }
 },
 {
  id="treasure_chart",
  text="a dying sailor presses a salt-stained chart into your hands",
  choices={
   {name="study the markings",effect="chart_study"},
   {name="sell it to the navigators' guild",effect="chart_sell"},
   {name="burn it as evidence",effect="chart_burn"}
  }
 },
 {
  id="shoal_pass",
  text="a narrow channel cuts between shallow islands",
  choices={
   {name="thread the shallows",effect="shoal_risk"},
   {name="put in at the small key",effect="shoal_rest"},
   {name="take the open water route",effect="shoal_safe"}
  }
 },
 {
  id="becalmed",
  text="the wind dies. sails hang limp under a brass sun",
  choices={
   {name="row through the glass",effect="calm_row"},
   {name="wait for a breeze",effect="calm_wait"},
   {name="whistle for wind",effect="calm_whistle"}
  }
 },
 {
  id="peddler",
  text="a small sloop draws alongside. her captain opens a crate",
  choices={
   {name="buy supplies at sea",effect="pedl_sup"},
   {name="barter for medicine",effect="pedl_med"},
   {name="send him on his way",effect="pedl_decline"}
  }
 },
 {
  id="stowaway",
  text="a figure is dragged up from the bilge, pale and blinking",
  choices={
   {name="press into the crew",effect="stow_press"},
   {name="over the side",effect="stow_drown"},
   {name="turn her in at port",effect="stow_turn"}
  }
 },
 {
  id="whale_pod",
  text="a pod of whales breaches off the bow, blowing rainbow mist",
  choices={
   {name="harpoon the nearest bull",effect="whale_hunt"},
   {name="sail through the pod",effect="whale_pass"},
   {name="take a wide course",effect="whale_wide"}
  }
 },
 {
  id="flotsam",
  text="debris from a wreck drifts past - crates, spars, a broken boat",
  choices={
   {name="launch a boat",effect="flot_salvage"},
   {name="scan for survivors",effect="flot_search"},
   {name="sail on through",effect="flot_ignore"}
  }
 }
}

function roll_sea_event()
 -- early-game bias: act 1, first 5 days, exclude punishing events so the
 -- first runs aren't bricked by a fever or a calm right out of port
 if g.run.act==1 and g.run.day<=5 then
  local soft={}
  for ev in all(event_defs) do
   if ev.id~="storm_front" and ev.id~="fever" and ev.id~="becalmed" then
    add(soft,ev)
   end
  end
  return rnd_item(soft)
 end
 return rnd_item(event_defs)
end

-- customs cutter is triggered contextually (not in the general pool).
-- kept out of event_defs so it only fires when sail_to_port finds the right conditions.
customs_cutter_def={
 id="customs_cutter",
 text="a customs cutter signals you to heave to",
 choices={
  {name="submit to inspection",effect="cust_submit"},
  {name="pay a quiet bribe",effect="cust_bribe"},
  {name="show false colors",effect="cust_bluff"},
  {name="refuse and make sail",effect="cust_fight"}
 }
}

-- lawful factions that run patrols
function is_lawful(owner)
 return owner=="crown" or owner=="empire" or owner=="republic"
end

-- decide if a customs cutter stops us on this leg. returns patroller id or nil.
function roll_customs_cutter(from_p,to_p)
 -- patrols only run shipping lanes in lawful waters
 local patroller=nil
 if is_lawful(to_p.owner) then patroller=to_p.owner
 elseif is_lawful(from_p.owner) then patroller=from_p.owner end
 if not patroller then return nil end
 local p=g.run.player
 local cband=(p.cargo and p.cargo.contraband) or 0
 local rep=(g.run.factions[patroller] and g.run.factions[patroller].rep) or 0
 local chance=.05
 chance+=min(.3,g.run.heat*.03)
 if cband>0 then chance+=.15 end
 if rep<-2 then chance+=.10 end
 -- smuggler priest keeps most patrols looking the other way
 if has_officer("smuggler_priest") then chance*=.5 end
 if rnd(1)<chance then return patroller end
 return nil
end

function event_init(arg)
 local ev=arg.event or roll_sea_event()
 g.evt={
  def=ev,
  sel=1,
  resolved=false,
  result_text=nil,
  dest=arg.dest,
  patroller=arg.patroller
 }
 -- seed an ocean matching the battle/prize feel
 g.evt.swells={}
 local n_esw=lowfx() and 2 or 4
 for i=1,n_esw do
  add(g.evt.swells,{
   cx=flr(rnd(128)),
   cy=40+flr(rnd(84)),
   pos=rnd(1),
   len=28+flr(rnd(28)),
   thick=4+flr(rnd(4)),
   spd=.4+rnd(.4)
  })
 end
 g.evt.dots={}
 local n_ed=lowfx() and 25 or 70
 for i=1,n_ed do
  add(g.evt.dots,{
   x=flr(rnd(128)),
   y=flr(rnd(128)),
   col=rnd_item({7,7,13,13,6,6}),
   ph=rnd(1)
  })
 end
end

function event_update()
 if g.evt.resolved then
  if btnp(5) or btnp(4) then
   -- continue to destination
   if g.evt.dest then
    g.run.loc=g.evt.dest
    g.pending_dest=nil
    if g.run.stats then g.run.stats.ports_visited["a"..g.run.act.."_"..g.run.loc]=true end
    check_contract_arrive(g.evt.dest)
   end
   set_state(states.world)
  end
  return
 end

 local choices=g.evt.def.choices
 if btnp(2) then g.evt.sel=cycle_idx(g.evt.sel,#choices,-1) end
 if btnp(3) then g.evt.sel=cycle_idx(g.evt.sel,#choices,1) end

 if btnp(5) then
  apply_event_effect(choices[g.evt.sel].effect)
  -- effects can flag a soft-failure retry (no gold to bribe, no colors to bluff)
  if not g.evt.retry then g.evt.resolved=true end
  g.evt.retry=nil
  maybe_gain_perk()
 end
end

function apply_event_effect(effect)
 local p=g.run.player
 local am=1+((g.run.act or 1)-1)*.5 -- gold multiplier: act 1=1x, act 2=1.5x, act 3=2x
 local ab=(g.run.act or 1)-1        -- flat bonus: 0 / 1 / 2 for later-act rewards

 -- storm_front
 if effect=="storm_push" then
  local dmg=3+flr(rnd(5))
  if has_perk("weather_eye") then dmg=max(1,flr(dmg*.5)) end
  if has_upgrade("storm_sails") then dmg=max(1,dmg-2) end
  p.sail_hp=max(0,p.sail_hp-dmg)
  p.morale=max(20,p.morale-3)
  g.run.day=max(1,g.run.day-1)
  g.evt.result_text="battered but a day ahead -"..dmg.." sails"

 elseif effect=="storm_wait" then
  g.run.day+=2
  p.morale=min(99,p.morale+3+ab)
  p.hp=min(run_hp_max(p),p.hp+2+ab)
  g.evt.result_text="+2 days, crew rested, hull patched"

 elseif effect=="storm_shelter" then
  -- divert to nearest port instead of the original destination
  local cur=cur_port()
  local best,bestd=g.run.loc,9999
  for i=1,#g.run.ports do
   if i~=g.run.loc then
    local d=dist(cur.x,cur.y,g.run.ports[i].x,g.run.ports[i].y)
    if d<bestd then best=i bestd=d end
   end
  end
  g.evt.dest=best
  g.run.day+=1
  g.evt.result_text="diverted to "..g.run.ports[best].name

 -- distress
 elseif effect=="distress_armed" then
  if rnd(1)<.5 then
   g.evt.result_text="trap! but you were ready"
   g.evt.resolved=true
   local enc={kind="sea",profile="raider",region=cur_port().region,heat_buff=-1}
   g.pending_dest=g.evt.dest
   start_battle(enc)
   return
  else
   local gold=flr((8+flr(rnd(10)))*am)
   p.gold+=gold
   p.morale=max(20,p.morale-2)
   g.evt.result_text="survivors spooked, small reward +"..gold.."g"
  end

 elseif effect=="distress_open" then
  if rnd(1)<.5 then
   g.evt.result_text="it was a trap - they board you!"
   g.evt.resolved=true
   local enc={kind="sea",profile="raider",region=cur_port().region,heat_buff=1}
   g.pending_dest=g.evt.dest
   start_battle(enc)
   return
  else
   local gold=flr((20+flr(rnd(14)))*am)
   local ren=1+ab
   p.gold+=gold
   g.run.renown+=ren
   g.evt.result_text="grateful captain pays "..gold.."g +"..ren.." ren"
  end

 elseif effect=="distress_ignore" then
  p.morale=max(20,p.morale-2)
  if g.run.factions["crown"] then
   g.run.factions["crown"].rep-=1
  end
  g.evt.result_text="crew remember. morale -2, crown -1"

 -- derelict
 elseif effect=="derelict_loot" then
  local gold=flr((14+flr(rnd(16)))*am)
  if has_perk("salvage_instinct") then gold=flr(gold*1.4) end
  p.gold+=gold
  p.supplies=min(30,p.supplies+2+ab)
  g.evt.result_text="stripped her clean +"..gold.."g"

 elseif effect=="derelict_repair" then
  p.hp=min(run_hp_max(p),p.hp+8+ab*2)
  p.sail_hp=min(run_sail_max(p),p.sail_hp+6+ab*2)
  g.evt.result_text="salvaged timbers and canvas"

 elseif effect=="derelict_press" then
  local h=3+ab
  p.crew.hands=p.crew.hands+h
  enforce_crew_cap(p)
  p.morale=max(20,p.morale-5)
  g.evt.result_text="+"..h.." hands, but crew uneasy -5 mor"

 -- brotherhood
 elseif effect=="broth_join" then
  g.run.heat=min(10,g.run.heat+2)
  g.run.renown+=2+ab
  -- set a pending payout in a few days
  g.run.pending_brotherhood={day=g.run.day+3,gold=flr(40*am)}
  g.evt.result_text="you ride with them. payout in 3 days"

 elseif effect=="broth_sell" then
  p.gold+=flr(30*am)
  if g.run.factions["pirates"] then
   g.run.factions["pirates"].rep-=3
  end
  g.evt.result_text="crown gold for pirate secrets"

 elseif effect=="broth_decline" then
  if g.run.factions["crown"] then
   g.run.factions["crown"].rep+=1
  end
  g.evt.result_text="crown learns of the meeting, +1 rep"

 -- fever
 elseif effect=="fever_medicine" then
  if p.cargo["medicine"] and p.cargo["medicine"]>0 then
   p.cargo["medicine"]-=1
   if p.cargo["medicine"]<=0 then p.cargo["medicine"]=nil end
   local m=4+ab
   p.morale=min(99,p.morale+m)
   g.evt.result_text="-1 medicine, crew healed +"..m.." mor"
  else
   p.crew.hands=max(1,p.crew.hands-2)
   p.morale=max(20,p.morale-6)
   g.evt.result_text="no medicine! -2 hands -6 mor"
  end

 elseif effect=="fever_isolate" then
  p.crew.hands=max(1,p.crew.hands-2)
  p.morale=min(99,p.morale+2)
  g.evt.result_text="sick put ashore. -2 hands +2 mor"

 elseif effect=="fever_rations" then
  p.supplies=max(0,p.supplies-5)
  p.morale=max(20,p.morale-3)
  g.evt.result_text="-5 supplies, crew sweat it out"

 -- false_colors
 elseif effect=="fc_engage" then
  g.evt.resolved=true
  local enc={kind="sea",profile=rnd_item({"privateer","raider"}),region=cur_port().region}
  g.pending_dest=g.evt.dest
  start_battle(enc)
  return

 elseif effect=="fc_tribute" then
  local pstats=ship_defs[p.hull]
  if pstats.broadside>=6 then
   p.gold+=flr(25*am)
   g.evt.result_text="they paid tribute +"..flr(25*am).."g"
  else
   g.evt.result_text="they see your guns and attack!"
   g.evt.resolved=true
   local enc={kind="sea",profile="privateer",region=cur_port().region}
   g.pending_dest=g.evt.dest
   start_battle(enc)
   return
  end

 elseif effect=="fc_flee" then
  g.run.day+=1
  p.morale=max(20,p.morale-3)
  g.evt.result_text="slipped away, lost a day"

 -- treasure chart
 elseif effect=="chart_study" then
  -- the chart always points to the final act — act-3-gated wins.
  g.run.treasure_clue={act=#act_defs}
  g.evt.result_text="the chart points to the frontier coast!"

 elseif effect=="chart_sell" then
  p.gold+=flr(35*am)
  g.evt.result_text="sold the chart +"..flr(35*am).."g"

 elseif effect=="chart_burn" then
  if g.run.factions["crown"] then
   g.run.factions["crown"].rep+=2
  end
  g.run.heat=max(0,g.run.heat-1)
  g.evt.result_text="burned. crown rep +2, heat -1"

 -- shoal
 elseif effect=="shoal_risk" then
  if rnd(1)<.4 then
   p.hp=max(0,p.hp-5)
   g.evt.result_text="scraped hard! -5 hull"
  else
   g.run.day=max(1,g.run.day-1)
   g.evt.result_text="shortcut! saved a day"
  end

 elseif effect=="shoal_rest" then
  local m=5+ab
  local sp=3+ab
  p.morale=min(99,p.morale+m)
  p.supplies=min(30,p.supplies+sp)
  g.run.day+=1
  g.evt.result_text="rested on the key +"..m.." mor +"..sp.." sup"

 elseif effect=="shoal_safe" then
  g.run.day+=1
  g.evt.result_text="the long route, +1 day"

 -- becalmed
 elseif effect=="calm_row" then
  p.supplies=max(0,p.supplies-4)
  p.morale=max(20,p.morale-3)
  g.evt.result_text="oars out. -4 sup -3 mor"

 elseif effect=="calm_wait" then
  g.run.day+=2
  p.morale=min(99,p.morale+1)
  g.evt.result_text="+2 days, crew takes the rest"

 elseif effect=="calm_whistle" then
  if rnd(1)<.5 then
   g.run.day=max(1,g.run.day-1)
   p.morale=min(99,p.morale+2)
   g.evt.result_text="a breeze rises! -1 day"
  else
   g.run.day+=1
   p.morale=max(20,p.morale-3)
   g.evt.result_text="bad omen. +1 day -3 mor"
  end

 -- peddler
 elseif effect=="pedl_sup" then
  local cost=8
  if p.gold<cost then
   msg("need "..cost.."g",8)
   g.evt.retry=true
   return
  end
  p.gold-=cost
  p.supplies=min(30,p.supplies+6)
  g.evt.result_text="-"..cost.."g +6 supplies"

 elseif effect=="pedl_med" then
  local cost=18
  if p.gold<cost then
   msg("need "..cost.."g",8)
   g.evt.retry=true
   return
  end
  p.gold-=cost
  p.cargo["medicine"]=(p.cargo["medicine"] or 0)+1
  g.evt.result_text="-"..cost.."g +1 medicine"

 elseif effect=="pedl_decline" then
  g.evt.result_text="he salutes and sails on"

 -- stowaway
 elseif effect=="stow_press" then
  p.crew.hands=p.crew.hands+1
  enforce_crew_cap(p)
  p.morale=max(20,p.morale-3)
  g.evt.result_text="+1 hand, crew uneasy -3 mor"

 elseif effect=="stow_drown" then
  p.morale=max(20,p.morale-6)
  if g.run.factions["crown"] then
   g.run.factions["crown"].rep-=2
  end
  g.evt.result_text="crew shaken -6 mor, crown -2"

 elseif effect=="stow_turn" then
  local gold=flr(10*am)
  p.gold+=gold
  if g.run.factions["crown"] then
   g.run.factions["crown"].rep+=1
  end
  g.evt.result_text="+"..gold.."g at port, crown +1"

 -- whale pod
 elseif effect=="whale_hunt" then
  if rnd(1)<.6 then
   local gold=flr((12+flr(rnd(10)))*am)
   p.gold+=gold
   p.supplies=min(30,p.supplies+3)
   g.run.day+=1
   g.evt.result_text="meat and oil +"..gold.."g +3 sup"
  else
   local dmg=4+flr(rnd(4))
   p.hp=max(0,p.hp-dmg)
   g.evt.result_text="the bull rammed! -"..dmg.." hull"
  end

 elseif effect=="whale_pass" then
  p.morale=min(99,p.morale+4)
  g.evt.result_text="crew cheered. +4 mor"

 elseif effect=="whale_wide" then
  g.run.day+=1
  g.evt.result_text="wide berth, +1 day"

 -- flotsam
 elseif effect=="flot_salvage" then
  g.run.day+=1
  if rnd(1)<.6 then
   local gold=flr((6+flr(rnd(10)))*am)
   p.gold+=gold
   g.evt.result_text="salvaged +"..gold.."g"
  else
   g.evt.result_text="picked over, nothing left"
  end

 elseif effect=="flot_search" then
  g.run.day+=1
  if rnd(1)<.5 then
   local ren=1+ab
   g.run.renown+=ren
   p.morale=min(99,p.morale+3)
   g.evt.result_text="rescued survivors +"..ren.." ren +3 mor"
  else
   p.morale=max(20,p.morale-1)
   g.evt.result_text="all dead. -1 mor"
  end

 elseif effect=="flot_ignore" then
  g.evt.result_text="left to the sea"

 -- customs cutter
 elseif effect=="cust_submit" then
  local pat=g.evt.patroller or "crown"
  local cband=(p.cargo and p.cargo.contraband) or 0
  if cband>0 then
   local fine=6+cband*2
   if p.gold>=fine then p.gold-=fine else p.gold=0 end
   if p.cargo then p.cargo.contraband=0 end
   g.run.heat=max(0,g.run.heat-1)
   g.evt.result_text=cband.." contraband seized, -"..fine.."g fine"
  else
   g.run.heat=max(0,g.run.heat-2)
   if g.run.factions[pat] then g.run.factions[pat].rep+=1 end
   g.evt.result_text="manifest clean. "..pat.." nods you through"
  end

 elseif effect=="cust_bribe" then
  local pat=g.evt.patroller or "crown"
  local cband=(p.cargo and p.cargo.contraband) or 0
  local cost=12+g.run.heat*4+cband*4
  if p.gold<cost then
   msg("need "..cost.."g to bribe",8)
   g.evt.retry=true
   return
  end
  p.gold-=cost
  g.run.heat=max(0,g.run.heat-1)
  -- bribery corrodes standing if caught twice; small rep drift
  if g.run.factions[pat] and rnd(1)<.3 then g.run.factions[pat].rep-=1 end
  g.evt.result_text="-"..cost.."g, the cutter veers off"

 elseif effect=="cust_bluff" then
  local pat=g.evt.patroller or "crown"
  local can=has_upgrade("false_colors") or has_officer("smuggler_priest")
  if not can then
   msg("no colors to fly",8)
   g.evt.retry=true
   return
  end
  local succ=has_officer("smuggler_priest") and .85 or .7
  if has_upgrade("false_colors") and has_officer("smuggler_priest") then succ=.92 end
  if rnd(1)<succ then
   g.evt.result_text="the colors fool them. you sail clean"
  else
   -- bluff failed: they signal escalation, battle starts
   g.evt.resolved=true
   g.run.heat=min(10,g.run.heat+2)
   if g.run.factions[pat] then g.run.factions[pat].rep-=2 end
   local enc={kind="hunter",profile="hunter",region=to_region_of(g.evt.dest),heat_buff=2}
   g.pending_dest=g.evt.dest
   msg("bluff called!",8)
   start_battle(enc)
   return
  end

 elseif effect=="cust_fight" then
  local pat=g.evt.patroller or "crown"
  g.run.heat=min(10,g.run.heat+3)
  if g.run.factions[pat] then g.run.factions[pat].rep-=3 end
  g.evt.resolved=true
  local enc={kind="hunter",profile="hunter",region=to_region_of(g.evt.dest),heat_buff=3}
  g.pending_dest=g.evt.dest
  msg(pat.." patrol hostile!",8)
  start_battle(enc)
  return
 end
end

-- region for a destination port index (used by customs cutter to tag battles)
function to_region_of(ix)
 local pr=find_port(ix)
 return (pr and pr.region) or "trade"
end

function event_draw()
 local ev=g.evt
 local tt=t()

 -- full-frame ocean matching battle/prize style
 rectfill(0,0,127,127,1)

 -- swell crests drifting across
 for s in all(g.evt.swells or {}) do
  local off=(s.pos+tt*s.spd*8)%160-16
  for tx=-s.len,s.len do
   local wx=s.cx+tx
   local wy=s.cy+sin(tx*.04+s.pos)*3+sin(tt*.3+s.pos)*1.5
   if wx>=0 and wx<=127 and wy>=0 and wy<=127 then
    local h=(tx*31+flr(s.pos*11))
    local dens=s.thick+flr(abs(tx)/s.len*8)
    if h%dens<1 then
     pset(wx,wy,h%17<3 and 6 or 13)
    end
   end
  end
 end

 -- drifting foam dots
 for d in all(g.evt.dots or {}) do
  pset(d.x+sin(tt*.2+d.ph)*.5,d.y,d.col)
 end

 -- header (no chrome bar — text sits directly over the ocean)
 shadow("sea event",46,4,12,1)
 shadow("day "..g.run.day,92,4,7,1)

 -- event narration panel
 panel(6,14,115,36,0,5)
 local lines=wrap_text(ev.def.text,26)
 for i=1,min(#lines,5) do
  shadow(lines[i],10,17+(i-1)*6,7,1)
 end

 if ev.resolved then
  -- result panel: generous, wrap to 5 lines, room for long outcomes
  panel(6,54,115,54,0,5)
  local rlines=wrap_text(ev.result_text or "",26)
  for i=1,min(#rlines,5) do
   shadow(rlines[i],10,58+(i-1)*6,10,1)
  end
  if flr(tt*2)%2==0 then
   shadow("\142 continue",42,114,7,1)
  end
 else
  -- choice panel: taller, each choice wraps to 2 lines if needed,
  -- arrow + text have real separation so they don't collide
  panel(6,54,115,68,0,5)
  local y=58
  for i=1,#ev.def.choices do
   local ch=ev.def.choices[i]
   local clines=wrap_text(ch.name,22)
   local nh=#clines*6
   local col=6
   if i==ev.sel then
    col=10
    shadow("\139",10,y,10,1)
   end
   for li=1,#clines do
    shadow(clines[li],20,y+(li-1)*6,col,1)
   end
   y+=nh+3
  end
 end
end

-- src/19_state_summary.lua
-- run summary screen (shown on defeat, retirement, or victory)

function summary_init(arg)
 local outcome=(arg and arg.outcome) or "defeat"
 local p=g.run.player
 local st=g.run.stats or {}

 -- count visited ports
 local ports_n=0
 for _ in pairs(st.ports_visited or {}) do ports_n+=1 end

 local hd=ship_defs[p.hull]
 g.summary={
  outcome=outcome,
  days=g.run.day,
  gold=p.gold,
  gold_earned=st.gold_earned or 0,
  hull=hull_name(p.hull),
  hull_id=p.hull,
  hull_size=(hd and hd.size) or 5,
  hull_hp_pct=hd and max(.2,p.hp/max(1,hd.hull)) or 1,
  hull_sail_pct=hd and hd.sails>0 and max(.2,p.sail_hp/hd.sails) or 1,
  captures=p.captures or 0,
  renown=g.run.renown,
  heat=g.run.heat,
  perks=#p.perks,
  rivals_beaten=0,
  contracts=st.contracts_done or 0,
  ports_visited=ports_n,
  biggest_prize=st.biggest_prize or 0,
  biggest_prize_name=st.biggest_prize_name or "",
  cause=st.cause,
  act_reached=g.run.act or 1
 }

 -- count defeated rivals
 if g.run.rivals then
  for r in all(g.run.rivals) do
   if r.defeated then
    g.summary.rivals_beaten+=1
   end
  end
 end

 -- play appropriate sfx
 if outcome=="defeat" then
  sfx(sfx_ids.defeat,3)
 else
  sfx(sfx_ids.victory,3)
 end

 -- update meta + award tokens
 g.meta.runs+=1
 if p.gold>g.meta.best_gold then g.meta.best_gold=p.gold end
 if g.run.renown>g.meta.best_renown then g.meta.best_renown=g.run.renown end
 local tok=1 -- every run
 tok+=g.summary.rivals_beaten -- +1 per rival
 if g.summary.act_reached>=2 then tok+=1 end
 if g.summary.act_reached>=3 then tok+=1 end
 if outcome=="legend" then tok+=3 end
 if outcome=="pirate_crown" then tok+=2 end
 if outcome=="marque" then tok+=2 end
 if outcome=="treasure" then tok+=2 end
 g.meta.tokens=(g.meta.tokens or 0)+tok
 g.summary.tokens_earned=tok
 save_meta()

 -- ocean seed matching the prize screen feel
 g.summary_swells={}
 local n_ssw=lowfx() and 2 or 3
 for i=1,n_ssw do
  add(g.summary_swells,{
   cx=flr(rnd(128)),
   cy=40+flr(rnd(70)),
   pos=rnd(1),
   len=30+flr(rnd(30)),
   thick=4+flr(rnd(4))
  })
 end
 g.summary_dots={}
 local n_sd=lowfx() and 30 or 80
 for i=1,n_sd do
  add(g.summary_dots,{
   x=flr(rnd(128)),
   y=flr(rnd(128)),
   col=rnd_item({7,7,13,13,6,6}),
   ph=rnd(1)
  })
 end
end

function summary_update()
 if btnp(5) or btnp(4) then
  boot_title()
 end
end

function summary_draw()
 local s=g.summary
 local tt=t()

 -- ocean fills the frame, matching prize/battle style
 rectfill(0,0,127,127,1)

 -- drifting swells
 for sw in all(g.summary_swells or {}) do
  for t=-sw.len,sw.len do
   local wx=sw.cx+t
   local wy=sw.cy+sin(t*.04+sw.pos)*3+sin(tt*.3+sw.pos)*1.5
   if wx>=0 and wx<=127 and wy>=0 and wy<=127 then
    local h=(t*31+flr(sw.pos*11))
    local dens=sw.thick+flr(abs(t)/sw.len*8)
    if h%dens<1 then
     pset(wx,wy,h%17<3 and 6 or 13)
    end
   end
  end
 end

 -- foam dots
 for d in all(g.summary_dots or {}) do
  pset(d.x+sin(tt*.2+d.ph)*.5,d.y,d.col)
 end

 -- outcome title
 local title,tcol
 if s.outcome=="defeat" then
  title="lost at sea"
  tcol=8
 elseif s.outcome=="mutiny" then
  title="mutiny in port"
  tcol=8
 elseif s.outcome=="retire" then
  title="retired to shore"
  tcol=10
 elseif s.outcome=="legend" then
  title="a legend is born"
  tcol=10
 elseif s.outcome=="pirate_crown" then
  title="pirate king!"
  tcol=9
 elseif s.outcome=="marque" then
  title="letter of marque!"
  tcol=12
 elseif s.outcome=="treasure" then
  title="galleon claimed!"
  tcol=10
 else
  title="run complete"
  tcol=11
 end

 -- title backdrop so it reads clearly over the sea
 local tw=#title*4
 rectfill(64-tw/2-3,2,64+tw/2+2,10,0)
 printc(title,4,tcol)

 -- ship silhouette: use final hull's size for a run-faithful portrait
 local sz=s.hull_size or 5
 local lost=s.outcome=="defeat" or s.outcome=="mutiny"
 local sail_col=lost and 5
  or (s.hull_sail_pct<.5 and 6 or 7)
 local body_col=lost and 5
  or (s.hull_hp_pct<.5 and 4 or 4)
 draw_ship_primitive(64,19,.08,body_col,sz,sail_col)
 -- smoke if defeated (heavier for big hulls)
 if lost then
  for i=0,4+sz do
   local st=(tt*.4+i*.17)%1
   local sy2=14-st*12
   local sx2=64+sin(tt*.3+i)*2-st*2
   local c=st<.35 and 5 or (st<.7 and 6 or 13)
   if st<.9 then pset(sx2,sy2,c) end
  end
 end

 -- cause of death / loss (defeat or mutiny), on its own line above stats
 if (s.outcome=="defeat" or s.outcome=="mutiny") and s.cause then
  local cs=(s.outcome=="mutiny" and "felled by " or "slain by ")..s.cause
  local cw=#cs*4
  rectfill(64-cw/2-2,28,64+cw/2+1,34,0)
  shadow(cs,64-cw/2,29,8,1)
 end

 -- stats panel: roomy enough to breathe, all inside
 panel(4,38,119,89,0,5)

 local y=41
 local function row(label,val,col)
  shadow(label,8,y,6,1)
  shadow(tostr(val),74,y,col or 7,1)
  y+=7
 end
 row("act reached",s.act_reached)
 row("days at sea",s.days)
 row("final ship",s.hull)
 row("gold now",s.gold,10)
 row("gold earned",s.gold_earned,10)
 row("ports visited",s.ports_visited.."/"..total_run_ports())
 row("contracts",s.contracts)
 row("captures",s.captures)
 row("rivals",s.rivals_beaten.."/3",s.rivals_beaten>=3 and 10 or 7)
 row("renown",s.renown,11)

 -- notable prize line
 if s.biggest_prize>0 then
  local hs="best: "..s.biggest_prize.."g "..s.biggest_prize_name
  shadow(hs,8,112,9,1)
 end

 -- rank + tokens on the bottom row inside the panel
 local rank="deckhand"
 if s.renown>=12 then rank="legend"
 elseif s.renown>=8 then rank="captain"
 elseif s.renown>=5 then rank="corsair"
 elseif s.renown>=3 then rank="privateer"
 end
 shadow("rank: "..rank,8,120,tcol,1)
 if s.tokens_earned and s.tokens_earned>0 then
  shadow("+"..s.tokens_earned.." \135",92,120,9,1)
 end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000900000000000000000000000100000000000000000000000000000000000000000000
000550000550000007000070005500000888880000c00000000b00000099000000aaa00004444400001110000077700000000000000000000000000000000000
005775005775000000700000057750008888888000cc000000bbb000099900000aa9aa0044474440000100000770770000000000000000000000000000000000
05777750055666000000700000550000888888800cccc0000bbbbb00098990000a999a0044747440011111000777770000000000000000000000000000000000
05777750000667500700000000055000088888000ccccc0000bbb000988989000aa9aa0044474440000100000707070000000000000000000000000000000000
0057750000005775000700700057750000888800cccccc00000b00009888890000aaa00044444440000100000077700000000000000000000000000000000000
00055000000005500000070000055000000880000000000000000000098890000000000004444400010101000067600000000000000000000000000000000000
00000000000000000000000000000000000080000000000000000000009900000000000000000000001110000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010e00000e5500e5500e5500e55015550155501555015550185501855018550185501a5601a5601a5601a5601a5501a5501a5501a55015550155501855018550155401554015540155400e5500e5500e5500e550
010e00000e5500e5500e55010540155501555015550175401855018550185501a5401a5601a5601a5601a5601a5501a5501a5501c55015550155501855018550155401554015540175300e5500e5500e55010540
010e00000e5501a5500e5500e5502155015550215501555024550185502455018550265601a560265601a560265501a550265501a55015550155502455018550155402154015540215400e5501a5500e5500e550
010e00000e5500e550000000e55015550155501555015550185501855018550185501a5601a5601a5601a5601a5501a550000001a55018550155501555018550155401554015540155400e5500e5500e5500e550
010e00000e5500e5500000011540155501555013550115500e5500000011540135501555018560155500000015550000001355011550105400e5500000010540115501355015550185601a5601a550000000c540
010e00000e5500e5501053011540155501555013550115500e5501053011540135501555018560155500000015550115301355011550105400e5501153010540115501355015550185601a5601a550000000c540
010e00000e550000000e55011540155501555013550115500e550000001154013550155501856000000155501555000000135501155010540000000e55010540115501355015550185601a560000001a5500c540
010e00000e5501a5500000011540215501555013550115500e5500000011540135501555024560155500000015550000001f55011550105400e550000001054011550135501555018560265601a550000000c540
010e00000265000000000000000020640000000000000000026500000000000000002064000000026300000002650000000000000000206400000000000000000265000000026300000020640000002062000000
01100000135501355017550175501a5501a5501f5501f5501a5501a5501c5501c5501a5501a55017550175501855018550175501755015550155501355013550115401154015550155501a5501a5501356013560
010f00001555015540265501a5501855000000235501754015550000001e5501254021550000001c550105400e5500e5401e550125402155000000235501754015550000001e5501254010550000001e5400e550
010e00000e3500e3501135011350133501335015350153501335013350113501135015350153501a3601a36018350183501535015350163401634015350153501335013350113501135010340103400e3600e360
010e0000021600216002160021600000000000021500215009160091600916009160000000000002150021500216002160021600216000000000000c1500c1500915009150071500715002160021600216002160
010e00000265000000000000000020640000000000000000026500000000000000002064000000026300000002650000000000000000206400000000000000000265000000026300000020640000000000000000
010e0000021600216002160021600000000000021500215009160091600916009160000000000002150021500216002160021600216000000000000c1500c1500915009150071500715002160021600216002160
010e00001524000000000001524018240000000000018240152400000000000152401a23000000000001a2301824000000000001824015240000000000015240112400000000000112400e24000000000000e240
010e000000000000001524015240000000000018240182400000000000152401524000000000001a2301a23000000000001824018240000000000015240152400000000000112401124000000000000e2400e240
010e00000e5501a5500e5500e5502155015550215501555024550185502455018550265601a560265601a560265501a550265501a55015550155502455018550155402154015540215400e5501a5500e5500e550
010e00000e5500e5500e55010540155501555015550165401855018550185501a5401a5601a5601a5601a5601a5501a5501a5501c55015550155501855018550155401554015540165300e5500e5500e55010540
01100000135501355017550175501a5501a5501f5501f5501a5501a5501c5501c5501a5501a55017550175501855018550175501755015550155501355013550115401154015550155501a5501a5501356013560
010f000015550155401a5501a5501855000000175501754015550000001255012540155500000010550105400e5500e540125501254015550000001755017540155500000012550125401055000000125400e550
010e00000e3500e3501135011350133501335015350153501335013350113501135015350153501a3601a36018350183501535015350163401634015350153501335013350113501135010340103400e3600e360
010e00000e5500e5500e5500e55015550155501555015550185501855018550185501a5601a5601a5601a5601a5501a5501a5501a55015550155501855018550155401554015540155400e5500e5500e5500e550
010c00001a560000001a560000000000000000000001a5501555000000155500000018550185501a5601a5601a560000001a56000000000001d550000001d550155500000015550185501a5601a560155501a560
011400001a040000000000000000210400000000000000001c03000000000000000000000000000000000000240300000000000000001a0300000000000000000000000000000000000000000000000000000000
01100000071600000013140000000e150000000e14000000071600000013140000000e150000001115000000071600000013140000000c150000000c140000000e15000000111500000007160000000e15007160
011000001f5501f55017550175501a5501a5501f5501f5501a5501a5501755017550135501355000000000001d5501d55015550155501a5501a5501d5501d5501c5401c5401a5501a55017550175501355013550
0110000000000000001a2401a2400000000000132401324000000000001a2401a240000000000011240112400000000000152401524000000000001a2401a2400000000000172401724000000000001324013240
011000000266000000000000000030640000000000000000026500000000000000003064000000000000000002660000000000000000306400000000000000000265000000000000000030650000000000000000
010f000002160000000000002140091500000000000061400215000000000000914002150000000b1500000002160000000b1400000009150000000614004140021500000009140000000b150000000914002150
010f000015550000001754015550125500000000000105500e550000001255000000155500000017550155501a550000001c5401a55017550000001555000000125500000015550000001755015540125500e550
010f00000000000000125401254000000000001554015540000000000012540125400000000000105401054000000000001354013540000000000012540125400000000000155401554000000000001254012540
010f00000263000000000000000020640000000000000000026300000000000000002064000000000000000002630000000000000000206400000000000000000263000000000000000020640000000000000000
010f00001254000000000001254015540000000000015540125400000000000125401054000000000001054013540000000000013540125400000000000125401554000000000001554012540000000000012540
010e000002170000000000002150000000214000000000000916000000091400000007150000000515002150021700000000000021500c15000000091500000002170000000000002150091500c1500715002160
010e00001535015350000000000015350153501a3501a350183501835000000000001535015350133501335015350153501a3601a3601d3501d3501a3501a3501835018350153501535013350133500e3500e350
010e000000000000000e230000000000000000152400000000000000000e230000000000000000152400000000000000000e230000000000000000152400000000000000000e2300000000000000001525000000
010e0000026600000002650000002a650000000000000000026600000002650000002a650000000000000000026600000002650000002a650000002a63000000026600263002650000002a6502a6402a65000000
011000001f5502b5501755017550265501a5502b5501f5501a550265501755023550135501f5500000000000295501d55021550215502655026550295501d5502854026550265002455023550235002655026540
011400000e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e7300e73015730157301573015730157301573015730157301573015730157301573015730157301573015730
011400001a040000000000000000210400000000000000001c03000000000000000000000000000000000000240300000000000000001a0300000000000000000000000000000000000000000000000000000000
010c0000021700215000000091500217002150000000c150021700215000000091500217000000071500c1500217002150000000915002170000000c1500c150021700215009150071500515007150091500c160
010c00001a5601a560000000000000000000001a550000001555015550000000000018550185501a5601a5601a5601a5600000000000000001d5501d55000000155501555000000185501a5601a560155501a560
010c0000021700215009150071500216005150091500c160021700215009150071500515007150091500c1600217002150091500715002160091500c1500c1600217009150071500515007150091500c15002170
010c00002155021550215502155000000000001f5401f5401d5501d55000000000001c5401c5401a5501a550215502155021550215500000000000245502455021540215401f5401f5401d5401d540155501a560
010c000002170021600215009150021700a1500915005160021700216002150091500217005150071500a1600217002160021500f150021700a150091500715002170021500a1500515002170051500a15002170
010c00000e2400e2400e2400e2400e2400e24000000000001624016240162401624000000000000f2300e2400e2400e2400e2400e240000000000011230112300f2300f2300e2400e2400e2400e2400e2400e250
010c00000266000000286200000020650000002862000000026600000028620000002065000000026400000002660000002862000000206500235007340000000266000000026400000020650000002063002640
010c00000267002630286200000020660000002862002630026700263028620000002066000000026500000002670026302862000000206602862028620026300267000000026500000020660206302063002650
010d00001a3601a3601a3601a36018350183501835018350153501535015350153501a3601a3601a3601a3601a3601a3601a3601a360183501835018350183501635016350163501635015360153601536015360
010d00000267000000000000000030650000000000000000026700000000000000003065000000000000000002670000000000000000306500000000000000000267000000000000000030660000000000000000
010e00001a5601a5601a5601a5601e5501e5501e5501e550215502155021550215502656026560265602656026540265402654026540265402654026540265400000000000000000000000000000000000000000
010e00000e5500e5500e55010540155501555015550175401855018550185501a5401a5601a5601a5601a5601a5501a5501a5501c55015550155501855018550155401554015540175300e5500e5500e55010540
010c00001a560000001a560000000000000000000001a5501555000000155501753018550185501a5601a5601a560000001a56000000000001d550000001d550155500000015550185501a5601a560155501a560
010c0000215502155000000215501f54000000000001f540000001d5501d550000001a5501c5401c5401a55021550215500000021550245500000000000245501f54021540215401f540155501d5401d5401a560
010e00001535000000153500000015350153501a3501a350183500000018350173301535015350133501335015350153501a3601a3601d3501d3501a3501a3501835018350153501535013350133500e3500e350
010600000c4700a460084500644004430044200441004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001846014440104200c40008400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001c15020140241300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01060000180401c050200502406024040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000018050180501c0501c06020060240702405024030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a0000202501c2501824014240102300c2200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040000144601c45010470184400c430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 160c1008
02 340c1008
00 41424344
01 1a191b1c
00 26191b1c
00 13191b1c
02 09191b1c
01 1e1d1f20
00 1e1d2120
00 141d1f20
02 0a1d1f20
01 23222425
00 37222425
00 15222425
02 0b222425
01 28274344
02 43274344
01 2a292f44
02 35292f44
01 2c2b2f44
02 362b2f44
01 2e2d3044
02 2e2d2f44
03 312d3244
00 41424344
04 33434344
01 000e0f0d
00 010e0f0d
00 020e0f0d
00 030e0f0d
00 040e0f0d
00 050e0f0d
00 060e0f0d
02 070e0f0d
01 110c1008
02 120c1008
01 17292f44
02 35292f44
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
