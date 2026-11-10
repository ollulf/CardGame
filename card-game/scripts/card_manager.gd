extends  Node

signal trump_chosen(suit: Card.Suit)
signal card_played(player_id: int, card: Card)

const CARD_PLAYED_SOUND := preload("res://sounds/card_played.wav")
const PLAY_ZONE_OFFSET := Vector2(-330, -350)
const PLAY_ZONE_SIZE := Vector2(660, 400)
const HAND_SIZE := 5
const DEAL_INTERVAL := 0.12
const DEAL_SETTLE_TIME := 0.45
const RETURN_FLY_TIME := 0.4
const CLEAR_TIME := 0.45
const CLEAR_STAGGER := 0.08
const COLLECT_GATHER_TIME := 0.25
const COLLECT_FLIP_TIME := 0.15
const COLLECT_FLY_TIME := 0.45
const ZERO_BEATS_RANK := 9
const TIE_CARD_SCALE := 1.5
const TIE_CARD_SPACING := 140.0
const TIE_FLY_TIME := 0.4
const TIE_FLIP_TIME := 0.3
const TIE_REVEAL_PAUSE := 0.35
const TIE_RESULT_TIME := 1.4
const TIE_LOSER_COLOR := Color(0.55, 0.55, 0.55, 0.8)
const TIE_TAG_GAP := 18.0
const TIE_TAG_FADE_TIME := 0.2
const TIE_TAG_FONT_SIZE := 18
const TIE_LOSER_TAG_COLOR := Color(0.85, 0.15, 0.15)
const TIE_OWNER_COLORS := {0: Color(0.3, 0.7, 1.0), 1: Color(1.0, 0.55, 0.2), 2: Color(0.75, 0.45, 1.0)}
const HUMAN_TIE_NAME := "YOU"

var table_root: Control

var played_cards_turn: Hand = Hand.new()
var played_cards_round: Hand = Hand.new()

var player_deck: Deck
var AI_1_deck: Deck
var AI_2_deck: Deck

var player_hand: Hand
var AI_1_hand: Hand
var AI_2_hand: Hand

var trump_suit : Card.Suit = Card.Suit.SMOKE

var leading_card : Card
var first_trump_card : Card
var last_played_by := {}

func _ready() -> void:
	PlayerDataManager.stats_changed.connect(apply_buffs)
	trump_chosen.connect(_on_trump_chosen)
	GameManager.round_finished.connect(_discard_leftover_hands)
	GameManager.new_match_started.connect(func(): last_played_by.clear())

func _discard_leftover_hands(_loosers) -> void:
	var pairs := [[player_hand, player_deck, Card.Owner.HUMAN], [AI_1_hand, AI_1_deck, Card.Owner.AI_1], [AI_2_hand, AI_2_deck, Card.Owner.AI_2]]
	for pair in pairs:
		var hand: Hand = pair[0]
		var deck: Deck = pair[1]
		if hand == null or hand.is_empty():
			continue
		var before := 0 if deck == null else deck.cards.size()
		var returned := hand.cards.duplicate()
		hand.cards.clear()
		var home := _deck_pile_center(pair[2], table_root) if table_root != null else Vector2.ZERO
		for card: Card in returned:
			card.rank = card.base_rank
			card.buff_parts = []
			if deck != null:
				deck.cards.append(card)
			_fly_card_to_deck(card, home)
		if deck != null:
			deck.cards.shuffle()
			deck.move_draw_first_to_top()
			print("Leftover cards shuffled into deck: owner ", pair[2], " returned ", returned.size(), " deck ", before, " -> ", deck.cards.size())

func _fly_card_to_deck(card: Card, home: Vector2) -> void:
	var visual := _find_visual(get_tree().root, card)
	if visual == null:
		card.remove()
		return
	if card.removed.is_connected(visual.destroy):
		card.removed.disconnect(visual.destroy)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.z_index = 40
	var tween := visual.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "global_position", home - visual.size * 0.5, RETURN_FLY_TIME)
	tween.tween_property(visual, "scale", Vector2.ONE * 0.5, RETURN_FLY_TIME)
	tween.chain().tween_callback(visual.queue_free)
	Sfx.play_card_move()

