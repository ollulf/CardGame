extends Node

const RUNS := 6000
const PACKS_PER_VISIT := 3
const PLAYER_DECK_SIZE := 25
const TRUMP_VALUE := 10.0
const SPECIAL_VALUE := 1.0
const SMOKE := Card.Suit.SMOKE
const ALK := Card.Suit.ALK

var trump := 0
var suit_bonus := []
var last_rank := []
var drinks := 0
var smoke_bonus := []


func _ready() -> void:
	var line := "match:"
	for m in range(2, Missions.LAST_MATCH + 1):
		line += " M%d=%d%%" % [m, roundi(100.0 * player_survival(m, RUNS))]
	print("WINRATE ", line)
	get_tree().quit()


func player_survival(m: int, runs: int) -> float:
	var survived := 0
	for i in runs:
		if play_match(m) != 0:
			survived += 1
	return float(survived) / runs


func player_deck(m: int) -> Array:
	var cards: Array = []
	for card in PlayerDataManager.starter_deck():
		cards.append(_from_card(card))
	for visit in range(2, m + 1):
		for index in _offers(visit):
			for card in BoosterWindow.roll(PlayerDataManager.BOOSTERS[index], visit):
				cards.append(_from_card(card))
	cards.sort_custom(func(a, b): return _value(a) > _value(b))
	return cards.slice(0, PLAYER_DECK_SIZE)


func ai_deck(m: int, seat: int) -> Array:
	var cards: Array = []
	var min_rank := Missions.lowest_rank(m)
	for entry in Missions.deck_cards(m, seat):
		var suit: int = entry[0]
		if suit == ALK and not Missions.allows_alk(m):
			suit = randi_range(0, Card.Suit.CLUBS)
		var rank: int = entry[1]
		if rank < min_rank:
			rank = randi_range(min_rank, 9)
		cards.append({"suit": suit, "rank": rank, "effect": CardManager.entry_effect(entry)})
	while cards.size() < Missions.DECK_SIZE:
		cards.append({"suit": randi_range(0, Card.Suit.CLUBS), "rank": randi_range(min_rank, 9), "effect": CardEffect.Id.NONE})
	return cards


func play_match(m: int) -> int:
	var decks := [player_deck(m), ai_deck(m, 1), ai_deck(m, 2)]
	for deck in decks:
		deck.shuffle()
	var lost := [0, 0, 0]
	suit_bonus = [{}, {}, {}]
	last_rank = [-1, -1, -1]
	drinks = 0
	var budgets := [0, Missions.budget(m, 1), Missions.budget(m, 2)]
	smoke_bonus = []
	for seat in 3:
		var cigs := Missions.cigarette_limit(m, seat)
		if seat == 0:
			cigs = 3 if m == 2 else 6
		smoke_bonus.append(clampi(cigs / 3, 0, PlayerDataManager.MAX_SMOKE_BONUS) if cigs >= 0 else PlayerDataManager.MAX_SMOKE_BONUS)
	var starter := randi_range(0, 2)
	for round_index in 8:
		if round_index > 0 and m >= PlayerDataManager.DRINK_ROUND_FROM_MATCH:
			for seat in [1, 2]:
				if budgets[seat] >= PlayerDataManager.DRINK_ROUND_PRICE and randf() < 0.5:
					budgets[seat] -= PlayerDataManager.DRINK_ROUND_PRICE
					drinks += 1
		trump = randi_range(0, Card.Suit.CLUBS)
		var hands := [[], [], []]
		for seat in 3:
			for i in CardManager.HAND_SIZE:
				if not decks[seat].is_empty():
					hands[seat].append(decks[seat].pop_back())
		var wins := [0, 0, 0]
		var leader := starter
		for trick in CardManager.HAND_SIZE:
			var table: Array = []
			for k in 3:
				var seat := (leader + k) % 3
				if hands[seat].is_empty():
					continue
				var card := _choose(hands[seat], table, seat, wins, CardManager.HAND_SIZE - trick)
				hands[seat].erase(card)
				card["by"] = seat
				card["eff"] = _rank(card, seat)
				table.append(card)
				_on_played(card, seat, hands, decks)
			if table.is_empty():
				break
			var best := _winner(table)
			wins[best["by"]] += 1
			leader = best["by"]
		var fewest: int = wins.min()
		var losers := []
		for seat in 3:
			if wins[seat] == fewest:
				losers.append(seat)
		var loser: int = losers.pick_random()
		lost[loser] += 1
		if lost[loser] >= GameManager.MAX_LIVES:
			return loser
		starter = (starter + 1) % 3
	return lost.find(lost.max())


