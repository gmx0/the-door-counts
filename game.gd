extends Node2D
# Original procedural art and rules. No network, accounts or filesystem mutation.
const NAMES=["BELL","EYE","TOOTH","MOON"]
const OPPOSITE=[3,2,1,0]
const TOTAL=5
var rng=RandomNumberGenerator.new()
var run_seed=104729
var state="title"
var round_index=0
var slots: Array=[]
var requested=0
var lie=false
var remaining=14.0
var transition=0.0
var paused=false
var reason=""
var selected_slot=-1
var font: Font
var screenshot_path=""

func _ready():
	font=ThemeDB.fallback_font
	if "--test" in OS.get_cmdline_user_args(): call_deferred("run_tests")
	elif "--preview" in OS.get_cmdline_user_args():
		start_run(104729); paused=true; call_deferred("preview")

func start_run(seed_value: int):
	run_seed=seed_value; rng.seed=run_seed; round_index=0; state="playing"; paused=false
	reason=""; selected_slot=-1; transition=0; next_rule()

func next_rule():
	slots=[0,1,2,3]
	for i in range(3,0,-1):
		var j=rng.randi_range(0,i); var value=slots[i]; slots[i]=slots[j]; slots[j]=value
	requested=rng.randi_range(0,3); lie=rng.randi_range(0,1)==1
	remaining=14.0-round_index; selected_slot=-1

func correct_slot() -> int:
	return slots.find(OPPOSITE[requested] if lie else requested)

func choose(index: int):
	if state!="playing" or paused or index<0 or index>3: return
	selected_slot=index
	if index!=correct_slot():
		state="lost"; reason="The door asked for %s. It was %s.\nYou needed %s, not %s." % [NAMES[requested],"LYING" if lie else "TRUTHFUL",NAMES[slots[correct_slot()]],NAMES[slots[index]]]
		return
	round_index+=1
	if round_index==TOTAL: state="won"; reason="Five seals opened.\nThere were only four doors when you arrived."
	else: state="changing"; transition=0.75

func _process(delta):
	if not paused:
		if state=="playing":
			remaining=maxf(0,remaining-delta)
			if remaining<=0: state="lost"; reason="You waited too long.\nThe door counted you instead."
		elif state=="changing":
			transition-=delta
			if transition<=0: next_rule(); state="playing"
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER:
				if state in ["title","lost","won"]: start_run(run_seed)
			KEY_R: start_run(run_seed)
			KEY_N: start_run(run_seed+1)
			KEY_SPACE, KEY_ESCAPE:
				if state in ["playing","changing"]: paused=not paused
			KEY_1: choose(0)
			KEY_2: choose(1)
			KEY_3: choose(2)
			KEY_4: choose(3)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var at=get_global_mouse_position()
		if Rect2(40,635,220,46).has_point(at): start_run(run_seed); return
		if Rect2(280,635,220,46).has_point(at): start_run(run_seed+1); return
		if Rect2(520,635,220,46).has_point(at):
			if state in ["playing","changing"]: paused=not paused
			return
		for i in 4:
			if door_rect(i).has_point(at): choose(i)

func door_rect(i: int) -> Rect2:
	return Rect2(40+i*180,305,160,255)
func text(at: Vector2, value: String, size: int=20, color=Color("e5e5d9")):
	draw_multiline_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
func _draw():
	if font==null: return
	draw_rect(Rect2(0,0,1100,720),Color("080b0f"))
	for x in range(0,1100,40): draw_line(Vector2(x,0),Vector2(x,720),Color(0.08,0.12,0.13,0.35))
	draw_rect(Rect2(780,0,320,720),Color("101a1d"))
	text(Vector2(40,53),"THE DOOR COUNTS",38)
	text(Vector2(42,82),"A one-minute ritual of unreliable instructions",16,Color("8caaa8"))
	text(Vector2(810,55),"THE CONTRACT",24,Color("e6c777"))
	text(Vector2(810,102),"Open five seals.\nRead the new rule each time.\nSymbols may move after each seal.\n\nTRUTH: choose the named sigil.\nLIE: choose its opposite.\n\nOPPOSITES\nBELL  <->  MOON\nEYE    <->  TOOTH\n\nPress 1 / 2 / 3 / 4\nor click a door.\n\nWrong door or empty timer:\nthe ritual ends.\n\nR: replay this seed\nN: reroll a new seed\nSpace / Esc: pause",16)
	text(Vector2(810,650),"SEED %d\nNo two rituals need agree." % run_seed,16,Color("8caaa8"))
	if state=="title":
		text(Vector2(45,160),"IT LEARNED TO LIE.",32,Color("e6c777"))
		text(Vector2(45,210),"You have fourteen seconds to answer the first door.\nEach seal steals a second. Read before you act.\n\nPress ENTER or REPLAY to begin.",22)
	else:
		for i in TOTAL:
			draw_circle(Vector2(55+i*32,115),7,Color("79e2c5") if i<round_index else Color("304847"))
		text(Vector2(240,122),"SEALS %d / %d" % [round_index,TOTAL],18)
		if state in ["playing","changing"]:
			var rule_color=Color("ec937e") if lie else Color("79e2c5")
			text(Vector2(42,181),"LIE / CHOOSE THE OPPOSITE" if lie else "TRUTH / OBEY THE NAME",25,rule_color)
			text(Vector2(42,225),'"OPEN THE %s."' % NAMES[requested],32)
			text(Vector2(42,275),"%04.1f SECONDS" % remaining,18,rule_color)
			draw_rect(Rect2(230,256,510*clampf(remaining/(14.0-mini(round_index,4)),0,1),13),rule_color)
		for i in 4:
			var rect=door_rect(i)
			var color=Color("79e2c5") if selected_slot==i and state!="lost" else Color("ec937e") if selected_slot==i else Color("8caaa8")
			draw_rect(rect,Color("10181b")); draw_rect(rect,color,false,2)
			draw_rect(Rect2(rect.position+Vector2(10,10),rect.size-Vector2(20,20)),Color("304847"),false,1)
			var center=rect.position+Vector2(80,90)
			draw_sigil(center,slots[i],color)
			text(rect.position+Vector2(48,173),NAMES[slots[i]],19,color)
			text(rect.position+Vector2(67,218),str(i+1),24,color)
		if state=="changing": text(Vector2(42,602),"A SEAL OPENS. THE RULES ARE CHANGING.",20,Color("79e2c5"))
		if state in ["lost","won"]:
			draw_rect(Rect2(25,142,730,445),Color("080b0f"))
			text(Vector2(45,204),"YOU WERE COUNTED." if state=="lost" else "YOU MAY LEAVE.",36,Color("ec937e") if state=="lost" else Color("79e2c5"))
			text(Vector2(45,264),reason,23)
			text(Vector2(45,390),"ENTER / R: same ritual, another attempt.\nN: new seed, new instructions.",22)
	if paused:
		draw_rect(Rect2(25,142,730,445),Color(0.03,0.05,0.06,0.94)); text(Vector2(245,330),"PAUSED",45); text(Vector2(165,385),"Space / Esc or PAUSE to continue",22)
	for spec in [[40,"REPLAY [R]"],[280,"REROLL [N]"],[520,"PAUSE [SPACE]"]]:
		draw_rect(Rect2(spec[0],635,220,46),Color("213537")); text(Vector2(spec[0]+15,665),spec[1],18)