func _find_visual(node: Node, card: Card) -> CardVisual:
	if node is CardVisual and node.card == card:
		return node
	for child in node.get_children():
		var found := _find_visual(child, card)
		if found != null:
			return found
	return null

static func entry_effect(entry: Array) -> CardEffect.Id:
	return entry[2] if entry.size() > 2 else CardEffect.Id.NONE

func _on_trump_chosen(_suit: Card.Suit) -> void:
	for player_id in PlayerDataManager.PLAYERS:
		apply_buffs(player_id)

func hand_of(player_id: int) -> Hand:
	match player_id:
		0:
			return player_hand
		1:
			return AI_1_hand
		2:
			return AI_2_hand
	return null

func apply_buffs(player_id: int) -> void:
	var hand := hand_of(player_id)
	if hand == null:
		return
	var smoke_bonus := PlayerDataManager.get_smoking(player_id)
	var drink_penalty := PlayerDataManager.get_drink_penalty(player_id)
	var drink_bonus := PlayerDataManager.get_drink_bonus(player_id)
	var cigarettes := smoke_bonus / maxi(PlayerDataManager.SMOKE_BONUS_PER_CIGARETTE, 1)
	var drink_rounds := PlayerDataManager.get_drinking(player_id)
	for card in hand.cards:
		var parts: Array[Dictionary] = []
		var target := card.base_rank
		if card.suit == Card.Suit.SMOKE and smoke_bonus != 0:
			target += smoke_bonus
			parts.append({"kind": "smoke", "amount": smoke_bonus, "count": cigarettes})
		if card.suit == Card.Suit.ALK:
			target += drink_bonus
			if drink_bonus != 0:
				parts.append({"kind": "drink_bonus", "amount": drink_bonus, "count": drink_rounds})
		else:
			var lowered := maxi(target - drink_penalty, mini(card.base_rank, 1))
			if drink_penalty != 0 and target > 0:
				parts.append({"kind": "drink_penalty", "amount": lowered - target, "count": drink_rounds, "capped": lowered - target != -drink_penalty, "floor": mini(card.base_rank, 1)})
			target = lowered
		target = CardEffect.modify_rank(card, target, player_id)
		var changed := card.rank != target or card.buff_parts != parts
		card.buff_parts = parts
		if changed:
			card.rank = target
			card.apply_modifiers()

func load_player_decks():
	var match_number := DialogueManager.upcoming_match()
	var min_rank := Missions.lowest_rank(match_number)
	var player_cards: Array[Card]
	if Missions.deck_cards(match_number, 0).is_empty() and PlayerDataManager.has_active_deck():
		player_cards = _lock_suits(_raise_low_ranks(PlayerDataManager.active_deck_copy(), min_rank), match_number)
	else:
		player_cards = _mission_cards(match_number, 0, Card.Owner.HUMAN)
	player_deck = Deck.new(player_cards)
	player_deck.move_draw_first_to_top()
	AI_1_deck = Deck.new(_mission_cards(match_number, 1, Card.Owner.AI_1))
	AI_2_deck = Deck.new(_mission_cards(match_number, 2, Card.Owner.AI_2))
	print("Decks generated")

func _mission_cards(match_number: int, seat: int, owner: Card.Owner) -> Array[Card]:
	var min_rank := Missions.lowest_rank(match_number)
	if seat == 0:
		min_rank = 1
	var listed: Array = Missions.deck_cards(match_number, seat)
	var cards := generate_cards(Missions.DECK_SIZE - listed.size(), owner, min_rank)
	if listed.is_empty():
		return cards
	var given: Array[Card] = []
	for entry in listed:
		given.append(Card.new(entry[0], entry[1], owner, false, entry_effect(entry)))
	cards.append_array(_lock_suits(_raise_low_ranks(given, min_rank), match_number))
	cards.shuffle()
	return cards