func _on_played(card: Dictionary, seat: int, hands: Array, decks: Array) -> void:
	match card["effect"]:
		CardEffect.Id.DRAW:
			if not decks[seat].is_empty():
				hands[seat].append(decks[seat].pop_back())
		CardEffect.Id.SUIT_UP:
			suit_bonus[seat][card["suit"]] = suit_bonus[seat].get(card["suit"], 0) + 1
		CardEffect.Id.TRUMP:
			if card["suit"] < ALK:
				trump = card["suit"]
	last_rank[seat] = card["eff"]


func _is_trump(card: Dictionary) -> bool:
	return card["suit"] == SMOKE or card["suit"] == ALK or card["suit"] == trump


func _rank(card: Dictionary, seat: int) -> int:
	var rank: int = card["rank"]
	if card["effect"] == CardEffect.Id.COPY and last_rank[seat] >= 0:
		return last_rank[seat]
	if card["suit"] == SMOKE:
		rank += smoke_bonus[seat]
	if card["suit"] == ALK:
		rank += drinks
	else:
		rank = maxi(rank - drinks, mini(rank, 1))
	return rank + suit_bonus[seat].get(card["suit"], 0)


func _winner(table: Array) -> Dictionary:
	var best: Dictionary = {}
	for card in table:
		if _is_trump(card) and (best.is_empty() or card["eff"] > best["eff"]):
			best = card
	if best.is_empty():
		best = table[0]
		for card in table:
			if card["suit"] == best["suit"] and card["eff"] > best["eff"]:
				best = card
	if best["eff"] >= CardManager.ZERO_BEATS_RANK:
		for card in table:
			if card["eff"] == 0 and card != best and card["suit"] == best["suit"]:
				return card
	return best


func _legal(hand: Array, table: Array) -> Array:
	if table.is_empty():
		return hand
	var lead: Dictionary = table[0]
	var follow: Array = []
	if _is_trump(lead):
		follow = hand.filter(func(c): return _is_trump(c))
	else:
		follow = hand.filter(func(c): return c["suit"] == lead["suit"] and not _is_trump(c))
	return follow if not follow.is_empty() else hand


func _cost(card: Dictionary, seat: int) -> float:
	var cost := float(_rank(card, seat))
	if card["rank"] == 0:
		cost = 4.0
	if _is_trump(card):
		cost += TRUMP_VALUE
	if card["effect"] != CardEffect.Id.NONE:
		cost -= SPECIAL_VALUE
	return cost


func _choose(hand: Array, table: Array, seat: int, wins: Array, tricks_left: int) -> Dictionary:
	var legal := _legal(hand, table)
	var by_cost := legal.duplicate()
	by_cost.sort_custom(func(a, b): return _cost(a, seat) < _cost(b, seat))
	var behind: bool = wins[seat] <= mini(wins[(seat + 1) % 3], wins[(seat + 2) % 3])
	if table.is_empty():
		if behind and tricks_left <= 2:
			return by_cost.back()
		for card in by_cost:
			if not _is_trump(card):
				return card
		return by_cost.front()
	for card in by_cost:
		var trial: Dictionary = card.duplicate()
		trial["by"] = seat
		trial["eff"] = _rank(card, seat)
		if _winner(table + [trial]) == trial:
			return card
	return by_cost.front()


func _value(card: Dictionary) -> float:
	var value := float(card["rank"])
	if card["suit"] == SMOKE or card["suit"] == ALK:
		value += 4.0
	if card["effect"] != CardEffect.Id.NONE:
		value += SPECIAL_VALUE
	return value


func _from_card(card: Card) -> Dictionary:
	return {"suit": card.suit, "rank": card.base_rank, "effect": card.effect}


func _offers(visit: int) -> Array:
	var pool: Array = []
	for i in range(1, PlayerDataManager.BOOSTERS.size()):
		if visit >= int(PlayerDataManager.BOOSTERS[i].get("from_match", 0)):
			pool.append(i)
	var picked := [0]
	while picked.size() < PACKS_PER_VISIT and not pool.is_empty():
		var total := 0
		for i in pool:
			total += int(PlayerDataManager.BOOSTERS[i].get("weight", 1))
		var roll := randi_range(1, maxi(total, 1))
		for i in pool:
			roll -= int(PlayerDataManager.BOOSTERS[i].get("weight", 1))
			if roll <= 0:
				picked.append(i)
				pool.erase(i)
				break
	return picked