func draw_sigil(at: Vector2, kind: int, color: Color):
	match kind:
		0:
			draw_arc(at,28,PI,TAU,24,color,4); draw_line(at+Vector2(-28,0),at+Vector2(-28,24),color,4); draw_line(at+Vector2(28,0),at+Vector2(28,24),color,4); draw_line(at+Vector2(-35,24),at+Vector2(35,24),color,4); draw_circle(at+Vector2(0,33),6,color)
		1:
			draw_polyline(PackedVector2Array([at+Vector2(-40,0),at+Vector2(0,-23),at+Vector2(40,0),at+Vector2(0,23),at+Vector2(-40,0)]),color,4); draw_circle(at,10,color)
		2:
			draw_polyline(PackedVector2Array([at+Vector2(-25,-28),at+Vector2(25,-28),at+Vector2(20,30),at+Vector2(0,10),at+Vector2(-20,30),at+Vector2(-25,-28)]),color,4)
		3:
			draw_circle(at,32,color); draw_circle(at+Vector2(16,-10),27,Color("10181b"))

func press(code: int):
	var event=InputEventKey.new(); event.keycode=code; event.pressed=true; _unhandled_input(event)
func signature() -> String: return str(slots)+":"+str(requested)+":"+str(lie)
func run_tests():
	var histories: Array=[]
	var paths: Array=[]
	for test_seed in [104729,104730]:
		start_run(test_seed); var first=signature(); var history: Array=[]; var path: Array=[]
		for i in TOTAL:
			history.append(signature()); path.append(correct_slot()+1); assert(slots.size()==4 and correct_slot()>=0)
			press(KEY_1+correct_slot())
			if i<TOTAL-1: assert(state=="changing"); _process(0.8)
		assert(state=="won" and round_index==TOTAL)
		histories.append(history); paths.append(path)
		print("SEED %d LEGAL KEYS %s" % [test_seed,str(path)])
		press(KEY_R); assert(state=="playing" and round_index==0 and signature()==first)
		press(KEY_1+(correct_slot()+1)%4); assert(state=="lost")
		press(KEY_ENTER); assert(state=="playing" and signature()==first)
		var before=remaining; press(KEY_SPACE); _process(30); assert(remaining==before and paused)
		press(KEY_1+correct_slot()); assert(round_index==0)
		press(KEY_SPACE); _process(30); assert(state=="lost")
		press(KEY_N); assert(state=="playing" and run_seed==test_seed+1)
	assert(histories[0]!=histories[1] and paths[0]!=paths[1],"Seeds failed to change required inputs")
	assert(paths[0][0]!=paths[1][0],"First required key should differ for sample seeds")
	start_run(104729); slots=[0,1,2,3]; requested=0; lie=false; assert(correct_slot()==0)
	lie=true; assert(correct_slot()==3,"Same named sigil must require a different action when the rule lies")
	# Every generated rule has exactly one legal sigil and distinct click region.
	for test_seed in range(100):
		start_run(test_seed)
		for i in TOTAL:
			assert(slots.count(slots[correct_slot()])==1)
			choose(correct_slot()); _process(0.8)
		assert(state=="won")
	print("DAILY GAME TEST PASSED: two seeded legal paths, distinct rules, deliberate wrong choice, restart determinism, timeout, pause and 100-seed reachability")
	get_tree().quit()

func preview():
	paused=false
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://preview.png")
	get_tree().quit()