func _raise_low_ranks(cards: Array[Card], min_rank: int) -> Array[Card]:
	var result: Array[Card] = []
	for card in cards:
		if card.base_rank < min_rank and not card.has_stamp():
			result.append(Card.new(card.suit, randi_range(min_rank, 9), card.owner, false, card.effect))
		else:
			result.append(card)
	return result

func _lock_suits(cards: Array[Card], match_number: int) -> Array[Card]:
	if Missions.allows_alk(match_number):
		return cards
	var result: Array[Card] = []
	for card in cards:
		if card.suit == Card.Suit.ALK:
			result.append(Card.new(randi_range(0, Card.Suit.CLUBS), card.printed_rank, card.owner, false, card.effect, card.stamp))
		else:
			result.append(card)
	return result

func random_trump_suit() -> Card.Suit:
	return [Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES, Card.Suit.CLUBS].pick_random()

func set_trump_suit(suit: Card.Suit) -> void:
	trump_suit = suit
	print("Trump suit: ", Card.Suit.keys()[trump_suit])
	trump_chosen.emit(trump_suit)

func generate_player_hands():	
	print("Drawing player hands")
	_place_scripted_cards(player_deck, 0, Card.Owner.HUMAN)
	_place_scripted_cards(AI_1_deck, 1, Card.Owner.AI_1)
	_place_scripted_cards(AI_2_deck, 2, Card.Owner.AI_2)
	player_hand = Hand.new()
	AI_1_hand = Hand.new()
	AI_2_hand = Hand.new()

	GameManager.human_player.recieve_hand(player_hand)
	GameManager.ai_player_1.recieve_hand(AI_1_hand)
	GameManager.ai_player_2.recieve_hand(AI_2_hand)

	await _deal_cards([
		[player_deck, GameManager.human_player, Card.Owner.HUMAN],
		[AI_1_deck, GameManager.ai_player_1, Card.Owner.AI_1],
		[AI_2_deck, GameManager.ai_player_2, Card.Owner.AI_2],
	])

	print("All Hands drawn")

func _deal_cards(seats: Array) -> void:
	var counts: Array[int] = []
	for seat in seats:
		counts.append(mini(HAND_SIZE, seat[0].cards.size()))

	for slot in range(HAND_SIZE):
		for i in range(seats.size()):
			if slot >= counts[i]:
				continue
			var deck: Deck = seats[i][0]
			seats[i][1].deal_card(deck.cards.pop_back(), _deck_pile_center(seats[i][2], seats[i][1]), slot, counts[i])
			await get_tree().create_timer(DEAL_INTERVAL, false).timeout

	await get_tree().create_timer(DEAL_SETTLE_TIME, false).timeout
	for seat in seats:
		seat[1].finish_deal()

func _deck_pile_center(owner: Card.Owner, fallback: Control) -> Vector2:
	for pile in get_tree().get_nodes_in_group(GameManager.DECK_PILE_GROUP):
		if pile.deck_owner == owner:
			return pile.global_position
	return fallback.global_position

func _place_scripted_cards(deck: Deck, seat: int, owner: Card.Owner) -> void:
	var planned: Array = TutorialScript.hand_cards(seat)
	for i in min(planned.size(), deck.cards.size()):
		var index: int = deck.cards.size() - 1 - i
		deck.replace_card(index, Card.new(planned[i][0], planned[i][1], owner, false, entry_effect(planned[i])))

func is_legal_play(hand: Hand, card: Card) -> bool:
	if not hand.contains(card):
		return false
	if leading_card == null or card.is_colorless():
		return true
	if leading_card.is_trump:
		return card.is_trump or not hand.has_trump_card()
	var lead := lead_suit()
	if lead < 0:
		return true
	return card.suit == lead or not hand.contains_card_of_suit(lead)

func lead_suit() -> int:
	if leading_card == null or leading_card.is_colorless():
		return -1
	return leading_card.suit

func generate_cards(amount: int, owner : Card.Owner, min_rank: int = 0) -> Array[Card]:
	var cards: Array[Card] = []

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(amount):
		var random_suit: Card.Suit = rng.randi_range(0, Card.Suit.CLUBS)
		var random_rank: int = rng.randi_range(min_rank, 9)

		var card := Card.new(
			random_suit,
			random_rank,
			owner,
			false
		)
		cards.append(card)
	return cards


# In this function the Card Manager should get through the active buffs and update the cards of that player
func update_cards(cigarettes_lit: int, player_id: int = 0) -> void:
	if cigarettes_lit <= 0:
		return
	PlayerDataManager.smoke(player_id, cigarettes_lit * PlayerDataManager.SMOKE_BONUS_PER_CIGARETTE)

func submit_play(player_id: int, card: Card, from: Transform2D = Transform2D.IDENTITY) -> void:
	if card == null:
		GameManager.play_callback(player_id)
		return

	# Track leading card
	if leading_card == null:
		leading_card = card
	
	# Track first played trump suit
	if first_trump_card == null and card.is_trump:
		first_trump_card = card

	played_cards_turn.append(card)
	played_cards_round.append(card)
	render_played_card(card, from)
	Sfx.play(CARD_PLAYED_SOUND, 0.1)
	card_played.emit(player_id, card)
	if card.suit == Card.Suit.SMOKE:
		PlayerDataManager.unlock_smoke()

	if card.has_effect():
		var token := GameManager.round_token
		await CardEffect.on_played(card, player_id)
		if token != GameManager.round_token:
			return
	last_played_by[player_id] = card

	GameManager.play_callback(player_id)
	print("played: ", card)
	print("contains: ", played_cards_round.cards[0])

func render_played_card(card : Card, from: Transform2D) -> void:
	
	var card_visual := preload("res://scenes/Card.tscn").instantiate() as CardVisual
	card_visual.setup(card, false)
	card_visual.add_table_shadow()
	
	table_root.add_child(card_visual)

	var center := _get_table_center_world()

	var offset : Vector2
	
	match card.owner:
		Card.Owner.HUMAN:
			offset = Vector2(0, -135)
		Card.Owner.AI_1:
			offset = Vector2(-70, -160)
		Card.Owner.AI_2:
			offset = Vector2(60, -195)

	card_visual.global_position = center + offset
	card_visual.scale = Vector2(1.5, 1.5)

	# Layering: later plays on top
	card_visual.z_index = played_cards_turn.size()
	card_visual.update_layout()
	card_visual.float_in_from(from)

func turn_clean_up() -> void:
	leading_card = null
	first_trump_card = null
	
	if played_cards_turn.size() == 0:
		return
	
	played_cards_turn.empty()

func clear_table() -> void:
	if table_root == null:
		return
	var visuals: Array[CardVisual] = []
	for child in table_root.get_children():
		if child is CardVisual and played_cards_turn.cards.has(child.card):
			visuals.append(child)
	if visuals.is_empty():
		return
	var top := table_root.get_viewport().get_visible_rect().position.y
	var duration := 0.0
	for i in visuals.size():
		var delay := i * CLEAR_STAGGER
		visuals[i].fly_off_top(top, delay, CLEAR_TIME)
		Sfx.play_card_move(delay)
		duration = maxf(duration, delay + CLEAR_TIME)
	await get_tree().create_timer(duration, false).timeout

func collect_table(winner: Card.Owner) -> void:
	var pile := won_pile_of(winner)
	if table_root == null or pile == null:
		await clear_table()
		return
	var winning_card := get_turn_winning_card()
	var visuals: Array[CardVisual] = []
	var winner_visual: CardVisual = null
	for child in table_root.get_children():
		if child is CardVisual and played_cards_turn.cards.has(child.card):
			visuals.append(child)
			if child.card == winning_card:
				winner_visual = child
	if visuals.is_empty():
		return
	if winner_visual == null:
		winner_visual = visuals[visuals.size() - 1]
	winner_visual.z_index = top_z_of(visuals)
	for i in visuals.size():
		var visual := visuals[i]
		var graveyard := graveyard_of(visual.card.owner)
		var delay := i * CLEAR_STAGGER
		var center := visual.global_position + visual.size * 0.5
		if graveyard == null:
			visual.fly_off_top(table_root.get_viewport().get_visible_rect().position.y, delay, CLEAR_TIME)
		else:
			var slot := graveyard.top_position()
			get_tree().create_timer(COLLECT_GATHER_TIME + delay + COLLECT_FLIP_TIME + COLLECT_FLY_TIME, false).timeout.connect(graveyard.add_cards.bind(1))
			visual.collect_to(center, slot, Vector2.ONE, COLLECT_GATHER_TIME + delay, COLLECT_FLIP_TIME, COLLECT_FLY_TIME)
		Sfx.play_card_move(COLLECT_GATHER_TIME + delay + COLLECT_FLIP_TIME)
	var cards_time := COLLECT_GATHER_TIME + (visuals.size() - 1) * CLEAR_STAGGER + COLLECT_FLIP_TIME + COLLECT_FLY_TIME
	await get_tree().create_timer(cards_time, false).timeout
	var stack: BierdeckelStack = get_tree().get_first_node_in_group(BierdeckelStack.GROUP)
	if stack != null:
		Sfx.play_card_move()
		await Bierdeckel.fly(pile.get_parent(), stack.take(), pile.top_position())
	pile.add_turn()

func top_z_of(visuals: Array[CardVisual]) -> int:
	var top := 0
	for visual in visuals:
		top = maxi(top, visual.z_index)
	return top + 2

func won_pile_of(owner: Card.Owner) -> WonPile:
	for pile in get_tree().get_nodes_in_group(GameManager.WON_PILE_GROUP):
		if pile.pile_owner == owner:
			return pile
	return null

func graveyard_of(owner: Card.Owner) -> GraveyardPile:
	for pile in get_tree().get_nodes_in_group(GraveyardPile.GROUP):
		if pile.pile_owner == owner:
			return pile
	return null

func clear_all_cards() -> void:
	turn_clean_up()
	played_cards_round.empty()

	for hand in [player_hand, AI_1_hand, AI_2_hand]:
		if hand != null:
			hand.empty()

func get_turn_winning_card() -> Card:
	var zero := get_zero_beating_nine()
	if zero != null:
		return zero
	return get_normal_winning_card()

func get_normal_winning_card() -> Card:
	var highest_trump = played_cards_turn.get_highest_trump_card()
	if highest_trump != null:
		return highest_trump
	return played_cards_turn.get_highest_card_of_suit(lead_suit())

func highlight_turn_winner() -> CardVisual:
	var winning_card := get_turn_winning_card()
	if winning_card == null or table_root == null:
		return null
	for child in table_root.get_children():
		if child is CardVisual and child.card == winning_card:
			var others: Array[CardVisual] = []
			for other in table_root.get_children():
				if other is CardVisual and other != child:
					others.append(other)
			child.z_index = top_z_of(others)
			child.set_winner(true)
			Sfx.play_win_card()
			return child
	return null

func get_turn_winner() -> Card.Owner:
	return get_turn_winning_card().owner

func get_zero_beating_nine() -> Card:
	var best := get_normal_winning_card()
	if best == null or best.rank < ZERO_BEATS_RANK:
		return null
	for card in played_cards_turn.cards:
		if card.rank == 0 and card != best and _same_color(card, best):
			return card
	return null

func _same_color(card: Card, best: Card) -> bool:
	if best.is_trump:
		return card.is_trump and card.suit == best.suit
	return not card.is_trump and card.matches_suit(lead_suit())

func turn_won_by_tie() -> bool:
	var winner := get_turn_winning_card()
	if winner == null or get_zero_beating_nine() != null:
		return false
	for card in played_cards_turn.cards:
		if card == winner or card.rank != winner.rank:
			continue
		if winner.is_trump:
			if card.is_trump:
				return true
		elif not card.is_trump and card.matches_suit(lead_suit()):
			return true
	return false

func turn_won_by_zero() -> bool:
	return get_zero_beating_nine() != null

static func has_rank_at_least(cards: Array[Card], rank: int) -> bool:
	for card in cards:
		if card.rank >= rank:
			return true
	return false

func deck_of(player_id: int) -> Deck:
	match player_id:
		0:
			return player_deck
		1:
			return AI_1_deck
		2:
			return AI_2_deck
	return null

func draw_extra_card(player_id: int) -> void:
	var deck := deck_of(player_id)
	if deck == null or deck.cards.is_empty():
		return
	var hand := hand_of(player_id)
	if hand == null or hand.size() >= HAND_SIZE:
		return
	var card: Card = deck.cards.pop_back()
	print("Effect draw: player ", player_id, " draws ", card.string_info())
	await give_card(player_id, card)

func give_card(player_id: int, card: Card) -> void:
	var hand := hand_of(player_id)
	var player := GameManager.id_to_player(player_id)
	if hand == null or player == null or card == null:
		return
	var count := hand.size() + 1
	player.deal_card(card, _deck_pile_center(player.player_id_to_Owner(player_id), player), count - 1, count)
	await get_tree().create_timer(DEAL_SETTLE_TIME, false).timeout
	if is_instance_valid(player):
		player.finish_deal()
	apply_buffs(player_id)

func draw_tie_card(player_id: int) -> Card:
	var deck := deck_of(player_id)
	if deck == null or deck.cards.is_empty():
		return null
	return deck.cards.pop_back()

func return_tie_card(player_id: int, card: Card) -> void:
	var deck := deck_of(player_id)
	if deck != null and card != null:
		deck.cards.insert(0, card)

func show_tie_break(draws: Dictionary, losers: Array[int]) -> void:
	var ids: Array = draws.keys()
	var visuals := {}
	var homes := {}
	var tags := {}
	if table_root != null:
		ids.sort_custom(func(a, b): return _deck_pile_center(a as Card.Owner, table_root).x < _deck_pile_center(b as Card.Owner, table_root).x)
		var center := _get_table_center_world()
		for i in ids.size():
			var id: int = ids[i]
			var card: Card = draws[id]
			if card == null:
				continue
			var visual := preload("res://scenes/Card.tscn").instantiate() as CardVisual
			visual.setup(card, true)
			visual.add_table_shadow()
			visual.hover_enabled = false
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual.z_index = 40
			table_root.add_child(visual)
			visual.show_back()
			visual.pivot_offset = visual.size * 0.5
			_add_owner_outline(visual, TIE_OWNER_COLORS.get(id, Color.WHITE))
			var home := _deck_pile_center(id as Card.Owner, table_root)
			homes[id] = home
			visual.global_position = home - visual.size * 0.5
			var target := center + Vector2((i - (ids.size() - 1) * 0.5) * TIE_CARD_SPACING, -150.0)
			var tween := visual.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(visual, "global_position", target - visual.size * 0.5, TIE_FLY_TIME)
			tween.tween_property(visual, "scale", Vector2.ONE * TIE_CARD_SCALE, TIE_FLY_TIME)
			visuals[id] = visual
			tags[id] = _make_tie_tag(id, target + Vector2(0.0, visual.size.y * TIE_CARD_SCALE * 0.5 + TIE_TAG_GAP))
			Sfx.play_card_move()
	if visuals.is_empty():
		for id in ids:
			return_tie_card(id, draws[id])
		return
	await get_tree().create_timer(TIE_FLY_TIME, false).timeout
	for id in visuals:
		if is_instance_valid(visuals[id]):
			visuals[id].flip_face_up(TIE_FLIP_TIME)
		if is_instance_valid(tags[id]):
			tags[id].create_tween().tween_property(tags[id], "modulate:a", 1.0, TIE_TAG_FADE_TIME)
	await get_tree().create_timer(TIE_FLIP_TIME + TIE_REVEAL_PAUSE, false).timeout
	for id in visuals:
		var visual: CardVisual = visuals[id]
		if not is_instance_valid(visual):
			continue
		if losers.has(id):
			visual.shake_and_dim(TIE_LOSER_COLOR)
			_mark_tie_tag(tags[id], _tie_name(id) + (" tie again" if losers.size() > 1 else (" lose!" if _tie_name(id) == HUMAN_TIE_NAME else " loses!")), TIE_LOSER_TAG_COLOR)
		else:
			_mark_tie_tag(tags[id], _tie_name(id) + " safe", TIE_OWNER_COLORS.get(id, Color.WHITE).darkened(0.35))
	await get_tree().create_timer(TIE_RESULT_TIME, false).timeout
	for id in visuals:
		var tag = tags[id]
		if is_instance_valid(tag):
			var fade: Tween = tag.create_tween()
			fade.tween_property(tag, "modulate:a", 0.0, TIE_TAG_FADE_TIME)
			fade.tween_callback(tag.queue_free)
		var visual: CardVisual = visuals[id]
		if not is_instance_valid(visual):
			continue
		Sfx.play_card_move()
		var tween := visual.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(visual, "global_position", homes[id] - visual.size * 0.5, TIE_FLY_TIME)
		tween.tween_property(visual, "scale", Vector2.ONE, TIE_FLY_TIME)
		tween.tween_callback(visual.show_back).set_delay(TIE_FLY_TIME * 0.5)
		tween.chain().tween_callback(visual.queue_free)
	await get_tree().create_timer(TIE_FLY_TIME, false).timeout
	for id in ids:
		return_tie_card(id, draws[id])

func _add_owner_outline(visual: CardVisual, color: Color) -> void:
	var outline: Control = visual.get_node("PlayableOutline").duplicate()
	outline.name = "OwnerOutline"
	var material: ShaderMaterial = outline.material.duplicate()
	material.set_shader_parameter("outline_color", color)
	outline.material = material
	outline.visible = true
	visual.add_child(outline)

func _tie_name(player_id: int) -> String:
	if player_id == GameManager.HUMAN_ID and PlayerDataManager.player_name == "":
		return HUMAN_TIE_NAME
	return GameManager.player_name(player_id)

func _make_tie_tag(player_id: int, top_center: Vector2) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.z_index = 41
	tag.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = TIE_OWNER_COLORS.get(player_id, Color.WHITE).darkened(0.35)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = _tie_name(player_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TIE_TAG_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	tag.add_child(label)
	table_root.add_child(tag)
	tag.reset_size()
	tag.global_position = top_center - Vector2(tag.size.x * 0.5, 0.0)
	return tag

func _mark_tie_tag(tag: PanelContainer, text: String, color: Color) -> void:
	if not is_instance_valid(tag):
		return
	var style: StyleBoxFlat = tag.get_theme_stylebox("panel")
	style.bg_color = color
	var label: Label = tag.get_child(0)
	label.text = text
	var center_x := tag.global_position.x + tag.size.x * 0.5
	tag.reset_size()
	tag.global_position.x = center_x - tag.size.x * 0.5
	tag.pivot_offset = tag.size * 0.5
	var pulse := tag.create_tween().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(tag, "scale", Vector2.ONE * 1.2, 0.15)
	pulse.tween_property(tag, "scale", Vector2.ONE, 0.15)

# - - - HELPER - - -

func _get_table_center_world() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5 + 60.0)

func is_in_play_zone(point: Vector2) -> bool:
	return Rect2(_get_table_center_world() + PLAY_ZONE_OFFSET, PLAY_ZONE_SIZE).has_point(point)

func set_table_root(node: Control) -> void:
	table_root = node

func get_highest_lead_card() -> Card:
	return played_cards_turn.get_highest_card_of_suit(lead_suit())

func get_highest_trump_card() -> Card:
	return played_cards_turn.get_highest_trump_card()
